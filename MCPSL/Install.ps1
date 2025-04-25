function Get-StringHash {
    param (
        [string]$String,
        [string]$Algorithm = 'SHA1'
    )
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.Write($String)
    $writer.Flush()
    $stringAsStream.Position = 0
    return (Get-FileHash -Algorithm $Algorithm -InputStream $stringAsStream).Hash
}

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
        [string]$Component,
        [string]$Path = "$env:LOCALAPPDATA/Packages/Microsoft.4297127D64EC6_8wekyb3d8bbwe/LocalCache/Local/runtime"
    )
    $ManifestDownload = (GetJavaManifest).$OS.$Component.manifest
    $Manifest = (Invoke-WebRequest $ManifestDownload.url).Content
    if ((Get-StringHash $Manifest) -eq $ManifestDownload.sha1 -and $Manifest.Length -eq $ManifestDownload.size) {
        $Manifest = $Manifest | ConvertFrom-Json
        $Manifest.files.Where{ $_.type -eq 'directory' }
        $Jobs = @()
        foreach ($Name in ($Manifest.files | Get-Member -MemberType 'NoteProperty').Name) {
            switch ($Manifest.files.$Name.type) {
                'directory' {
                    New-Item "$Path/$Component/$OS/$Component/$Name" -Type 'Directory' -Force | Out-Null
                }
                'file' {
                    $Jobs += Start-ThreadJob -Name $Name -ScriptBlock {
                        Invoke-WebRequest ($Using:Manifest).files.$Using:Name.downloads.raw.url -OutFile "$Using:Path/$Using:Component/$Using:OS/$Using:Component/$Using:Name"
                    }
                }
                default {}
            }
        }
        Wait-Job $Jobs
    }
}