# PowerShell script to convert UTF-16 LE file to UTF-8
# Usage: .\convert_utf16le_to_utf8.ps1 -InputFile "path\to\utf16le.txt" -OutputFile "path\to\utf8.txt"
# Returns: Exit code 0 on success, 1 on error

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

try {
    # Verify input file exists
    if (-not (Test-Path $InputFile)) {
        Write-Error "Input file does not exist: $InputFile"
        exit 1
    }
    
    # Read UTF-16 LE file content (Unicode encoding handles BOM automatically)
    $content = [System.IO.File]::ReadAllText($InputFile, [System.Text.Encoding]::Unicode)
    
    # Write as UTF-8 (no BOM for NsJSON compatibility)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutputFile, $content, $utf8NoBom)
    
    # Verify output file was created
    if (-not (Test-Path $OutputFile)) {
        Write-Error "Output file was not created: $OutputFile"
        exit 1
    }
    
    exit 0
}
catch {
    Write-Error "Error converting file: $_"
    exit 1
}

