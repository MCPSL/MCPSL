function Auth {
    param (
        [string]$ClientID = '96008c85-c6f0-4cb5-a2dc-fe31d94e1177'
    )
    $OAuth = AuthCodeFlow -ClientID $ClientID
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
        [string]$ClientID,
        [string]$RedirectURI = 'http://localhost:' + (Get-Random -Minimum 1024 -Maximum 65535) + '/',
        [string]$Scope = 'XboxLive.signin%20offline_access',
        [string]$State = (Get-Random -Minimum 10000 -Maximum 99999),
        [string]$Prompt = 'select_account'
    )
    $EncodedRedirectURI = [System.Web.HttpUtility]::UrlEncode($RedirectURI)
    Start-Process "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=$ClientID&response_type=code&redirect_uri=$EncodedRedirectURI&scope=$Scope&response_mode=query&state=$State&prompt=$Prompt"
    $HttpListener = New-Object System.Net.HttpListener
    $HttpListener.Prefixes.Add($RedirectURI)
    $HttpListener.Start()
    $Context = $HttpListener.GetContext()
    $Code = $Context.Request.QueryString['code']
    If ($Code -and $Context.Request.QueryString['state'] -eq $State) {
        $Context.Response.StatusCode = 200
        $ResponseString = "<HTML><BODY><h1>Success.</h1><h2>You can close this page now.</h2></BODY></HTML>"
        $Return = Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=$Scope&code=$Code&redirect_uri=$EncodedRedirectURI&grant_type=authorization_code" | ConvertFrom-Json
    } else {
        $Context.Response.StatusCode = 400
        $ResponseString = "<HTML><BODY><h1>$($Context.Request.QueryString['error_description'])</h1><h2>$ErrorDescription</h2></BODY></HTML>"
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
        [string]$ClientID,
        [string]$RefreshToken
    )
    return Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=XboxLive.signin%20offline_access&refresh_token=$RefreshToken&grant_type=refresh_token" | ConvertFrom-Json
}

function DeviceCodeFlow {
    param(
        [string]$ClientID
    )
    return Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=XboxLive.signin%20offline_access&grant_type=device_code" | ConvertFrom-Json
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
        [securestring]$AccessToken
    )
    return Invoke-WebRequest 'https://api.minecraftservices.com/entitlements/mcstore' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
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