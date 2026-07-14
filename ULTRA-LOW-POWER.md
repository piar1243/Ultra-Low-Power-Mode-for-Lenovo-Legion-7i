# Legion Pro 7i ultra-low-power mode

This implementation is tailored to the detected Lenovo Legion Pro 7 16IAX10H (83F5): Core Ultra 9 275HX, RTX 5090 Laptop GPU, 2560 x 1600 OLED, and 99.9 Wh design battery. Measured full-charge capacity is 92.59 Wh (92.7% health, 90 cycles).

The existing AutoHotkey shortcut can keep launching C:\Scripts\toggle-ultralow.ps1 with no arguments. It remains a toggle.

## What changed

Ultra mode saves the current state, then:

- requests Lenovo Hybrid-iGPU Only through the embedded controller, waits up to 15 seconds, and verifies that the RTX 5090 is no longer electronically enumerable;
- selects Lenovo Quiet mode, 10% OLED brightness, and 60 Hz;
- confines long and short threads to the efficient processor class;
- parks every P-core and asks Windows to retain only its minimum runnable E-core set;
- activates Windows Energy Saver below 100%;
- disables CPU boost, caps frequency demand at 10%, maximizes both efficiency-class energy preferences, disables autonomous performance selection, and uses passive cooling;
- disables Intel AI Boost (NPU), the complete webcam USB parent, disconnected I226-V Ethernet, unused USB4 host router, Logitech G502 receiver, and Bluetooth unless their Keep switches are supplied;
- sends both NVMe SSDs into deep idle states much sooner using supported StorNVMe timeouts and latency tolerances;
- selects maximum Intel graphics, Wi-Fi, PCIe, USB, and video-playback savings;
- directs currently running light-work apps to the minimum-power GPU;
- temporarily stops Search indexing, Steam, iCUE, and NVIDIA overlay helpers;
- enables Windows dark theme;
- starts battery-overlay.ps1 as a draggable, top-right, always-on-top system watt meter;
- sleeps after five idle minutes and hibernates after fifteen, with wake timers off.

The next toggle closes the meter, sets brightness to 60%, and restores the previous plan, refresh rate, Lenovo modes, Bluetooth, NPU/camera/Ethernet/USB4/USB accessory devices, Search, theme, GPU preferences, and utilities. Runtime state/logs are under C:\ProgramData\LegionUltraLowPower.

The old script is preserved as toggle-ultralow.legacy-backup.ps1 and toggle-ultralow.pre-research.ps1. It left global background apps disabled and the normal Balanced plan capped at 20% on battery. The replacement detects that exact fingerprint and repairs it when normal mode is restored.

## Commands

Toggle:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1

Enable but keep Bluetooth:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode On -KeepBluetooth

Keep normally-disabled components or omit the overlay:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode On -KeepNpu -KeepCamera -KeepEthernet -KeepUsb4 -KeepUsbAccessories -NoOverlay

Restore:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode Off

Live watts, runtime, display, and RTX status:
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Scripts\toggle-ultralow.ps1 -Mode Status

Wait five minutes after enabling before judging watts. Ten hours from 92.59 Wh requires a sustained average at or below 9.26 W. Sustained draw over 12 W cannot reach ten hours.

The first revision measured 14.7-18 W in Chrome, equivalent to only 5.1-6.3 hours from the current battery. The second revision exists because the audit found that Lenovo/Windows had reset class-0 parking to 100%, leaving all 16 E-cores unparked.

## Hardware boundaries

- Core parking is the supported runtime equivalent of turning cores off: parked cores can enter deep idle states but remain available after the plan is restored. The script does not use the global, reboot-dependent BCDEdit numproc setting.
- Disabling Intel AI Boost prevents Windows from scheduling NPU work. It may save little at idle because the NPU is already power-managed; only a BIOS option, if Lenovo exposes one, can promise complete hardware disablement.
- The Intel iGPU must stay enabled because it drives the internal OLED and performs efficient hardware video decode. Disabling it could blank the panel or force the RTX awake.
- The RTX is different: Lenovo Hybrid-iGPU Only asks the embedded controller to disconnect it electrically. Device Manager disable is intentionally never used.
- The D: SSD is mounted and may contain projects, so it is never surprise-disabled. Both SSDs instead use supported deep NVMe idle states.
- USB4 is disabled only when its root router reports no attached external device. Use -KeepUsb4 before connecting a dock or USB4 device; use -KeepUsbAccessories to keep the G502 receiver powered.

## Required one-time settings

1. In Legion Space, confirm Hybrid-iGPU Only and Quiet. Disable Super Resolution, Smart Noise Cancelling, AI gaming features, and unnecessary effects.
2. Turn keyboard/chassis lighting fully off with Fn+Space. Disable Always-on USB unless needed during sleep.
3. In Settings > System > Display, turn HDR off on battery and confirm 60 Hz. Avoid bright white full-screen OLED content.
4. In Chrome enable Energy Saver, disable page preloading, and leave hardware acceleration on so Intel decodes YouTube. Edge Energy Saver at Maximum is a strong alternative. Prefer 1080p SDR to 4K/HDR.
5. Disconnect external displays and unnecessary USB devices. Some ports are wired to the RTX.
6. Charge to 100% before an all-day class. Conservation Mode preserves battery health but its 75-80% limit removes substantial unplugged capacity.

Do not disable the RTX in Device Manager. That does not electrically disconnect it and can leave it consuming power. If Status still shows the RTX, close GPU apps, set Hybrid-iGPU Only in Legion Space, and check again.

## The ten-hour limit

During the audit this laptop drew 40.9 W at 70% brightness and 240 Hz; the idle RTX alone drew 10.2 W. That explains the two-hour runtime.

Lenovo rates the 99.9 Wh model for up to 6.25 hours of local 1080p video at 150 nits and about 2.85 hours in MobileMark at 250 nits. Software cannot guarantee ten hours of YouTube/web/code on this hardware.

## Expected runtime after the changes

These are power-budget estimates from the measured 92.59 Wh full-charge capacity, not promises:

| Scenario | Likely average draw | Full-charge runtime |
| --- | ---: | ---: |
| Word/Google Docs plus mostly static web, dark theme | 10.5-13.5 W | 6.9-8.8 hours |
| VS Code, light local coding, no containers or builds | 11.5-15 W | 6.2-8.1 hours |
| Chrome/Edge 1080p SDR YouTube, Intel hardware decode | 13-17 W | 5.4-7.1 hours |
| Mixed class session: documents, browsing, light code, short video | 12-16 W | 5.8-7.7 hours |

Ten-plus hours is plausible only when the overlay settles below 9.26 W. Builds, extensions, sync, video conferencing, bright OLED pages, 4K/HDR video, poor Wi-Fi, or an RTX that failed to disconnect can move the result below these ranges.

If ten hours is non-negotiable, use this mode plus external energy. Lenovo documents USB-C PD inputs of 20 V/4.75 A, 20 V/5 A, 20 V/6.75 A, and 20 V/7 A. A classroom outlet or roughly 100 Wh USB-C pack supporting at least 20 V/5 A (100 W), or Lenovo's 140 W protocol, supplies the missing margin.

## Primary references

- Lenovo guide: https://download.lenovo.com/pccbbs/pubs/legion_pro7_16_10/user_guide/en/index.html
- Lenovo PSREF: https://psref.lenovo.com/syspool/Sys/PDF/Legion/Legion_Pro_7_16IAX10H/Legion_Pro_7_16IAX10H_Spec.pdf
- Microsoft battery guidance: https://support.microsoft.com/en-us/topic/a850d64d-ee8e-c8d2-6c75-8ffe6ea3ea99
- Microsoft powercfg: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options
- Microsoft processor power: https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options
- Microsoft StorNVMe power management: https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/power-management-for-storage-hardware-devices-nvme
- Microsoft core-parking maximum: https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-core-parking-cpmaxcores
- Microsoft heterogeneous scheduling: https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configuration-for-hetero-power-scheduling-schedulingpolicy
- Microsoft efficiency-class definition: https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-processor_relationship
- Microsoft Energy Saver threshold: https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/battery-threshold
- Intel Core Ultra 200HX core layout: https://cdrdv2-public.intel.com/842532/Intel%20Core%20Ultra%20200HX%20Series%20Processors%20-%20Quick%20Reference%20Guide%20v1.1.pdf
- Microsoft Edge Energy Saver: https://support.microsoft.com/en-us/edge/learn-about-performance-features-in-microsoft-edge
- Google Chrome Energy Saver: https://support.google.com/chrome/answer/12929150
- Legion Toolkit dGPU notes: https://github.com/LenovoLegionToolkit-Team/LenovoLegionToolkit#hybrid-mode-and-gpu-working-modes

