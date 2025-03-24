function OAuth2AuthorizationCodeRequest {
    param(
        [string]$ClientID,
        [string]$RedirectURI = "https://login.microsoftonline.com/common/oauth2/nativeclient"
    )
    $EncodedRedirectURI = [System.Web.HttpUtility]::UrlEncode($RedirectURI)
    Write-Output "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=$ClientID&response_type=code&redirect_uri=$EncodedRedirectURI&scope=XboxLive.signin%20offline_access"
}

function OAuth2AuthorizationCodeRedeem {
    param (
        [string]$ClientID,
        [string]$AuthorizationCode
    )
    Write-Output $(curl -X POST -d "client_id=$ClientID&scope=XboxLive.signin%20offline_access&code=$AuthorizationCode&redirect_uri=http%3A%2F%2Flocalhost&grant_type=authorization_code" "https://login.microsoftonline.com/consumers/oauth2/v2.0/token" | ConvertFrom-Json)
}

function OAuth2RefreshToken {
    param(
        [string]$ClientID,
        [string]$RefreshToken
    )
    Write-Output $(curl -X POST -d "client_id=$ClientID&scope=XboxLive.signin%20offline_access&refresh_token=$RefreshToken&grant_type=refresh_token" "https://login.microsoftonline.com/consumers/oauth2/v2.0/token" | ConvertFrom-Json)
}

function OAuth2DeviceCodeFlow {
    param(
        [string]$ClientID
    )
    Write-Output $(curl -X POST -d "client_id=$ClientID&scope=XboxLive.signin%20offline_access&grant_type=device_code" "https://login.microsoftonline.com/consumers/oauth2/v2.0/token" | ConvertFrom-Json)
}

function XboxLiveAuth {
    param (
        [string]$AccessToken
    )
    Write-Output $(curl -X POST --json '{"Properties":{"AuthMethod":"RPS","SiteName":"user.auth.xboxlive.com","RpsTicket":"d=$AccessToken"},"RelyingParty":"http://auth.xboxlive.com","TokenType":"JWT"}' "https://user.auth.xboxlive.com/user/authenticate" | ConvertFrom-Json)
}

function XSTSAuth {
    param (
        [string]$XboxLiveToken
    )
    Write-Output $(curl -X POST --json '{"Properties":{"SandboxId":"RETAIL","UserTokens":["$XboxLiveToken"]},"RelyingParty":"rp://api.minecraftservices.com/","TokenType":"JWT"}' "https://xsts.auth.xboxlive.com/xsts/authorize" | ConvertFrom-Json)
}

function LoginWithXbox {
    param (
        [string]$UHs,
        [string]$XSTSToken
    )
    Write-Output $(curl -X POST --json '{"identityToken":"XBL3.0 x=$UHs;$XSTSToken"}' "https://api.minecraftservices.com/authentication/login_with_xbox" | ConvertFrom-Json)
}

function MCStore {
    param (
        [string]$AccessToken
    )
    Write-Output $(curl -H "Authorization: Bearer $AccessToken" "https://api.minecraftservices.com/entitlements/mcstore" | ConvertFrom-Json)
}