<#
  iCUE Scheduler - Install.ps1
  Registers the "iCUE Profile Scheduler" task in Windows Task Scheduler and creates a desktop shortcut
  for the GUI. No administrator rights needed. Run it again after moving the folder or editing schedule.json.

    -Quiet        no console output
    -NoShortcut   do not create the desktop shortcut
#>
param([switch]$Quiet, [switch]$NoShortcut)
$ErrorActionPreference = "Stop"
$dir  = $PSScriptRoot
$user = "$env:USERDOMAIN\$env:USERNAME"
$confPath = "$dir\schedule.json"
if (-not (Test-Path $confPath)) { Copy-Item "$dir\schedule.example.json" $confPath }
$conf  = Get-Content $confPath -Raw -Encoding UTF8 | ConvertFrom-Json
$Times = @($conf.schedule | % { $_.time } | Sort-Object -Unique)
if ($Times.Count -eq 0) { throw "schedule.json has no entries." }
foreach ($t in $Times) { if ($t -notmatch '^([01]\d|2[0-3]):[0-5]\d$') { throw "Invalid time: $t (use HH:mm)" } }

$cal  = ($Times | % { "<CalendarTrigger><StartBoundary>2026-01-01T${_}:00</StartBoundary><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger>" }) -join ""
$desc = [Security.SecurityElement]::Escape("iCUE Scheduler: " + (($conf.schedule | % { "$($_.time) $($_.profile)" }) -join " / "))
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>$desc</Description></RegistrationInfo>
  <Triggers>
    $cal
    <LogonTrigger><UserId>$user</UserId><Delay>PT30S</Delay></LogonTrigger>
    <EventTrigger><Delay>PT15S</Delay><Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription></EventTrigger>
  </Triggers>
  <Principals><Principal id="Author"><UserId>$user</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author"><Exec><Command>wscript.exe</Command><Arguments>"$dir\run-hidden.vbs"</Arguments></Exec></Actions>
</Task>
"@
Register-ScheduledTask -TaskName "iCUE Profile Scheduler" -Xml $xml -Force | Out-Null

if (-not $NoShortcut) {
    $lnkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'iCUE Scheduler.lnk'
    $ws  = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
    $lnk.Arguments  = "`"$dir\iCUE-Scheduler.vbs`""
    $lnk.WorkingDirectory = $dir
    $icon = "$env:ProgramFiles\Corsair\Corsair iCUE5 Software\iCUE.exe"
    if (Test-Path $icon) { $lnk.IconLocation = "$icon,0" }
    $lnk.Description = "iCUE Scheduler"
    $lnk.Save()
}
# Keep the tray widget startup entry pointing at this folder
$startLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'iCUE Scheduler Tray.lnk'
if ($conf.trayStartup -eq $true) {
    $ws2 = New-Object -ComObject WScript.Shell; $s2 = $ws2.CreateShortcut($startLnk)
    $s2.TargetPath = "$env:WINDIR\System32\wscript.exe"; $s2.Arguments = "`"$dir\iCUE-Tray.vbs`""; $s2.WorkingDirectory = $dir; $s2.Save()
}
if (-not $Quiet) {
    Write-Host "Installed: task 'iCUE Profile Scheduler' ($($Times -join ', '))"
    if (-not $NoShortcut) { Write-Host "Desktop shortcut: iCUE Scheduler" }
}