function Auth {
    param (
        [string]$ClientID
    )
    $OAuth = AuthCodeFlow -ClientID $ClientID
    $XboxLive = XboxLiveAuth -AccessToken $OAuth.access_token
    $XSTSAuth = MCXSTSAuth -XboxLiveToken $XboxLive.Token
    $LoginWithXbox = MCLoginWithXbox -UHs $XboxLive.DisplayClaims.xui[0].uhs -XSTSToken $XSTSAuth.Token
    $LoginWithXbox.access_token = ConvertTo-SecureString $LoginWithXbox.access_token -AsPlainText
    If ((MCStore -AccessToken $LoginWithXbox.access_token).items.game_minecraft) {
        return $LoginWithXbox.access_token
    } else {
        throw "This account doesn't own Minecraft Java Edition."
        exit
    }
}

function AuthCodeFlow {
    param(
        [string]$ClientID,
        [string]$RedirectURI = 'http://localhost:' + (Get-Random -Minimum 1024 -Maximum 65535) + '/',
        [string]$Scope = 'XboxLive.signin%20offline_access',
        [string]$State
    )
    $EncodedRedirectURI = [System.Web.HttpUtility]::UrlEncode($RedirectURI)
    Start-Process "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=$ClientID&response_type=code&redirect_uri=$EncodedRedirectURI&scope=$Scope&response_mode=query&state=$State"
    $HttpListener = New-Object System.Net.HttpListener
    $HttpListener.Prefixes.Add($RedirectURI)
    $HttpListener.Start()
    $Context = $HttpListener.GetContext()
    $Code = $Context.Request.QueryString['code']
    If ($Code) {
        $Context.Response.StatusCode = 200
    }
    $HttpListener.Stop()
    return Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=$Scope&code=$Code&redirect_uri=$EncodedRedirectURI&grant_type=authorization_code" | ConvertFrom-Json
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