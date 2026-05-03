function Auth {
    param (
        [string]$ClientId = '96008c85-c6f0-4cb5-a2dc-fe31d94e1177'
    )
    $OAuth = AuthCodeFlow -ClientId $ClientId
    $XboxLive = XboxLiveAuth -AccessToken $OAuth.access_token
    $XSTSAuth = MCXSTSAuth -XboxLiveToken $XboxLive.Token
    $LoginWithXbox = MCLoginWithXbox -UHs $XboxLive.DisplayClaims.xui[0].uhs -XSTSToken $XSTSAuth.Token
    $Return = @{}
    $Return.AccessToken = ConvertTo-SecureString $LoginWithXbox.access_token -AsPlainText
    $Return.RefreshToken = $OAuth.refresh_token
    $Return.ExpiresIn = $LoginWithXbox.expires_in
    $Return.Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss:fffZ' -AsUTC
    If ((MCStore -AccessToken $Return.AccessToken).items.product_minecraft) {
        return $Return
    } else {
        throw "This account doesn't own Minecraft Java Edition."
    }
}

function AuthCodeFlow {
    param(
        [string]$ClientId,
        [string]$RedirectURI = 'http://localhost:' + (Get-Random -Minimum 1024 -Maximum 65535) + '/',
        [string]$Scope = 'XboxLive.signin%20offline_access',
        [string]$State = (Get-Random -Minimum 10000 -Maximum 99999),
        [string]$Prompt = 'select_account',
        [string]$CodeVerifier = '',
        [string]$CodeChallengeMethod = 'S256'
    )
    if ($CodeChallengeMethod -ne '') {
        if ($CodeChallengeMethod -eq "S256") {
            If ($CodeVerifier -eq '') {
                $CodeVerifier = [System.Convert]::ToBase64String(([System.Text.Encoding]::ASCII.GetBytes((Get-Random -Minimum 10000000000000000000 -Maximum 99999999999999999999).ToString()))).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            }
            $CodeChallenge = [System.Convert]::ToBase64String(([System.Security.Cryptography.SHA256]::Create()).ComputeHash([System.Text.Encoding]::ASCII.GetBytes($CodeVerifier))).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        } else {
            $CodeChallengeMethod = 'plain'
        }
    }
    $EncodedRedirectURI = [System.Web.HttpUtility]::UrlEncode($RedirectURI)
    $HttpListener = New-Object System.Net.HttpListener
    $HttpListener.Prefixes.Add($RedirectURI)
    $HttpListener.Start()
    Start-Process "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=$ClientId&response_type=code&redirect_uri=$EncodedRedirectURI&scope=$Scope&response_mode=query&state=$State&prompt=$Prompt&code_challenge=$CodeChallenge&code_challenge_method=$CodeChallengeMethod"
    $Context = $HttpListener.GetContext()
    $Code = $Context.Request.QueryString['code']
    If ($Code -and $Context.Request.QueryString['state'] -eq $State) {
        $Context.Response.StatusCode = 200
        $ResponseString = "<HTML><BODY><h1>Success.</h1><h2>You can close this page now.</h2></BODY></HTML>"
        $Return = Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientId&scope=$Scope&code=$Code&redirect_uri=$EncodedRedirectURI&grant_type=authorization_code&code_verifier=$CodeVerifier" | ConvertFrom-Json
    } else {
        $Context.Response.StatusCode = 400
        $ResponseString = "<HTML><BODY><h1>$($Context.Request.QueryString['error'])</h1><h2>$ErrorDescription</h2></BODY></HTML>"
        $ErrorDescription = $Context.Request.QueryString['error_description']
    }
    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($ResponseString)
    $Context.Response.ContentLength64 = $Buffer.Length
    $Context.Response.OutputStream.Write($Buffer,0,$Buffer.Length)
    $HttpListener.Stop()
    if ($Return) {
        return $Return
    } else {
        throw $ErrorDescription
    }
}

function RefreshToken {
    param(
        [string]$ClientId,
        [string]$RefreshToken
    )
    return Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientId&scope=XboxLive.signin%20offline_access&refresh_token=$RefreshToken&grant_type=refresh_token" | ConvertFrom-Json
}

function DeviceCodeFlow {
    param(
        [string]$ClientId
    )
    return Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientId&scope=XboxLive.signin%20offline_access&grant_type=device_code" | ConvertFrom-Json
}

function XboxLiveAuth {
    param (
        [string]$AccessToken
    )
    return Invoke-WebRequest 'https://user.auth.xboxlive.com/user/authenticate' -Method 'POST' -Body "{""Properties"":{""AuthMethod"":""RPS"",""SiteName"":""user.auth.xboxlive.com"",""RpsTicket"":""d=$AccessToken""},""RelyingParty"":""http://auth.xboxlive.com"",""TokenType"":""JWT""}" -ContentType 'application/json' | ConvertFrom-Json
}

function MCXSTSAuth {
    param (
        [string]$XboxLiveToken
    )
    return Invoke-WebRequest 'https://xsts.auth.xboxlive.com/xsts/authorize' -Method 'POST' -Body "{""Properties"":{""SandboxId"":""RETAIL"",""UserTokens"":[""$XboxLiveToken""]},""RelyingParty"":""rp://api.minecraftservices.com/"",""TokenType"":""JWT""}" -ContentType 'application/json' | ConvertFrom-Json
}

function MCLoginWithXbox {
    param (
        [string]$UHs,
        [string]$XSTSToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/authentication/login_with_xbox' -Method 'POST' -Body "{""identityToken"":""XBL3.0 x=$UHs;$XSTSToken""}" -ContentType 'application/json' | ConvertFrom-Json
}

function MCStore {
    param (
        [securestring]$AccessToken,
        [string]$RequestId = (New-Guid).ToString()
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/entitlements/license?requestId=$RequestId" -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Write-Auth {
    $Auth = Auth
    $Auth.AccessToken = ConvertFrom-SecureString $Auth.AccessToken
    Set-Content -Path "auth.json" -Value ($Auth | ConvertTo-Json)
}

function Read-Auth {
    param (
        [string]$Path = "auth.json"
    )
    $Auth = Get-Content -Path $Path | ConvertFrom-Json
    $Auth.AccessToken = ConvertTo-SecureString $Auth.AccessToken
    return $Auth
}

#Account

function LookupProfileByName {
    param (
        [string]$Name
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/lookup/name/$Name" | ConvertFrom-Json
}

function LookupProfile {
    param (
        [string]$Uuid
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/lookup/$Uuid" | ConvertFrom-Json
}

function LookupBulkByName {
    param (
        [string[]]$Names
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/minecraft/profile/lookup/bulk/byname' -Method 'POST' -Body ($Names | ConvertTo-Json) | ConvertFrom-Json
}

function Get-ProfileByUuid {
    param (
        [string]$Uuid,
        [string]$Unsigned = 'true'
    )
    return Invoke-WebRequest "https://sessionserver.mojang.com/session/minecraft/profile/$Uuid?unsigned=$Unsigned" | ConvertFrom-Json
}

#Need AccessToken

function Get-Profile {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/minecraft/profile' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Get-Attribute {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/player/attributes' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Set-Attribute {
    param (
        [securestring]$AccessToken
    )
    
}

function Get-Blocklist {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/privacy/blocklist' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Get-Certificate {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/player/certificates' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Get-NameChange {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/minecraft/profile/namechange' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Get-GiftCodeStatus {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/productvoucher/giftcode' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Get-NameAvailable {
    param (
        [securestring]$AccessToken,
        [string]$Name
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/name/$Name/available" | ConvertFrom-Json
}

function Set-Name {
    param (
        [securestring]$AccessToken,
        [string]$Name
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/name/$Name" -Method 'PUT' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}

function Set-Skin {
    param (
        [securestring]$AccessToken,
        [string]$Variant = 'classic', #classic or slim
        [string]$URL
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/skins" -Method 'PUT' -Authentication 'Bearer' -Token $AccessToken -Body "variant=$Variant&url=$URL" | ConvertFrom-Json
}

function Add-Skin {
    param (
        [securestring]$AccessToken,
        [string]$Variant = 'classic', #classic or slim
        [string]$File
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/skins" -Method 'POST' -Authentication 'Bearer' -Token $AccessToken -Form @{'variant'=$Variant; 'file'=Get-Item -Path $File} | ConvertFrom-Json
}

function Reset-Skin {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/skins/active" -Method 'DELETE' -Authentication 'Bearer' -Token $AccessToken
}

function Set-Cape {
    param (
        [securestring]$AccessToken,
        [string]$CapeId
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/capes" -Method 'PUT' -Authentication 'Bearer' -Token $AccessToken -Body "capeId=$CapeId" | ConvertFrom-Json
}

function Reset-Cape {
    param (
        [securestring]$AccessToken
    )
    return Invoke-WebRequest "https://api.minecraftservices.com/minecraft/profile/capes/active" -Method 'DELETE' -Authentication 'Bearer' -Token $AccessToken
}