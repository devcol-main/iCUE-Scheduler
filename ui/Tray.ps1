<#
  iCUE Scheduler - optional tray widget. Start it with iCUE-Tray.vbs, or turn it on in Settings.
  Left click the tray icon for the quick panel, right click for the menu.
  Time-based switching is still done by Task Scheduler, so the schedule keeps working without this.
#>
. "$PSScriptRoot\Common.ps1"
$created=$false; $mtx=New-Object Threading.Mutex($true,'Local\iCUESchedulerTray',[ref]$created)
if(-not $created){ exit 0 }
$script:conf=Load-Config; $script:lang=$script:conf.language
if(-not $script:conf.trayEnabled){ exit 0 }
$script:proc=$null; $script:hiddenAt=[datetime]::MinValue; $script:rendering=$false

$pop=Load-Xaml (Join-Path $uiDir 'TrayPanel.xaml'); $script:ResHost=$pop
foreach($n in 'AppIcon','L_Title','TglAuto','CurName','CurWhen','MiniTL','Tiles','Bright','Status','BtnOpen','BtnApply'){ Set-Variable -Name $n -Value ($pop.FindName($n)) -Scope Script }
$appIco=New-AppIcon; $AppIcon.Source=Icon-Source $appIco
$tlMini=New-Timeline @{Height=8;Labels=$false;Ticks=$false;Marker=$true}; $MiniTL.Content=$tlMini.Root
$bcTray=New-BrightControl $false $true; $Bright.Content=$bcTray.Root

function Exit-Tray { try{ $ni.Visible=$false; $ni.Dispose() }catch{}; try{ $mtx.ReleaseMutex() }catch{}; [Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() }
function Set-Busy([bool]$b){
    $Status.Visibility= if($b){'Visible'}else{'Collapsed'}; $Status.Text=T 'ApplyingT'
    foreach($x in @($BtnApply) + @($Tiles.Children)){ $x.IsEnabled=-not $b }; $bcTray.Root.IsEnabled=-not $b
}
function Run-Switch($argText){
    if($script:proc -and -not $script:proc.HasExited){ return }
    Set-Busy $true; $script:proc=Invoke-Switch $argText; $script:procTimer.Start()
}
function Render-Tray {
    $script:rendering=$true
    try{
        $c=Load-Config; $script:conf=$c; $script:lang=$c.language
        if(-not $c.trayEnabled){ Exit-Tray; return }
        $profiles=@(Get-IcueProfiles); $act=Get-ActiveName $profiles; $nx=Get-Next $c; $ic=Get-IcueCfg
        $L_Title.Text=T 'Title'; $TglAuto.IsChecked=$c.enabled
        if($act){ $CurName.Text=$act } else { $CurName.Text=T 'Unknown' }
        if($c.enabled){ $CurWhen.Text=(T 'WhenFmt') -f $nx.Time,$nx.Entry.profile,(Format-Dur $nx.Minutes) } else { $CurWhen.Text=T 'AutoOffState' }
        $tlMini.Conf=$c; Draw-Timeline $tlMini
        $Tiles.Children.Clear()
        foreach($p in $profiles){
            $tb=New-Object Windows.Controls.Primitives.ToggleButton; $tb.Style=Res 'Tile'; $tb.IsChecked=($p.Name -eq $act); $tb.Tag=$p.Name
            $sp=New-Object Windows.Controls.StackPanel
            $t1=New-Object Windows.Controls.TextBlock; $t1.Text=$p.Name; $t1.FontWeight='SemiBold'; $t1.FontSize=12.5; $t1.TextTrimming='CharacterEllipsis'
            $slot=$c.schedule | ? { $_.profile -eq $p.Name } | Select-Object -First 1
            $sub=''; if($slot){ $sub=Range-Of $c $slot.time }; if($p.Name -eq $act){ $sub=(@($sub,(T 'NowTag')) | ? { $_ }) -join ' · ' }
            $t2=New-Object Windows.Controls.TextBlock; $t2.Text=$sub; $t2.FontSize=10.5; $t2.Opacity=0.75; $t2.TextTrimming='CharacterEllipsis'
            [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2); $tb.Content=$sp
            $tb.Add_Click({ param($sender,$ev) Run-Switch "-ProfileName `"$($sender.Tag)`" -Brightness keep" })
            [void]$Tiles.Children.Add($tb)
        }
        if($ic -and $ic.BL -ne $null){ BC-Set $bcTray ([int]$ic.BL) }
        $BtnOpen.Content=T 'OpenWin'; $BtnApply.Content=T 'ApplySchedShort'
        $miOpen.Text=T 'TrayOpen'; $miApply.Text=T 'TrayApply'; $miAuto.Text=T 'Auto'; $miAuto.Checked=$c.enabled; $miExit.Text=T 'TrayExit'
        $tip=(T 'TrayTip') -f $(if($act){$act}else{'-'}); if($tip.Length -gt 63){ $tip=$tip.Substring(0,63) }; $ni.Text=$tip
    } catch { Err-Log "tray render: $_" } finally { $script:rendering=$false }
}
function Show-Panel {
    Render-Tray
    $pop.Show(); $pop.UpdateLayout()
    $wa=[System.Windows.SystemParameters]::WorkArea
    $pop.Left=$wa.Right-$pop.ActualWidth; $pop.Top=$wa.Bottom-$pop.ActualHeight
    $pop.Activate() | Out-Null
}
function Toggle-Panel {
    if($pop.IsVisible){ $pop.Hide(); return }
    if(((Get-Date)-$script:hiddenAt).TotalMilliseconds -lt 350){ return }
    Show-Panel
}
function Open-Main { Start-Process wscript.exe -ArgumentList "`"$(Join-Path $root 'iCUE-Scheduler.vbs')`"" }

# brightness: apply 0.9 s after the last change, to the current profile
$script:brTimer=New-Object Windows.Threading.DispatcherTimer; $script:brTimer.Interval=[TimeSpan]::FromMilliseconds(900)
$script:brTimer.Add_Tick({ $script:brTimer.Stop(); $act=Get-ActiveName (Get-IcueProfiles); if($act -and $bcTray.Value -ne $null){ Run-Switch "-ProfileName `"$act`" -Brightness $($bcTray.Value)" } })
$bcTray.OnChange={ param($c) if($script:rendering){ return }; $script:brTimer.Stop(); $script:brTimer.Start() }
$script:procTimer=New-Object Windows.Threading.DispatcherTimer; $script:procTimer.Interval=[TimeSpan]::FromMilliseconds(700)
$script:procTimer.Add_Tick({ if($script:proc -and $script:proc.HasExited){ $script:procTimer.Stop(); Set-Busy $false; Render-Tray } })

$pop.Add_Deactivated({ $pop.Hide(); $script:hiddenAt=Get-Date })
$TglAuto.Add_Click({ $on=[bool]$TglAuto.IsChecked; $c=Load-Config; $c.enabled=$on; Write-Config $c; Render-Tray })
$BtnOpen.Add_Click({ $pop.Hide(); Open-Main })
$BtnApply.Add_Click({ Run-Switch '-Force' })

# tray icon + menu
$ni=New-Object System.Windows.Forms.NotifyIcon; $ni.Icon=$appIco; $ni.Visible=$true
$menu=New-Object System.Windows.Forms.ContextMenuStrip
$miOpen=$menu.Items.Add('Open'); $miApply=$menu.Items.Add('Apply'); $miAuto=New-Object System.Windows.Forms.ToolStripMenuItem 'Auto'; [void]$menu.Items.Add($miAuto)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)); $miExit=$menu.Items.Add('Exit')
$miOpen.Add_Click({ Open-Main })
$miApply.Add_Click({ Run-Switch '-Force' })
$miAuto.Add_Click({ $c=Load-Config; $c.enabled=-not $c.enabled; Write-Config $c; Render-Tray })
$miExit.Add_Click({ Exit-Tray })
$ni.ContextMenuStrip=$menu
$ni.Add_MouseClick({ param($sender,$ev) if($ev.Button -eq [System.Windows.Forms.MouseButtons]::Left){ Toggle-Panel } })
$menu.Add_Opening({ Render-Tray })

$script:tick=New-Object Windows.Threading.DispatcherTimer; $script:tick.Interval=[TimeSpan]::FromSeconds(3)
$script:tick.Add_Tick({ try{ $c=Load-Config; if(-not $c.trayEnabled){ Exit-Tray; return }; if($pop.IsVisible -and -not ($script:proc -and -not $script:proc.HasExited)){ Render-Tray } else { $act=Get-ActiveName (Get-IcueProfiles); $script:lang=$c.language; $tip=(T 'TrayTip') -f $(if($act){$act}else{'-'}); if($tip.Length -gt 63){ $tip=$tip.Substring(0,63) }; $ni.Text=$tip } }catch{ Err-Log "tray tick: $_" } })
$script:tick.Start()
Render-Tray
[Windows.Threading.Dispatcher]::Run()