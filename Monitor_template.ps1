# Polling-Based Monitor - Lightweight and reliable
# Checks for Holdfast NaW.exe every 5 seconds using Get-Process (low resource usage)
$ErrorActionPreference = 'Stop'
$logFile = '%TARGET_FOLDER%\Monitor.log'
try {
  '=== Monitor.ps1 Started ===' | Out-File -FilePath $logFile -Append -Encoding UTF8
  'Timestamp: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $logFile -Append -Encoding UTF8
} catch { }
$exePath = "%EXE_PATH%"
'Executable path: ' + $exePath | Out-File -FilePath $logFile -Append -Encoding UTF8
if (-not (Test-Path $exePath)) {
  'ERROR: BlackFishOfficer.exe not found at: ' + $exePath | Out-File -FilePath $logFile -Append -Encoding UTF8
  exit 1
}

# State tracking for process detection
$holdfastRunning = $false

'Monitoring active - polling for Holdfast NaW.exe every 5 seconds...' | Out-File -FilePath $logFile -Append -Encoding UTF8

# Main polling loop
while($true) {
  try {
    $holdfast = Get-Process -Name "Holdfast NaW" -ErrorAction SilentlyContinue
    $currentHoldfastState = ($holdfast -ne $null)
    
    # Detect state change: Holdfast just started
    if ($currentHoldfastState -and !$holdfastRunning) {
      'Holdfast NaW.exe detected (started)' | Out-File -FilePath $logFile -Append -Encoding UTF8
      
      # Robust check for existing BlackFishOfficer process (check multiple times to avoid race conditions)
      $bf = $null
      $maxRetries = 3
      $retryCount = 0
      while ($retryCount -lt $maxRetries -and !$bf) {
        $bf = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
        if (!$bf) {
          Start-Sleep -Milliseconds 200
          $retryCount++
        }
      }
      
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
        'WARNING: Multiple BlackFishOfficer.exe processes detected (' + $allBfProcesses.Count + ' instances)' | Out-File -FilePath $logFile -Append -Encoding UTF8
        $bf = $allBfProcesses | Select-Object -First 1
      }
      
      if(!$bf) {
        # Double-check one more time right before starting to prevent race condition
        Start-Sleep -Milliseconds 100
        $bf = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
        if (!$bf) {
          try {
            $allProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exePath }
            if ($allProcesses) {
              $bf = $allProcesses | Select-Object -First 1
            }
          } catch {
            # Path comparison might fail, ignore
          }
        }
      }
      
      if(!$bf) {
        'Starting BlackFishOfficer.exe...' | Out-File -FilePath $logFile -Append -Encoding UTF8
        try {
          Start-Process -FilePath $exePath -WindowStyle Hidden -ErrorAction Stop
          Start-Sleep -Seconds 1
          # Verify it actually started
          $bf = Get-Process -Name "BlackFishOfficer" -ErrorAction SilentlyContinue
          if (!$bf) {
            try {
              $allProcesses = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exePath }
              if ($allProcesses) {
                $bf = $allProcesses | Select-Object -First 1
              }
            } catch {
              # Path comparison might fail, ignore
            }
          }
          if($bf) {
            'SUCCESS: BlackFishOfficer.exe started (PID: ' + $bf.Id + ')' | Out-File -FilePath $logFile -Append -Encoding UTF8
          } else {
            'ERROR: Failed to start BlackFishOfficer.exe' | Out-File -FilePath $logFile -Append -Encoding UTF8
          }
        } catch {
          'ERROR: Exception starting BlackFishOfficer.exe: ' + $_.Exception.Message | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
      } else {
        'BlackFishOfficer.exe already running (PID: ' + $bf.Id + ')' | Out-File -FilePath $logFile -Append -Encoding UTF8
      }
      $holdfastRunning = $true
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

