# AutoHotkey v2 Compilation Script with Custom Icon
# Run: powershell -ExecutionPolicy Bypass -File compile_ahk.ps1

$ErrorActionPreference = "Continue"

# Set console encoding to UTF-8 for proper display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Paths relative to Helper Scripts folder
$parentDir = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $parentDir "Bundled Assets\BlackFishOffcierV137.ahk"
$iconPath = Join-Path $parentDir "Bundled Assets\BlackFish_2.ico"
# Output to installer's Bundled Assets folder
$projectRoot = Split-Path $parentDir -Parent
$installerAssetsDir = Join-Path $projectRoot "Needed to compile installer\Bundled Assets"
$outputPath = Join-Path $installerAssetsDir "BlackFishOfficer.exe"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "AutoHotkey v2 Compiler" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Try to find Ahk2Exe.exe in common locations
$ahk2exePaths = @(
    "C:\Program Files\AutoHotkey\v2\Compiler\Ahk2Exe.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\Compiler\Ahk2Exe.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\Compiler\Ahk2Exe.exe"
)

Write-Host "Searching for Ahk2Exe.exe..." -ForegroundColor Yellow
Write-Host ""

$ahk2exe = $null
foreach ($path in $ahk2exePaths) {
    if (Test-Path $path) {
        $ahk2exe = $path
        Write-Host "[FOUND] $path" -ForegroundColor Green
        break
    }
}

# If still not found, do a system-wide search
if (-not $ahk2exe) {
    Write-Host "Performing system-wide search..." -ForegroundColor Yellow
    $systemSearch = Get-ChildItem -Path "C:\Program Files" -Filter "Ahk2Exe.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($systemSearch) {
        $ahk2exe = $systemSearch.FullName
        Write-Host "[FOUND] $ahk2exe" -ForegroundColor Green
    }
}

Write-Host ""

if (-not $ahk2exe) {
    Write-Host "ERROR: Ahk2Exe.exe not found!" -ForegroundColor Red
    Write-Host "Please install AutoHotkey v2 with compiler component" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] Script file not found: $scriptPath" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Script found: $scriptPath" -ForegroundColor Green

# Check for WaluigiTime.wav in the same directory as the script (required for FileInstall)
$wavFile = Join-Path $parentDir "Bundled Assets\WaluigiTime.wav"
if (-not (Test-Path $wavFile)) {
    Write-Host "[WARNING] WaluigiTime.wav not found: $wavFile" -ForegroundColor Yellow
    Write-Host "FileInstall will fail - WaluigiTime.wav must be in the same folder as the .ahk script" -ForegroundColor Yellow
} else {
    Write-Host "[OK] WaluigiTime.wav found: $wavFile" -ForegroundColor Green
}

if (-not (Test-Path $iconPath)) {
    Write-Host "[WARNING] Icon file not found: $iconPath" -ForegroundColor Yellow
    Write-Host "Compiling without custom icon..." -ForegroundColor Yellow
    $iconPath = $null
} else {
    Write-Host "[OK] Icon found: $iconPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting compilation..." -ForegroundColor Green
Write-Host "Output will be written to: $outputPath" -ForegroundColor Cyan
Write-Host ""

# Ensure output directory exists
$outputDir = Split-Path $outputPath -Parent
if (-not (Test-Path $outputDir)) {
    Write-Host "Creating output directory: $outputDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Compile with custom icon
# Note: Ahk2Exe must be run from the directory containing the .ahk script for FileInstall to work
$scriptDir = Split-Path $scriptPath -Parent
$originalLocation = Get-Location
try {
    Set-Location $scriptDir
    if ($iconPath) {
        $process = Start-Process -FilePath $ahk2exe -ArgumentList "/in", "`"$scriptPath`"", "/out", "`"$outputPath`"", "/icon", "`"$iconPath`"" -Wait -NoNewWindow -PassThru
    } else {
        $process = Start-Process -FilePath $ahk2exe -ArgumentList "/in", "`"$scriptPath`"", "/out", "`"$outputPath`"" -Wait -NoNewWindow -PassThru
    }
    Set-Location $originalLocation
    
    if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
        Write-Host "SUCCESS! Compiled: $outputPath" -ForegroundColor Green
        $fileInfo = Get-Item $outputPath
        Write-Host "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Cyan
        
        # Apply version information and manifest using Resource Hacker
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Applying Version Information & Manifest" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Find Resource Hacker
        $resourceHackerPaths = @(
            "C:\Program Files\Resource Hacker\ResourceHacker.exe",
            "C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe",
            "$env:LOCALAPPDATA\Programs\Resource Hacker\ResourceHacker.exe",
            "$env:USERPROFILE\Downloads\ResourceHacker.exe",
            "$env:USERPROFILE\Desktop\ResourceHacker.exe"
        )
        
        $resourceHacker = $null
        foreach ($path in $resourceHackerPaths) {
            if (Test-Path $path) {
                $resourceHacker = $path
                Write-Host "[FOUND] Resource Hacker: $path" -ForegroundColor Green
                break
            }
        }
        
        # Also check in PATH
        if (-not $resourceHacker) {
            try {
                $pathResult = Get-Command ResourceHacker -ErrorAction Stop
                $resourceHacker = $pathResult.Source
                Write-Host "[FOUND] Resource Hacker: $resourceHacker (in PATH)" -ForegroundColor Green
            } catch {
                # Not in PATH
            }
        }
        
        if ($resourceHacker) {
            # Paths to resource files
            $versionInfoPath = Join-Path $parentDir "Bundled Assets\version_info.rc"
            $manifestPath = Join-Path $parentDir "Bundled Assets\app.manifest"
            
            # Check if resource files exist
            $applyVersion = Test-Path $versionInfoPath
            $applyManifest = Test-Path $manifestPath
            
            if ($applyVersion -or $applyManifest) {
                Write-Host "Applying resources to compiled executable..." -ForegroundColor Yellow
                
                try {
                    $success = $true
                    
                    if ($applyVersion) {
                        Write-Host "  - Adding version information..." -ForegroundColor Cyan
                        # Resource Hacker command: -open exe -save exe -action addoverwrite -res version_info.rc -mask VERSIONINFO,1,
                        $rhProcess = Start-Process -FilePath $resourceHacker -ArgumentList "-open", "`"$outputPath`"", "-save", "`"$outputPath`"", "-action", "addoverwrite", "-res", "`"$versionInfoPath`"", "-mask", "VERSIONINFO,1," -Wait -NoNewWindow -PassThru
                        if ($rhProcess.ExitCode -ne 0) {
                            Write-Host "    WARNING: Version info may not have been applied (exit code: $($rhProcess.ExitCode))" -ForegroundColor Yellow
                            $success = $false
                        }
                    }
                    
                    if ($applyManifest) {
                        Write-Host "  - Embedding manifest..." -ForegroundColor Cyan
                        # Resource Hacker command: -open exe -save exe -action addoverwrite -res app.manifest -mask 24,1,
                        $rhProcess = Start-Process -FilePath $resourceHacker -ArgumentList "-open", "`"$outputPath`"", "-save", "`"$outputPath`"", "-action", "addoverwrite", "-res", "`"$manifestPath`"", "-mask", "24,1," -Wait -NoNewWindow -PassThru
                        if ($rhProcess.ExitCode -ne 0) {
                            Write-Host "    WARNING: Manifest may not have been applied (exit code: $($rhProcess.ExitCode))" -ForegroundColor Yellow
                            $success = $false
                        }
                    }
                    
                    if ($success) {
                        Write-Host "SUCCESS! Version information and manifest applied" -ForegroundColor Green
                    } else {
                        Write-Host "WARNING: Some resources may not have been applied correctly" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "WARNING: Failed to apply resources: $($_.Exception.Message)" -ForegroundColor Yellow
                    Write-Host "Compilation succeeded, but version info/manifest not applied" -ForegroundColor Yellow
                }
            } else {
                Write-Host "[SKIP] Resource files not found, skipping version info/manifest" -ForegroundColor Yellow
                Write-Host "  Expected: $versionInfoPath" -ForegroundColor Gray
                Write-Host "  Expected: $manifestPath" -ForegroundColor Gray
            }
        } else {
            Write-Host "[SKIP] Resource Hacker not found" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To add version information and manifest:" -ForegroundColor Yellow
            Write-Host "  1. Download Resource Hacker (free):" -ForegroundColor Cyan
            Write-Host "     http://www.angusj.com/resourcehacker/" -ForegroundColor Cyan
            Write-Host "  2. Extract ResourceHacker.exe" -ForegroundColor Cyan
            Write-Host "  3. Place it in one of these locations:" -ForegroundColor Cyan
            foreach ($path in $resourceHackerPaths[0..2]) {
                Write-Host "     - $path" -ForegroundColor Gray
            }
            Write-Host "  4. Re-run this compilation script" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Note: Compilation succeeded, but version info/manifest not applied" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Output location verified in installer's Bundled Assets folder" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Compilation failed (exit code: $($process.ExitCode))" -ForegroundColor Red
        Write-Host "Input: $scriptPath" -ForegroundColor Yellow
        Write-Host "Output: $outputPath" -ForegroundColor Yellow
        if ($iconPath) {
            Write-Host "Icon: $iconPath" -ForegroundColor Yellow
        }
        Write-Host "`nNote: Exit code 54 may indicate AutoHotkey v1 compiler found instead of v2" -ForegroundColor Yellow
        Write-Host "Please ensure AutoHotkey v2 is installed with compiler component" -ForegroundColor Yellow
        Write-Host "`nAlso ensure WaluigiTime.wav is in the same folder as BlackFishOffcierV137.ahk" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

