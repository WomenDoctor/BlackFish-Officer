Set WshShell = CreateObject("WScript.Shell")
strPS = "powershell.exe"
strScriptPath = "%MONITOR_SCRIPT_PATH%"
strTargetFolder = "%TARGET_FOLDER%"
strExePath = "%EXE_PATH%"
strArgs = "-NoProfile -NoLogo -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File " & Chr(34) & strScriptPath & Chr(34) & " -TargetFolder " & Chr(34) & strTargetFolder & Chr(34) & " -ExePath " & Chr(34) & strExePath & Chr(34)
strCommand = strPS & " " & strArgs
WshShell.Run strCommand, 0, False
