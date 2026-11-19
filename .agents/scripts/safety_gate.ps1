$ErrorActionPreference = "SilentlyContinue"

$BannedPatterns = @(
    '(?i)\b(mkfs(\.[a-z0-9]+)?|fdisk|sfdisk|cfdisk|parted|gdisk|wipefs|diskpart|format\.com)\b',
    '(?i)\bdd\s+[^;|&\n]*of=/dev/(sd|nvme|mmcblk|vd|hd)',
    '(?i)\b(update-grub|grub-install|grub-mkconfig|bcdedit|bootrec)\b',
    '(?i)\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[a-zA-Z]*\s+/(?:\s|$|\*|(?:bin|boot|dev|etc|lib|lib64|opt|proc|root|run|sbin|sys|usr|var)(?:/|\s|$))',
    '(?i)\b(rd|rmdir)\s+/s\s+/q\s+c:\\(windows|users|program files)\b',
    '(?i)\bsystemctl\s+(stop|disable|mask)\s+(ssh|sshd|tailscaled|ufw|firewalld)\b',
    '(?i)\btailscale\s+(down|logout)\b',
    '(?i)\bufw\s+disable\b',
    '(?i)\bnetsh\s+advfirewall\s+set\s+\S+\s+state\s+off\b',
    '(?i)Set-MpPreference\s+[^;|&\n]*-DisableRealtimeMonitoring\s+\$?true'
)

$InteractiveSudoPattern = '(?i)(?:^|\n|&&|\|\||;|\||\$\(|`)\s*sudo(?:\s+(?!-n\b|--non-interactive\b)|$)'

function Emit-Decision {
    param(
        [string]$Decision,
        [string]$Reason = ""
    )
    $obj = @{ decision = $Decision }
    if ($Reason) { $obj.reason = $Reason }
    Write-Output ($obj | ConvertTo-Json -Compress)
    exit 0
}

function Test-BannedOp {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    foreach ($pat in $BannedPatterns) {
        if ($Text -match $pat) { return $true }
    }
    return $false
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { Emit-Decision -Decision "allow" }
    $data = $raw | ConvertFrom-Json
} catch {
    Emit-Decision -Decision "allow"
}

$toolName = ""
if ($data.toolCall -and $data.toolCall.name) {
    $toolName = $data.toolCall.name.ToString().ToLowerInvariant()
}
$args = $data.toolCall.args

if ($toolName -eq "run_command") {
    $cmd = ""
    if ($args.CommandLine) { $cmd = $args.CommandLine.ToString() }
    elseif ($args.commandLine) { $cmd = $args.commandLine.ToString() }

    if (Test-BannedOp -Text $cmd) {
        Emit-Decision -Decision "deny" -Reason "Blocked by TechSupport safety gate: destructive or security-disabling operation is prohibited."
    }
    if ($cmd -match $InteractiveSudoPattern) {
        Emit-Decision -Decision "deny" -Reason "Interactive sudo is blocked. Follow the PRIVILEGE ESCALATION PROTOCOL in AGENTS.md."
    }
} elseif ($toolName -in @("write_file", "edit_file")) {
    $targetPath = ""
    if ($args.Path) { $targetPath = $args.Path.ToString() }
    elseif ($args.path) { $targetPath = $args.path.ToString() }

    $baseName = [System.IO.Path]::GetFileName($targetPath).ToLowerInvariant()
    if ($baseName.StartsWith("temp_fix.")) {
        $content = ""
        if ($args.Content) { $content = $args.Content.ToString() }
        elseif ($args.content) { $content = $args.content.ToString() }
        elseif ($args.Replacement) { $content = $args.Replacement.ToString() }
        elseif ($args.replacement) { $content = $args.replacement.ToString() }

        if (Test-BannedOp -Text $content) {
            Emit-Decision -Decision "deny" -Reason "Blocked by TechSupport safety gate: destructive or security-disabling operation in temp_fix script is prohibited."
        }
    }
}

Emit-Decision -Decision "allow"
