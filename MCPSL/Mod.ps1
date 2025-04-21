function GetForgeVersionList {
    param (
        [string]$GameVersion = '*'
    )
    return ([xml](Invoke-WebRequest 'https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml').Content).metadata.versioning.versions.version -match "^$GameVersion-"
}

function GetForgeDownloadLink {
    param (
        [string]$Version,
        [string]$Type = 'installer'
    )
    return "https://maven.minecraftforge.net/net/minecraftforge/forge/$ForgeVersion/forge-$ForgeVersion-$Type.jar"
}

function GetFabricVersionList {
    param (
        [string]$GameVersion
    )
    return Invoke-WebRequest "https://meta.fabricmc.net/v2/versions/game/$GameVersion" | ConvertFrom-Json
}

function GetFabricInstallerList {
    return Invoke-WebRequest "https://meta.fabricmc.net/v2/versions/installer" | ConvertFrom-Json
}

function GetNeoForgeVersionList {
    param (
        [string]$GameVersion
    )
    return Invoke-WebRequest 'https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge' | ConvertFrom-Json
}

function GetNeoForgeVersionLatest {
    return Invoke-WebRequest 'https://maven.neoforged.net/api/maven/latest/version/releases/net%2Fneoforged%2Fneoforge' | ConvertFrom-Json
}

function GetNeoForgeDownloadLink {
    param (
        [string]$Version
    )
    return "https://maven.neoforged.net/releases/net/neoforged/neoforge/$Version/neoforge-$Version-installer.jar"
}