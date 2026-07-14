# Live battery discharge overlay for Legion Ultra Battery mode.
# BatteryStatus reports system-level discharge rate in milliwatts.
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$created=$false
$mutex=New-Object Threading.Mutex($true,'Local\LegionBatteryOverlay',[ref]$created)
if (-not $created) { $mutex.Dispose(); exit }

$form=New-Object Windows.Forms.Form
$form.Text='Legion Battery Draw'
$form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
$form.StartPosition=[Windows.Forms.FormStartPosition]::Manual
$form.Size=New-Object Drawing.Size(252,72)
$form.TopMost=$true
$form.ShowInTaskbar=$false
$form.BackColor=[Drawing.Color]::FromArgb(24,24,27)
$form.Opacity=0.94
$form.Padding=New-Object Windows.Forms.Padding(10,4,10,4)

$power=New-Object Windows.Forms.Label
$power.AutoSize=$false
$power.Location=New-Object Drawing.Point(10,2)
$power.Size=New-Object Drawing.Size(232,39)
$power.Font=New-Object Drawing.Font('Segoe UI',22,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$power.ForeColor=[Drawing.Color]::Gainsboro
$power.TextAlign=[Drawing.ContentAlignment]::MiddleLeft
$power.Text='--.- W'

$detail=New-Object Windows.Forms.Label
$detail.AutoSize=$false
$detail.Location=New-Object Drawing.Point(11,41)
$detail.Size=New-Object Drawing.Size(230,24)
$detail.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Regular)
$detail.ForeColor=[Drawing.Color]::Silver
$detail.Text='Reading battery telemetry...'

$form.Controls.Add($power)
$form.Controls.Add($detail)

$menu=New-Object Windows.Forms.ContextMenuStrip
$exitItem=$menu.Items.Add('Close watt meter')
$exitItem.Add_Click({ $form.Close() })
$form.ContextMenuStrip=$menu
$power.ContextMenuStrip=$menu
$detail.ContextMenuStrip=$menu

$tip=New-Object Windows.Forms.ToolTip
$tip.SetToolTip($form,'Drag to move; right-click to close')
$tip.SetToolTip($power,'Drag to move; right-click to close')
$tip.SetToolTip($detail,'Average of the last ten seconds; right-click to close')

$script:dragging=$false
$script:dragCursor=New-Object Drawing.Point(0,0)
$script:dragForm=New-Object Drawing.Point(0,0)
$mouseDown={
    param($sender,$e)
    if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $script:dragging=$true
        $script:dragCursor=[Windows.Forms.Cursor]::Position
        $script:dragForm=$form.Location
    }
}
$mouseMove={
    param($sender,$e)
    if ($script:dragging) {
        $now=[Windows.Forms.Cursor]::Position
        $form.Location=New-Object Drawing.Point(
            ($script:dragForm.X+$now.X-$script:dragCursor.X),
            ($script:dragForm.Y+$now.Y-$script:dragCursor.Y)
        )
    }
}
$mouseUp={ $script:dragging=$false }
foreach ($control in @($form,$power,$detail)) {
    $control.Add_MouseDown($mouseDown)
    $control.Add_MouseMove($mouseMove)
    $control.Add_MouseUp($mouseUp)
}

$samples=New-Object 'System.Collections.Generic.Queue[double]'
function Update-Telemetry {
    try {
        $b=Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus |
            Where-Object Active | Select-Object -First 1
        $f=Get-CimInstance -Namespace root\WMI -ClassName BatteryFullChargedCapacity |
            Where-Object Active | Select-Object -First 1
        if ($null -eq $b -or $null -eq $f) { throw 'No active battery' }

        $remaining=[double]$b.RemainingCapacity/1000
        $full=[double]$f.FullChargedCapacity/1000
        $percent=if ($full -gt 0) { [Math]::Min(100,[Math]::Round(100*$remaining/$full)) } else { 0 }
        $rate=[uint64]$b.DischargeRate

        if ($b.Discharging -and $rate -gt 0 -and $rate -lt 1000000) {
            $watts=[double]$rate/1000
            $samples.Enqueue($watts)
            while ($samples.Count -gt 5) { $null=$samples.Dequeue() }
            $average=($samples | Measure-Object -Average).Average
            $hours=if ($average -gt 0) { $remaining/$average } else { 0 }
            $whole=[Math]::Floor($hours)
            $minutes=[Math]::Floor(($hours-$whole)*60)
            $target=if ($full -gt 0) { $full/10 } else { 9.3 }

            $power.Text=('{0:N1} W' -f $average)
            $detail.Text=('Battery {0}%  |  {1}h {2:00}m  |  target <= {3:N1}W' -f $percent,$whole,$minutes,$target)
            if ($average -le $target) {
                $power.ForeColor=[Drawing.Color]::FromArgb(90,220,140)
            } elseif ($average -le ($target*1.35)) {
                $power.ForeColor=[Drawing.Color]::FromArgb(255,190,80)
            } else {
                $power.ForeColor=[Drawing.Color]::FromArgb(255,105,105)
            }
        } else {
            $samples.Clear()
            $power.Text='AC power'
            $power.ForeColor=[Drawing.Color]::FromArgb(110,190,255)
            $detail.Text=('Battery {0}%  |  not discharging' -f $percent)
        }
    } catch {
        $power.Text='--.- W'
        $power.ForeColor=[Drawing.Color]::Gainsboro
        $detail.Text='Battery telemetry unavailable'
    }
}

$form.Add_Shown({
    $area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location=New-Object Drawing.Point(($area.Right-$form.Width-12),($area.Top+12))
    Update-Telemetry
})

$timer=New-Object Windows.Forms.Timer
$timer.Interval=2000
$timer.Add_Tick({ Update-Telemetry })
$timer.Start()

try { [Windows.Forms.Application]::Run($form) }
finally {
    $timer.Stop()
    $timer.Dispose()
    $form.Dispose()
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
}
