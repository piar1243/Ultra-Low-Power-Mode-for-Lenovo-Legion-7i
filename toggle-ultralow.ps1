[CmdletBinding()]
param(
    [ValidateSet('Toggle','On','Off','Status')][string]$Mode = 'Toggle',
    [switch]$KeepBluetooth,
    [switch]$KeepNpu,
    [switch]$KeepCamera,
    [switch]$KeepEthernet,
    [switch]$KeepUsb4,
    [switch]$KeepUsbAccessories,
    [switch]$NoOverlay,
    [switch]$NoMessage
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$UltraGuid = '456e3e72-99dd-4d3f-ac63-deeb00852e17'
$BalancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
$StateDir = Join-Path $env:ProgramData 'LegionUltraLowPower'
$StateFile = Join-Path $StateDir 'state.json'
$LogFile = Join-Path $StateDir 'toggle.log'
$NL = [Environment]::NewLine

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($Mode -ne 'Status' -and -not (Test-Admin)) {
    $a = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode {1}' -f $PSCommandPath,$Mode
    if ($KeepBluetooth) { $a += ' -KeepBluetooth' }
    if ($KeepNpu) { $a += ' -KeepNpu' }
    if ($KeepCamera) { $a += ' -KeepCamera' }
    if ($KeepEthernet) { $a += ' -KeepEthernet' }
    if ($KeepUsb4) { $a += ' -KeepUsb4' }
    if ($KeepUsbAccessories) { $a += ' -KeepUsbAccessories' }
    if ($NoOverlay) { $a += ' -NoOverlay' }
    if ($NoMessage) { $a += ' -NoMessage' }
    Start-Process powershell.exe -ArgumentList $a -Verb RunAs -WindowStyle Hidden
    exit
}

function Initialize-StateDir {
    if (-not (Test-Path -LiteralPath $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
    }
}

function Write-Log([string]$Text) {
    try {
        Initialize-StateDir
        Add-Content -LiteralPath $LogFile -Value ('{0:u} {1}' -f (Get-Date),$Text) -Encoding UTF8
    } catch { }
}

function Show-Message([string]$Text,[string]$Title='Legion Ultra Battery') {
    Write-Output $Text
    if (-not $NoMessage) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Text,$Title) | Out-Null
    }
}

function PowerCfg([string[]]$Arguments,[switch]$Optional) {
    $out = & powercfg.exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $m = 'powercfg {0} failed: {1}' -f ($Arguments -join ' '),($out -join ' ')
        if ($Optional) { Write-Log $m; return $false }
        throw $m
    }
    $out
}

function Get-ActiveScheme {
    $text = (& powercfg.exe /getactivescheme 2>&1) -join ' '
    $m = [regex]::Match($text,'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')
    if (-not $m.Success) { throw 'Cannot read the active power scheme.' }
    $m.Value.ToLowerInvariant()
}

function Test-Scheme([string]$Guid) {
    ((& powercfg.exe /list 2>&1) -join $NL) -match [regex]::Escape($Guid)
}

function Set-PowerValue([string]$Sub,[string]$Setting,[int]$Value) {
    PowerCfg -Arguments @('/setdcvalueindex',$UltraGuid,$Sub,$Setting,[string]$Value) -Optional | Out-Null
    PowerCfg -Arguments @('/setacvalueindex',$UltraGuid,$Sub,$Setting,[string]$Value) -Optional | Out-Null
}

function Configure-UltraPlan {
    if (-not (Test-Scheme $UltraGuid)) {
        PowerCfg -Arguments @('/duplicatescheme','SCHEME_MAX',$UltraGuid) | Out-Null
    }
    PowerCfg -Arguments @('/changename',$UltraGuid,'Legion Ultra Battery','Stable media-safe battery mode') | Out-Null
    $s = @(
        @('0012ee47-9041-4b5d-9b77-535fba8b1442','6738e2c4-e8a5-4a42-b16a-e040e769756e',10),
        @('0012ee47-9041-4b5d-9b77-535fba8b1442','d639518a-e56d-4345-8af2-b9f32fb26109',100),
        @('0012ee47-9041-4b5d-9b77-535fba8b1442','fc95af4d-40e7-4b6d-835a-56d131dbc80e',200),
        @('0012ee47-9041-4b5d-9b77-535fba8b1442','d3d55efd-c1ff-424e-9dc3-441be7833010',1000),
        @('0012ee47-9041-4b5d-9b77-535fba8b1442','dbc9e238-6de9-49e3-92cd-8c2b4946b472',200),
        @('0d7dbae2-4294-402a-ba8e-26777e8488cd','309dce9b-bef4-4119-9921-a851fb12f0f4',1),
        @('19cbb8fa-5279-450e-9fac-8a3d5fedd0c1','12bbebe6-58d6-4636-95bb-3217ef867c1a',3),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20','29f6c1db-86da-48c5-9fdb-f2b67b1f44da',300),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20','9d7815a6-7ee4-497e-8888-515a05f02364',900),
        @('238c9fa8-0aad-41ed-83f4-97be242c8f20','bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d',0),
        @('2a737441-1930-4402-8d77-b2bebba308a3','48e6b7a6-50f5-4782-a5d4-53bb8f07e226',1),
        @('501a4d13-42af-4429-9fd1-a8218c268e20','ee12f906-d277-404b-b6da-e5fa1a576df5',2),
        @('44f3beca-a7c0-460e-9df2-bb8b99e0cba6','3619c3f2-afb2-4afc-b0e9-e7fef372de36',0),
        @('54533251-82be-4824-96c1-47b60b740d00','893dee8e-2bef-41e0-89c6-b55d0929964c',5),
        @('54533251-82be-4824-96c1-47b60b740d00','bc5038f7-23e0-4960-96da-33abaf5935ec',40),
        @('54533251-82be-4824-96c1-47b60b740d00','be337238-0d82-4146-a960-4f3749d470c7',0),
        @('54533251-82be-4824-96c1-47b60b740d00','36687f9e-e3a5-4dbf-b1dc-15eb381c6863',90),
        @('54533251-82be-4824-96c1-47b60b740d00','36687f9e-e3a5-4dbf-b1dc-15eb381c6864',90),
        @('54533251-82be-4824-96c1-47b60b740d00','893dee8e-2bef-41e0-89c6-b55d0929964d',5),
        @('54533251-82be-4824-96c1-47b60b740d00','bc5038f7-23e0-4960-96da-33abaf5935ed',40),
        @('54533251-82be-4824-96c1-47b60b740d00','8baa4a8a-14c6-4451-8e8b-14bdbd197537',1),
        @('54533251-82be-4824-96c1-47b60b740d00','5d76a2ca-e8c0-402f-a133-2158492d58ad',0),
        @('54533251-82be-4824-96c1-47b60b740d00','94d3a615-a899-4ac5-ae2b-e4d8f634367f',0),
        # 275HX: class 0 is the 16 E-cores; class 1 is the 8 P-cores.
        # Keep 4-8 E-cores available and permit up to 2 P-cores as overload relief.
        @('54533251-82be-4824-96c1-47b60b740d00','0cc5b647-c1df-4637-891a-dec35c318583',25),
        @('54533251-82be-4824-96c1-47b60b740d00','ea062031-0e34-4ff1-9b6d-eb1059334028',50),
        @('54533251-82be-4824-96c1-47b60b740d00','0cc5b647-c1df-4637-891a-dec35c318584',0),
        @('54533251-82be-4824-96c1-47b60b740d00','ea062031-0e34-4ff1-9b6d-eb1059334029',25),
        @('54533251-82be-4824-96c1-47b60b740d00','93b8b6dc-0698-4d1c-9ee4-0644e900c85d',4),
        @('54533251-82be-4824-96c1-47b60b740d00','bae08b81-2d5e-4688-ad6a-13243356654b',4),
        @('54533251-82be-4824-96c1-47b60b740d00','616cdaa5-695e-4545-97ad-97dc2d1bdd88',25),
        @('54533251-82be-4824-96c1-47b60b740d00','616cdaa5-695e-4545-97ad-97dc2d1bdd89',13),
        @('7516b95f-f776-4464-8c53-06167f40cc99','3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e',90),
        @('7516b95f-f776-4464-8c53-06167f40cc99','aded5e82-b909-4619-9949-f5d71dac0bcb',20),
        @('7516b95f-f776-4464-8c53-06167f40cc99','f1fbfde2-a960-4165-9f88-50667911ce96',10),
        @('9596fb26-9850-41fd-ac3e-f7c3c00afd4b','10778347-1370-4ee0-8bbd-33bdacaade49',0),
        @('9596fb26-9850-41fd-ac3e-f7c3c00afd4b','34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4',2),
        @('de830923-a562-41af-a086-e3a2c6bad2da','e69653ca-cf7f-4f05-aa73-cb833fa90ad4',100),
        @('de830923-a562-41af-a086-e3a2c6bad2da','13d09884-f74e-474a-a852-b6bde8ad03a8',100)
    )
    foreach ($v in $s) { Set-PowerValue $v[0] $v[1] $v[2] }
    PowerCfg -Arguments @('/hibernate','on') -Optional | Out-Null
}

function Get-Brightness {
    try {
        [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness |
            Where-Object Active | Select-Object -First 1).CurrentBrightness
    } catch { -1 }
}

function Set-Brightness([int]$Value) {
    try {
        Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightnessMethods |
            Where-Object Active | ForEach-Object {
                Invoke-CimMethod -InputObject $_ -MethodName WmiSetBrightness -Arguments @{Timeout=[uint32]1;Brightness=[byte]$Value} | Out-Null
            }
        $true
    } catch { Write-Log ('Brightness failed: '+$_.Exception.Message); $false }
}

function Add-DisplayApi {
    if ('LegionDisplayApi' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LegionDisplayApi {
    const int Current = -1;
    const int FrequencyField = 0x00400000;
    const int UpdateRegistry = 1;
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct Mode {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string device;
        public short spec, driver, size, extra;
        public int fields, x, y, orientation, fixedOutput;
        public short color, duplex, yResolution, ttOption, collate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string form;
        public short logPixels;
        public int bits, width, height, flags, frequency;
        public int icmMethod, icmIntent, mediaType, ditherType, reserved1, reserved2, panWidth, panHeight;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern bool EnumDisplaySettings(string name, int number, ref Mode mode);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern int ChangeDisplaySettings(ref Mode mode, int flags);
    static Mode NewMode() {
        Mode mode = new Mode();
        mode.device = new string('\0',32);
        mode.form = new string('\0',32);
        mode.size = (short)Marshal.SizeOf(typeof(Mode));
        return mode;
    }
    public static int GetRefresh() {
        Mode mode = NewMode();
        return EnumDisplaySettings(null,Current,ref mode) ? mode.frequency : 0;
    }
    public static int SetRefresh(int value) {
        Mode mode = NewMode();
        if (!EnumDisplaySettings(null,Current,ref mode)) return -99;
        mode.fields = FrequencyField;
        mode.frequency = value;
        return ChangeDisplaySettings(ref mode,UpdateRegistry);
    }
}
'@
}

function Get-Refresh {
    try { Add-DisplayApi; [LegionDisplayApi]::GetRefresh() }
    catch { Write-Log ('Refresh read failed: '+$_.Exception.Message); 0 }
}

function Set-Refresh([int]$Value) {
    try {
        Add-DisplayApi
        $result=[LegionDisplayApi]::SetRefresh($Value)
        if ($result -notin @(0,1)) { throw "Windows display error $result" }
        $true
    } catch { Write-Log ('Refresh failed: '+$_.Exception.Message); $false }
}

function Get-RegState([string]$Path,[string]$Name) {
    try {
        [pscustomobject]@{Path=$Path;Name=$Name;Had=$true;Value=(Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop)}
    } catch { [pscustomobject]@{Path=$Path;Name=$Name;Had=$false;Value=$null} }
}

function Restore-Reg($State) {
    if ($State.Had) {
        New-Item -Path $State.Path -Force | Out-Null
        Set-ItemProperty -Path $State.Path -Name $State.Name -Value $State.Value -Force
    } else { Remove-ItemProperty -Path $State.Path -Name $State.Name -ErrorAction SilentlyContinue }
}

function Get-Lenovo {
    try { Get-CimInstance -Namespace root\WMI -ClassName LENOVO_GAMEZONE_DATA }
    catch { Write-Log ('Lenovo WMI unavailable: '+$_.Exception.Message); $null }
}

function Get-LenovoValue($Object,[string]$Method) {
    if ($null -eq $Object) { return $null }
    try { (Invoke-CimMethod -InputObject $Object -MethodName $Method).Data }
    catch { Write-Log ("$Method failed: "+$_.Exception.Message); $null }
}

function Set-LenovoIGpu($Object,[uint32]$Value) {
    if ($null -eq $Object) { return $false }
    try {
        Invoke-CimMethod -InputObject $Object -MethodName SetIGPUModeStatus -Arguments @{mode=$Value} | Out-Null
        $true
    } catch { Write-Log ('iGPU mode failed: '+$_.Exception.Message); $false }
}

function Set-LenovoPower($Object,[uint32]$Value) {
    if ($null -eq $Object) { return $false }
    try {
        Invoke-CimMethod -InputObject $Object -MethodName SetSmartFanMode -Arguments @{Data=$Value} | Out-Null
        $true
    } catch { Write-Log ('Quiet mode failed: '+$_.Exception.Message); $false }
}

function Get-GpuPreferenceStates {
    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    New-Item -Path $key -Force | Out-Null
    $names = @('chrome','msedge','firefox','Code','WINWORD','EXCEL','POWERPNT','ONENOTE','ChatGPT','codex')
    $paths = @()
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue | Where-Object ProcessName -in $names)) {
        try { if ($p.Path) { $paths += $p.Path } } catch { }
    }
    $saved = @()
    foreach ($path in ($paths | Sort-Object -Unique)) {
        $saved += Get-RegState $key $path
        Set-ItemProperty -Path $key -Name $path -Value 'GpuPreference=1;' -Type String -Force
    }
    @($saved)
}

function Get-BalancedMax {
    try {
        $t = (& powercfg /query $BalancedGuid SUB_PROCESSOR) -join $NL
        $m = [regex]::Match($t,'(?s)bc5038f7-23e0-4960-96da-33abaf5935ec.*?Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)')
        if ($m.Success) { return [Convert]::ToInt32($m.Groups[1].Value,16) }
    } catch { }
    -1
}

function Save-State($State) {
    Initialize-StateDir
    $tmp = $StateFile+'.tmp'
    [IO.File]::WriteAllText($tmp,($State | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
    Move-Item $tmp $StateFile -Force
}

function Read-State {
    if (Test-Path -LiteralPath $StateFile) { Get-Content $StateFile -Raw | ConvertFrom-Json } else { $null }
}

function Get-BatteryText {
    try {
        $b = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus | Where-Object Active | Select-Object -First 1
        $f = Get-CimInstance -Namespace root\WMI -ClassName BatteryFullChargedCapacity | Where-Object Active | Select-Object -First 1
        $w = 0.0
        if ($b.Discharging -and [uint64]$b.DischargeRate -lt 1000000) { $w=[double]$b.DischargeRate/1000 }
        $r=[double]$b.RemainingCapacity/1000
        $full=[double]$f.FullChargedCapacity/1000
        $h=0.0
        if ($w -gt 0) { $h=$r/$w }
        'Battery {0:N1}/{1:N1} Wh | draw {2:N1} W | current-charge projection {3:N1} h | 10h target <= {4:N1} W' -f $r,$full,$w,$h,($full/10)
    } catch { 'Battery telemetry unavailable: '+$_.Exception.Message }
}

function Get-NvidiaText {
    try {
        $n = Get-Command nvidia-smi.exe -ErrorAction Stop
        $t = & $n.Source --query-gpu=power.draw,pstate,utilization.gpu --format=csv,noheader 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $t) { 'RTX 5090 disconnected/powered off (desired).' }
        else { "RTX 5090 still visible: $t" }
    } catch { 'RTX 5090 disconnected or telemetry unavailable.' }
}

function Test-NvidiaConnected {
    try {
        $n=Get-Command nvidia-smi.exe -ErrorAction Stop
        $null=& $n.Source --query-gpu=name --format=csv,noheader 2>$null
        ($LASTEXITCODE -eq 0)
    } catch { $false }
}

function Wait-NvidiaState([bool]$Connected,[int]$TimeoutSeconds=15) {
    $end=(Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if ((Test-NvidiaConnected) -eq $Connected) { return $true }
        Start-Sleep -Milliseconds 750
    } while ((Get-Date) -lt $end)
    ((Test-NvidiaConnected) -eq $Connected)
}

function Get-UltraDeviceCandidates {
    $devices=@()
    if (-not $KeepNpu) {
        $devices += @(Get-PnpDevice -Class ComputeAccelerator -Status OK -ErrorAction SilentlyContinue |
            Where-Object FriendlyName -like '*Intel*AI Boost*' |
            ForEach-Object { [pscustomobject]@{InstanceId=$_.InstanceId;FriendlyName=$_.FriendlyName;Kind='NPU'} })
    }
    if (-not $KeepCamera) {
        $devices += @(Get-PnpDevice -Class USB -Status OK -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -like 'USB\VID_5986&PID_11AD\*' -and $_.InstanceId -notlike '*&MI_*' } |
            ForEach-Object { [pscustomobject]@{InstanceId=$_.InstanceId;FriendlyName='Integrated Camera USB parent';Kind='Camera'} })
    }
    if (-not $KeepEthernet) {
        foreach ($d in @(Get-PnpDevice -Class Net -Status OK -ErrorAction SilentlyContinue |
            Where-Object FriendlyName -like '*Ethernet*I226-V*')) {
            $adapter=Get-NetAdapter -InterfaceDescription $d.FriendlyName -ErrorAction SilentlyContinue
            if ($null -eq $adapter -or $adapter.Status -ne 'Up') {
                $devices += [pscustomobject]@{InstanceId=$d.InstanceId;FriendlyName=$d.FriendlyName;Kind='Ethernet'}
            }
        }
    }
    if ($false -and -not $KeepUsb4) {
        $root=Get-PnpDevice -Class USB -Status OK -ErrorAction SilentlyContinue |
            Where-Object FriendlyName -like 'USB4 Root Router*' | Select-Object -First 1
        $children=@()
        if ($null -ne $root) {
            $properties=@(Get-PnpDeviceProperty -InstanceId $root.InstanceId -KeyName 'DEVPKEY_Device_Children' -ErrorAction SilentlyContinue)
            foreach ($property in $properties) {
                if ($null -ne $property -and @($property.PSObject.Properties.Name) -contains 'Data') {
                    $children += @($property.Data)
                }
            }
        }
        if ($null -ne $root -and $children.Count -eq 0) {
            $devices += @(Get-PnpDevice -Class USB -Status OK -ErrorAction SilentlyContinue |
                Where-Object FriendlyName -eq 'USB4(TM) Host Router (Microsoft)' |
                ForEach-Object { [pscustomobject]@{InstanceId=$_.InstanceId;FriendlyName=$_.FriendlyName;Kind='USB4'} })
        }
    }
    if ($false -and -not $KeepUsbAccessories) {
        $devices += @(Get-PnpDevice -Class USB -Status OK -ErrorAction SilentlyContinue |
            Where-Object { $_.FriendlyName -eq 'G502 LIGHTSPEED' -and $_.InstanceId -like 'USB\VID_046D&PID_C539\*' } |
            ForEach-Object { [pscustomobject]@{InstanceId=$_.InstanceId;FriendlyName=$_.FriendlyName;Kind='USB accessory'} })
    }
    @($devices | Sort-Object InstanceId -Unique)
}

function Disable-UltraDevices {
    $disabled=@()
    foreach ($d in @(Get-UltraDeviceCandidates)) {
        try {
            Disable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop
            $disabled += $d
            Write-Log ('Disabled {0}: {1}' -f $d.Kind,$d.FriendlyName)
        } catch { Write-Log ('Device disable failed for {0}: {1}' -f $d.FriendlyName,$_.Exception.Message) }
    }
    @($disabled)
}

function Restore-UltraDevices($Devices) {
    foreach ($d in @($Devices)) {
        $id=if ($d -is [string]) { $d } else { [string]$d.InstanceId }
        if (-not $id) { continue }
        try { Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop }
        catch { Write-Log ('Device restore failed for {0}: {1}' -f $id,$_.Exception.Message) }
    }
}

function Start-BatteryOverlay {
    if ($NoOverlay) { return 0 }
    $script=Join-Path $PSScriptRoot 'battery-overlay.ps1'
    if (-not (Test-Path -LiteralPath $script)) { Write-Log 'Battery overlay script missing.'; return 0 }
    try {
        $a='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $script
        $p=Start-Process powershell.exe -ArgumentList $a -WindowStyle Hidden -PassThru
        [int]$p.Id
    } catch { Write-Log ('Overlay start failed: '+$_.Exception.Message); 0 }
}

function Stop-BatteryOverlay {
    $needle='battery-overlay.ps1'
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like ('*'+$needle+'*') })) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Enable-Ultra {
    $prev=Get-ActiveScheme
    $lenovo=Get-Lenovo
    $theme='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $bg='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    $bgState=Get-RegState $bg 'GlobalUserDisabled'
    $search=Get-Service WSearch -ErrorAction SilentlyContinue
    $bt=@()
    if (-not $KeepBluetooth) {
        $bt=@(Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue |
            Where-Object InstanceId -like 'USB\*' | Select-Object -ExpandProperty InstanceId)
    }
    $utilities=@()
    foreach ($p in (Get-Process -Name steam,iCUE -ErrorAction SilentlyContinue)) {
        try { if ($p.Path) { $utilities += [pscustomobject]@{Name=$p.ProcessName;Path=$p.Path} } } catch { }
    }
    $state=[ordered]@{
        PreviousScheme=$prev;Brightness=Get-Brightness;Refresh=Get-Refresh
        SearchRunning=[bool]($search -and $search.Status -eq 'Running');Bluetooth=$bt
        AppsTheme=Get-RegState $theme 'AppsUseLightTheme';SystemTheme=Get-RegState $theme 'SystemUsesLightTheme'
        Background=$bgState;LegacyDamage=[bool]($prev -eq $BalancedGuid -and (Get-BalancedMax) -eq 20 -and $bgState.Had -and [int]$bgState.Value -eq 1)
        GpuMode=Get-LenovoValue $lenovo 'GetIGPUModeStatus';PowerMode=Get-LenovoValue $lenovo 'GetSmartFanMode'
        GpuPreferences=@();Utilities=@($utilities | Sort-Object Path -Unique)
        DisabledDevices=@();OverlayPid=0;DgpuVerifiedOff=$false
    }
    Save-State $state
    Configure-UltraPlan
    $state.GpuPreferences=@(Get-GpuPreferenceStates)
    Save-State $state
    New-Item $theme -Force | Out-Null
    Set-ItemProperty $theme AppsUseLightTheme 0 -Type DWord
    Set-ItemProperty $theme SystemUsesLightTheme 0 -Type DWord
    if ($state.SearchRunning) { Stop-Service WSearch -Force -ErrorAction SilentlyContinue }
    foreach ($id in $state.Bluetooth) { Disable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction SilentlyContinue }
    Get-Process -Name steam,iCUE,'NVIDIA Overlay',nvsphelper64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $state.DisabledDevices=@(Disable-UltraDevices)
    Save-State $state
    Set-LenovoPower $lenovo 1 | Out-Null
    $gpu=Set-LenovoIGpu $lenovo 1
    Set-Brightness 10 | Out-Null
    $hz=Set-Refresh 60
    PowerCfg -Arguments @('/setactive',$UltraGuid) | Out-Null
    Configure-UltraPlan
    PowerCfg -Arguments @('/setactive',$UltraGuid) | Out-Null
    $off=Wait-NvidiaState -Connected $false -TimeoutSeconds 15
    $state.DgpuVerifiedOff=$off
    $state.OverlayPid=Start-BatteryOverlay
    Save-State $state
    $nv=Get-NvidiaText
    $warn=@()
    if (-not $gpu) { $warn+='Lenovo firmware rejected Hybrid-iGPU Only; select it in Legion Space.' }
    if (-not $hz) { $warn+='Press Fn+R to select 60 Hz.' }
    if (-not $off) { $warn+='RTX remains electrically connected: close every GPU app, disconnect external displays, then toggle off/on.' }
    $kinds=@($state.DisabledDevices | Select-Object -ExpandProperty Kind -Unique)
    $components=if ($kinds.Count) { $kinds -join ', ' } else { 'none (kept, unavailable, or already disabled)' }
    $m='ULTRA BATTERY MODE ON'+$NL+$NL+'CPU: 4-8 E-cores, up to 2 P-cores under load, 40% frequency ceiling.'+$NL+('Components disabled: '+$components)+$NL+(Get-BatteryText)+$NL+$nv
    if ($warn.Count) { $m += $NL+$NL+'ACTION NEEDED:'+$NL+'- '+($warn -join ($NL+'- ')) }
    Write-Log 'Enabled'
    Show-Message $m
}


function Repair-StrandedDevices {
    # Older releases could disable these while reporting failure and therefore
    # fail to save them in the rollback state.
    $devices=@(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
        $_.Status -eq 'Error' -and ($_.FriendlyName -like 'USB4*Host Router*' -or $_.FriendlyName -eq 'G502 LIGHTSPEED')
    })
    foreach ($d in $devices) {
        $problem=Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue
        if ($null -eq $problem -or $problem.Data -ne 22) { continue }
        try { Enable-PnpDevice -InstanceId $d.InstanceId -Confirm:$false -ErrorAction Stop }
        catch { & pnputil.exe /enable-device $d.InstanceId | Out-Null }
        $check=Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode' -ErrorAction SilentlyContinue
        if ($null -ne $check -and $check.Data -eq 22) {
            throw ('Could not re-enable '+$d.FriendlyName+'. Restart Windows, then run -Mode Off again as administrator.')
        }
        Write-Log ('Repaired stranded device: '+$d.FriendlyName)
    }
}
function Disable-Ultra {
    Repair-StrandedDevices
    $s=Read-State
    if ($null -eq $s) { PowerCfg -Arguments @('/setactive',$BalancedGuid)|Out-Null; Show-Message 'Balanced selected; no saved state existed.'; return }
    Stop-BatteryOverlay
    $lenovo=Get-Lenovo
    $gm=0
    if ($null -ne $s.GpuMode) { $gm=[uint32]$s.GpuMode }
    Set-LenovoIGpu $lenovo $gm | Out-Null
    Start-Sleep 3
    if ($null -ne $s.PowerMode) { Set-LenovoPower $lenovo ([uint32]$s.PowerMode)|Out-Null }
    Set-Brightness 60 | Out-Null
    if ([int]$s.Refresh -gt 0) { Set-Refresh ([int]$s.Refresh)|Out-Null }
    foreach ($id in @($s.Bluetooth)) { Enable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction SilentlyContinue }
    if (@($s.PSObject.Properties.Name) -contains 'DisabledDevices') {
        Restore-UltraDevices $s.DisabledDevices
    }
    if ($s.SearchRunning) { Start-Service WSearch -ErrorAction SilentlyContinue }
    Restore-Reg $s.AppsTheme
    Restore-Reg $s.SystemTheme
    foreach ($r in @($s.GpuPreferences)) { Restore-Reg $r }
    if ($s.LegacyDamage) {
        Remove-ItemProperty -Path $s.Background.Path -Name $s.Background.Name -ErrorAction SilentlyContinue
        PowerCfg -Arguments @('/setdcvalueindex',$BalancedGuid,'SUB_PROCESSOR','PROCTHROTTLEMIN','5') -Optional|Out-Null
        PowerCfg -Arguments @('/setdcvalueindex',$BalancedGuid,'SUB_PROCESSOR','PROCTHROTTLEMAX','100') -Optional|Out-Null
    } else { Restore-Reg $s.Background }
    foreach ($u in @($s.Utilities)) {
        if ($u.Path -and (Test-Path $u.Path) -and -not (Get-Process -Name $u.Name -ErrorAction SilentlyContinue)) {
            Start-Process $u.Path -WindowStyle Minimized -ErrorAction SilentlyContinue
        }
    }
    $scheme=[string]$s.PreviousScheme
    if (-not (Test-Scheme $scheme)) { $scheme=$BalancedGuid }
    PowerCfg -Arguments @('/setactive',$scheme)|Out-Null
    Remove-Item $StateFile -Force -ErrorAction SilentlyContinue
    Write-Log "Disabled; restored $scheme"
    Show-Message ('NORMAL MODE RESTORED'+$NL+$NL+'Previous plan, display, Lenovo modes, Bluetooth, NPU/camera/Ethernet devices, Search, theme, GPU preferences, and utilities restored.')
}

function Show-Status {
    $a=Get-ActiveScheme
    $on=($a -eq $UltraGuid -or (Test-Path $StateFile))
    Show-Message (('Ultra mode: '+$on)+$NL+"Active plan: $a"+$NL+('Display: {0}% / {1} Hz' -f (Get-Brightness),(Get-Refresh))+$NL+$NL+(Get-BatteryText)+$NL+(Get-NvidiaText)) 'Legion Battery Status'
}

$mutex=New-Object Threading.Mutex($false,'Global\LegionUltraLowPowerToggle')
if (-not $mutex.WaitOne(0)) { exit }
try {
    if ($Mode -eq 'Toggle') {
        if ((Get-ActiveScheme) -eq $UltraGuid -or (Test-Path $StateFile)) { $Mode='Off' } else { $Mode='On' }
    }
    switch ($Mode) { 'On'{Enable-Ultra};'Off'{Disable-Ultra};'Status'{Show-Status} }
} catch {
    $originalError=$_.Exception.Message
    Write-Log ('ERROR: '+$originalError)
    $rollback='No partial activation was detected.'
    if ($Mode -eq 'On' -and (Test-Path $StateFile)) {
        try {
            Disable-Ultra
            $rollback='Automatic rollback completed.'
            Write-Log $rollback
        } catch {
            $rollback='Automatic rollback also failed: '+$_.Exception.Message
            Write-Log $rollback
        }
    }
    Show-Message ('Toggle failed: '+$originalError+$NL+$NL+$rollback+$NL+'Run with -Mode Off if restoration is still needed.'+$NL+"Log: $LogFile") 'Legion Toggle Error'
    exit 1
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}

