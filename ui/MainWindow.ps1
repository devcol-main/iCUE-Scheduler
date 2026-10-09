<#
  iCUE Scheduler - main window. Start it with iCUE-Scheduler.vbs (or the desktop shortcut made by Install.ps1).
#>
. "$PSScriptRoot\Common.ps1"
# one window at a time: bring the existing one to the front instead
$created=$false; $mainMtx=New-Object Threading.Mutex($true,'Local\iCUESchedulerMain',[ref]$created)
if(-not $created){
    $other=Get-Process powershell -EA SilentlyContinue | ? { $_.Id -ne $PID -and $_.MainWindowTitle -and $_.MainWindowTitle -notlike '*Tray*' -and $_.MainWindowTitle -match 'iCUE' } | Select-Object -First 1
    if($other){ [void](New-Object -ComObject WScript.Shell).AppActivate($other.Id) }
    exit 0
}

$script:conf = Load-Config
$script:lang = $script:conf.language
$script:edit = New-Object System.Collections.ArrayList
$script:sel = $null; $script:dirty = $false; $script:busy = $false
$script:applyProc = $null; $script:closeArmed = $false; $script:tempSel = $null

$win = Load-Xaml (Join-Path $uiDir 'MainWindow.xaml'); $script:ResHost = $win
foreach($n in 'AppIcon','L_Title','L_Ver','NavHome','NavSched','NavLog','NavSettings','T_NavHome','T_NavSched','T_NavLog','T_NavSettings','TitleBar','BtnMin','BtnClose',
  'PageHome','PageSched','PageLog','PageSettings','H_Home','L_Now','CurDot','CurGlow','CurName','CurWhen','CurState','L_BrightNow','CurBright','CurBrightBar','HomeTL','HomeLegend',
  'TglEnabled','L_Auto','L_AutoSub','TaskDot','L_Task','L_TaskSub','L_Temp','L_TempNote','TempChips','TempBright','BtnTemp',
  'H_Sched','L_Unsaved','BtnApplySched','BtnSave','SchedTL','SlotList','BtnAdd','L_Start','EdTime','EdRange','L_Prof','EdProfile','L_Br','EdCustom','EdBright','BtnDel',
  'H_Log','BtnFolder','LogBox','H_Settings','L_Lang','L_LangSub','LangEn','LangKo','L_Tray','L_TraySub','TglTray','L_TrayStart','L_TrayStartSub','TglTrayStart',
  'L_FolderT','L_FolderSub','BtnOpenFolder','L_Rereg','L_ReregSub','BtnRereg','L_About','L_AboutSub','BtnGitHub','Toast','ToastText'){
    Set-Variable -Name $n -Value ($win.FindName($n)) -Scope Script
}
try{ $src=Icon-Source (New-AppIcon); $win.Icon=$src; $AppIcon.Source=$src }catch{}

$tlHome  = New-Timeline @{Height=30;Labels=$true;Ticks=$true;Marker=$true;MarkerLabel=$true}
$tlSched = New-Timeline @{Height=30;Labels=$true;Ticks=$true;Handles=$true;OnHandle={ param($t) Select-Slot ($script:edit | ? { $_.time -eq $t } | Select-Object -First 1) }}
$HomeTL.Content=$tlHome.Root; $SchedTL.Content=$tlSched.Root
$tempBC = New-BrightControl $true $false; $TempBright.Content=$tempBC.Root
$edBC   = New-BrightControl $true $true;  $EdBright.Content=$edBC.Root
$edBC.OnChange = { param($c) if($script:busy -or -not $script:sel){ return }; $script:sel.brightness=$c.Value; Set-Dirty $true; Render-Slots; Update-EdCustom }

# ---------------- helpers ----------------
$script:toastTimer=New-Object Windows.Threading.DispatcherTimer; $script:toastTimer.Interval=[TimeSpan]::FromSeconds(4)
$script:toastTimer.Add_Tick({ $script:toastTimer.Stop(); $Toast.Visibility='Collapsed' })
function Show-Toast($msg,$kind='info'){
    $c=@{ok=@('#173A2E','#2C6B52'); err=@('#40212A','#7A3340'); warn=@('#3F3320','#80652E'); info=@('#232A3D','#3A4468')}[$kind]
    $Toast.Background=Brush $c[0]; $Toast.BorderBrush=Brush $c[1]; $ToastText.Text=$msg; $Toast.Visibility='Visible'; $script:toastTimer.Interval=[TimeSpan]::FromSeconds($(if($kind -in 'warn','err'){7}else{4}))
    $script:toastTimer.Stop(); $script:toastTimer.Start()
}
function Safe([scriptblock]$b){ try{ & $b }catch{ Err-Log "$_ $($_.InvocationInfo.PositionMessage)"; Show-Toast ((T 'Err') + $_.Exception.Message) 'err' } }
function Set-Dirty($v){ $script:dirty=$v; $script:closeArmed=$false; $L_Unsaved.Visibility= if($v){'Visible'}else{'Collapsed'} }
function Update-ConfigField([scriptblock]$change){ $c=Load-Config; & $change $c; Write-Config $c; $script:conf=$c }
function Show-Page($name){
    foreach($p in @(@($PageHome,$NavHome,'home'),@($PageSched,$NavSched,'sched'),@($PageLog,$NavLog,'log'),@($PageSettings,$NavSettings,'settings'))){
        $on=($p[2] -eq $name); $p[0].Visibility= if($on){'Visible'}else{'Collapsed'}; $p[1].IsChecked=$on
    }
    $script:page=$name
    if($name -eq 'log'){ Render-Log }
}
function Copy-Schedule($items){ $l=New-Object System.Collections.ArrayList; foreach($e in $items){ [void]$l.Add([pscustomobject]@{time=$e.time;profile=$e.profile;brightness=$e.brightness}) }; ,$l }
function Edit-Conf { [pscustomobject]@{schedule=@($script:edit | Sort-Object time)} }

# ---------------- home ----------------
function Render-Home {
    $conf=$script:conf; $profiles=@(Get-IcueProfiles); $script:profiles=$profiles
    $act=Get-ActiveName $profiles; $cur=Get-Current $conf; $nx=Get-Next $conf; $cm=Get-ColorMap $conf; $ic=Get-IcueCfg
    if($act){ $CurName.Text=$act } else { $CurName.Text=T 'Unknown' }
    $dot='#8A92A6'; if($act -and $cm.ContainsKey($act)){ $dot=$cm[$act][3] }
    $CurDot.Fill=Brush $dot; $CurGlow.Color=Color $dot
    if($conf.enabled){
        $CurWhen.Text=(T 'WhenFmt') -f $nx.Time,$nx.Entry.profile,(Format-Dur $nx.Minutes)
        if($act -eq $cur.profile){ $CurState.Text=T 'Match'; $CurState.Foreground=Res 'Good' } else { $CurState.Text=T 'ManualOn'; $CurState.Foreground=Res 'Warn' }
    } else { $CurWhen.Text=T 'AutoOffState'; $CurState.Text='' }
    if($ic -and $ic.BL -ne $null){ $CurBright.Text="$($ic.BL)%"; $CurBrightBar.Width=120*[math]::Min(100,$ic.BL)/100 } else { $CurBright.Text='-'; $CurBrightBar.Width=0 }
    $tlHome.Conf=$conf; Draw-Timeline $tlHome
    $HomeLegend.Children.Clear(); $seen=@{}
    foreach($e in $conf.schedule){
        if($seen.ContainsKey($e.profile)){ continue }; $seen[$e.profile]=1
        $sp=New-Object Windows.Controls.StackPanel; $sp.Orientation='Horizontal'; $sp.Margin='0,0,18,0'
        $sq=New-Object Windows.Controls.Border; $sq.Width=9; $sq.Height=9; $sq.CornerRadius=3; $sq.Background=Brush $cm[$e.profile][3]; $sq.Margin='0,0,7,0'; $sq.VerticalAlignment='Center'
        $tb=New-Object Windows.Controls.TextBlock; $tb.Text=(T 'LegendFmt') -f $e.profile,(BL-Text $e.brightness); $tb.Foreground=Res 'MutedBrush'; $tb.FontSize=11.5
        [void]$sp.Children.Add($sq); [void]$sp.Children.Add($tb); [void]$HomeLegend.Children.Add($sp)
    }
    $script:busy=$true; $TglEnabled.IsChecked=$conf.enabled; $script:busy=$false
    $L_AutoSub.Text= if($conf.enabled){ T 'On' } else { T 'Off' }
    $ts=Get-TaskState; $L_Task.Text=$ts.Title; $L_TaskSub.Text=$ts.Sub; $TaskDot.Fill= if($ts.Ok){ Res 'Good' } else { Res 'Bad' }
    $L_TempNote.Text=(T 'TempNote') -f $nx.Time
    $names=@($profiles | % Name)
    if(-not $script:tempSel -or $names -notcontains $script:tempSel){ $script:tempSel=($names | ? { $_ -ne $act } | Select-Object -First 1); if(-not $script:tempSel){ $script:tempSel=$names | Select-Object -First 1 } }
    $TempChips.Children.Clear()
    foreach($n in $names){
        $ch=New-Object Windows.Controls.Primitives.ToggleButton; $ch.Style=Res 'Chip'; $ch.Content=$n; $ch.IsChecked=($n -eq $script:tempSel); $ch.Tag=$n
        $ch.Add_Click({ param($s,$e) $script:tempSel=$s.Tag; foreach($x in $TempChips.Children){ $x.IsChecked=($x.Tag -eq $script:tempSel) } })
        [void]$TempChips.Children.Add($ch)
    }
}

# ---------------- schedule ----------------
function Update-EdCustom { if(BC-IsCustom $edBC){ $EdCustom.Text=T 'Custom' } else { $EdCustom.Text='' } }
function Render-Slots {
    $SlotList.Children.Clear()
    $ec=Edit-Conf; $cm=Get-ColorMap $ec; $known=@($script:profiles | % Name)
    foreach($e in $ec.schedule){
        $bd=New-Object Windows.Controls.Border; $bd.CornerRadius=11; $bd.BorderThickness=1; $bd.Padding='12,9'; $bd.Margin='0,0,0,8'; $bd.Cursor='Hand'
        if($e -eq $script:sel){ $bd.BorderBrush=Res 'Accent'; $bd.Background=Brush '#1C1A33' } else { $bd.BorderBrush=Res 'Line'; $bd.Background=Res 'CardBg' }
        $g=New-Object Windows.Controls.Grid
        foreach($w in 'Auto','*','Auto'){ $cd=New-Object Windows.Controls.ColumnDefinition; if($w -eq '*'){ $cd.Width=[Windows.GridLength]::new(1,'Star') } else { $cd.Width=[Windows.GridLength]::Auto }; [void]$g.ColumnDefinitions.Add($cd) }
        $bar=New-Object Windows.Controls.Border; $bar.Width=4; $bar.CornerRadius=2; $bar.Background=Brush $cm[$e.profile][3]; $bar.Margin='0,1,11,1'
        $sp=New-Object Windows.Controls.StackPanel; [Windows.Controls.Grid]::SetColumn($sp,1)
        $t1=New-Object Windows.Controls.TextBlock; $t1.Text=$e.time; $t1.FontSize=15; $t1.FontWeight='Bold'; $t1.Foreground=Res 'Fg'
        $t2=New-Object Windows.Controls.TextBlock; $t2.FontSize=11.5; $t2.TextTrimming='CharacterEllipsis'
        if($known.Count -and $known -notcontains $e.profile){ $t2.Text="$($e.profile) · $(T 'Missing')"; $t2.Foreground=Res 'Warn' } else { $t2.Text=$e.profile; $t2.Foreground=Res 'Fg2' }
        [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2)
        $pill=New-Object Windows.Controls.Border; $pill.CornerRadius=9; $pill.Background=Brush '#232836'; $pill.Padding='8,2'; $pill.VerticalAlignment='Center'; [Windows.Controls.Grid]::SetColumn($pill,2)
        $pt=New-Object Windows.Controls.TextBlock; $pt.Text=BL-Text $e.brightness; $pt.FontSize=10.5; $pt.Foreground=Brush '#9AA2B5'; $pill.Child=$pt
        foreach($x in $bar,$sp,$pill){ [void]$g.Children.Add($x) }
        $bd.Child=$g; $bd.Tag=$e
        $bd.Add_MouseLeftButtonDown({ param($s,$a) Safe { Select-Slot $s.Tag } })
        [void]$SlotList.Children.Add($bd)
    }
    $tlSched.Conf=$ec; $tlSched.Sel= if($script:sel){ $script:sel.time } else { $null }; Draw-Timeline $tlSched
    if($script:sel){ $EdRange.Text=Range-Of $ec $script:sel.time }
}
function Select-Slot($e){
    if(-not $e){ return }
    $script:sel=$e; $script:busy=$true
    try{
        $EdTime.Text=$e.time; $EdTime.BorderBrush=Res 'Line2'
        $EdProfile.Items.Clear()
        $names=@($script:profiles | % Name); if($names -notcontains $e.profile){ $names+=$e.profile }
        foreach($n in $names){ [void]$EdProfile.Items.Add($n) }; $EdProfile.SelectedItem=$e.profile
        BC-Set $edBC $e.brightness
    } finally { $script:busy=$false }
    Update-EdCustom; Render-Slots
}
function Commit-Time {
    if(-not $script:sel){ return }
    $n=Normalize-Time $EdTime.Text
    if(-not $n){ $EdTime.BorderBrush=Res 'Bad'; Show-Toast (T 'BadTimeT') 'err'; return }
    if($n -eq $script:sel.time){ $script:busy=$true; $EdTime.Text=$n; $script:busy=$false; return }
    if($script:edit | ? { $_ -ne $script:sel -and $_.time -eq $n }){ Show-Toast ((T 'Dup') -f $n) 'err'; $script:busy=$true; $EdTime.Text=$script:sel.time; $script:busy=$false; return }
    $script:sel.time=$n; $script:busy=$true; $EdTime.Text=$n; $script:busy=$false
    Set-Dirty $true; Render-Slots
}
function Load-Edit {
    $script:edit=Copy-Schedule $script:conf.schedule
    $script:profiles=@(Get-IcueProfiles)
    $keep= if($script:sel){ $script:sel.time } else { $null }
    $pick=$script:edit | ? { $_.time -eq $keep } | Select-Object -First 1
    if(-not $pick){ $pick=$script:edit | Sort-Object time | Select-Object -First 1 }
    Select-Slot $pick; Set-Dirty $false
}
function Save-Schedule {
    $known=@($script:profiles | % Name)
    $missing=@($script:edit | ? { $known -notcontains $_.profile } | % { $_.profile } | Sort-Object -Unique)
    if($missing.Count -gt 0){ Show-Toast ((T 'MissingT') -f ($missing -join ', ')) 'err'; return $false }
    Update-ConfigField { param($c) $c.schedule=@(Copy-Schedule $script:edit) }
    $p=Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$install`"",'-Quiet','-NoShortcut' -WindowStyle Hidden -Wait -PassThru
    if($p.ExitCode -ne 0){ Show-Toast ((T 'RegFail') -f $p.ExitCode) 'err'; return $false }
    Load-Edit; Render-Home
    $true
}

# ---------------- log / settings ----------------
function Render-Log { $l=@(Get-LogLines 300); if($l.Count){ $LogBox.Text=$l -join "`r`n" } else { $LogBox.Text=T 'NoLog' } }
function Render-Settings {
    $script:busy=$true
    try{
        $LangEn.IsChecked=($script:lang -eq 'en'); $LangKo.IsChecked=($script:lang -eq 'ko')
        $TglTray.IsChecked=$script:conf.trayEnabled; $TglTrayStart.IsChecked=$script:conf.trayStartup; $TglTrayStart.IsEnabled=$script:conf.trayEnabled
    } finally { $script:busy=$false }
}
function Apply-Lang {
    $win.Title=T 'Title'; $L_Title.Text=T 'Title'; $L_Ver.Text="v$AppVersion"
    $T_NavHome.Text=T 'NavHome'; $T_NavSched.Text=T 'NavSched'; $T_NavLog.Text=T 'NavLog'; $T_NavSettings.Text=T 'NavSettings'
    $H_Home.Text=T 'NavHome'; $L_Now.Text=T 'Now'; $L_BrightNow.Text=T 'BrightNow'; $L_Auto.Text=T 'Auto'; $L_Temp.Text=T 'Temp'; $BtnTemp.Content=T 'TempBtn'
    $H_Sched.Text=T 'Sched'; $L_Unsaved.Text=T 'Unsaved'; $BtnApplySched.Content=T 'Apply'; $BtnSave.Content=T 'Save'; $BtnAdd.Content=T 'Add'
    $L_Start.Text=T 'Start'; $L_Prof.Text=T 'Prof'; $L_Br.Text=T 'Br'; $BtnDel.Content=T 'Del'
    $H_Log.Text=T 'Log'; $BtnFolder.Content=T 'Folder'
    $H_Settings.Text=T 'Settings'; $L_Lang.Text=T 'Lang'; $L_LangSub.Text=T 'LangSub'; $L_Tray.Text=T 'Tray'; $L_TraySub.Text=T 'TraySub'
    $L_TrayStart.Text=T 'TrayStart'; $L_TrayStartSub.Text=T 'TrayStartSub'; $L_FolderT.Text=T 'FolderT'; $L_FolderSub.Text=T 'FolderSub'; $BtnOpenFolder.Content=T 'Open'
    $L_Rereg.Text=T 'Rereg'; $L_ReregSub.Text=T 'ReregSub'; $BtnRereg.Content=T 'ReregBtn'; $L_About.Text=T 'About'; $L_AboutSub.Text=(T 'AboutSub') -f $AppVersion; $BtnGitHub.Content=T 'GitHub'
    BC-Relabel $tempBC; BC-Relabel $edBC
    Render-Home; Render-Slots; Update-EdCustom; Render-Settings; if($script:page -eq 'log'){ Render-Log }
}

# ---------------- apply ----------------
$script:applyTimer=New-Object Windows.Threading.DispatcherTimer; $script:applyTimer.Interval=[TimeSpan]::FromMilliseconds(700)
$script:applyTimer.Add_Tick({
    if($script:applyProc -and $script:applyProc.HasExited){
        $script:applyTimer.Stop(); $code=$script:applyProc.ExitCode
        $BtnApplySched.IsEnabled=$true; $BtnTemp.IsEnabled=$true; $BtnApplySched.Content=T 'Apply'; $BtnTemp.Content=T 'TempBtn'
        Render-Home
        if($code -eq 0){ Show-Toast ((T 'Done') -f (T $script:applyWhat)) 'ok'; if($script:reqBL -ne $null){ $script:roundTimer.Start() } } else { Show-Toast (T 'Failed') 'err' }
    }
})
$script:reqBL=$null
$script:roundTimer=New-Object Windows.Threading.DispatcherTimer; $script:roundTimer.Interval=[TimeSpan]::FromSeconds(12)
$script:roundTimer.Add_Tick({ $script:roundTimer.Stop(); try{ $m=Check-Rounded $script:reqBL; if($m){ Show-Toast $m 'warn' }; Render-Home }catch{ Err-Log "round: $_" } })
function Start-Apply($argText,$what){
    if($script:applyProc -and -not $script:applyProc.HasExited){ Show-Toast (T 'Busy') 'warn'; return }
    $BtnApplySched.IsEnabled=$false; $BtnTemp.IsEnabled=$false; $BtnApplySched.Content=T 'Applying'; $BtnTemp.Content=T 'Applying'
    $script:applyWhat=$what; $script:applyProc=Invoke-Switch $argText
    Show-Toast (T 'ApplyingT') 'info'; $script:applyTimer.Start()
}

# ---------------- events ----------------
$TitleBar.Add_MouseLeftButtonDown({ try{ $win.DragMove() }catch{} })
$BtnMin.Add_Click({ $win.WindowState='Minimized' })
$BtnClose.Add_Click({
    if($script:dirty -and -not $script:closeArmed){ $script:closeArmed=$true; Show-Toast (T 'CloseArm') 'warn'; return }
    $win.Close()
})
$NavHome.Add_Click({ Safe { Show-Page 'home' } })
$NavSched.Add_Click({ Safe { Show-Page 'sched' } })
$NavLog.Add_Click({ Safe { Show-Page 'log' } })
$NavSettings.Add_Click({ Safe { Show-Page 'settings' } })

$TglEnabled.Add_Click({ Safe {
    $on=[bool]$TglEnabled.IsChecked; Update-ConfigField { param($c) $c.enabled=$on }; Render-Home
    if($on){ Show-Toast (T 'AutoOnT') 'ok' } else { Show-Toast (T 'AutoOffT') 'info' }
}})
$BtnTemp.Add_Click({ Safe {
    if(-not $script:tempSel){ Show-Toast (T 'ChooseProfile') 'warn'; return }
    $b='keep'; $script:reqBL=$null; if($tempBC.Value -ne $null){ $b="$($tempBC.Value)"; $script:reqBL=[int]$tempBC.Value }
    Start-Apply "-ProfileName `"$($script:tempSel)`" -Brightness $b" 'WhatManual'
}})

$EdTime.Add_LostFocus({ Safe { if(-not $script:busy){ Commit-Time } } })
$EdTime.Add_KeyDown({ param($s,$e) if($e.Key -eq 'Return'){ Safe { Commit-Time } } })
$EdTime.Add_TextChanged({ if(-not $script:busy){ $EdTime.BorderBrush=Res 'Line2' } })
$EdProfile.Add_SelectionChanged({ Safe {
    if($script:busy -or -not $script:sel -or -not $EdProfile.SelectedItem){ return }
    $script:sel.profile=[string]$EdProfile.SelectedItem; Set-Dirty $true; Render-Slots
}})
$BtnAdd.Add_Click({ Safe {
    $used=@($script:edit | % { $_.time }); $t=$null
    foreach($h in @(12..23)+@(0..11)){ $c='{0:00}:00' -f $h; if($used -notcontains $c){ $t=$c; break } }
    if(-not $t){ return }
    $first=@($script:profiles | % Name) | Select-Object -First 1
    $e=[pscustomobject]@{time=$t;profile=$first;brightness=$null}; [void]$script:edit.Add($e)
    Set-Dirty $true; Select-Slot $e; $EdTime.Focus(); $EdTime.SelectAll()
}})
$BtnDel.Add_Click({ Safe {
    if($script:edit.Count -le 1){ Show-Toast (T 'MinOne') 'warn'; return }
    $script:edit.Remove($script:sel); Set-Dirty $true
    Select-Slot ($script:edit | Sort-Object time | Select-Object -First 1)
}})
$BtnSave.Add_Click({ Safe { Commit-Time; if(Save-Schedule){ Show-Toast (T 'Saved') 'ok' } } })
$BtnApplySched.Add_Click({ Safe {
    if($script:dirty){ Show-Toast (T 'SaveFirst') 'warn'; return }
    $script:reqBL=(Get-Current $script:conf).brightness; Start-Apply '-Force' 'WhatSched'
}})

$BtnFolder.Add_Click({ Start-Process explorer.exe $root })
$BtnOpenFolder.Add_Click({ Start-Process explorer.exe $root })
$BtnGitHub.Add_Click({ Start-Process $RepoUrl })
$LangEn.Add_Click({ Safe { $script:lang='en'; Update-ConfigField { param($c) $c.language='en' }; Apply-Lang } })
$LangKo.Add_Click({ Safe { $script:lang='ko'; Update-ConfigField { param($c) $c.language='ko' }; Apply-Lang } })
$TglTray.Add_Click({ Safe {
    if($script:busy){ return }
    $on=[bool]$TglTray.IsChecked
    Update-ConfigField { param($c) $c.trayEnabled=$on; if(-not $on){ $c.trayStartup=$false } }
    if($on){ Start-Tray; Show-Toast (T 'TrayOnT') 'ok' } else { Set-TrayStartup $false; Show-Toast (T 'TrayOffT') 'info' }
    Render-Settings
}})
$TglTrayStart.Add_Click({ Safe {
    if($script:busy){ return }
    $on=[bool]$TglTrayStart.IsChecked; Update-ConfigField { param($c) $c.trayStartup=$on }; Set-TrayStartup $on; Render-Settings
}})
$BtnRereg.Add_Click({ Safe {
    $p=Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$install`"",'-Quiet' -WindowStyle Hidden -Wait -PassThru
    if($p.ExitCode -eq 0){ Show-Toast (T 'Rereged') 'ok' } else { Show-Toast ((T 'RegFail') -f $p.ExitCode) 'err' }
    Render-Home
}})

$script:statusTimer=New-Object Windows.Threading.DispatcherTimer; $script:statusTimer.Interval=[TimeSpan]::FromSeconds(5)
$script:statusTimer.Add_Tick({
    try{
        $c=Load-Config; $script:conf.enabled=$c.enabled; $script:conf.trayEnabled=$c.trayEnabled; $script:conf.trayStartup=$c.trayStartup
        Render-Home; if($script:page -eq 'log'){ Render-Log }; if($script:page -eq 'settings'){ Render-Settings }
    }catch{ Err-Log "tick: $_" }
})
$win.Add_Loaded({ Safe { Load-Edit; Apply-Lang; Show-Page 'home'; $script:statusTimer.Start(); if($script:conf.trayEnabled){ Start-Tray } } })
[void]$win.ShowDialog()