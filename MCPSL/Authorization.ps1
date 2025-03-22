function OAuth2AuthCodeFlow {
    param(
        [string]$ClientID
    )
    Start-Process "https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize?client_id=$ClientID&response_type=code&redirect_uri=http%3A%2F%2Flocalhost&scope=XboxLive.signin%20offline_access"
    $JSON = curl -X POST -d "client_id=$ClientID&scope=XboxLive.signin%20offline_access&code=$Code&redirect_uri=http%3A%2F%2Flocalhost&grant_type=authorization_code" "https://login.microsoftonline.com/consumers/oauth2/v2.0/token" | ConvertFrom-Json
    Write-Output $JSON
}

function OAuth2RefreshToken {
    param(
        [string]$ClientID,
        [string]$RefreshToken
    )
    $JSON = curl -X POST -d "client_id=$ClientID&scope=XboxLive.signin%20offline_access&refresh_token=$RefreshToken&grant_type=refresh_token" "https://login.microsoftonline.com/consumers/oauth2/v2.0/token" | ConvertFrom-Json
    Write-Output $JSON
}

function OAuth2DeviceCodeFlow {
    param(
        [string]$ClientID
    )
    $JSON = curl -X POST -d "client_id=$ClientID&scope=XboxLive.signin%20offline_access&grant_type=device_code" "https://login.microsoftonline.com/consumers/oauth2/v2.0/token" | ConvertFrom-Json
    Write-Output $JSON
}

function XboxLiveAuth {
    param (
        [string]$AccessToken
    )
    $JSON = curl -X POST --json '{"Properties":{"AuthMethod":"RPS","SiteName":"user.auth.xboxlive.com","RpsTicket":"d=$AccessToken"},"RelyingParty":"http://auth.xboxlive.com","TokenType":"JWT"}' "https://user.auth.xboxlive.com/user/authenticate" | ConvertFrom-Json
    Write-Output $JSON
}

function XSTSAuth {
    param (
        [string]$XboxLiveToken
    )
    $JSON = curl -X POST --json '{"Properties":{"SandboxId":"RETAIL","UserTokens":["$XboxLiveToken"]},"RelyingParty":"rp://api.minecraftservices.com/","TokenType":"JWT"}' "https://xsts.auth.xboxlive.com/xsts/authorize" | ConvertFrom-Json
    Write-Output $JSON
}

function LoginWithXbox {
    param (
        [string]$UHs,
        [string]$XSTSToken
    )
    $JSON = curl -X POST --json '{"identityToken":"XBL3.0 x=$UHs;$XSTSToken"}' "https://api.minecraftservices.com/authentication/login_with_xbox" | ConvertFrom-Json
    Write-Output $JSON
}

function MCStore {
    param (
        [string]$AccessToken
    )
    $JSON = curl -H "Authorization: Bearer $AccessToken" "https://api.minecraftservices.com/entitlements/mcstore" | ConvertFrom-Json
    Write-Output $JSON
}