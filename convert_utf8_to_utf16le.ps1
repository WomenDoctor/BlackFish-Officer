# PowerShell script to convert UTF-8 file to UTF-16 LE with BOM
# Usage: .\convert_utf8_to_utf16le.ps1 -InputFile "path\to\utf8.txt" -OutputFile "path\to\utf16le.txt"
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
    
    # Read UTF-8 file content
    $content = [System.IO.File]::ReadAllText($InputFile, [System.Text.Encoding]::UTF8)
    
    # Write as UTF-16 LE (Unicode encoding includes BOM automatically)
    [System.IO.File]::WriteAllText($OutputFile, $content, [System.Text.Encoding]::Unicode)
    
    # Verify output file was created
    if (-not (Test-Path $OutputFile)) {
        Write-Error "Output file was not created: $OutputFile"
        exit 1
    }
    
    # Verify BOM exists (first 2 bytes should be 0xFF 0xFE)
    $bytes = [System.IO.File]::ReadAllBytes($OutputFile)
    if ($bytes.Length -lt 2 -or $bytes[0] -ne 0xFF -or $bytes[1] -ne 0xFE) {
        Write-Error "Output file does not have UTF-16 LE BOM"
        exit 1
    }
    
    exit 0
}
catch {
    Write-Error "Error converting file: $_"
    exit 1
}

