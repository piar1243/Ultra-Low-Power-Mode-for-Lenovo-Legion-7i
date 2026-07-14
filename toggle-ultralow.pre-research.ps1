# Self-elevate if not already admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ultraLowGUID  = "456e3e72-99dd-4d3f-ac63-deeb00852e17"
$normalGUID    = "381b4222-f694-41f0-9685-ff5bb260df2e"
$qresPath      = "C:\Scripts\QRes.exe"

$currentGUID = ((powercfg /getactivescheme) -split ' ')[3]
$wmi = Get-CimInstance -Namespace "root\WMI" -ClassName "LENOVO_GAMEZONE_DATA"

if ($currentGUID -eq $ultraLowGUID) {
    powercfg /setactive $normalGUID
    Invoke-CimMethod -InputObject $wmi -MethodName "SetIGPUModeStatus" -Arguments @{mode = 0}

    # Restore refresh rate to 240Hz
    if (Test-Path $qresPath) {
        Start-Process -FilePath $qresPath -ArgumentList "/r:240" -WindowStyle Hidden -Wait
    }

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Normal Mode ON - GPU Enabled - 240Hz", "Power Toggle")
} else {
    # ── Power Plan ──────────────────────────────────────────
    powercfg /setactive $ultraLowGUID

    # ── GPU ─────────────────────────────────────────────────
    Invoke-CimMethod -InputObject $wmi -MethodName "SetIGPUModeStatus" -Arguments @{mode = 1}

    # ── Display ─────────────────────────────────────────────
    powercfg /setdcvalueindex $ultraLowGUID SUB_VIDEO VIDEOIDLE 120
    powercfg /setacvalueindex $ultraLowGUID SUB_VIDEO VIDEOIDLE 120
    (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1, 50)

    # Change refresh rate to 60Hz
    if (Test-Path $qresPath) {
        Start-Process -FilePath $qresPath -ArgumentList "/r:60" -WindowStyle Hidden -Wait
    }

    # ── Processor ───────────────────────────────────────────
    powercfg /setacvalueindex $ultraLowGUID SUB_PROCESSOR PROCTHROTTLEMAX 20
    powercfg /setdcvalueindex $ultraLowGUID SUB_PROCESSOR PROCTHROTTLEMAX 20
    powercfg /setacvalueindex $ultraLowGUID SUB_PROCESSOR PROCTHROTTLEMIN 0
    powercfg /setdcvalueindex $ultraLowGUID SUB_PROCESSOR PROCTHROTTLEMIN 0

    # ── Bluetooth ────────────────────────────────────────────
    Disable-PnpDevice -InstanceId (Get-PnpDevice | Where-Object {$_.Class -eq "Bluetooth" -and $_.Name -like "*Radio*"}).InstanceId -Confirm:$false -ErrorAction SilentlyContinue

    # ── USB Selective Suspend ────────────────────────────────
    powercfg /setacvalueindex $ultraLowGUID 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
    powercfg /setdcvalueindex $ultraLowGUID 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1

    # ── Hibernate ────────────────────────────────────────────
    powercfg /hibernate on
    powercfg /setdcvalueindex $ultraLowGUID SUB_SLEEP HIBERNATEIDLE 900

    # ── Wi-Fi Power Saving ───────────────────────────────────
    $wifi = Get-NetAdapter | Where-Object {$_.PhysicalMediaType -like "*802.11*" -and $_.Status -eq "Up"}
    Set-NetAdapterPowerManagement -Name $wifi.Name -SelectiveSuspend Enabled -ErrorAction SilentlyContinue

    # ── PCI Express Link State ───────────────────────────────
    powercfg /setacvalueindex $ultraLowGUID SUB_PCIEXPRESS ASPM 2
    powercfg /setdcvalueindex $ultraLowGUID SUB_PCIEXPRESS ASPM 2

    # ── Background Apps ──────────────────────────────────────
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v "GlobalUserDisabled" /t REG_DWORD /d 1 /f | Out-Null

    # ── Search Indexing ──────────────────────────────────────
    Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue

    powercfg /applyscheme $ultraLowGUID 2>$null

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Ultra-Low Power Mode ON - iGPU Only - 60Hz", "Power Toggle")
}