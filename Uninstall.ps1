<#
  iCUE Scheduler - Uninstall.ps1
  Removes the scheduled task, the desktop shortcut, the tray widget startup entry, and closes the tray widget.
  Your files in this folder are left as they are.
#>
Unregister-ScheduledTask -TaskName "iCUE Profile Scheduler" -Confirm:$false -ErrorAction SilentlyContinue
foreach ($lnk in (Join-Path ([Environment]::GetFolderPath('Desktop')) 'iCUE Scheduler.lnk'),
                 (Join-Path ([Environment]::GetFolderPath('Startup')) 'iCUE Scheduler Tray.lnk')) {
    if (Test-Path $lnk) { Remove-Item $lnk }
}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*ui\Tray.ps1*' -or $_.CommandLine -like '*ui\MainWindow.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host "Removed the scheduled task, shortcuts and tray widget. You can delete this folder now."