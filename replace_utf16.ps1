# ReplaceInFileUTF16 - Bundled PowerShell Script
# LEGITIMATE USE: This script is bundled with the installer and accepts command-line parameters
# It performs UTF-16 file text replacement, which is required because NSIS native functions
# don't properly handle UTF-16 encoding. This is standard practice for installers that need
# to modify UTF-16 encoded configuration files.
#
# Parameters are passed via command-line to avoid file modification (placeholder replacement),
# which reduces AV false positives by using static bundled scripts instead of dynamically
# generated ones.

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$true)]
    [string]$SearchText,
    
    [Parameter(Mandatory=$true)]
    [string]$ReplacementText
)

try {
    # Verify file exists
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        exit 1
    }
    
    # Read UTF-16 file content
    $content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::Unicode)
    
    # Perform replacement with regex escape for search text
    $content = $content -replace [regex]::Escape($SearchText), $ReplacementText
    
    # Write back as UTF-16
    [System.IO.File]::WriteAllText($FilePath, $content, [System.Text.Encoding]::Unicode)
    
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

