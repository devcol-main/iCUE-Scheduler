<#
  iCUE Scheduler - Switch-iCUEProfile.ps1
  Switches the active Corsair iCUE 5 profile (and keyboard brightness) by time of day.
  Settings live in schedule.json (edit them with the GUI: iCUE-Scheduler.vbs).

  (no arguments)  Called by Task Scheduler. Applies the current time slot ONCE per slot,
                  so anything you change by hand inside a slot is left alone until the next slot.
  -Force          Re-apply the current time slot right now.
  -ProfileName "Name" [-Brightness 0-100|keep]
                  Temporary (manual) override. Returns to the schedule at the next slot.

  How it works: iCUE has no public API for switching profiles, so the script closes iCUE,
  edits defaultProfile / BrightnessLevel in %APPDATA%\Corsair\CUE5\config.cuecfg and starts iCUE again.
#>
param([switch]$Force, [string]$ProfileName = '', [string]$Brightness = 'keep')
$ErrorActionPreference = "Stop"
$cueDir    = "$env:APPDATA\Corsair\CUE5"
$cfgPath   = "$cueDir\config.cuecfg"
$confPath  = "$PSScriptRoot\schedule.json"
$statePath = "$PSScriptRoot\state.json"
$logPath   = "$PSScriptRoot\scheduler.log"

function Get-IcueDir {
    $def = "$env:ProgramFiles\Corsair\Corsair iCUE5 Software"
    if (Test-Path "$def\iCUE.exe") { return $def }
    $k = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue |
         ? { $_.DisplayName -like 'Corsair iCUE*Software*' -and $_.InstallLocation } | Select-Object -First 1
    if ($k) { return $k.InstallLocation.TrimEnd('\') }
    $def
}
$icueDir  = Get-IcueDir
$launcher = Join-Path $icueDir 'iCUE Launcher.exe'
if (-not (Test-Path $launcher)) { $launcher = Join-Path $icueDir 'iCUE.exe' }

$lang = 'en'
function L($en, $ko) { if ($lang -eq 'ko') { $ko } else { $en } }
function Log($m){
    if ((Test-Path $logPath) -and (Get-Item $logPath).Length -gt 200KB) { Move-Item $logPath "$logPath.old" -Force }
    "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content -Path $logPath -Encoding UTF8
}

$manual = ($ProfileName -ne '')
$mutex = New-Object Threading.Mutex($false, "Global\iCUEProfileScheduler")
$wait = 0; if ($manual -or $Force) { $wait = 30000 }
if (-not $mutex.WaitOne($wait)) { exit 0 }
try {
    $conf = Get-Content $confPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($conf.language -eq 'ko') { $lang = 'ko' }
    if (-not $manual -and $conf.enabled -eq $false) { exit 0 }
    $entries = @($conf.schedule | % { [pscustomobject]@{ T=[TimeSpan]::Parse($_.time); Name=$_.profile; BL=$_.brightness } } | Sort-Object T)
    if ($entries.Count -eq 0) { Log (L 'Error: schedule is empty' '오류: 스케줄이 비어 있음'); exit 1 }

    # Current time slot and when it started
    $now = Get-Date
    $seg = @(foreach ($d in 0,-1) { foreach ($e in $entries) { [pscustomobject]@{ At=$now.Date.AddDays($d)+$e.T; E=$e } } }) |
           ? { $_.At -le $now } | Sort-Object At | Select-Object -Last 1
    $st = $null
    if (Test-Path $statePath) { try { $st = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
    # Already applied (or confirmed) in this slot -> respect whatever the user changed since
    if (-not $manual -and -not $Force -and $st -and ([datetime]$st.at) -ge $seg.At) { exit 0 }

    # Right after logon: give iCUE up to 90 s to start by itself
    if (-not $manual -and -not $Force) { for ($i=0; $i -lt 18 -and -not (Get-Process iCUE -EA SilentlyContinue); $i++) { Start-Sleep 5 } }

    # Target profile / brightness
    if ($manual) {
        $tName = $ProfileName; $reason = L 'manual' '수동'
        $tBL = $null; if ($Brightness -match '^\d+$') { $tBL = [Math]::Min(100,[int]$Brightness) }
    } else {
        $tName = $seg.E.Name; $reason = L 'schedule' '스케줄'; if ($Force) { $reason = L 'forced' '강제' }
        $tBL = $null; if ("$($seg.E.BL)" -match '^\d+$') { $tBL = [Math]::Min(100,[int]"$($seg.E.BL)") }
    }

    # Profile name -> GUID
    $guid = $null
    foreach ($f in Get-ChildItem "$cueDir\profiles\*.cueprofiledata") {
        $head = (Get-Content $f.FullName -TotalCount 12 -Encoding UTF8) -join "`n"
        $n = [System.Net.WebUtility]::HtmlDecode([regex]::Match($head, '<name>(.*?)</name>').Groups[1].Value)
        if ($n -eq $tName) { $guid = [regex]::Match($head, '<id>(\{[0-9a-fA-F-]{36}\})</id>').Groups[1].Value; break }
    }
    if (-not $guid) { Log (L "Error: profile '$tName' not found" "오류: 프로필 '$tName' 을(를) 찾을 수 없음"); exit 1 }

    function Save-State {
        $o = [pscustomobject]@{ at=(Get-Date -f 'yyyy-MM-ddTHH:mm:ss'); guid=$guid; name=$tName; brightness=$tBL; reason=$reason }
        [IO.File]::WriteAllText($statePath, (ConvertTo-Json -InputObject $o), (New-Object Text.UTF8Encoding $true))
    }
    $blText = L 'keep' '유지'; if ($tBL -ne $null) { $blText = "$tBL%" }

    # Nothing to change -> just record it
    $cfg = [IO.File]::ReadAllText($cfgPath)
    $cur   = [regex]::Match($cfg, '<value name="defaultProfile">(\{[^<]+\})</value>').Groups[1].Value
    $curBL = [regex]::Match($cfg, '<value name="BrightnessLevel">(\d+)</value>').Groups[1].Value
    $running = Get-Process -Name iCUE -EA SilentlyContinue
    $needP = ($cur -ne $guid)
    $needB = ($tBL -ne $null -and $curBL -ne "$tBL")
    if (-not $needP -and -not $needB -and $running) {
        Save-State
        if ($manual -or $Force) { Log (L "Already active: '$tName' · brightness $blText [$reason]" "이미 적용됨: '$tName' · 밝기 $blText [$reason]") }
        exit 0
    }

    # Close iCUE -> edit config -> start iCUE
    if ($running) {
        Stop-Process -Name iCUE -Force
        Wait-Process -Name iCUE -Timeout 20 -EA SilentlyContinue
        Start-Sleep -Seconds 2
    }
    Copy-Item $cfgPath "$cfgPath.bak" -Force
    $cfg = [IO.File]::ReadAllText($cfgPath)
    if ($cfg -match '<value name="defaultProfile">') {
        $cfg = [regex]::Replace($cfg, '(<value name="defaultProfile">)\{[^<]+\}(</value>)', "`${1}$guid`${2}")
    } else {
        $cfg = $cfg -replace '</config>', "`t<value name=`"defaultProfile`">$guid</value>`n</config>"
    }
    if ($tBL -ne $null) { $cfg = [regex]::Replace($cfg, '(<value name="BrightnessLevel">)\d+(</value>)', "`${1}$tBL`${2}") }
    [IO.File]::WriteAllText($cfgPath, $cfg, (New-Object Text.UTF8Encoding $false))
    Start-Process -FilePath $launcher -ArgumentList "--autorun"
    Save-State
    Log (L "Switched: '$tName' · brightness $blText [$reason]" "전환: '$tName' · 밝기 $blText [$reason]")
} catch { Log ((L 'Error: ' '오류: ') + $_); exit 1 }
finally { $mutex.ReleaseMutex() }