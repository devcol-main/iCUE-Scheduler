'Opens the iCUE Scheduler window without a console window
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\ui\MainWindow.ps1""", 0, False
