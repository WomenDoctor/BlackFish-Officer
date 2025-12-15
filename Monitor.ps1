# Polling-Based Monitor - Lightweight and reliable
# Checks for Holdfast NaW.exe every 5 seconds using Get-Process (low resource usage)
# LEGITIMATE USE: This script is bundled with the installer and accepts command-line parameters
# It monitors for game process and automatically launches BlackFishOfficer.exe when the game starts
# Parameters are passed via command-line to avoid file modification (placeholder replacement),
# which reduces AV false positives by using static bundled scripts instead of dynamically generated ones.

param(
    [Parameter(Mandatory=$true)]
    [string]$TargetFolder,
    
    [Parameter(Mandatory=$true)]
    [string]$ExePath
)

$ErrorActionPreference = 'Stop'
$logFile = "$TargetFolder\Monitor.log"
$lockFile = "$TargetFolder\Monitor.lock"

# Prevent multiple instances from running simultaneously
# LEGITIMATE USE: Lock file prevents multiple Monitor.ps1 instances from launching duplicate BlackFishOfficer.exe processes
if (Test-Path $lockFile) {
  try {
    $lockContent = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue
    $lockPid = [int]$lockContent
    $lockProcess = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
    if ($lockProcess -and $lockProcess.ProcessName -eq "powershell") {
      # Another instance is running, exit silently
      exit 0
    }
  } catch {
    # Lock file exists but couldn't read it, assume stale and continue
  }
}

# Create lock file with current process ID
try {
  $PID | Out-File -FilePath $lockFile -Encoding UTF8 -ErrorAction Stop
} catch {
  'WARNING: Could not create lock file: ' + $_.Exception.Message | Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
  '=== Monitor.ps1 Started ===' | Out-File -FilePath $logFile -Append -Encoding UTF8
  'Timestamp: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $logFile -Append -Encoding UTF8
  'Process ID: ' + $PID | Out-File -FilePath $logFile -Append -Encoding UTF8
} catch { }
$exePath = $ExePath
'Executable path: ' + $exePath | Out-File -FilePath $logFile -Append -Encoding UTF8
if (-not (Test-Path $exePath)) {
  'ERROR: BlackFishOfficer.exe not found at: ' + $exePath | Out-File -FilePath $logFile -Append -Encoding UTF8
  Remove-Item $lockFile -ErrorAction SilentlyContinue
  exit 1
}

# State tracking for process detection
$holdfastRunning = $false

'Monitoring active - polling for Holdfast NaW.exe every 5 seconds...' | Out-File -FilePath $logFile -Append -Encoding UTF8

# Function to check if BlackFishOfficer.exe is running
function Check-BlackFishOfficer {
  param([string]$exePath)
  
  $bf = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
  
  # Also check by executable path to catch processes with different names
  if (!$bf) {
    try {
      $allProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exePath }
      if ($allProcesses) {
        $bf = $allProcesses | Select-Object -First 1
      }
    } catch {
      # Path comparison might fail if process doesn't have path accessible, ignore
    }
  }
  
  # Check if multiple instances exist (shouldn't happen, but handle it)
  $allBfProcesses = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
  if ($allBfProcesses -and $allBfProcesses.Count -gt 1) {
    'WARNING: Multiple BlackFishOfficer.exe processes detected (' + $allBfProcesses.Count + ' instances) - killing duplicates' | Out-File -FilePath $logFile -Append -Encoding UTF8
    # Keep the first one, kill the rest
    $allBfProcesses | Select-Object -Skip 1 | ForEach-Object {
      try {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        'Killed duplicate BlackFishOfficer.exe (PID: ' + $_.Id + ')' | Out-File -FilePath $logFile -Append -Encoding UTF8
      } catch { }
    }
    $bf = $allBfProcesses | Select-Object -First 1
  }
  
  return $bf
}

# Function to launch BlackFishOfficer.exe with guard against duplicates
function Start-BlackFishOfficer {
  param([string]$exePath)
  
  # CRITICAL: Always check if already running before launching (prevents multiple instances)
  $bf = Check-BlackFishOfficer -exePath $exePath
  
  if ($bf) {
    'BlackFishOfficer.exe already running (PID: ' + $bf.Id + ') - skipping launch' | Out-File -FilePath $logFile -Append -Encoding UTF8
    return $bf
  }
  
  # Double-check one more time right before starting to prevent race condition
  Start-Sleep -Milliseconds 200
  $bf = Check-BlackFishOfficer -exePath $exePath
  if ($bf) {
    'BlackFishOfficer.exe detected during final check (PID: ' + $bf.Id + ') - skipping launch' | Out-File -FilePath $logFile -Append -Encoding UTF8
    return $bf
  }
  
  'Starting BlackFishOfficer.exe...' | Out-File -FilePath $logFile -Append -Encoding UTF8
  try {
    Start-Process -FilePath $exePath -WindowStyle Hidden -ErrorAction Stop
    Start-Sleep -Seconds 1
    # Verify it actually started
    $bf = Check-BlackFishOfficer -exePath $exePath
    if($bf) {
      'SUCCESS: BlackFishOfficer.exe started (PID: ' + $bf.Id + ')' | Out-File -FilePath $logFile -Append -Encoding UTF8
    } else {
      'ERROR: Failed to start BlackFishOfficer.exe' | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
  } catch {
    'ERROR: Exception starting BlackFishOfficer.exe: ' + $_.Exception.Message | Out-File -FilePath $logFile -Append -Encoding UTF8
  }
  
  return $bf
}

# Main polling loop
while($true) {
  try {
    $holdfast = Get-Process -Name "Holdfast NaW" -ErrorAction SilentlyContinue
    $currentHoldfastState = ($holdfast -ne $null)
    
    # CRITICAL FIX: Always check if BlackFishOfficer.exe should be running when Holdfast is running
    # This prevents multiple launches if script restarts or multiple instances exist
    if ($currentHoldfastState) {
      # Holdfast is running - ensure BlackFishOfficer.exe is also running
      $bf = Check-BlackFishOfficer -exePath $exePath
      
      if (!$bf) {
        # Holdfast is running but BlackFishOfficer.exe is not - launch it
        'Holdfast NaW.exe is running but BlackFishOfficer.exe is not - launching...' | Out-File -FilePath $logFile -Append -Encoding UTF8
        $bf = Start-BlackFishOfficer -exePath $exePath
      }
      
      # Track state change for logging
      if (!$holdfastRunning) {
        'Holdfast NaW.exe detected (started)' | Out-File -FilePath $logFile -Append -Encoding UTF8
        $holdfastRunning = $true
      }
    }
    # Detect state change: Holdfast just stopped
    elseif (!$currentHoldfastState -and $holdfastRunning) {
      'Holdfast NaW.exe detected (stopped)' | Out-File -FilePath $logFile -Append -Encoding UTF8
      $bf = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
      if($bf) {
        'Stopping BlackFishOfficer.exe (PID: ' + $bf.Id + ')...' | Out-File -FilePath $logFile -Append -Encoding UTF8
        Stop-Process -Name "BlackFishOfficer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        $bf = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
        if(!$bf) {
          'SUCCESS: BlackFishOfficer.exe stopped' | Out-File -FilePath $logFile -Append -Encoding UTF8
        } else {
          'WARNING: BlackFishOfficer.exe still running after stop attempt' | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
      } else {
        'BlackFishOfficer.exe not running (no action needed)' | Out-File -FilePath $logFile -Append -Encoding UTF8
      }
      $holdfastRunning = $false
    }
  } catch {
    'ERROR in polling loop: ' + $_.Exception.Message | Out-File -FilePath $logFile -Append -Encoding UTF8
  }
  
  # Sleep 5 seconds between checks (low resource usage)
  Start-Sleep -Seconds 5
}

# Cleanup lock file on exit (shouldn't normally reach here, but just in case)
Remove-Item $lockFile -ErrorAction SilentlyContinue

