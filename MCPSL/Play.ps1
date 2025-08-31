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
    Invoke-WebRequest $VersionJson.downloads.client.url -OutFile "$Path/versions/$Id/$Id.jar"
}

function Prepare {
    param (
        [string]$VersionJson,
        [string]$Path = "$env:APPDATA/.minecraft"
    )
    $Version = $VersionJson | ConvertFrom-Json
    Invoke-WebRequest $Version.assetIndex.url -OutFile "$Path/assets/indexes/$($Version.assetIndex.id).json"
    if ((Get-FileHash -Algorithm 'SHA1' -Path "$Path/assets/indexes/$($Version.assetIndex.id).json").Hash -eq $Version.assetIndex.sha1) {
        $AssetIndex = Get-Content "$Path/assets/indexes/$($Version.assetIndex.id).json" | ConvertFrom-Json
        $Jobs = @()
        foreach ($Directory in ($AssetIndex | Get-Member -MemberType 'NoteProperty').Name) {
            $Directory
            foreach ($Name in ($AssetIndex.$Directory | Get-Member -MemberType 'NoteProperty').Name) {
                $Hash = ($AssetIndex).$Directory.$Name.hash
                $Jobs += Start-ThreadJob -Name $Name -ScriptBlock {
                    Invoke-WebRequest "https://resources.download.minecraft.net/$(($Using:Hash).Substring(0, 2))/$Using:Hash" -OutFile "$Using:Path/assets/objects/$(($Using:Hash).Substring(0, 2))/$Using:Hash"
                }
            }
        }
        Wait-Job $Jobs
    }
}

function Launch {
    param (
        [string]$VersionJsonPath,
        [string]$VersionJarPath,
        [string]$LibrariesPath,
        [string]$OsName,
        [string]$OsArch,
        [string]$JavaPath,
        [string]$NativesDirectory,
        [string]$LauncherName,
        [string]$LauncherVersion,
        [string]$Classpath,
        [string]$JVMArguments = '-Xmx2G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M',
        [string]$AuthPlayerName,
        [string]$VersionName,
        [string]$GameDirectory,
        [string]$AssetsRoot,
        [string]$AssetsIndexName,
        [string]$AuthUuid,
        [string]$AuthAccessToken,
        [string]$ClientId,
        [string]$AuthXuid,
        [string]$UserType,
        [string]$VersionType,
        [string]$ResolutionWidth,
        [string]$ResolutionHeight,
        [string]$QuickPlayPath,
        [string]$QuickPlaySingleplayer,
        [string]$QuickPlayMultiplayer,
        [string]$QuickPlayRealms
    )
    $VersionJson = Get-Content $VersionJsonPath | ConvertFrom-Json
    [string]$Arguments = $null
    foreach ($Argument in $VersionJson.arguments.jvm) {
        if ($Argument.rules) {
            $Join = $true
            foreach ($Rule in $Argument.rules) {
                if ($Rule.action -eq 'allow') {
                    if ($Rule.os.name -ne $OsName -or $Rule.os.arch -ne $OsArch) {
                        $Join = $false
                    }
                }
            }
            if ($Join) {
                $Arguments += "$($Argument.value) "
            }
        } else {
            $Arguments += "$Argument "
        }
    }
    $Arguments += "$JVMArguments "
    $Arguments += "$($VersionJson.logging.client.argument) "
    $Arguments += "$($VersionJson.mainClass)"
    foreach ($Argument in $VersionJson.arguments.game) {
        if ($Argument.rules) {
            $Join = $true
            foreach ($Rule in $Argument.rules) {
                if ($Rule.action -eq 'allow') {
                    if ($Rule.features.has_custom_resolution -and $ResolutionWidth -and $ResolutionHeight) {
                        $Join = $true
                    } else {
                        $Join = $false
                    }
                }
            }
            if ($Join) {
                $Arguments += "$($Argument.value) "
            }
        } else {
            $Arguments += "$Argument "
        }
    }
    if (-not $Classpath) {
        foreach ($Library in $VersionJson.libraries) {
            $Classpath += "$LibrariesPath/$($Library.downloads.artifact.path);"
        }
        $Classpath += "$VersionJarPath "
    }
    $Arguments = $Arguments.TrimEnd(" ")
    $Arguments = $Arguments.Replace('${natives_directory}',$NativesDirectory)
    $Arguments = $Arguments.Replace('${launcher_name}',$LauncherName)
    $Arguments = $Arguments.Replace('${launcher_version}',$LauncherVersion)
    $Arguments = $Arguments.Replace('${classpath}',$Classpath)
    $Arguments = $Arguments.Replace('${game_directory}',$GameDirectory)
    $Arguments = $Arguments.Replace('${assets_root}',$AssetsRoot)
    $Arguments = $Arguments.Replace('${assets_index_name}',$AssetsIndexName)
    $Arguments = $Arguments.Replace('${auth_player_name}',$AuthPlayerName)
    $Arguments = $Arguments.Replace('${auth_uuid}',$AuthUuid)
    $Arguments = $Arguments.Replace('${auth_access_token}',$AuthAccessToken)
    $Arguments = $Arguments.Replace('${clientid}',$ClientId)
    $Arguments = $Arguments.Replace('${auth_xuid}',$AuthXuid)
    $Arguments = $Arguments.Replace('${user_type}',$UserType)
    $Arguments = $Arguments.Replace('${version_name}',$VersionName)
    $Arguments = $Arguments.Replace('${version_type}',$VersionType)
    $Arguments = $Arguments.Replace('${resolution_width}',$ResolutionWidth)
    $Arguments = $Arguments.Replace('${resolution_height}',$ResolutionHeight)
    $Arguments = $Arguments.Replace('${quick_play_path}',$QuickPlayPath)
    $Arguments = $Arguments.Replace('${quick_play_singleplayer}',$QuickPlaySingleplayer)
    $Arguments = $Arguments.Replace('${quick_play_multiplayer}',$QuickPlayMultiplayer)
    $Arguments = $Arguments.Replace('${quick_play_realms}',$QuickPlayRealms)
    $Arguments
    'stop'
}

function Play {
    param (
        $test
    )
    
}

function GetJavaManifest {
    return Invoke-WebRequest 'https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json' | ConvertFrom-Json
}

function Install-MCJava {
    param (
        [string]$OS,
        [string]$Component,
        [string]$Path = "$env:LOCALAPPDATA/Packages/Microsoft.4297127D64EC6_8wekyb3d8bbwe/LocalCache/Local/runtime"
    )
    New-Item "$Path/$Component/$OS/$Component" -Type 'Directory' -Force | Out-Null
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