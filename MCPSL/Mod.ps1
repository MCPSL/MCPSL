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

function ModrinthCreateFacets {
    param (
        [string]$ProjectType,
        [string]$Categories,
        [string]$Versions,
        [string]$ClientSide,
        [string]$ServerSide,
        [string]$OpenSource 
    )
    [string]$Facets
    if ($ProjectType) {
        $Facets += "[project_type:$ProjectType],"
    }
    if ($Categories) {
        $Facets += "[categories:$Categories],"
    }
    if ($Versions) {
        $Facets += "[versions:$Versions],"
    }
    if ($ClientSide) {
        $Facets += "[client_side:$ClientSide],"
    }
    if ($ServerSide) {
        $Facets += "[server_side:$ServerSide],"
    }
    if ($OpenSource) {
        $Facets += "[open_source:$OpenSource],"
    }
    if ($Facets) {
        $Facets = $Facets.TrimEnd(',')
    }
    return "[$Facets]"
}

function ModrinthSearchProject {
    param (
        [string]$Query,
        [string]$Facets,
        [string]$Index = "relevance",
        [int]$Offset,
        [int]$Limit = 10
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/search" -Method 'GET' -Body @{
        query = $Query
        facets = $Facets
        index = $Index
        offset = $Offset
        limit = $Limit
    } | ConvertFrom-Json
}

function ModrinthGetProject {
    param (
        [string]$IdSlug
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/project/$IDSlug" | ConvertFrom-Json
}

function ModrinthGetMultipleProjects {
    param (
        [string]$IdSlugs
    )
    return Invoke-WebRequest 'https://api.modrinth.com/v2/projects' -Method 'GET' -Body @{
        ids = $IdSlugs
    } | ConvertFrom-Json
}

function ModrinthGetRandomProjectsList {
    param (
        [int]$Count
    )
    return Invoke-WebRequest 'https://api.modrinth.com/v2/projects/random' -Method 'GET' -Body @{
        count = $Count
    } | ConvertFrom-Json
}

function ModrinthCheckProjectValidity {
    param (
        [string]$IdSlug
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/project/$IdSlug/check" | ConvertFrom-Json
}

function ModrinthGetAllProjectDependencies {
    param (
        [string]$IdSlug
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/project/$IdSlug/dependencies" | ConvertFrom-Json
}

function ModrinthListProjectVersions {
    param (
        [string]$IdSlug
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/project/$IdSlug/version" | ConvertFrom-Json
}

function ModrinthGetVersion {
    param (
        [string]$VersionId
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/version/$VersionId" | ConvertFrom-Json
}

function ModrinthGetVersionFromIdOrNumber {
    param (
        [string]$IdSlug,
        [string]$VersionIdNumber
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/project/$IdSlug/version/$VersionIdNumber" | ConvertFrom-Json
}

function ModrinthGetMultipleVersions {
    param (
        [string]$VersionIds
    )
    return Invoke-WebRequest 'https://api.modrinth.com/v2/versions' -Method 'GET' -Body @{
        ids = $VersionIds
    } | ConvertFrom-Json
}

function GetVersionFromHash {
    param (
        [string]$Hash,
        [string]$Algorithm = 'sha1',
        [bool]$Multiple
    )
    Invoke-WebRequest "https://api.modrinth.com/v2/version/$Hash" -Method 'GET' -Body @{
        algorithm = $Algorithm
        multiple = $Multiple
    } | ConvertFrom-Json
}

function ModrinthGetLatestVersionFromHash {
    param (
        [string]$Hash,
        [string]$Algorithm = 'sha1',
        [string]$Loaders,
        [string]$GameVersions
    )
    return Invoke-WebRequest "https://api.modrinth.com/v2/version_file/$Hash/update?algorithm=$Algorithm" -Method 'POST' -Body @{
        loaders = $Loaders
        game_versions = $GameVersions
    } | ConvertFrom-Json
}

function ModrinthGetVersionsFromHashes {
    param (
        [string]$Hashes,
        [string]$Algorithm = 'sha1'
    )
    return Invoke-WebRequest 'https://api.modrinth.com/v2/version_files' -Method 'POST' -Body @{
        hashes = $Hashes
        algorithm = $Algorithm
    } | ConvertFrom-Json
}

function ModrinthGetLatestVersionsFromHashes {
    param (
        [string]$Hashes,
        [string]$Algorithm = 'sha1',
        [string]$Loaders,
        [string]$GameVersions
    )
    return Invoke-WebRequest 'https://api.modrinth.com/v2/version_files/update' -Method 'POST' -Body @{
        hashes = $Hashes
        algorithm = $Algorithm
        loaders = $Loaders
        game_versions = $GameVersions
    } | ConvertFrom-Json
}