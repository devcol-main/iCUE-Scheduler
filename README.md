# iCUE Scheduler

Switch your Corsair iCUE 5 profile and keyboard brightness automatically by time of day.
Windows only. Plain PowerShell, nothing to install.

**English** | [한국어](README.ko.md)

## Features

- **Time-based profile switching.** Add as many time slots as you like.
- **Keyboard brightness per slot** (optional): 0 / 33 / 66 / 100 %.
- **Temporary override.** Use a different profile now; the schedule takes over again at the next switch.
- **Leaves your manual changes alone.** Each slot is applied once, so if you change the profile in iCUE yourself, it stays until the next slot starts.
- **Catches up** after logon or waking from sleep, if a switch was missed.
- **Dark GUI** in English and Korean. You can switch the language in the title bar.
- Runs from Windows Task Scheduler, so nothing stays running in the background.

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
4. Open **iCUE Scheduler**, set your times and profiles, and press **Save**.
   Profile names come from iCUE, so create your profiles in iCUE first.

## Using the GUI

| Section | What it does |
|---|---|
| Status cards | Current iCUE profile, keyboard brightness, and the next switch |
| Auto switching | Turns the whole schedule on or off |
| Schedule | Start time, profile, and brightness for each slot. **Save** writes the settings and updates the scheduled task. **Apply now** applies the current slot immediately |
| Temporary override | Applies a profile and brightness right away until the next scheduled switch |
| Recent activity | The last few switches |

A slot runs from its start time until the next start time, wrapping past midnight.
With `07:00 Default` and `23:00 Night`, *Night* is used from 23:00 to 07:00.

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
.\Switch-iCUEProfile.ps1                                    # what the scheduled task runs
.\Switch-iCUEProfile.ps1 -Force                             # apply the current slot now
.\Switch-iCUEProfile.ps1 -ProfileName "Gaming" -Brightness 66   # temporary override (-Brightness keep = don't change)
```

## Files

| File | Purpose |
|---|---|
| `iCUE-Scheduler.vbs` | Starts the GUI without a console window (the desktop shortcut points here) |
| `iCUE-Scheduler.ps1`, `iCUE-Scheduler.xaml` | GUI |
| `Switch-iCUEProfile.ps1` | Does the actual switch |
| `run-hidden.vbs` | Lets the scheduled task run the switch script without a console window |
| `Install.ps1` / `Uninstall.ps1` | Register or remove the scheduled task and desktop shortcut |
| `schedule.example.json` | Starting settings, copied to `schedule.json` on first install |
| `schedule.json`, `state.json`, `scheduler.log` | Your settings, last applied state, and log (created locally, not in git) |

## Moving or removing

- **Moved the folder?** Run `Install.ps1` again. The task and shortcut point to the folder's location.
- **Uninstall:** run `Uninstall.ps1`, then delete the folder.

## Notes and limitations

- Every switch restarts iCUE.
- It reads and edits iCUE's own settings files, which are not documented. A future iCUE update could change them and break this tool.
- Brightness uses iCUE's device brightness setting and is applied to every device that has one. It was developed with a K70 RGB RAPIDFIRE keyboard. Other devices are untested.
- Profile names must match iCUE exactly. The GUI warns you when a name is not found.

## Disclaimer

This is an unofficial tool. It is not affiliated with or endorsed by Corsair. iCUE is a trademark of Corsair.
Use it at your own risk. A backup of the iCUE config is saved before every change.

## License

[Apache License 2.0](LICENSE)