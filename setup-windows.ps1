$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogsDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path -LiteralPath $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}

# Create LOCAL_ENV.md from template if missing
$LocalEnv = Join-Path $ScriptDir "LOCAL_ENV.md"
$ExampleEnv = Join-Path $ScriptDir "LOCAL_ENV.example.md"
if ((-not (Test-Path -LiteralPath $LocalEnv)) -and (Test-Path -LiteralPath $ExampleEnv)) {
    Copy-Item -LiteralPath $ExampleEnv -Destination $LocalEnv
    Write-Host "Created $LocalEnv from template. Update it with this machine's details."
}

# Ensure GEMINI.md is not a broken 9-byte git symlink stub on Windows
$GeminiMd = Join-Path $ScriptDir "GEMINI.md"
$AgentsMd = Join-Path $ScriptDir "AGENTS.md"
if ((Test-Path -LiteralPath $GeminiMd) -and ((Get-Item -LiteralPath $GeminiMd).Length -lt 64)) {
    Remove-Item -LiteralPath $GeminiMd -Force -ErrorAction SilentlyContinue
    try {
        New-Item -ItemType HardLink -Path $GeminiMd -Target $AgentsMd -ErrorAction Stop | Out-Null
    } catch {
        Copy-Item -LiteralPath $AgentsMd -Destination $GeminiMd -Force
    }
}

# Create Desktop & Start Menu shortcuts: Tech Support.lnk
$DesktopDir = [Environment]::GetFolderPath("Desktop")
$StartProgramsDir = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
$ShortcutPaths = @(
    (Join-Path $DesktopDir "Tech Support.lnk"),
    (Join-Path $StartProgramsDir "Tech Support.lnk")
)
$LaunchBat = Join-Path $ScriptDir "launch.bat"
$IconPath = Join-Path $ScriptDir "assets\support.ico"

$WshShell = New-Object -ComObject WScript.Shell
foreach ($ShortcutPath in $ShortcutPaths) {
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "$env:SystemRoot\System32\cmd.exe"
    $Shortcut.Arguments = "/c `"$LaunchBat`""
    $Shortcut.WorkingDirectory = $ScriptDir
    if (Test-Path -LiteralPath $IconPath) {
        $Shortcut.IconLocation = "$IconPath,0"
    }
    $Shortcut.Description = "Start Personal Tech Support"
    $Shortcut.Save()
}

# Notify Windows Explorer to refresh Desktop/Start Menu icons immediately
try {
    $ShellRefreshCode = @"
using System;
using System.Runtime.InteropServices;
public class TechSupportShellRefresh {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(int wEventId, int uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
"@
    Add-Type -TypeDefinition $ShellRefreshCode -ErrorAction SilentlyContinue
    [TechSupportShellRefresh]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
} catch {}

$NoBomUtf8 = New-Object System.Text.UTF8Encoding($false)

# Ensure .agents/hooks.json uses native PowerShell directly on Windows (avoids cmd.exe stderr noise)
$HooksPath = Join-Path $ScriptDir ".agents\hooks.json"
if (Test-Path -LiteralPath $HooksPath) {
    $HooksObj = @{
        "tech-support-safety-gate" = @{
            "PreToolUse" = @(
                @{
                    "matcher" = "run_command|write_file|edit_file"
                    "hooks"   = @(
                        @{
                            "type"    = "command"
                            "command" = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/safety_gate.ps1"
                            "timeout" = 10
                        }
                    )
                }
            )
        }
        "session-transcript-logger" = @{
            "Stop" = @(
                @{
                    "type"    = "command"
                    "command" = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/export_session_log.ps1"
                    "timeout" = 10
                }
            )
        }
    }
    $HooksJson = ($HooksObj | ConvertTo-Json -Depth 10) + "`r`n"
    [System.IO.File]::WriteAllText($HooksPath, $HooksJson, $NoBomUtf8)
}

# Add TechSupport folder to agy trustedWorkspaces
$SettingsDir = Join-Path $env:USERPROFILE ".gemini\antigravity-cli"
$SettingsPath = Join-Path $SettingsDir "settings.json"
if (-not (Test-Path -LiteralPath $SettingsDir)) {
    New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null
}

$Data = @{}
if (Test-Path -LiteralPath $SettingsPath) {
    $Raw = Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8
    if (-not [string]::IsNullOrWhiteSpace($Raw)) {
        $Parsed = $Raw | ConvertFrom-Json
        foreach ($prop in $Parsed.PSObject.Properties) {
            $Data[$prop.Name] = $prop.Value
        }
    }
}

$Trusted = New-Object System.Collections.Generic.List[string]
if ($Data.ContainsKey("trustedWorkspaces") -and $Data["trustedWorkspaces"]) {
    foreach ($item in $Data["trustedWorkspaces"]) {
        $Trusted.Add($item.ToString())
    }
}
if (-not $Trusted.Contains($ScriptDir)) {
    $Trusted.Add($ScriptDir)
}
$Data["trustedWorkspaces"] = $Trusted.ToArray()

$JsonOut = ($Data | ConvertTo-Json -Depth 10) + "`r`n"
[System.IO.File]::WriteAllText($SettingsPath, $JsonOut, $NoBomUtf8)

Write-Host "Windows TechSupport setup complete:"
Write-Host "  Desktop shortcut: $($ShortcutPaths[0])"
Write-Host "  Start Menu shortcut: $($ShortcutPaths[1])"
Write-Host "  Trusted workspace: $ScriptDir"
