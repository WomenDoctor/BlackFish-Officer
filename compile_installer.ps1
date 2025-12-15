# NSIS Installer Compilation Script
# This script finds the official NSIS Unicode build and compiles the installer
# 
# IMPORTANT: This installer requires the official NSIS Unicode build (not Large Strings build)
# - Download from: https://nsis.sourceforge.io/
# - Standard installation: C:\Program Files (x86)\NSIS\ or C:\Program Files\NSIS\
# - The Unicode build provides proper UTF-16 file handling required for keybinds editing

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "NSIS Installer Compiler" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Check if installer.nsi exists in Helper Scripts folder
$nsiFile = Join-Path $PSScriptRoot "Helper Scripts\installer.nsi"
if (-not (Test-Path $nsiFile)) {
    Write-Host "[ERROR] installer.nsi not found!" -ForegroundColor Red
    Write-Host "Expected location: $nsiFile" -ForegroundColor Yellow
    exit 1
}

# Extract version number from installer.nsi
Write-Host "Extracting version number from installer.nsi..." -ForegroundColor Cyan
$version = $null

try {
    # Try multiple regex patterns to find version
    $content = Get-Content -Path $nsiFile -Raw -ErrorAction Stop
    $patterns = @(
        '!define\s+VERSION\s+"([^"]+)"',
        '!define\s+VERSION\s+''([^'']+)''',
        'VERSION\s*=\s*"([^"]+)"',
        'VERSION\s*=\s*''([^'']+)'''
    )
    
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $version = $matches[1]
            Write-Host "Found version using pattern: $pattern" -ForegroundColor Gray
            break
        }
    }
    
    # Also try Select-String as fallback
    if (-not $version) {
        $versionLine = Select-String -Path $nsiFile -Pattern '!define\s+VERSION\s+"([^"]+)"' | Select-Object -First 1
        if ($versionLine -and $versionLine.Matches.Groups.Count -gt 1) {
            $version = $versionLine.Matches.Groups[1].Value
        }
    }
} catch {
    Write-Host "[WARNING] Error reading installer.nsi: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($version) {
    Write-Host "Found version: $version" -ForegroundColor Green
    
    # Increment version number (patch version - last number)
    $versionParts = $version -split '\.'
    if ($versionParts.Count -ge 3) {
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        $patch = [int]$versionParts[2]
        $patch++
        $newVersion = "$major.$minor.$patch"
        Write-Host "Incrementing version: $version -> $newVersion" -ForegroundColor Cyan
        
        # Update version in installer.nsi
        $content = Get-Content -Path $nsiFile -Raw
        # Use a more specific pattern to avoid issues with $ in replacement
        $oldPattern = '!define\s+VERSION\s+"[^"]+"'
        $newLine = "!define VERSION `"$newVersion`""
        $content = $content -replace $oldPattern, $newLine
        Set-Content -Path $nsiFile -Value $content -NoNewline
        
        $version = $newVersion
        Write-Host "Version updated in installer.nsi: $version" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Version format not recognized, cannot increment" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARNING] Could not extract version number from installer.nsi" -ForegroundColor Yellow
    Write-Host "Using default version: 1.0.0" -ForegroundColor Yellow
    $version = "1.0.0"
}

# Prompt for change description (or use parameter)
if ($args.Count -gt 0 -and $args[0]) {
    $changeDescription = $args[0]
    Write-Host "Using description from parameter: $changeDescription" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Enter a brief description of changes (or press Enter to skip, timeout: 10 seconds):" -ForegroundColor Cyan
    
    # Use a simple timeout approach with Read-Host
    # Since Read-Host blocks, we'll use a background job to implement timeout
    $changeDescription = ""
    $job = Start-Job -ScriptBlock {
        $input = Read-Host
        return $input
    }
    
    # Wait for job with 10 second timeout
    $result = Wait-Job $job -Timeout 10
    
    if ($result) {
        # Job completed (user entered something or pressed Enter)
        $changeDescription = Receive-Job $job
        Remove-Job $job -ErrorAction SilentlyContinue
    } else {
        # Timeout - stop the job and skip description
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -ErrorAction SilentlyContinue
        Write-Host "(Timeout - skipping description)" -ForegroundColor Gray
        $changeDescription = ""
    }
}

# Create backup of source code
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating Source Code Backup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$backupDir = Join-Path $PSScriptRoot "SourceCodeInstallerBackups"
Write-Host "Backup directory: $backupDir" -ForegroundColor Gray

# Ensure backup directory exists
try {
    if (-not (Test-Path $backupDir)) {
        $null = New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop
        Write-Host "Created backup directory" -ForegroundColor Green
    } else {
        Write-Host "Backup directory exists" -ForegroundColor Green
    }
} catch {
    Write-Host "[ERROR] Failed to create backup directory: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Cannot create backup without directory. Exiting." -ForegroundColor Red
    exit 1
}

# Generate backup filename with version and timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host "Version: $version" -ForegroundColor Gray

# Build filename: installer_v{VERSION}_{DESCRIPTION}_{TIMESTAMP}.nsi
$backupFileName = "installer_v$version"

if ($changeDescription -and $changeDescription.Trim() -ne "") {
    # Sanitize description for filename (remove invalid characters)
    $sanitizedDesc = $changeDescription -replace '[<>:"/\\|?*]', '_' -replace '\s+', '_'
    # Remove leading/trailing underscores
    $sanitizedDesc = $sanitizedDesc.Trim('_')
    # Limit length
    if ($sanitizedDesc.Length -gt 50) {
        $sanitizedDesc = $sanitizedDesc.Substring(0, 50).TrimEnd('_')
    }
    if ($sanitizedDesc) {
        $backupFileName = "${backupFileName}_$sanitizedDesc"
        Write-Host "Description: $changeDescription" -ForegroundColor Gray
    }
}

# Always add timestamp
$backupFileName = "${backupFileName}_$timestamp.nsi"
$backupPath = Join-Path $backupDir $backupFileName

Write-Host "Backup filename: $backupFileName" -ForegroundColor Cyan
Write-Host "Full path: $backupPath" -ForegroundColor Gray
Write-Host ""

# Copy installer.nsi to backup location
Write-Host "Copying installer.nsi to backup location..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $nsiFile)) {
        throw "Source file not found: $nsiFile"
    }
    
    Copy-Item -Path $nsiFile -Destination $backupPath -Force -ErrorAction Stop
    
    # Verify backup was created
    Start-Sleep -Milliseconds 100  # Brief pause to ensure file system sync
    if (Test-Path $backupPath) {
        $backupInfo = Get-Item $backupPath
        Write-Host "[SUCCESS] Backup created successfully!" -ForegroundColor Green
        Write-Host "  Filename: $backupFileName" -ForegroundColor Gray
        Write-Host "  Location: $backupPath" -ForegroundColor Gray
        Write-Host "  Size: $([math]::Round($backupInfo.Length / 1KB, 2)) KB" -ForegroundColor Gray
        if ($changeDescription -and $changeDescription.Trim() -ne "") {
            Write-Host "  Description: $changeDescription" -ForegroundColor Gray
        }
        Write-Host ""
    } else {
        throw "Backup file was not created at expected location"
    }
} catch {
    Write-Host "[ERROR] Failed to create backup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Source: $nsiFile" -ForegroundColor Yellow
    Write-Host "Destination: $backupPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Continuing with compilation anyway..." -ForegroundColor Yellow
    Write-Host ""
}

# Check if BlackFishOfficer.exe exists in Bundled Assets folder
$exeFile = Join-Path $PSScriptRoot "Bundled Assets\BlackFishOfficer.exe"
if (-not (Test-Path $exeFile)) {
    Write-Host "[WARNING] BlackFishOfficer.exe not found in Bundled Assets folder" -ForegroundColor Yellow
    Write-Host "The installer will check for it at runtime." -ForegroundColor Yellow
    Write-Host ""
}

# Search for makensis.exe (official NSIS Unicode build)
Write-Host "Searching for NSIS (makensis.exe)..." -ForegroundColor Cyan
Write-Host "NOTE: Must be the official NSIS Unicode build (not Large Strings build)" -ForegroundColor Yellow
Write-Host ""

$nsisPaths = @(
    "C:\Program Files (x86)\NSIS\makensis.exe",
    "C:\Program Files\NSIS\makensis.exe",
    "$env:LOCALAPPDATA\Programs\NSIS\makensis.exe",
    "$env:ProgramFiles\NSIS\makensis.exe"
)

$makensis = $null
foreach ($path in $nsisPaths) {
    if (Test-Path $path) {
        $makensis = $path
        Write-Host "[FOUND] $path" -ForegroundColor Green
        
        # Verify it's likely the Unicode build by checking file version
        try {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)
            Write-Host "  Version: $($versionInfo.FileVersion)" -ForegroundColor Gray
            Write-Host "  Product: $($versionInfo.ProductName)" -ForegroundColor Gray
        } catch {
            Write-Host "  (Could not read version info)" -ForegroundColor Gray
        }
        break
    } else {
        Write-Host "[NOT FOUND] $path" -ForegroundColor Gray
    }
}

# Also check in PATH
if (-not $makensis) {
    try {
        $pathResult = Get-Command makensis -ErrorAction Stop
        $makensis = $pathResult.Source
        Write-Host "[FOUND] $makensis (in PATH)" -ForegroundColor Green
        
        # Verify it's likely the Unicode build
        try {
            $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($makensis)
            Write-Host "  Version: $($versionInfo.FileVersion)" -ForegroundColor Gray
            Write-Host "  Product: $($versionInfo.ProductName)" -ForegroundColor Gray
        } catch {
            Write-Host "  (Could not read version info)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[NOT FOUND] makensis.exe not in PATH" -ForegroundColor Gray
    }
}

Write-Host ""

if (-not $makensis) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: NSIS not found!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure the official NSIS Unicode build is installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Download from: https://nsis.sourceforge.io/" -ForegroundColor Cyan
    Write-Host "IMPORTANT: Must be the Unicode build (default since NSIS 3.0)" -ForegroundColor Yellow
    Write-Host "           NOT the Large Strings build (causes UTF-16 issues)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common installation locations:" -ForegroundColor Yellow
    foreach ($path in $nsisPaths) {
        Write-Host "  - $path" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "If NSIS is installed in a different location, please run:" -ForegroundColor Yellow
    Write-Host '  "C:\Path\To\NSIS\makensis.exe" installer.nsi' -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Delete old compiled installer(s)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cleaning Old Installers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$parentDir = Split-Path $PSScriptRoot -Parent
$oldInstallerPattern = Join-Path $parentDir "BlackFishOfficer_Setup_v*.exe"
$oldInstallers = Get-ChildItem -Path $oldInstallerPattern -ErrorAction SilentlyContinue

if ($oldInstallers) {
    Write-Host "Found $($oldInstallers.Count) old installer(s) to delete:" -ForegroundColor Yellow
    foreach ($oldInstaller in $oldInstallers) {
        Write-Host "  Deleting: $($oldInstaller.Name)" -ForegroundColor Gray
        try {
            Remove-Item -Path $oldInstaller.FullName -Force -ErrorAction Stop
            Write-Host "    [DELETED]" -ForegroundColor Green
        } catch {
            Write-Host "    [ERROR] Failed to delete: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
} else {
    Write-Host "No old installers found to delete." -ForegroundColor Gray
    Write-Host ""
}

# Compile the installer
Write-Host "========================================" -ForegroundColor Green
Write-Host "Compiling Installer" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "NSIS Compiler: $makensis" -ForegroundColor Cyan
Write-Host "Script: $nsiFile" -ForegroundColor Cyan
Write-Host "Output: BlackFishOfficer_Setup.exe" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

& $makensis $nsiFile

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installer compiled successfully!" -ForegroundColor Green
    # Output is in project root (parent of "Needed to compile installer")
    $outputFile = Join-Path $parentDir "BlackFishOfficer_Setup_v$version.exe"
    Write-Host "Output: $outputFile" -ForegroundColor Cyan
    Write-Host ""
    if (Test-Path $outputFile) {
        $fileInfo = Get-Item $outputFile
        Write-Host "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "ERROR: Compilation failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error code: $LASTEXITCODE" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "  1. installer.nsi has no syntax errors" -ForegroundColor Yellow
    Write-Host "  2. BlackFishOfficer.exe exists (for runtime check)" -ForegroundColor Yellow
    Write-Host "  3. You have write permissions" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

