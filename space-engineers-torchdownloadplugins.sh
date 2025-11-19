#!/bin/bash

pluginsDir="./space-engineers/298740/Plugins"
mkdir -p "$pluginsDir"

# First arg controls overwrite
overwrite="$1"
shift

# Temp dir for downloads
tempDir=$(mktemp -d)

echo "Downloading plugins"

# Download AMPUtilities and MayhemSync directly
directDownloads=(
    "AMPUtilities.zip:https://cdn.mayhem-gaming.com/space-engineers/plugins/AMPUtilities.zip"
    "MayhemSync.zip:https://cdn.mayhem-gaming.com/space-engineers/plugins/MayhemSync.zip"
)

for download in "${directDownloads[@]}"; do
    IFS=':' read -r name url <<< "$download"
    targetPath="$pluginsDir/$name"
    
    if [[ -f "$targetPath" && "$overwrite" != "true" ]]; then
        echo "Existing plugin $name skipped"
        continue
    fi
    
    echo "Downloading $name"
    if wget -qO "$targetPath" "$url"; then
        echo "Plugin $name downloaded"
    else
        echo "Failed to download $name"
    fi
done

# Loop through each provided GUID
for guid in "$@"; do
    cleanGuid=$(echo "$guid" | tr -d '{}[:space:]')

    if [[ ! "$cleanGuid" =~ ^[a-fA-F0-9-]{36}$ ]]; then
        echo "Skipping invalid GUID: $guid"
        continue
    fi

    # Get actual filename via Content-Disposition header
    filename=$(wget --spider --server-response "https://torchapi.com/plugin/download/$cleanGuid" 2>&1 \
        | grep -i 'Content-Disposition' \
        | sed -n 's/.*filename="\([^"]*\).*/\1/p')

    if [[ -z "$filename" ]]; then
        echo "Failed to determine filename for GUID: $cleanGuid"
        continue
    fi

    pluginName="${filename%.zip}"
    targetPath="$pluginsDir/$filename"

    if [[ -f "$targetPath" && "$overwrite" != "true" ]]; then
        echo "Existing plugin $pluginName skipped"
        continue
    fi

    # Clean any leftovers from previous loop
    rm -f "$tempDir"/*.zip >/dev/null 2>&1

    # Download with correct filename
    if wget -qO "$tempDir/$filename" "https://torchapi.com/plugin/download/$cleanGuid"; then
        if [[ -f "$tempDir/$filename" ]]; then
            mv -f "$tempDir/$filename" "$targetPath" >/dev/null 2>&1
            echo "Plugin $pluginName downloaded"
        else
            echo "Download succeeded but file not found: $filename"
        fi
    else
        echo "Failed to download for GUID: $cleanGuid"
    fi
done

# Final cleanup
rm -rf "$tempDir" >/dev/null 2>&1
echo "Done"
exit 0