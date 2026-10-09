<#
  iCUE Scheduler - Uninstall.ps1
  Removes the scheduled task and the desktop shortcut. Your files in this folder are left as they are.
#>
Unregister-ScheduledTask -TaskName "iCUE Profile Scheduler" -Confirm:$false -ErrorAction SilentlyContinue
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'iCUE Scheduler.lnk'
if (Test-Path $lnk) { Remove-Item $lnk }
Write-Host "Removed the scheduled task and desktop shortcut. You can delete this folder now."