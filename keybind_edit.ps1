# KeybindEdit - Bundled PowerShell Script
# LEGITIMATE USE: This script is bundled with the installer and accepts command-line parameters
# It modifies game keybinds JSON files by applying changes from a changes file. NSIS doesn't
# have native JSON parsing, so PowerShell's ConvertFrom-Json/ConvertTo-Json are required.
# This is standard practice for installers that need to modify JSON configuration files.
#
# Parameters are passed via command-line to avoid file modification (placeholder replacement),
# which reduces AV false positives by using static bundled scripts instead of dynamically
# generated ones.

param(
    [Parameter(Mandatory=$true)]
    [string]$KeybindsFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ChangesFile
)

try {
    # Detect encoding and read keybinds file
    $bytes = [System.IO.File]::ReadAllBytes($KeybindsFile)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        # UTF-16 LE BOM detected
        $keybinds = Get-Content $KeybindsFile -Raw -Encoding Unicode | ConvertFrom-Json
        $writeAsUnicode = $true
    } else {
        # UTF-8 (no BOM or UTF-8 BOM)
        $keybinds = Get-Content $KeybindsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $writeAsUnicode = $false
    }
    
    # Read changes file as UTF-8
    $changes = Get-Content $ChangesFile -Raw -Encoding UTF8 | ConvertFrom-Json
    
    $controllerMap = $keybinds.ControllerMaps | Where-Object { $_.ID -eq 0 }
    if ($controllerMap) {
        $keyboardData = $controllerMap.KeyboardMapData | ConvertFrom-Json
        
        # Modify entries in place to preserve order
        foreach ($button in $keyboardData.buttonMaps) {
            # Check if this button should be removed
            $shouldRemove = $false
            foreach ($removeEntry in $changes.remove) {
                if ($button.actionId -eq $removeEntry.actionId -and $button.elementIdentifierId -eq $removeEntry.elementIdentifierId) {
                    $shouldRemove = $true
                    break
                }
            }
            if ($shouldRemove) {
                # Find matching add entry to modify in place
                foreach ($addEntry in $changes.add) {
                    if ($button.actionId -eq $addEntry.actionId) {
                        # Modify existing entry in place
                        $button.elementIdentifierId = $addEntry.elementIdentifierId
                        $button.keyboardKeyCode = 0
                        break
                    }
                }
            }
        }
        
        # Remove any entries that weren't modified (shouldn't happen, but safety check)
        $newButtonMaps = @()
        foreach ($button in $keyboardData.buttonMaps) {
            $shouldRemove = $false
            foreach ($removeEntry in $changes.remove) {
                if ($button.actionId -eq $removeEntry.actionId -and $button.elementIdentifierId -eq $removeEntry.elementIdentifierId) {
                    $shouldRemove = $true
                    break
                }
            }
            if (-not $shouldRemove) {
                $newButtonMaps += $button
            }
        }
        
        # Add any entries that don't exist yet (shouldn't happen if remove worked)
        foreach ($addEntry in $changes.add) {
            $exists = $false
            foreach ($existing in $newButtonMaps) {
                if ($existing.actionId -eq $addEntry.actionId -and $existing.elementIdentifierId -eq $addEntry.elementIdentifierId) {
                    $exists = $true
                    break
                }
            }
            if (-not $exists) {
                $newEntry = [PSCustomObject]@{
                    actionCategoryId = 0
                    actionId = $addEntry.actionId
                    elementType = 1
                    elementIdentifierId = $addEntry.elementIdentifierId
                    axisRange = 0
                    invert = $false
                    axisContribution = 0
                    keyboardKeyCode = 0
                    modifierKey1 = 0
                    modifierKey2 = 0
                    modifierKey3 = 0
                    enabled = $true
                }
                $newButtonMaps += $newEntry
            }
        }
        
        $keyboardData.buttonMaps = $newButtonMaps
        $controllerMap.KeyboardMapData = ($keyboardData | ConvertTo-Json -Compress -Depth 100)
        $output = $keybinds | ConvertTo-Json -Compress -Depth 100
        
        # Write using same encoding as original file
        if ($writeAsUnicode) {
            $enc = New-Object System.Text.UnicodeEncoding $false, $false
        } else {
            $enc = New-Object System.Text.UTF8Encoding $false
        }
        [System.IO.File]::WriteAllText($KeybindsFile, $output, $enc)
    }
    
    exit 0
} catch {
    Write-Host $_.Exception.Message
    exit 1
}

