function MSAAuthCodeRequest {
    param(
        [string]$ClientID,
        [string]$RedirectURI = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
    )
    $EncodedRedirectURI = [System.Web.HttpUtility]::UrlEncode($RedirectURI)
    Write-Output "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=$ClientID&response_type=code&redirect_uri=$EncodedRedirectURI&scope=XboxLive.signin%20offline_access"
}

function MSAAuthCodeRedeem {
    param (
        [string]$ClientID,
        [string]$AuthorizationCode,
        [string]$RedirectURI = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
    )
    $EncodedRedirectURI = [System.Web.HttpUtility]::UrlEncode($RedirectURI)
    Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=XboxLive.signin%20offline_access&code=$AuthorizationCode&redirect_uri=$EncodedRedirectURI&grant_type=authorization_code" | ConvertFrom-Json
}

function MSARefreshToken {
    param(
        [string]$ClientID,
        [string]$RefreshToken
    )
    Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=XboxLive.signin%20offline_access&refresh_token=$RefreshToken&grant_type=refresh_token" | ConvertFrom-Json
}

function MSADeviceCodeFlow {
    param(
        [string]$ClientID
    )
    Invoke-WebRequest 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token' -Method 'POST' -Body "client_id=$ClientID&scope=XboxLive.signin%20offline_access&grant_type=device_code" | ConvertFrom-Json
}

function MSAXboxLiveAuth {
    param (
        [string]$AccessToken
    )
    Invoke-WebRequest 'https://user.auth.xboxlive.com/user/authenticate' -Method 'POST' -Body "{""Properties"":{""AuthMethod"":""RPS"",""SiteName"":""user.auth.xboxlive.com"",""RpsTicket"":""d=$AccessToken""},""RelyingParty"":""http://auth.xboxlive.com"",""TokenType"":""JWT""}" -ContentType 'application/json' | ConvertFrom-Json
}

function MSAMCXSTSAuth {
    param (
        [string]$XboxLiveToken
    )
    Invoke-WebRequest 'https://xsts.auth.xboxlive.com/xsts/authorize' -Method 'POST' -Body "{""Properties"":{""SandboxId"":""RETAIL"",""UserTokens"":[""$XboxLiveToken""]},""RelyingParty"":""rp://api.minecraftservices.com/"",""TokenType"":""JWT""}" -ContentType 'application/json' | ConvertFrom-Json
}

function MSAMCLoginWithXbox {
    param (
        [string]$UHs,
        [string]$XSTSToken
    )
    Invoke-WebRequest 'https://api.minecraftservices.com/authentication/login_with_xbox' -Method 'POST' -Body "{""identityToken"":""XBL3.0 x=$UHs;$XSTSToken""}" -ContentType 'application/json' | ConvertFrom-Json
}

function MSAMCStore {
    param (
        [securestring]$AccessToken
    )
    Invoke-WebRequest 'https://api.minecraftservices.com/entitlements/mcstore' -Authentication 'Bearer' -Token $AccessToken | ConvertFrom-Json
}