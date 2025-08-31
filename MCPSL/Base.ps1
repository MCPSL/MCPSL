function MCPSLVersion {
    Write-Host "        _______________________" -ForegroundColor DarkGreen
    Write-Host "       /   _                  /" -ForegroundColor DarkGreen
    Write-Host "      /    \ \               / " -ForegroundColor DarkGreen
    Write-Host "     /      \ \             /  " -ForegroundColor DarkGreen
    Write-Host "    /        \ \           /   " -ForegroundColor DarkGreen
    Write-Host "   /        / /           /    " -ForegroundColor DarkGreen
    Write-Host "  /       / / ______     /     " -ForegroundColor DarkGreen
    Write-Host " /      /_/  (______)   /      " -ForegroundColor DarkGreen
    Write-Host "/______________________/       " -ForegroundColor DarkGreen
}

function GetOsName {
    if ($IsWindows) {
        return 'windows'
    }
    if ($IsLinux) {
        return 'linux'
    }
    if ($IsMacOS) {
        return 'osx'
    }
    return 'unknown'
}

# https://gist.github.com/TransparentLC/7a37a7867b0f65c0068035d00f49e09b
function PartiallyDownload([String]$Uri, [String]$OutFile, [Int64]$Start, [Int64]$End = 0, [String]$UserAgent = 'MCPSL/v1.0.0.0') {
    [Net.ServicePointManager]::DefaultConnectionLimit = [Int32]::MaxValue
    $Request = [Net.WebRequest]::Create($Uri)
    if ($End) {
        $Request.AddRange($Start, $End)
    }
    else {
        $Request.AddRange($Start)
    }
    $Request.UserAgent = $UserAgent
    $Request.Proxy = $null
    $Response = $Request.GetResponse()
    $Stream = $Response.GetResponseStream()
    $File = [IO.File]::Create($OutFile)
    $Stream.CopyTo($File)
    $File.Close()
    $Stream.Close()
    $Response.Close()
}

function Merge-File([String[]]$Source, [String]$Destination) {
    $destinationStream = [System.IO.FileStream]::new($Destination, [System.IO.FileMode]::Create)
    foreach ($SourcePath in $Source) {
        $sourceStream = [System.IO.FileStream]::new($SourcePath, [System.IO.FileMode]::Open)
        try {
            # Create a buffer to hold the data and copy the content
            $buffer = New-Object byte[] 1024  # Buffer of 1KB size
            $bytesRead = 0
            # Read and write in chunks
            while (($bytesRead = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $destinationStream.Write($buffer, 0, $bytesRead)
            }
        } finally {
            # Ensure source file stream is closed
            $sourceStream.Close()
        }
        Remove-Item $SourcePath
    }
    $destinationStream.Close()
}

function MultiThreadDownload([String]$Uri, [String]$OutFile, [Int32]$ThreadCount = 4, [Int32]$MinSliceSize = 256KB, [String]$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36') {
    [Net.ServicePointManager]::DefaultConnectionLimit = [Int32]::MaxValue
    [Int64]$Length = (Invoke-WebRequest $Uri -Method Head -UseBasicParsing -Proxy $null).Headers.'Content-Length'[0]
    [String[]]$Part = @()
    [Int64[]]$Start = @()
    [Int64[]]$End = @()
    [Management.Automation.PowerShell[]]$Job = @()
    [Object[]]$Handle = @()
    if (($MinSliceSize * $ThreadCount) -gt $Length) { $ThreadCount = [Math]::Floor($Length / $MinSliceSize) }

    for ($i = 0; $i -lt $ThreadCount; $i++) {
        $Start += $End[$i - 1] + [Int64](!!$i)
        $End += [Math]::Round($Length / $ThreadCount * ($i + 1))
        $Part += $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([GUID]::NewGuid().ToString('N') + '.bin')
        $Job += [PowerShell]::Create().AddScript(${Function:PartiallyDownload}).AddParameter('Uri', $Uri).AddParameter('OutFile', $Part[$i]).AddParameter('Start', $Start[$i]).AddParameter('End', $End[$i]).AddParameter('UserAgent', $UserAgent)
        $Handle += $Job[$i].BeginInvoke()
    }

    [Double]$Progress = 0
    [Int32]$Interval = 200
    [Boolean]$Complete = $false
    while (!$Complete) {
        Start-Sleep -Milliseconds $Interval

        $Complete = $true
        for ($i = 0; $i -lt $ThreadCount; $i++) {
            if (!$Handle[$i].IsCompleted) {
                $Complete = $false
                break
            }
        }

        for ($i = 0; $i -lt $ThreadCount; $i++) {
            if (!(Test-Path $Part[$i])) { continue }
            $Progress = (Get-Item $Part[$i]).Length / ($End[$i] - $Start[$i] + 1) * 100
            Write-Progress -Id $i -Activity ('Thread #{0} {1} - {2}' -f $i, $Start[$i], $End[$i]) -Status ('{0} / {1} {2:f2}%' -f (Get-Item $Part[$i]).Length, ($End[$i] - $Start[$i] + 1), $Progress) -PercentComplete $Progress
        }
    }

    for ($i = 0; $i -lt $ThreadCount; $i++) {
        Write-Progress -Id $i -Activity ('Thread {0} - {1}' -f $Start[$i], $End[$i]) -Completed
        $Job[$i].EndInvoke($Handle[$i])
        $Job[$i].Runspace.Close()
        $Job[$i].Dispose()
    }

    Merge-File -Source $Part -Destination $OutFile
}