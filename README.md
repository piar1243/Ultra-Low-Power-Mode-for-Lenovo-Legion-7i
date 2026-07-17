# Legion Ultra Low Power Mode

An aggressive, reversible Windows power mode for a Lenovo Legion Pro 7 16IAX10H equipped with an Intel Core Ultra 9 275HX and an NVIDIA RTX 5090 Laptop GPU.

The project was built for situations where battery runtime matters more than performance. It combines Windows power-plan controls, Lenovo firmware interfaces, reversible device shutdown, and a live system-discharge overlay.

> [!WARNING]
> This is hardware-specific power-management software. Review the script before using it on another Lenovo model. It intentionally disables selected devices and restricts CPU performance while enabled. The current profile is deliberately media-safe; older minimum-core/10% revisions could starve Windows, audio, and video workloads.

## Features

When ultra-low-power mode is enabled, the script:

- requests Lenovo Quiet mode and Hybrid-iGPU Only mode;
- waits for and verifies firmware-level RTX 5090 disconnection;
- prefers the efficient CPU class while retaining overload capacity;
- keeps approximately 4-8 E-cores available;
- permits up to two P-cores when demand spikes;
- disables CPU boost and applies a 40% processor-performance ceiling;
- applies a strong energy-saving preference to both processor efficiency classes;
- sets the OLED to 10% brightness and 60 Hz;
- enables Windows Energy Saver for the entire battery range;
- enables maximum PCIe, USB, Wi-Fi, iGPU, and video-playback savings;
- applies conservative, media-safe NVMe idle and latency settings;
- temporarily disables the Intel NPU, webcam, disconnected Ethernet, and Bluetooth;
- always leaves USB4 controllers and USB receivers enabled so that rollback remains reliable;
- stops Search indexing, Steam, iCUE, and NVIDIA overlay helpers when present;
- leaves the user's Windows theme, app mode, system mode, and colors untouched;
- launches a draggable live battery-watt overlay.

Turning the mode off restores the saved system state and sets display brightness to 60%. If activation throws an error after saving state, the script now attempts automatic rollback.

## Hardware target

This configuration was developed and tested for:

- Lenovo Legion Pro 7 16IAX10H, machine type 83F5
- Intel Core Ultra 9 275HX, 8 P-cores plus 16 E-cores
- NVIDIA RTX 5090 Laptop GPU
- 2560 x 1600, 240 Hz OLED
- 99.9 Wh design battery
- Windows 11

Other Lenovo Legion generations may expose different WMI methods or device identifiers.

## Requirements

- Windows 11
- Windows PowerShell 5.1
- Administrator approval for device and Lenovo firmware changes
- Lenovo firmware support for `LENOVO_GAMEZONE_DATA`
- Hybrid graphics enabled in firmware
- No application actively using the RTX when ultra mode is enabled
- No external display attached through an RTX-wired port

No third-party executable is required by the active implementation. Refresh-rate switching uses the native Windows display API.

## Quick start

*I put the contents in a "Scripts" folder in my windows SSD 
Run the main script with no arguments:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1
```

The command is a toggle:

- first run: enable ultra-low-power mode;
- next run: restore normal mode.

Windows may request UAC approval.

**For shortcuts:** you may also run the scripts under Autohotkey when you install it to setup the shortcut of cntrl+alt+f12 to move between power modes.

### AutoHotkey v2 example

```ahk
#Requires AutoHotkey v2.0

^!b::Run(
    'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\toggle-ultralow.ps1"',
    ,
    'Hide'
)
```

Change `^!b` to the shortcut you prefer.

## Commands

Enable explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode On
```

Restore normal mode:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode Off
```

Show battery, display, plan, and RTX status:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode Status
```

Suppress message boxes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode Status -NoMessage
```

## Optional keep switches

Ultra mode is intentionally severe. Use these switches when the corresponding hardware is needed:

| Switch | Effect |
| --- | --- |
| `-KeepBluetooth` | Leaves Bluetooth enabled |
| `-KeepNpu` | Leaves Intel AI Boost enabled |
| `-KeepCamera` | Leaves the integrated webcam enabled |
| `-KeepEthernet` | Leaves the I226-V Ethernet controller enabled |
| `-NoOverlay` | Does not launch the watt overlay |
| `-NoMessage` | Suppresses message boxes |

Example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode On -KeepBluetooth
```

## Live watt overlay

`battery-overlay.ps1` reads the Windows battery discharge rate every two seconds and displays:

- rolling system power draw in watts;
- remaining battery percentage;
- projected runtime at the current draw;
- the wattage target required for ten hours.

Drag the borderless window with the left mouse button. Right-click it to close it manually. Restoring normal mode closes it automatically.

## Recovery

Runtime state and logs are stored in:

```text
C:\ProgramData\LegionUltraLowPower\state.json
C:\ProgramData\LegionUltraLowPower\toggle.log
```

If activation fails, the script first attempts automatic rollback. If normal mode is not fully restored, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode Off
```

Do not delete `state.json` before restoration. It records which devices and settings must be restored.

`-Mode Off` also repairs USB4 host-router and Logitech G502 devices that an older script revision may have disabled without recording in `state.json`.

If Windows is severely unresponsive, restart the computer and run `-Mode Off` before attempting to enable ultra mode again.

Do not disable the RTX through Device Manager. That does not electronically disconnect the GPU and can increase power consumption. The script uses Lenovo's embedded-controller interface instead.

## Battery-life reality

The measured full-charge capacity during development was approximately 92.59 Wh. Ten hours requires a sustained whole-system draw no higher than approximately 9.26 W.

Observed Chrome draw before the current media-safe revision was approximately 14.7-18 W, equivalent to about 5.1-6.3 hours from that battery. Core parking helps when CPU activity is responsible for the draw, but parking too many cores can increase latency and cause audio buzzing, video glitches, or an unresponsive Windows shell. The current 4-8 E-core profile preserves enough headroom for media playback and normal desktop activity.

Lenovo rates the 99.9 Wh configuration for up to approximately 6.25 hours of local 1080p playback. Ten hours is a target, not a guarantee. Use the overlay to measure the result on your workload.

## Repository files

| File | Purpose |
| --- | --- |
| `toggle-ultralow.ps1` | Main reversible toggle |
| `battery-overlay.ps1` | Draggable system-watt display |
| `ULTRA-LOW-POWER.md` | Detailed implementation notes, measurements, and references |
| `toggle-ultralow.legacy-backup.ps1` | Original script backup |
| `toggle-ultralow.pre-research.ps1` | Pre-research backup |

`QRes.exe` is retained for historical compatibility but is not used by the current script.

## Technical references

- [Lenovo Legion Pro 7 16IAX10H product specification](https://psref.lenovo.com/syspool/Sys/PDF/Legion/Legion_Pro_7_16IAX10H/Legion_Pro_7_16IAX10H_Spec.pdf)
- [Microsoft processor power-management options](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options)
- [Microsoft core-parking maximum](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-core-parking-cpmaxcores)
- [Microsoft heterogeneous scheduling policy](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configuration-for-hetero-power-scheduling-schedulingpolicy)
- [Microsoft StorNVMe power management](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/power-management-for-storage-hardware-devices-nvme)
- [Lenovo Legion Toolkit GPU-mode notes](https://github.com/LenovoLegionToolkit-Team/LenovoLegionToolkit#hybrid-mode-and-gpu-working-modes)
