<#
  iCUE Scheduler - shared code for the main window (MainWindow.ps1) and the tray widget (Tray.ps1).
  Dot-source this file: . "$PSScriptRoot\Common.ps1"
#>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -AssemblyName System.Drawing, System.Windows.Forms

$AppVersion = '1.1.0'
$uiDir    = $PSScriptRoot
$root     = Split-Path $uiDir -Parent
$cfgFile  = Join-Path $root 'schedule.json'
$exFile   = Join-Path $root 'schedule.example.json'
$logFile  = Join-Path $root 'scheduler.log'
$install  = Join-Path $root 'Install.ps1'
$switchPs = Join-Path $root 'Switch-iCUEProfile.ps1'
$cueDir   = "$env:APPDATA\Corsair\CUE5"
$icueExe  = "$env:ProgramFiles\Corsair\Corsair iCUE5 Software\iCUE.exe"
$taskName = 'iCUE Profile Scheduler'
$RepoUrl  = 'https://github.com/devcol-main/iCUE-Scheduler'
$script:lang = 'en'
$Presets  = @(0,33,66,100)   # iCUE keyboard brightness steps (e.g. K70 RGB RAPIDFIRE)
# timeline colors: gradient start, gradient end, label text, dot
$Palette  = @(
    @('#14524A','#1A6B5F','#BFF3E6','#2FBFA4'), @('#3A2C74','#4A3699','#D8CEFF','#9B7BFF'),
    @('#6B3A14','#8A4A17','#FFE0C2','#E08A3C'), @('#6B1F4A','#8A2A5F','#FFD0E8','#FF5FA8'),
    @('#1D3A6B','#24508A','#CFE0FF','#5B9BFF'), @('#5A5214','#756B1A','#FFF3B0','#E0C43C'))

# ---------------- Strings (English / 한국어) ----------------
$StrTable = @{
 en = @{ Title='iCUE Scheduler'; NavHome='Home'; NavSched='Schedule'; NavLog='Activity'; NavSettings='Settings'
   Now='Now'; BrightNow='Keyboard brightness'; WhenFmt='{0} → {1} · in {2}'; Match='● Matches the schedule'; ManualOn='● Temporary override · back at the next switch'
   AutoOffState='Auto switching is off'; Unknown='(unknown)'; LegendFmt='{0} · brightness {1}'
   Auto='Auto switching'; On='On'; Off='Off'; TaskOkT='Task Scheduler OK'; TaskBad='Task not registered'; TaskFailT='Last run failed'
   LastOk='Last run {0}'; LastFail='Last run {0} · code {1}'; NoRun='Not run yet'
   Temp='Temporary override'; TempNote='Kept until the next switch ({0})'; TempBtn='Apply'
   Sched='Schedule'; Add='＋  Add time slot'; Start='Start time'; Prof='Profile'; Br='Keyboard brightness'; Custom='Custom'; Del='Delete time slot'
   Apply='Apply now'; Applying='Applying…'; Save='Save'; Unsaved='● Unsaved'; Keep='Keep'; AllDay='All day'; NextDay=' (next day)'; Missing='Not in iCUE'
   Log='Activity'; Folder='Open folder'; NoLog='(no activity yet)'
   Settings='Settings'; Lang='Language'; LangSub='언어'; Tray='Tray widget'; TraySub='Quick switching from the taskbar. Stays running in the background while on.'
   TrayStart='Start the tray widget with Windows'; TrayStartSub='Shows the tray icon when you sign in'
   FolderT='Program folder'; FolderSub='Settings and log files'; Open='Open'; Rereg='Re-register scheduled task'; ReregSub='Use this after moving the folder'; ReregBtn='Re-register'
   About='About'; AboutSub='Version {0} · Apache-2.0'; GitHub='GitHub'
   MinOne='At least one time slot is required'; BadTimeT='Invalid time (e.g. 05:00, 23:30)'; Dup='Duplicate time: {0}'; MissingT='Not found in iCUE: {0}'
   RegFail='Could not register the scheduled task (code {0})'; Saved='Saved · press Apply now to use it right away'; SaveFirst='Save your changes first'
   Busy='Already applying…'; ApplyingT='Restarting iCUE to apply…'; Done='{0} applied'; Failed='Failed to apply · see Activity'
   AutoOnT='Auto switching on'; AutoOffT='Auto switching off'; CloseArm='Unsaved changes · press ✕ again to close'; Err='Error: '; ChooseProfile='Choose a profile'
   Rereged='Scheduled task re-registered'; TrayOnT='Tray widget started'; TrayOffT='Tray widget closed'; WhatSched='Schedule'; WhatManual='Temporary settings'
   DurHM='{0}h {1}m'; DurM='{0}m'; TrayOpen='Open iCUE Scheduler'; TrayApply='Apply schedule now'; TrayExit='Exit tray widget'
   NowTag='now'; OpenWin='Open window'; ApplySchedShort='Apply schedule'; TrayTip='iCUE Scheduler · {0}'; BrHint='{0} · brightness has 4 steps: 0 / 33 / 66 / 100%'; BrHintGen='Keyboard brightness has 4 steps: 0 / 33 / 66 / 100%'; Rounded='iCUE applied {0}% · {1} supports 0 / 33 / 66 / 100% only' }
 ko = @{ Title='iCUE 스케줄러'; NavHome='홈'; NavSched='스케줄'; NavLog='기록'; NavSettings='설정'
   Now='지금'; BrightNow='키보드 밝기'; WhenFmt='{0} → {1} · {2} 후'; Match='● 스케줄과 일치'; ManualOn='● 임시 사용 중 · 다음 전환에서 복귀'
   AutoOffState='자동 전환 꺼짐'; Unknown='(알 수 없음)'; LegendFmt='{0} · 밝기 {1}'
   Auto='자동 전환'; On='켜짐'; Off='꺼짐'; TaskOkT='작업 스케줄러 정상'; TaskBad='작업 스케줄러 미등록'; TaskFailT='마지막 실행 실패'
   LastOk='마지막 실행 {0}'; LastFail='마지막 실행 {0} · 코드 {1}'; NoRun='실행 기록 없음'
   Temp='임시 사용'; TempNote='다음 전환({0})까지 유지'; TempBtn='적용'
   Sched='스케줄'; Add='＋  시간대 추가'; Start='시작 시각'; Prof='프로필'; Br='키보드 밝기'; Custom='직접 지정'; Del='시간대 삭제'
   Apply='지금 적용'; Applying='적용 중…'; Save='저장'; Unsaved='● 저장 안 됨'; Keep='유지'; AllDay='하루 종일'; NextDay=' (다음날)'; Missing='iCUE에 없음'
   Log='기록'; Folder='폴더 열기'; NoLog='(기록 없음)'
   Settings='설정'; Lang='언어'; LangSub='Language'; Tray='트레이 위젯 사용'; TraySub='작업 표시줄 아이콘에서 빠르게 전환합니다. 켜져 있는 동안 백그라운드에 상주합니다.'
   TrayStart='Windows 시작 시 트레이 위젯 실행'; TrayStartSub='로그인할 때 트레이 아이콘을 자동으로 띄웁니다'
   FolderT='프로그램 폴더'; FolderSub='설정 파일과 기록 위치'; Open='열기'; Rereg='작업 스케줄러 다시 등록'; ReregSub='폴더를 옮긴 뒤 사용하세요'; ReregBtn='다시 등록'
   About='정보'; AboutSub='버전 {0} · Apache-2.0'; GitHub='GitHub'
   MinOne='시간대가 최소 1개 필요합니다'; BadTimeT='시각 형식이 올바르지 않습니다 (예: 05:00, 23:30)'; Dup='같은 시각이 이미 있습니다: {0}'; MissingT='iCUE에 없는 프로필: {0}'
   RegFail='작업 스케줄러 등록 실패 (코드 {0})'; Saved='저장했습니다 · 바로 반영하려면 지금 적용을 누르세요'; SaveFirst='먼저 저장해 주세요'
   Busy='이미 적용 중입니다'; ApplyingT='iCUE를 재시작하며 적용 중입니다…'; Done='{0} 적용 완료'; Failed='적용 실패 · 기록을 확인하세요'
   AutoOnT='자동 전환을 켰습니다'; AutoOffT='자동 전환을 껐습니다'; CloseArm='저장하지 않은 변경이 있습니다 · ✕를 한 번 더 누르면 닫습니다'; Err='오류: '; ChooseProfile='프로필을 선택하세요'
   Rereged='작업 스케줄러를 다시 등록했습니다'; TrayOnT='트레이 위젯을 실행했습니다'; TrayOffT='트레이 위젯을 종료했습니다'; WhatSched='스케줄'; WhatManual='임시 설정'
   DurHM='{0}시간 {1}분'; DurM='{0}분'; TrayOpen='iCUE 스케줄러 열기'; TrayApply='지금 스케줄 적용'; TrayExit='트레이 위젯 종료'
   NowTag='지금'; OpenWin='창 열기'; ApplySchedShort='스케줄 적용'; TrayTip='iCUE 스케줄러 · {0}'; BrHint='{0} · 밝기는 0 / 33 / 66 / 100% 4단계만 지원합니다'; BrHintGen='키보드 밝기는 0 / 33 / 66 / 100% 4단계로 적용됩니다'; Rounded='{1} 지원 단계에 맞춰 {0}%로 적용되었습니다' }
}
function T($k){ $v=$StrTable[$script:lang][$k]; if($v -eq $null){ $v=$StrTable['en'][$k] }; $v }

# ---------------- Data ----------------
function Err-Log($m){ try{ "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content (Join-Path $root 'gui-error.log') -Encoding UTF8 }catch{} }
function Get-IcueProfiles {
    $list=@()
    foreach($f in Get-ChildItem "$cueDir\profiles\*.cueprofiledata" -EA SilentlyContinue){
        $head=(Get-Content $f.FullName -TotalCount 12 -Encoding UTF8) -join "`n"
        $n=[Net.WebUtility]::HtmlDecode([regex]::Match($head,'<name>(.*?)</name>').Groups[1].Value)
        $g=[regex]::Match($head,'<id>(\{[0-9a-fA-F-]{36}\})</id>').Groups[1].Value
        if($n -and $g){ $list += [pscustomobject]@{Name=$n;Id=$g} }
    }
    $list
}
function Load-Config {
    $c=$null
    foreach($p in $cfgFile,$exFile){ if(-not $c -and (Test-Path $p)){ try{ $c=Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json }catch{} } }
    if(-not $c){ $c=[pscustomobject]@{} }
    $items=@($c.schedule | ? { $_ } | % { $b=$null; if("$($_.brightness)" -match '^\d+$'){ $b=[int]$_.brightness }; [pscustomobject]@{ time=[string]$_.time; profile=[string]$_.profile; brightness=$b } } | Sort-Object time)
    if($items.Count -eq 0){ $items=@([pscustomobject]@{time='07:00';profile='Default';brightness=$null}) }
    $lg='en'; if($c.language -eq 'ko'){ $lg='ko' }
    [pscustomobject]@{ language=$lg; enabled=($c.enabled -ne $false); trayEnabled=($c.trayEnabled -eq $true); trayStartup=($c.trayStartup -eq $true); schedule=$items }
}
function Write-Config($c){
    $obj=[ordered]@{ language=$c.language; enabled=[bool]$c.enabled; trayEnabled=[bool]$c.trayEnabled; trayStartup=[bool]$c.trayStartup
                     schedule=@($c.schedule | Sort-Object time | % { [ordered]@{ time=$_.time; profile=$_.profile; brightness=$_.brightness } }) }
    [IO.File]::WriteAllText($cfgFile,(ConvertTo-Json -InputObject $obj -Depth 5),(New-Object Text.UTF8Encoding $true))
}
function Normalize-Time([string]$s){
    $m=[regex]::Match($s.Trim(),'^(\d{1,2}):(\d{2})$')
    if(-not $m.Success){ $m=[regex]::Match($s.Trim(),'^(\d{2})(\d{2})$') }
    if(-not $m.Success){ return $null }
    $h=[int]$m.Groups[1].Value; $mi=[int]$m.Groups[2].Value
    if($h -gt 23 -or $mi -gt 59){ return $null }
    '{0:00}:{1:00}' -f $h,$mi
}
function To-Min([string]$t){ $p=$t.Split(':'); [int]$p[0]*60+[int]$p[1] }
function BL-Text($v){ if("$v" -match '^\d+$'){ "$v%" } else { T 'Keep' } }
function Get-IcueCfg {
    try{
        $c=[IO.File]::ReadAllText("$cueDir\config.cuecfg")
        $bl=[regex]::Match($c,'<value name="BrightnessLevel">(\d+)</value>').Groups[1].Value
        [pscustomobject]@{ Guid=[regex]::Match($c,'<value name="defaultProfile">(\{[^<]+\})</value>').Groups[1].Value; BL=$(if($bl){[int]$bl}else{$null}) }
    }catch{ $null }
}
function Get-ActiveName($profiles){
    $ic=Get-IcueCfg; if(-not $ic){ return $null }
    $h=$profiles | ? { $_.Id -eq $ic.Guid } | Select-Object -First 1
    if($h){ $h.Name } else { $null }
}
function Get-ColorMap($conf){
    $map=@{}; $i=0
    foreach($e in $conf.schedule){ if(-not $map.ContainsKey($e.profile)){ $map[$e.profile]=$Palette[$i % $Palette.Count]; $i++ } }
    $map
}
function Get-Segments($conf){
    $e=@($conf.schedule); $segs=@()
    if($e.Count -eq 1){ return ,@([pscustomobject]@{From=0;To=1440;Entry=$e[0]}) }
    $first=To-Min $e[0].time
    if($first -gt 0){ $segs += [pscustomobject]@{From=0;To=$first;Entry=$e[-1]} }
    for($i=0;$i -lt $e.Count;$i++){
        $to=1440; if($i -lt $e.Count-1){ $to=To-Min $e[$i+1].time }
        $segs += [pscustomobject]@{From=(To-Min $e[$i].time);To=$to;Entry=$e[$i]}
    }
    ,$segs
}
function Get-Current($conf){
    $now=Get-Date -f 'HH:mm'; $e=@($conf.schedule)
    $hit=$e | ? { $_.time -le $now } | Select-Object -Last 1
    if(-not $hit){ $hit=$e | Select-Object -Last 1 }
    $hit
}
function Format-Dur([int]$m){ if($m -ge 60){ (T 'DurHM') -f [math]::Floor($m/60),($m%60) } else { (T 'DurM') -f $m } }
function Get-Next($conf){
    $now=Get-Date; $nm=$now.Hour*60+$now.Minute; $e=@($conf.schedule)
    $hit=$e | ? { (To-Min $_.time) -gt $nm } | Select-Object -First 1
    $wrap=$false; if(-not $hit){ $hit=$e[0]; $wrap=$true }
    $mins=(To-Min $hit.time)-$nm; if($wrap){ $mins+=1440 }
    [pscustomobject]@{ Time=$hit.time; Entry=$hit; Minutes=$mins }
}
function Range-Of($conf,$time){
    $ts=@($conf.schedule | % { $_.time })
    if($ts.Count -le 1){ return T 'AllDay' }
    $nx=$ts | ? { $_ -gt $time } | Select-Object -First 1; $sfx=''
    if(-not $nx){ $nx=$ts[0]; $sfx=T 'NextDay' }
    "$time ~ $nx$sfx"
}
function Get-TaskState {
    $t=Get-ScheduledTask -TaskName $taskName -EA SilentlyContinue
    if(-not $t){ return [pscustomobject]@{ Ok=$false; Title=(T 'TaskBad'); Sub='' } }
    $ti=Get-ScheduledTaskInfo -TaskName $taskName; $when=$ti.LastRunTime.ToString('MM-dd HH:mm')
    if($ti.LastRunTime.Year -lt 2000){ return [pscustomobject]@{ Ok=$true; Title=(T 'TaskOkT'); Sub=(T 'NoRun') } }
    if($ti.LastTaskResult -eq 0){ return [pscustomobject]@{ Ok=$true; Title=(T 'TaskOkT'); Sub=((T 'LastOk') -f $when) } }
    [pscustomobject]@{ Ok=$false; Title=(T 'TaskFailT'); Sub=((T 'LastFail') -f $when,$ti.LastTaskResult) }
}
function Get-LogLines([int]$n){
    if(-not (Test-Path $logFile)){ return @() }
    $lines=@(Get-Content $logFile -Tail $n -Encoding UTF8 | % { ($_ -replace '^\d{4}-','' -replace '\s*\{[0-9a-fA-F-]{36}\}','' -replace '\s*\(이전\s*\)','' -replace '^(\S+ \d\d:\d\d):\d\d','$1') })
    [array]::Reverse($lines); $lines
}
function Invoke-Switch([string]$argText){
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$switchPs`" $argText" -WindowStyle Hidden -PassThru
}

# ---------------- UI helpers ----------------
$script:ResHost = $null
$bc_ = New-Object Windows.Media.BrushConverter
function Brush($hex){ $bc_.ConvertFromString($hex) }
function Color($hex){ [Windows.Media.ColorConverter]::ConvertFromString($hex) }
function Res($k){ $script:ResHost.FindResource($k) }
function Load-Xaml($file){
    $theme=[IO.File]::ReadAllText((Join-Path $uiDir 'Theme.xaml'),[Text.Encoding]::UTF8)
    $inner=[regex]::Match($theme,'(?s)<ResourceDictionary[^>]*>(.*)</ResourceDictionary>').Groups[1].Value
    $x=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8).Replace('<!--THEME-->',$inner)
    [Windows.Markup.XamlReader]::Parse($x)
}
function New-AppIcon {
    $bmp=New-Object System.Drawing.Bitmap 32,32; $g=[System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode='AntiAlias'
    $rc=New-Object System.Drawing.Rectangle 0,0,32,32
    $br=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rc,[System.Drawing.Color]::FromArgb(124,108,255),[System.Drawing.Color]::FromArgb(47,191,164),45)
    $p=New-Object System.Drawing.Drawing2D.GraphicsPath; $r=9
    $p.AddArc(0,0,$r*2,$r*2,180,90); $p.AddArc(31-$r*2,0,$r*2,$r*2,270,90); $p.AddArc(31-$r*2,31-$r*2,$r*2,$r*2,0,90); $p.AddArc(0,31-$r*2,$r*2,$r*2,90,90); $p.CloseFigure()
    $g.FillPath($br,$p)
    $pen=New-Object System.Drawing.Pen([System.Drawing.Color]::White,2.6); $pen.StartCap='Round'; $pen.EndCap='Round'
    $g.DrawEllipse($pen,7,7,18,18); $g.DrawLine($pen,16,16,16,10.5); $g.DrawLine($pen,16,16,20,18)
    $g.Dispose(); [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
function Icon-Source($icon){ [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle,[Windows.Int32Rect]::Empty,[Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()) }

# Brightness control: presets (Keep, 0, 10, 25, 50, 75, 100) + slider 0-100
function New-BrightControl([bool]$showKeep,[bool]$stack){
    $segB=New-Object Windows.Controls.Border; $segB.Background=Res 'Card2'; $segB.CornerRadius=9; $segB.Padding='3'
    $ug=New-Object Windows.Controls.Primitives.UniformGrid; $ug.Rows=1; $segB.Child=$ug
    $sl=New-Object Windows.Controls.Slider; $sl.Style=Res 'Slim'; $sl.VerticalAlignment='Center'; $sl.Ticks=[Windows.Media.DoubleCollection]::Parse(($Presets -join ','))
    $val=New-Object Windows.Controls.TextBlock; $val.Foreground=Res 'Fg'; $val.FontSize=13; $val.FontWeight='Bold'; $val.MinWidth=44; $val.TextAlignment='Right'; $val.VerticalAlignment='Center'
    $sun=New-Object Windows.Controls.TextBlock; $sun.Text='☀'; $sun.Foreground=Res 'MutedBrush'; $sun.VerticalAlignment='Center'; $sun.Margin='0,0,10,0'
    $row=New-Object Windows.Controls.Grid
    foreach($w in 'Auto','*','Auto'){ $cd=New-Object Windows.Controls.ColumnDefinition; if($w -eq '*'){ $cd.Width=[Windows.GridLength]::new(1,'Star') } else { $cd.Width=[Windows.GridLength]::Auto }; [void]$row.ColumnDefinitions.Add($cd) }
    [Windows.Controls.Grid]::SetColumn($sl,1); [Windows.Controls.Grid]::SetColumn($val,2); $val.Margin='10,0,0,0'
    foreach($x in $sun,$sl,$val){ [void]$row.Children.Add($x) }
    if($stack){
        $rootEl=New-Object Windows.Controls.StackPanel; [void]$rootEl.Children.Add($segB); $row.Margin='2,10,0,0'; [void]$rootEl.Children.Add($row)
    } else {
        $rootEl=New-Object Windows.Controls.Grid
        foreach($w in 'Auto','*'){ $cd=New-Object Windows.Controls.ColumnDefinition; if($w -eq '*'){ $cd.Width=[Windows.GridLength]::new(1,'Star') } else { $cd.Width=[Windows.GridLength]::Auto }; [void]$rootEl.ColumnDefinitions.Add($cd) }
        [Windows.Controls.Grid]::SetColumn($row,1); $row.Margin='14,0,0,0'
        [void]$rootEl.Children.Add($segB); [void]$rootEl.Children.Add($row)
    }
    $hint=New-Object Windows.Controls.TextBlock; $hint.Foreground=Res 'MutedBrush'; $hint.FontSize=11.5; $hint.Margin='2,9,0,0'; $hint.TextWrapping='Wrap'; $hint.Text=Get-BrightHint
    $outer=New-Object Windows.Controls.StackPanel; [void]$outer.Children.Add($rootEl); [void]$outer.Children.Add($hint); $rootEl=$outer
    $bc=[pscustomobject]@{Hint=$hint;Root=$rootEl;Slider=$sl;Val=$val;Value=$null;Busy=$false;OnChange=$null;Btns=@{};ShowKeep=$showKeep}
    $keys=@(); if($showKeep){ $keys+='keep' }; $keys+=$Presets
    foreach($k in $keys){
        $b=New-Object Windows.Controls.Primitives.ToggleButton; $b.Style=Res 'SegItem'
        $b.Content= if($k -eq 'keep'){ T 'Keep' } else { "$k" }
        $b.Tag=@($bc,$k)
        $b.Add_Click({ param($s,$e) try{ $c=$s.Tag[0]; $v=$s.Tag[1]; if($v -eq 'keep'){ $v=$null }; BC-Set $c $v; if($c.OnChange){ & $c.OnChange $c } }catch{ Err-Log "preset: $_ @ $($_.InvocationInfo.PositionMessage)" } })
        [void]$ug.Children.Add($b); $bc.Btns["$k"]=$b
    }
    $sl.Tag=$bc
    $sl.Add_ValueChanged({ param($s,$e) try{ $c=$s.Tag; if($c.Busy){ return }; if(-not ($s.IsMouseCaptureWithin -or $s.IsMouseOver -or $s.IsKeyboardFocusWithin)){ return }; BC-Set $c ([int][math]::Round($s.Value)) -FromSlider; if($c.OnChange){ & $c.OnChange $c } }catch{ Err-Log "slider: $_ @ $($_.InvocationInfo.PositionMessage)" } })
    if($showKeep){ BC-Set $bc $null } else { BC-Set $bc 0 }
    $bc
}
function BC-Set($bc,$v,[switch]$FromSlider){
    $bc.Busy=$true
    try{
        if($v -eq $null -and -not $bc.ShowKeep){ $v=0 }
        $bc.Value=$v
        $key= if($v -eq $null){ 'keep' } else { "$v" }
        foreach($k in @($bc.Btns.Keys)){ $bc.Btns[$k].IsChecked=($k -eq $key) }
        if($v -eq $null){ $bc.Slider.Opacity=0.35; $bc.Val.Text=T 'Keep' }
        else { if(-not $FromSlider){ $bc.Slider.Value=$v }; $bc.Slider.Opacity=1; $bc.Val.Text="$v%" }
    } finally { $bc.Busy=$false }
}
function BC-IsCustom($bc){ $bc.Value -ne $null -and ($Presets -notcontains [int]$bc.Value) }
function BC-Relabel($bc){ $bc.Hint.Text=Get-BrightHint; if($bc.Btns.ContainsKey('keep')){ $bc.Btns['keep'].Content=T 'Keep' }; if($bc.Value -eq $null){ $bc.Val.Text=T 'Keep' } }

# Keyboards that have a brightness setting in iCUE, and the hint shown under the brightness controls
function Get-BrightDevices {
    try{ $c=[IO.File]::ReadAllText("$cueDir\config.cuecfg")
         @([regex]::Matches($c,'(?s)<map name="([^"{][^"]*)">\s*<map name="\{[0-9a-fA-F-]+\}">(?:(?!<map name=).)*?<value name="BrightnessLevel">') | % { $_.Groups[1].Value } | Select-Object -Unique) }
    catch{ @() }
}
function Get-BrightHint { $dv=@(Get-BrightDevices); if($dv.Count){ (T 'BrHint') -f ($dv -join ', ') } else { T 'BrHintGen' } }
# After iCUE restarts it may round the brightness to a supported step; returns a message if it did
function Check-Rounded($requested){
    if($requested -eq $null){ return $null }
    $ic=Get-IcueCfg; if(-not $ic -or $ic.BL -eq $null){ return $null }
    if([int]$ic.BL -eq [int]$requested){ return $null }
    $dv=@(Get-BrightDevices); $n='iCUE'; if($dv.Count){ $n=$dv -join ', ' }
    (T 'Rounded') -f $ic.BL,$n
}

# 24-hour timeline
function New-Timeline([hashtable]$o){
    $g=New-Object Windows.Controls.Grid
    foreach($i in 0,1){ $rd=New-Object Windows.Controls.RowDefinition; $rd.Height=[Windows.GridLength]::Auto; [void]$g.RowDefinitions.Add($rd) }
    if($o.MarkerLabel){ $g.Margin='0,16,0,0' }
    $track=New-Object Windows.Controls.Canvas; $track.Height=$o.Height; $track.Background=Brush '#1A1D26'
    $over=New-Object Windows.Controls.Canvas; $over.Height=$o.Height
    $ticks=New-Object Windows.Controls.Canvas; $ticks.Height=14; $ticks.Margin='0,7,0,0'; [Windows.Controls.Grid]::SetRow($ticks,1)
    [void]$g.Children.Add($track); [void]$g.Children.Add($over); if($o.Ticks){ [void]$g.Children.Add($ticks) }
    $tl=[pscustomobject]@{Root=$g;Track=$track;Over=$over;Ticks=$ticks;Opt=$o;Conf=$null;Sel=$null}
    $track.Tag=$tl
    $track.Add_SizeChanged({ param($s,$e) Draw-Timeline $s.Tag })
    $tl
}
function Draw-Timeline($tl){
    $w=$tl.Track.ActualWidth; $h=[double]$tl.Opt.Height; $conf=$tl.Conf
    $tl.Track.Children.Clear(); $tl.Over.Children.Clear(); $tl.Ticks.Children.Clear()
    if($w -le 0 -or -not $conf){ return }
    $tl.Track.Clip=New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect(0,0,$w,$h)),7,7)
    $cm=Get-ColorMap $conf
    foreach($sg in (Get-Segments $conf)){
        $x=$sg.From/1440*$w; $sw=($sg.To-$sg.From)/1440*$w; $pal=$cm[$sg.Entry.profile]
        $rc=New-Object Windows.Shapes.Rectangle; $rc.Width=[math]::Max(0,$sw); $rc.Height=$h
        $rc.Fill=New-Object Windows.Media.LinearGradientBrush((Color $pal[0]),(Color $pal[1]),0.0)
        [Windows.Controls.Canvas]::SetLeft($rc,$x); [void]$tl.Track.Children.Add($rc)
        if($tl.Opt.Labels -and $sw -gt 46){
            $tb=New-Object Windows.Controls.TextBlock; $tb.Text=$sg.Entry.profile
            if($sw -gt 230){ $tb.Text+="  ·  " + ('{0:00}:{1:00} – {2:00}:{3:00}' -f [math]::Floor($sg.From/60),($sg.From%60),[math]::Floor($sg.To/60),($sg.To%60)) }
            $tb.Foreground=Brush $pal[2]; $tb.FontSize=11; $tb.FontWeight='SemiBold'; $tb.Width=[math]::Max(0,$sw-16); $tb.TextTrimming='CharacterEllipsis'
            [Windows.Controls.Canvas]::SetLeft($tb,$x+9); [Windows.Controls.Canvas]::SetTop($tb,($h-15)/2); [void]$tl.Track.Children.Add($tb)
        }
    }
    if($tl.Opt.Handles){
        foreach($e in $conf.schedule){
            $x=(To-Min $e.time)/1440*$w
            $hd=New-Object Windows.Shapes.Rectangle; $hd.Width=10; $hd.Height=$h-8; $hd.RadiusX=4; $hd.RadiusY=4; $hd.Fill=Brush '#FFFFFF'; $hd.Cursor='Hand'
            if($e.time -eq $tl.Sel){ $hd.Stroke=Res 'Accent'; $hd.StrokeThickness=2.5 }
            $hd.Effect=New-Object Windows.Media.Effects.DropShadowEffect -Property @{BlurRadius=5;ShadowDepth=1;Opacity=0.5}
            $hd.Tag=@($tl,$e.time); $hd.ToolTip=$e.time
            $hd.Add_MouseLeftButtonDown({ param($s,$a) $t=$s.Tag[0]; if($t.Opt.OnHandle){ & $t.Opt.OnHandle $s.Tag[1] }; $a.Handled=$true })
            [Windows.Controls.Canvas]::SetLeft($hd,$x-5); [Windows.Controls.Canvas]::SetTop($hd,4); [void]$tl.Over.Children.Add($hd)
        }
    }
    if($tl.Opt.Marker){
        $n=Get-Date; $x=($n.Hour*60+$n.Minute)/1440*$w
        $ln=New-Object Windows.Shapes.Rectangle; $ln.Width=2; $ln.Height=$h+8; $ln.Fill=Brush '#FFFFFF'
        $ln.Effect=New-Object Windows.Media.Effects.DropShadowEffect -Property @{BlurRadius=8;ShadowDepth=0;Color=(Color '#FFFFFF');Opacity=0.9}
        [Windows.Controls.Canvas]::SetLeft($ln,$x-1); [Windows.Controls.Canvas]::SetTop($ln,-4); [void]$tl.Over.Children.Add($ln)
        if($tl.Opt.MarkerLabel){
            $bd=New-Object Windows.Controls.Border; $bd.Background=Brush '#2A2F3C'; $bd.CornerRadius=5; $bd.Padding='5,1'
            $tt=New-Object Windows.Controls.TextBlock; $tt.Text=$n.ToString('HH:mm'); $tt.Foreground=Brush '#FFFFFF'; $tt.FontSize=10; $bd.Child=$tt
            [Windows.Controls.Canvas]::SetLeft($bd,[math]::Min([math]::Max($x-17,0),$w-36)); [Windows.Controls.Canvas]::SetTop($bd,-21); [void]$tl.Over.Children.Add($bd)
        }
    }
    if($tl.Opt.Ticks){
        foreach($hh in 0,3,6,9,12,15,18,21,24){
            $x=$hh/24*$w; $tb=New-Object Windows.Controls.TextBlock; $tb.Text='{0:00}' -f $hh; $tb.Foreground=Res 'Dim'; $tb.FontSize=10; $tb.Width=24
            if($hh -eq 0){ $tb.TextAlignment='Left'; $lx=0 } elseif($hh -eq 24){ $tb.TextAlignment='Right'; $lx=$w-24 } else { $tb.TextAlignment='Center'; $lx=$x-12 }
            [Windows.Controls.Canvas]::SetLeft($tb,$lx); [void]$tl.Ticks.Children.Add($tb)
        }
    }
}

# Tray widget helpers
$trayVbs = Join-Path $root 'iCUE-Tray.vbs'
function Set-TrayStartup([bool]$on){
    $lnk=Join-Path ([Environment]::GetFolderPath('Startup')) 'iCUE Scheduler Tray.lnk'
    if($on){
        $ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut($lnk)
        $s.TargetPath="$env:WINDIR\System32\wscript.exe"; $s.Arguments="`"$trayVbs`""; $s.WorkingDirectory=$root; $s.Description='iCUE Scheduler tray widget'; $s.Save()
    } elseif(Test-Path $lnk){ Remove-Item $lnk -Force }
}
function Get-TrayProcs { @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -EA SilentlyContinue | ? { $_.CommandLine -like '*ui\Tray.ps1*' }) }
function Start-Tray { if((Get-TrayProcs).Count -eq 0){ Start-Process wscript.exe -ArgumentList "`"$trayVbs`"" } }