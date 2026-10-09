<#
  iCUE Scheduler - GUI (WPF). Start it with iCUE-Scheduler.vbs (or the desktop shortcut made by Install.ps1).
#>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -AssemblyName System.Drawing

$dir      = $PSScriptRoot
$cfgFile  = Join-Path $dir 'schedule.json'
$exFile   = Join-Path $dir 'schedule.example.json'
$logFile  = Join-Path $dir 'scheduler.log'
$install  = Join-Path $dir 'Install.ps1'
$switch   = Join-Path $dir 'Switch-iCUEProfile.ps1'
$xamlFile = Join-Path $dir 'iCUE-Scheduler.xaml'
$cueDir   = "$env:APPDATA\Corsair\CUE5"
$taskName = 'iCUE Profile Scheduler'
$script:dirty = $false; $script:busy = $false; $script:profiles = @(); $script:lang = 'en'
$script:rows = New-Object System.Collections.ArrayList
$script:applyProc = $null; $script:closeArmed = $false

# ---------------- Strings (English / 한국어) ----------------
$S = @{
 en = @{ Title='iCUE Scheduler'; Dirty='   ● Unsaved'; Cur='Current profile'; Bright='Keyboard brightness'; Next='Next switch'
         Auto='Auto switching'; Sched='Schedule'; SchedDesc='Each profile and brightness is used from its start time until the next start time'
         Add='＋  Add'; HTime='Start'; HProfile='Profile'; HBright='Brightness'; HRange='Active period'; DirtyNote='You have unsaved changes'
         Apply='Apply now'; Applying='Applying…'; Save='Save'; Manual='Temporary override'; ManualBtn='Apply'; Log='Recent activity'; Folder='Open folder'
         ManualNote='Applies the selected profile and brightness now. The schedule takes over again at the next switch ({0}).'
         Keep='Keep'; AllDay='All day'; NextDay=' (next day)'; BadTime='⚠ Invalid time (e.g. 05:00)'; Missing='  ⚠ Not in iCUE'; Del='Delete'
         Today='Today'; Tomorrow='Tomorrow'; Match='● Matches the current time slot'; ManualOn='● Manual override · back on next switch'
         AutoOff='Auto switching is off'; Unknown='(unknown)'; SlotBright='Current slot: {0}'; CfgBright='Current iCUE setting'; NextSub='→ {0} · brightness {1}'
         TaskNone='Scheduled task not registered · press Save to register'; TaskOk='Task Scheduler: registered · {0}'
         LastOk='last run {0} OK'; LastFail='last run {0} failed (code {1})'; NoRun='not run yet'; NoLog='(no activity yet)'
         MinOne='At least one schedule entry is required'; BadTimeT='Invalid time (e.g. 05:00, 23:30)'; PickProfile='Choose a profile for {0}'
         Dup='Duplicate time: {0}'; MissingT='Not found in iCUE: {0}'; RegFail='Could not register the scheduled task (code {0})'
         Saved='Saved · press [Apply now] to use it right away'; SaveFirst='Save your changes first'; Busy='Already applying…'
         ApplyingT='Restarting iCUE to apply…'; Done='{0} applied'; Failed='Failed to apply · see Recent activity'
         AutoOnT='Auto switching on'; AutoOffT='Auto switching off'; CloseArm='Unsaved changes · press ✕ again to close'
         WhatSched='Schedule'; WhatManual='Temporary settings'; Err='Error: '; ChooseProfile='Choose a profile' }
 ko = @{ Title='iCUE 스케줄러'; Dirty='   ● 저장 안 됨'; Cur='현재 프로필'; Bright='키보드 밝기'; Next='다음 전환'
         Auto='자동 전환'; Sched='스케줄'; SchedDesc='시작 시각부터 다음 시작 시각 전까지 해당 프로필과 키보드 밝기를 사용합니다'
         Add='＋  추가'; HTime='시작 시각'; HProfile='프로필'; HBright='키보드 밝기'; HRange='적용 구간'; DirtyNote='변경 사항이 저장되지 않았습니다'
         Apply='지금 적용'; Applying='적용 중…'; Save='저장'; Manual='임시 사용'; ManualBtn='바로 적용'; Log='최근 기록'; Folder='폴더 열기'
         ManualNote='선택한 프로필·밝기를 지금 적용합니다. 다음 스케줄 시각({0})이 되면 스케줄 설정으로 자동 복귀합니다.'
         Keep='유지'; AllDay='하루 종일'; NextDay=' (다음날)'; BadTime='⚠ 형식 오류 (예: 05:00)'; Missing='  ⚠ iCUE에 없음'; Del='삭제'
         Today='오늘'; Tomorrow='내일'; Match='● 현재 시간대 설정과 일치'; ManualOn='● 수동 설정 중 · 다음 전환에서 복귀'
         AutoOff='자동 전환 꺼짐'; Unknown='(알 수 없음)'; SlotBright='현재 구간 설정 {0}'; CfgBright='현재 iCUE 설정값'; NextSub='→ {0} · 밝기 {1}'
         TaskNone='작업 스케줄러 미등록 · 저장하면 자동 등록됩니다'; TaskOk='작업 스케줄러 등록됨 · {0}'
         LastOk='마지막 실행 {0} 성공'; LastFail='마지막 실행 {0} 실패(코드 {1})'; NoRun='실행 기록 없음'; NoLog='(기록 없음)'
         MinOne='스케줄이 최소 1개 필요합니다'; BadTimeT='시각 형식이 올바르지 않습니다 (예: 05:00, 23:30)'; PickProfile='{0} 행의 프로필을 선택하세요'
         Dup='같은 시각({0})이 중복되었습니다'; MissingT='iCUE에 없는 프로필: {0}'; RegFail='작업 스케줄러 등록 실패 (코드 {0})'
         Saved='저장했습니다 · 지금 구간에 바로 반영하려면 [지금 적용]'; SaveFirst='먼저 [저장]을 눌러주세요'; Busy='이미 적용 중입니다'
         ApplyingT='iCUE를 재시작하며 적용 중입니다…'; Done='{0} 적용 완료'; Failed='적용 실패 · 최근 기록을 확인하세요'
         AutoOnT='자동 전환을 켰습니다'; AutoOffT='자동 전환을 껐습니다'; CloseArm='저장하지 않은 변경이 있습니다 · ✕를 한 번 더 누르면 닫습니다'
         WhatSched='스케줄'; WhatManual='임시 설정'; Err='오류: '; ChooseProfile='프로필을 선택하세요' }
}
function T($k){ $S[$script:lang][$k] }
function Bright-Items { @((T 'Keep'),'0%','33%','66%','100%') }

function Err-Log($m){ try{ "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m" | Add-Content (Join-Path $dir 'gui-error.log') -Encoding UTF8 }catch{} }

# ---------------- Data ----------------
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
    if(-not $c){ $c=[pscustomobject]@{enabled=$true; schedule=@()} }
    $items=@($c.schedule | % { $b=$null; if("$($_.brightness)" -match '^\d+$'){ $b=[int]$_.brightness }; [pscustomobject]@{ time=[string]$_.time; profile=[string]$_.profile; brightness=$b } })
    if($items.Count -eq 0){ $items=@([pscustomobject]@{time='07:00';profile='Default';brightness=$null}) }
    $lg='en'; if($c.language -eq 'ko'){ $lg='ko' }
    [pscustomobject]@{ language=$lg; enabled=($c.enabled -ne $false); schedule=$items }
}
function Write-Config($enabled,$items){
    $obj=[pscustomobject]@{language=$script:lang; enabled=[bool]$enabled; schedule=@($items)}
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
function BL-Text($v){ if("$v" -match '^\d+$'){ "$v%" } else { T 'Keep' } }
function BL-Arg([string]$t){ if($t -match '^(\d+)%$'){ $Matches[1] } else { 'keep' } }
function Get-IcueCfg {
    try{
        $c=[IO.File]::ReadAllText("$cueDir\config.cuecfg")
        [pscustomobject]@{ Guid=[regex]::Match($c,'<value name="defaultProfile">(\{[^<]+\})</value>').Groups[1].Value; BL=[regex]::Match($c,'<value name="BrightnessLevel">(\d+)</value>').Groups[1].Value }
    }catch{ $null }
}
function Get-Expected($conf){
    $now=Get-Date -f 'HH:mm'; $e=@($conf.schedule | sort time)
    $hit=$e | ? { $_.time -le $now } | select -Last 1
    if(-not $hit){ $hit=$e | select -Last 1 }
    $hit
}
function Get-Next($conf){
    $now=Get-Date -f 'HH:mm'; $e=@($conf.schedule | sort time)
    $hit=$e | ? { $_.time -gt $now } | select -First 1
    if($hit){ return [pscustomobject]@{ When="$(T 'Today') $($hit.time)"; Time=$hit.time; Entry=$hit } }
    [pscustomobject]@{ When="$(T 'Tomorrow') $($e[0].time)"; Time=$e[0].time; Entry=$e[0] }
}

# ---------------- Window ----------------
$win = [Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText($xamlFile,[Text.Encoding]::UTF8))
foreach($n in 'TitleBar','L_Title','DirtyChip','BtnLangEn','BtnLangKo','BtnMin','BtnClose','L_Cur','L_Bright','L_Next','ActiveName','ActiveSub','BrightVal','BrightSub','NextTime','NextSub',
              'TglEnabled','L_Auto','TaskInfo','L_Sched','L_SchedDesc','BtnAdd','H_Time','H_Profile','H_Bright','H_Range','RowsPanel','DirtyNote','BtnApplySched','BtnSave',
              'L_Manual','ManualNote','CmbManualProfile','CmbManualBright','BtnManual','L_Log','BtnFolder','LogBox','Toast','ToastText'){
    Set-Variable -Name $n -Value ($win.FindName($n)) -Scope Script
}
try{
    $ico=[System.Drawing.Icon]::ExtractAssociatedIcon("$env:ProgramFiles\Corsair\Corsair iCUE5 Software\iCUE.exe")
    $win.Icon=[Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($ico.Handle,[Windows.Int32Rect]::Empty,[Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
}catch{}
$bc = New-Object Windows.Media.BrushConverter
function Brush($hex){ $bc.ConvertFromString($hex) }
function Res($k){ $win.FindResource($k) }

# ---------------- Helpers ----------------
$script:toastTimer = New-Object Windows.Threading.DispatcherTimer; $script:toastTimer.Interval=[TimeSpan]::FromSeconds(4)
$script:toastTimer.Add_Tick({ $script:toastTimer.Stop(); $Toast.Visibility='Collapsed' })
function Show-Toast($msg,$kind='info'){
    $c=@{ok=@('#173A2E','#2C6B52'); err=@('#40212A','#7A3340'); warn=@('#3F3320','#80652E'); info=@('#232A3D','#3A4468')}[$kind]
    $Toast.Background=Brush $c[0]; $Toast.BorderBrush=Brush $c[1]; $ToastText.Text=$msg; $Toast.Visibility='Visible'
    $script:toastTimer.Stop(); $script:toastTimer.Start()
}
function Safe([scriptblock]$b){ try{ & $b }catch{ Err-Log "$_"; Show-Toast ((T 'Err') + $_.Exception.Message) 'err' } }
function Set-Dirty($v){
    $script:dirty=$v; $script:closeArmed=$false
    $vis='Collapsed'; if($v){ $vis='Visible' }
    $DirtyChip.Visibility=$vis; $DirtyNote.Visibility=$vis
}
function Fill-Combo($cb,$items,$sel){
    $cb.Items.Clear()
    $list=@($items); if($sel -and $list -notcontains $sel){ $list += $sel }
    foreach($i in $list){ [void]$cb.Items.Add([string]$i) }
    if($sel){ $cb.SelectedItem=[string]$sel } elseif($cb.Items.Count -gt 0){ $cb.SelectedIndex=0 }
}
function Apply-Lang {
    $win.Title=T 'Title'; $L_Title.Text=T 'Title'; $DirtyChip.Text=T 'Dirty'
    $L_Cur.Text=T 'Cur'; $L_Bright.Text=T 'Bright'; $L_Next.Text=T 'Next'; $L_Auto.Text=T 'Auto'
    $L_Sched.Text=T 'Sched'; $L_SchedDesc.Text=T 'SchedDesc'; $BtnAdd.Content=T 'Add'
    $H_Time.Text=T 'HTime'; $H_Profile.Text=T 'HProfile'; $H_Bright.Text=T 'HBright'; $H_Range.Text=T 'HRange'
    $DirtyNote.Text=T 'DirtyNote'; $BtnApplySched.Content=T 'Apply'; $BtnSave.Content=T 'Save'
    $L_Manual.Text=T 'Manual'; $BtnManual.Content=T 'ManualBtn'; $L_Log.Text=T 'Log'; $BtnFolder.Content=T 'Folder'
    foreach($p in @(@($BtnLangEn,'en'),@($BtnLangKo,'ko'))){
        if($script:lang -eq $p[1]){ $p[0].Background=Res 'Accent'; $p[0].Foreground=Brush '#FFFFFF' } else { $p[0].Background=Brush '#00000000'; $p[0].Foreground=Res 'MutedBrush' }
    }
    # relabel brightness combos, keeping the selected values
    $script:busy=$true
    try{
        foreach($cb in @($script:rows | % { $_.Bright }) + @($CmbManualBright)){
            if($cb.Items.Count -eq 0){ continue }
            $v=BL-Arg ([string]$cb.SelectedItem); $sel=T 'Keep'; if($v -ne 'keep'){ $sel="$v%" }
            Fill-Combo $cb (Bright-Items) $sel
        }
        foreach($r in $script:rows){ $r.Del.ToolTip=T 'Del' }
    } finally { $script:busy=$false }
}

# ---------------- Schedule rows ----------------
function New-Cols($g){
    foreach($w in 96,10,-1,10,124,10,168,36){
        $cd=New-Object Windows.Controls.ColumnDefinition
        if($w -lt 0){ $cd.Width=[Windows.GridLength]::new(1,[Windows.GridUnitType]::Star) } else { $cd.Width=[Windows.GridLength]::new($w) }
        [void]$g.ColumnDefinitions.Add($cd)
    }
}
function Add-Row($time,$profile,$bright){
    $g=New-Object Windows.Controls.Grid; $g.Margin=[Windows.Thickness]::new(0,0,0,8); New-Cols $g
    $tb=New-Object Windows.Controls.TextBox; $tb.Style=(Res 'Input'); $tb.Text=$time; $tb.MaxLength=5; $tb.VerticalAlignment='Center'
    $cb=New-Object Windows.Controls.ComboBox; $cb.Style=(Res 'Drop'); $cb.Height=39
    $bb=New-Object Windows.Controls.ComboBox; $bb.Style=(Res 'Drop'); $bb.Height=39
    $rg=New-Object Windows.Controls.TextBlock; $rg.Foreground=(Res 'MutedBrush'); $rg.VerticalAlignment='Center'; $rg.Margin=[Windows.Thickness]::new(8,0,0,0); $rg.FontSize=12.5; $rg.TextTrimming='CharacterEllipsis'
    $del=New-Object Windows.Controls.Button; $del.Style=(Res 'BtnIcon'); $del.Content='✕'; $del.ToolTip=T 'Del'
    [Windows.Controls.Grid]::SetColumn($tb,0); [Windows.Controls.Grid]::SetColumn($cb,2); [Windows.Controls.Grid]::SetColumn($bb,4); [Windows.Controls.Grid]::SetColumn($rg,6); [Windows.Controls.Grid]::SetColumn($del,7)
    foreach($c in $tb,$cb,$bb,$rg,$del){ [void]$g.Children.Add($c) }
    Fill-Combo $cb ($script:profiles | % Name) $profile
    Fill-Combo $bb (Bright-Items) (BL-Text $bright)
    $row=[pscustomobject]@{Panel=$g;Time=$tb;Profile=$cb;Bright=$bb;Range=$rg;Del=$del}
    $tb.Add_TextChanged({ if(-not $script:busy){ Set-Dirty $true; Update-Ranges } })
    $tb.Add_LostFocus({ param($s,$e) $n=Normalize-Time $s.Text; if($n -and $n -ne $s.Text){ $s.Text=$n } })
    $cb.Add_SelectionChanged({ if(-not $script:busy){ Set-Dirty $true; Update-Ranges } })
    $bb.Add_SelectionChanged({ if(-not $script:busy){ Set-Dirty $true } })
    $del.Tag=$row
    $del.Add_Click({ param($s,$e) Safe { Remove-Row $s.Tag } })
    [void]$script:rows.Add($row); [void]$RowsPanel.Children.Add($g)
    $row
}
function Remove-Row($row){
    if($script:rows.Count -le 1){ Show-Toast (T 'MinOne') 'warn'; return }
    $RowsPanel.Children.Remove($row.Panel); $script:rows.Remove($row); Set-Dirty $true; Update-Ranges
}
function Update-Ranges {
    $script:busy=$true
    try{
        $ts=@($script:rows | % { Normalize-Time $_.Time.Text } | ? { $_ } | sort -Unique)
        $known=@($script:profiles | % Name)
        foreach($r in $script:rows){
            $t=Normalize-Time $r.Time.Text
            if(-not $t){ $r.Range.Text=T 'BadTime'; $r.Range.Foreground=(Res 'Bad'); $r.Time.BorderBrush=(Res 'Bad'); continue }
            $r.Time.BorderBrush=(Res 'Line'); $r.Range.Foreground=(Res 'MutedBrush')
            if($ts.Count -le 1){ $txt=T 'AllDay' } else {
                $next=$ts | ? { $_ -gt $t } | select -First 1; $sfx=''
                if(-not $next){ $next=$ts[0]; $sfx=T 'NextDay' }
                $txt="$t ~ $next$sfx"
            }
            if($known.Count -gt 0 -and $r.Profile.SelectedItem -and $known -notcontains [string]$r.Profile.SelectedItem){ $txt+=T 'Missing'; $r.Range.Foreground=(Res 'Warn') }
            $r.Range.Text=$txt
        }
    } finally { $script:busy=$false }
}
function Load-Grid {
    $conf=Load-Config; $script:profiles=@(Get-IcueProfiles)
    $script:busy=$true
    try{
        $RowsPanel.Children.Clear(); $script:rows.Clear()
        foreach($it in @($conf.schedule | sort time)){ [void](Add-Row $it.time $it.profile $it.brightness) }
        $TglEnabled.IsChecked=$conf.enabled
        $names=@($script:profiles | % Name)
        $ic=Get-IcueCfg; $act=''; if($ic){ $h=$script:profiles | ? { $_.Id -eq $ic.Guid } | select -First 1; if($h){ $act=$h.Name } }
        $pick=($names | ? { $_ -ne $act } | select -First 1); if(-not $pick){ $pick=$names | select -First 1 }
        Fill-Combo $CmbManualProfile $names $pick
        Fill-Combo $CmbManualBright (Bright-Items) (T 'Keep')
    } finally { $script:busy=$false }
    Update-Ranges; Set-Dirty $false
}

# ---------------- Status ----------------
function Refresh-Status {
    try{
        $script:profiles=@(Get-IcueProfiles); $conf=Load-Config; $ic=Get-IcueCfg
        $act=T 'Unknown'; if($ic){ $h=$script:profiles | ? { $_.Id -eq $ic.Guid } | select -First 1; if($h){ $act=$h.Name } }
        $ActiveName.Text=$act
        $exp=Get-Expected $conf; $nx=Get-Next $conf
        if(-not $conf.enabled){ $ActiveSub.Text=T 'AutoOff'; $ActiveSub.Foreground=(Res 'MutedBrush') }
        elseif($exp.profile -eq $act){ $ActiveSub.Text=T 'Match'; $ActiveSub.Foreground=(Res 'Good') }
        else { $ActiveSub.Text=T 'ManualOn'; $ActiveSub.Foreground=(Res 'Warn') }
        if($ic -and $ic.BL){ $BrightVal.Text="$($ic.BL)%" } else { $BrightVal.Text='-' }
        if($conf.enabled -and "$($exp.brightness)" -ne ''){ $BrightSub.Text=(T 'SlotBright') -f "$($exp.brightness)%" } else { $BrightSub.Text=T 'CfgBright' }
        $NextTime.Text=$nx.When
        if($conf.enabled){ $NextSub.Text=(T 'NextSub') -f $nx.Entry.profile,(BL-Text $nx.Entry.brightness) } else { $NextSub.Text='-' }
        $ManualNote.Text=(T 'ManualNote') -f $nx.Time
        $t=Get-ScheduledTask -TaskName $taskName -EA SilentlyContinue
        if(-not $t){ $TaskInfo.Text=T 'TaskNone'; $TaskInfo.Foreground=(Res 'Bad') }
        else{
            $ti=Get-ScheduledTaskInfo -TaskName $taskName; $when=$ti.LastRunTime.ToString('MM-dd HH:mm')
            if($ti.LastRunTime.Year -lt 2000){ $res=T 'NoRun' } elseif($ti.LastTaskResult -eq 0){ $res=(T 'LastOk') -f $when } else { $res=(T 'LastFail') -f $when,$ti.LastTaskResult }
            $TaskInfo.Text=(T 'TaskOk') -f $res; $TaskInfo.Foreground=(Res 'MutedBrush')
        }
        if(Test-Path $logFile){
            $lines=@(Get-Content $logFile -Tail 14 -Encoding UTF8 | % { ($_ -replace '^\d{4}-','' -replace '\s*\{[0-9a-fA-F-]{36}\}','' -replace '\s*\(이전\s*\)','' -replace '^(\S+ \d\d:\d\d):\d\d','$1') })
            [array]::Reverse($lines); $LogBox.Text=($lines | select -First 5) -join "`r`n"
        } else { $LogBox.Text=T 'NoLog' }
    }catch{ Err-Log "Refresh: $_" }
}

# ---------------- Save / apply ----------------
function Save-Config {
    $items=@(); $seen=@{}
    foreach($r in $script:rows){
        $t=Normalize-Time $r.Time.Text; $p=[string]$r.Profile.SelectedItem
        if(-not $t){ Show-Toast (T 'BadTimeT') 'err'; return $false }
        if(-not $p){ Show-Toast ((T 'PickProfile') -f $t) 'err'; return $false }
        if($seen.ContainsKey($t)){ Show-Toast ((T 'Dup') -f $t) 'err'; return $false }
        $seen[$t]=$true
        $bv=$null; $arg=BL-Arg ([string]$r.Bright.SelectedItem); if($arg -ne 'keep'){ $bv=[int]$arg }
        $items += [pscustomobject]@{time=$t;profile=$p;brightness=$bv}
    }
    $known=@($script:profiles | % Name)
    $missing=@($items | ? { $known -notcontains $_.profile } | % { $_.profile } | sort -Unique)
    if($missing.Count -gt 0){ Show-Toast ((T 'MissingT') -f ($missing -join ', ')) 'err'; return $false }
    Write-Config $TglEnabled.IsChecked @($items | sort time)
    $p=Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$install`"",'-Quiet','-NoShortcut' -WindowStyle Hidden -Wait -PassThru
    if($p.ExitCode -ne 0){ Show-Toast ((T 'RegFail') -f $p.ExitCode) 'err'; return $false }
    Load-Grid; Refresh-Status
    $true
}
$script:applyTimer=New-Object Windows.Threading.DispatcherTimer; $script:applyTimer.Interval=[TimeSpan]::FromMilliseconds(700)
$script:applyTimer.Add_Tick({
    if($script:applyProc -and $script:applyProc.HasExited){
        $script:applyTimer.Stop(); $code=$script:applyProc.ExitCode
        $BtnApplySched.IsEnabled=$true; $BtnManual.IsEnabled=$true; $BtnApplySched.Content=T 'Apply'; $BtnManual.Content=T 'ManualBtn'
        Refresh-Status
        if($code -eq 0){ Show-Toast ((T 'Done') -f (T $script:applyWhat)) 'ok' } else { Show-Toast (T 'Failed') 'err' }
    }
})
function Start-Apply($argText,$what){
    if($script:applyProc -and -not $script:applyProc.HasExited){ Show-Toast (T 'Busy') 'warn'; return }
    $BtnApplySched.IsEnabled=$false; $BtnManual.IsEnabled=$false; $BtnApplySched.Content=T 'Applying'; $BtnManual.Content=T 'Applying'
    $script:applyWhat=$what
    $script:applyProc=Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$switch`" $argText" -WindowStyle Hidden -PassThru
    Show-Toast (T 'ApplyingT') 'info'
    $script:applyTimer.Start()
}
function Set-Lang($lg){
    $script:lang=$lg
    $conf=Load-Config; Write-Config $conf.enabled $conf.schedule   # saves only the language; unsaved edits stay in the window
    Apply-Lang; Update-Ranges; Refresh-Status
}

# ---------------- Events ----------------
$TitleBar.Add_MouseLeftButtonDown({ try{ $win.DragMove() }catch{} })
$BtnMin.Add_Click({ $win.WindowState='Minimized' })
$BtnClose.Add_Click({
    if($script:dirty -and -not $script:closeArmed){ $script:closeArmed=$true; Show-Toast (T 'CloseArm') 'warn'; return }
    $win.Close()
})
$BtnLangEn.Add_Click({ Safe { Set-Lang 'en' } })
$BtnLangKo.Add_Click({ Safe { Set-Lang 'ko' } })
$BtnAdd.Add_Click({ Safe {
    $first=@($script:profiles | % Name) | select -First 1
    [void](Add-Row '12:00' $first $null); Set-Dirty $true; Update-Ranges
}})
$BtnSave.Add_Click({ Safe { if(Save-Config){ Show-Toast (T 'Saved') 'ok' } } })
$BtnApplySched.Add_Click({ Safe {
    if($script:dirty){ Show-Toast (T 'SaveFirst') 'warn'; return }
    Start-Apply '-Force' 'WhatSched'
}})
$BtnManual.Add_Click({ Safe {
    $p=[string]$CmbManualProfile.SelectedItem; if(-not $p){ Show-Toast (T 'ChooseProfile') 'warn'; return }
    $b=BL-Arg ([string]$CmbManualBright.SelectedItem)
    Start-Apply "-ProfileName `"$p`" -Brightness $b" 'WhatManual'
}})
$TglEnabled.Add_Click({ Safe {
    $conf=Load-Config; Write-Config $TglEnabled.IsChecked $conf.schedule; Refresh-Status
    if($TglEnabled.IsChecked){ Show-Toast (T 'AutoOnT') 'ok' } else { Show-Toast (T 'AutoOffT') 'info' }
}})
$BtnFolder.Add_Click({ Start-Process explorer.exe $dir })

$script:statusTimer=New-Object Windows.Threading.DispatcherTimer; $script:statusTimer.Interval=[TimeSpan]::FromSeconds(5)
$script:statusTimer.Add_Tick({ Refresh-Status })
$win.Add_Loaded({ Safe { $script:lang=(Load-Config).language; Load-Grid; Apply-Lang; Refresh-Status; $script:statusTimer.Start() } })
[void]$win.ShowDialog()