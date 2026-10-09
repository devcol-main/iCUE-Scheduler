# iCUE Scheduler

Switch your Corsair iCUE 5 profile and keyboard brightness automatically by time of day.
Windows only. Plain PowerShell + WPF, nothing to install.

**English** | [한국어](README.ko.md)

<p align="center"><img src="docs/home.png" width="720" alt="iCUE Scheduler home tab"></p>

## Features

- **24-hour timeline.** See which profile runs when, with a marker for the current time.
- **Time slots.** Add as many as you like. Each slot sets a profile and, optionally, keyboard brightness.
- **Brightness presets and slider.** Keep / 0 / 10 / 25 / 50 / 75 / 100 %, or drag the slider to any value.
- **Temporary override.** Use another profile or brightness now; the schedule takes over again at the next switch.
- **Leaves your manual changes alone.** Each slot is applied once, so changes you make in iCUE stay until the next slot starts.
- **Catches up** after logon or waking from sleep, if a switch was missed.
- **Optional tray widget** for one-click switching from the taskbar.
- English and Korean UI.
- The schedule itself runs from Windows Task Scheduler, so nothing has to stay running.

<p align="center"><img src="docs/schedule.png" width="560" alt="Schedule tab"> <img src="docs/tray.png" width="250" alt="Tray widget"></p>

## Requirements

- Windows 10 / 11
- Corsair iCUE 5 (developed with 5.51)
- Windows PowerShell 5.1 (comes with Windows)

## Install

1. Download the repository (**Code → Download ZIP**, or `git clone`) and put the folder where it can stay, for example `Documents\iCUE-Scheduler`.
2. If you downloaded a ZIP, unblock the files once. Open PowerShell in the folder and run:
   ```powershell
   Get-ChildItem -Recurse | Unblock-File
   ```
3. Run the installer (no administrator rights needed):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install.ps1
   ```
   This registers the scheduled task **iCUE Profile Scheduler** and puts an **iCUE Scheduler** shortcut on your desktop.
4. Open **iCUE Scheduler**, set up your time slots in the **Schedule** tab, and press **Save**.
   Profile names come from iCUE, so create your profiles in iCUE first.

## The app

| Tab | What it does |
|---|---|
| **Home** | Current profile and brightness, today's timeline, auto switching on/off, Task Scheduler status, and the temporary override |
| **Schedule** | Timeline plus a list of time slots. Pick a slot to edit its start time, profile and brightness. **Save** stores the schedule and updates the scheduled task. **Apply now** applies the current slot immediately |
| **Activity** | Every switch, newest first |
| **Settings** | Language, tray widget, start the tray widget with Windows, open folder, re-register the scheduled task |

A slot runs from its start time until the next start time, wrapping past midnight.
With `07:00 Default` and `23:00 Night`, *Night* is used from 23:00 to 07:00.

### Tray widget (optional)

Turn it on in **Settings → Tray widget**. Left-click the tray icon for a quick panel with
profile tiles, brightness and a mini timeline; right-click for a menu.
Anything you pick there is a temporary override until the next switch.
While it is on, the widget keeps running in the background. Time-based switching does not depend on it.

## How it works

iCUE has no public API for changing the active profile, so each switch does this:

1. Close iCUE.
2. Set `defaultProfile` (and `BrightnessLevel`, if a brightness is set) in `%APPDATA%\Corsair\CUE5\config.cuecfg`. The previous file is kept as `config.cuecfg.bak`.
3. Start iCUE again.

Your lighting goes off for a few seconds while iCUE restarts.

The scheduled task runs at every start time, at logon, and when the PC wakes from sleep.
It applies the current slot only if it has not been applied in that slot yet.

## Command line

```powershell
.\Switch-iCUEProfile.ps1                                        # what the scheduled task runs
.\Switch-iCUEProfile.ps1 -Force                                 # apply the current slot now
.\Switch-iCUEProfile.ps1 -ProfileName "Gaming" -Brightness 75   # temporary override (-Brightness keep = don't change)
```

## Files

| File | Purpose |
|---|---|
| `iCUE-Scheduler.vbs` | Opens the app without a console window (the desktop shortcut points here) |
| `iCUE-Tray.vbs` | Starts the tray widget |
| `ui/` | App code: `MainWindow`, `Tray`, shared `Common.ps1` and `Theme.xaml` |
| `Switch-iCUEProfile.ps1` | Does the actual switch |
| `run-hidden.vbs` | Lets the scheduled task run the switch script without a console window |
| `Install.ps1` / `Uninstall.ps1` | Register or remove the scheduled task and shortcuts |
| `schedule.example.json` | Starting settings, copied to `schedule.json` on first install |
| `schedule.json`, `state.json`, `scheduler.log` | Your settings, last applied state, and log (created locally, not in git) |

## Moving or removing

- **Moved the folder?** Run `Install.ps1` again, or use **Settings → Re-register scheduled task**.
- **Uninstall:** run `Uninstall.ps1`, then delete the folder.

## Notes and limitations

- Every switch restarts iCUE.
- **Brightness steps depend on your device.** iCUE rounds the value to what the device supports. A K70 RGB RAPIDFIRE, for example, only has 0 / 33 / 66 / 100 %, so 10 → 0, 25 → 33 and 50 → 66. The Home tab always shows the value iCUE actually uses.
- Brightness uses iCUE's device brightness setting and is applied to every device that has one.
- It reads and edits iCUE's own settings files, which are not documented. A future iCUE update could change them and break this tool.
- Profile names must match iCUE exactly. The app warns you when a name is not found.

## Disclaimer

This is an unofficial tool. It is not affiliated with or endorsed by Corsair. iCUE is a trademark of Corsair.
Use it at your own risk. A backup of the iCUE config is saved before every change.

## License

[Apache License 2.0](LICENSE)