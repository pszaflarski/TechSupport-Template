param([string]$FixScript = "")

$ProjectDir = (Get-Item -LiteralPath $PSScriptRoot).Parent.Parent.FullName
if ([string]::IsNullOrWhiteSpace($FixScript)) {
    $FixScript = Join-Path $ProjectDir "temp_fix.bat"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$Title = "Tech Support - Fix Issue"

if (-not (Test-Path -LiteralPath $FixScript)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Could not find the fix script. Go back to Tech Support and ask to try again.",
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

try {
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$FixScript`"" -Verb RunAs -WindowStyle Hidden -PassThru
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Cancelled - no changes were made.",
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    exit 126
}

if (-not $proc.HasExited) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.ClientSize = New-Object System.Drawing.Size(340, 88)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.ControlBox = $false
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Working! Please wait..."
    $label.Location = New-Object System.Drawing.Point(16, 16)
    $label.Size = New-Object System.Drawing.Size(308, 22)
    $form.Controls.Add($label)

    $bar = New-Object System.Windows.Forms.ProgressBar
    $bar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $bar.MarqueeAnimationSpeed = 30
    $bar.Location = New-Object System.Drawing.Point(16, 44)
    $bar.Size = New-Object System.Drawing.Size(308, 22)
    $form.Controls.Add($bar)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 200
    $timer.Add_Tick({
        if ($proc.HasExited) {
            $timer.Stop()
            $form.Close()
        }
    })
    $form.Add_Shown({
        if ($proc.HasExited) {
            $form.Close()
        } else {
            $timer.Start()
        }
    })

    [void]$form.ShowDialog()
    $timer.Dispose()
    $form.Dispose()
}

$proc.WaitForExit()
$exitCode = $proc.ExitCode

if ($exitCode -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "Done! Go back to Tech Support and type 'done'.",
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} else {
    [System.Windows.Forms.MessageBox]::Show(
        "Done, but something may have failed. Go back to Tech Support and type 'done' so I can check.",
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

exit $exitCode
