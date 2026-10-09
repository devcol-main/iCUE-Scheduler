'Runs Switch-iCUEProfile.ps1 without a console window (used by Task Scheduler)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\Switch-iCUEProfile.ps1""", 0, False
