$pluginsDir = ".\space-engineers\298740\Plugins"
New-Item -Path $pluginsDir -ItemType Directory -Force | Out-Null

# First arg controls overwrite
$overwrite = $args[0]
$guids = $args[1..($args.Count - 1)] | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

# Temp dir for downloads
$tempDir = Join-Path $env:TEMP ("torch_" + [guid]::NewGuid().ToString())
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

Write-Output "Downloading plugins"

$ProgressPreference='SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Download AMPUtilities and MayhemSync directly
$directDownloads = @(
    @{ Name = "AMPUtilities.zip"; Url = "https://cdn.mayhem-gaming.com/space-engineers/plugins/AMPUtilities.zip" },
    @{ Name = "MayhemSync.zip"; Url = "https://cdn.mayhem-gaming.com/space-engineers/plugins/MayhemSync.zip" }
)

foreach ($download in $directDownloads) {
    $targetPath = Join-Path $pluginsDir $download.Name
    
    if ((Test-Path $targetPath) -and $overwrite -ne "true") {
        Write-Output "Existing plugin $($download.Name) skipped"
        continue
    }
    
    try {
        Write-Output "Downloading $($download.Name)"
        Invoke-WebRequest -Uri $download.Url -OutFile $targetPath -UseBasicParsing
        Write-Output "Plugin $($download.Name) downloaded"
    } catch {
        Write-Output "Failed to download $($download.Name)"
    }
}

# Loop through each provided GUID
foreach ($guid in $guids) {
    $cleanGuid = $guid -replace '[{}\s]', ''

    if ($cleanGuid -notmatch '^[a-fA-F0-9-]{36}$') {
        Write-Output "Skipping invalid GUID: $guid"
        continue
    }

    # Get actual filename via Content-Disposition header
    try {
        $head = Invoke-WebRequest -Uri "https://torchapi.com/plugin/download/$cleanGuid" -Method Head -UseBasicParsing
        if ($head.Headers["Content-Disposition"] -match 'filename="?([^"]+)"?') {
            $filename = $matches[1]
        }
    } catch {
        Write-Output "Failed to determine filename for GUID: $cleanGuid"
        continue
    }

    $pluginName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    $targetPath = Join-Path $pluginsDir $filename

    if ((Test-Path $targetPath) -and $overwrite -ne "true" -and $cleanGuid -ne "5c14d8ea-7032-4db1-a2e6-9134ef6cb8d9") {
        Write-Output "Existing plugin $pluginName skipped"
        continue
    } elseif ($cleanGuid -eq "5c14d8ea-7032-4db1-a2e6-9134ef6cb8d9" -or $cleanGuid -eq "your-guid-here") {
        Write-Output "Downloading AMPUtilities.zip"
        $targetPath = Join-Path $pluginsDir "AMPUtilities.zip"
        Invoke-WebRequest -Uri "https://cdn.mayhem-gaming.com/space-engineers/plugins/AMPUtilities.zip" -OutFile $targetPath -UseBasicParsing
    } elseif ($cleanGuid -eq "your-guid-here") {
        Write-Output "Downloading MayhemSync.zip"
        $targetPath = Join-Path $pluginsDir "MayhemSync.zip"
        Invoke-WebRequest -Uri "https://cdn.mayhem-gaming.com/space-engineers/plugins/MayhemSync.zip" -OutFile $targetPath -UseBasicParsing
    }

    # Clean any leftovers from previous loop
    Get-ChildItem -Path $tempDir -Filter '*.zip' -File -ErrorAction SilentlyContinue | Remove-Item -Force

    # Download with correct filename
    try {
        $tempFile = Join-Path $tempDir $filename
        Invoke-WebRequest -Uri "https://torchapi.com/plugin/download/$cleanGuid" -OutFile $tempFile -UseBasicParsing
        if (Test-Path $tempFile) {
            Move-Item -Force -Path $tempFile -Destination $targetPath
            Write-Output "Plugin $pluginName downloaded"
        } else {
            Write-Output "Download succeeded but file not found: $filename"
        }
    } catch {
        Write-Output "Failed to download for GUID: $cleanGuid"
    }
}

# Final cleanup
Remove-Item -Recurse -Force -Path $tempDir -ErrorAction SilentlyContinue
Write-Output "Done"
