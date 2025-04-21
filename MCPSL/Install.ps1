function GetMCVersionManifest {
    return Invoke-WebRequest 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json' | ConvertFrom-Json
}

function Install {
    param (
        [string]$Path = "$env:APPDATA/.minecraft",
        [string]$Icon = 'Furnace',
        [string]$Id,
        [string]$Name = $null
    )
    New-Item "$Path/versions/$Id/" -ItemType 'Directory'
    $LauncherProfiles = $(Get-Content "$Path/launcher_profiles.json" | ConvertFrom-Json)
    $ProfileId=$(New-Guid).ToString().Replace("-","")
    $LauncherProfiles.profiles | Add-Member $ProfileId @{
        created = $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss:fffZ' -AsUTC)
        icon = $Icon
        lastUsed = "1970-01-01T00:00:00.000Z"
        lastVersionId = $Id
        name = $Name
        type = "custom"
    }
    $LauncherProfiles | ConvertTo-Json | Set-Content "$Path/launcher_profiles.json"
    $Version = (GetMCVersionManifest).versions.Where{ $_.id -eq $Id }
    Invoke-WebRequest $Version.url -OutFile "$Path/versions/$Id/$Id.json"
    $VersionJson = Get-Content "$Path/versions/$Id/$Id.json" | ConvertFrom-Json
    Invoke-WebRequest $VersionJson.downloads.client -OutFile "$Path/versions/$Id/$Id.jar"
}

function GetJavaManifest {
    return Invoke-WebRequest 'https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json' | ConvertFrom-Json
}
function InstallJava {
    param (
        [string]$OS,
        [string]$Component
    )
    (GetJavaManifest).$OS.$Component
}