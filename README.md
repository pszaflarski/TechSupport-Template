# TechSupport Bot (`agy`) Template

A portable, family-friendly IT support assistant powered by the Antigravity CLI (`agy`) for **Linux** and **Windows** (tested on **Ubuntu 24.04 LTS** and **Windows 11**, and designed to work on most modern desktop Linux distributions with Bash, Python 3, and Polkit/`pkexec`—regardless of whether your interactive shell is Bash, Zsh, etc.—and Windows 10/11 with PowerShell 5.1+; macOS is not currently supported out of the box). This pattern can be used with other coding CLIs such as Claude but agy still offers a generous free tier that allows it to help with a variety of issues to anyone with a Google account at $0. Each launch opens a fresh support conversation with plain-English guidance, targeted diagnostic skills, a deterministic safety hook, and a one-click privilege-escalation workflow (**Fix Issue** banana icon) so non-technical users never touch a terminal.

---

## Directory Layout

```text
TechSupport/
├── AGENTS.md                        # Core rules, skill router, safety guardrails, Fix Issue protocol
├── GEMINI.md -> AGENTS.md           # Relative symlink for CLI compatibility (avoids double rule tokens)
├── LOCAL_ENV.example.md             # Template copied to git-ignored LOCAL_ENV.md per machine
├── launch.sh                        # Linux GUI-terminal launcher + internet pre-flight + agy -i
├── launch.bat                       # Windows pre-flight + agy -i launcher
├── setup-ubuntu.sh                  # Linux setup (tested on Ubuntu): Desktop launcher, Caja/GNOME trust, workspace trust
├── setup-windows.ps1                # Windows setup: Desktop shortcut (.lnk), workspace trust
├── pair-ssh.sh                      # Optional Tailscale-pinned SSH pairing helper (Windows & Linux hosts)
├── .agents/
│   ├── hooks.json                   # PreToolUse safety gate + Stop session log exporter
│   ├── scripts/
│   │   ├── safety_gate.py / .ps1    # Blocks interactive sudo, disk/boot damage, disabling firewall/Tailscale
│   │   ├── export_session_log.py / .ps1 # Exports readable logs to logs/session_YYYY-MM-DD_<id>.log
│   │   └── run_fix.sh / .ps1        # Elevates temp_fix.* with "Working!" progress and "Done!" popups
│   └── skills/
│       ├── moonlight-sunshine/SKILL.md  # Moonlight / Sunshine / MultiSeat streaming recovery
│       ├── audio-output/SKILL.md        # PipeWire / WirePlumber / Bluetooth / Windows Audio recovery
│       └── printer-spooler/SKILL.md     # CUPS / Windows Print Spooler recovery
├── assets/
│   ├── support.png / support.ico    # Main launcher icons
│   └── banana.png / banana.ico      # Escalation shortcut icons ("Fix Issue")
└── logs/                            # Local session transcripts (git-ignored)
```

---

## Prerequisites

- **Antigravity CLI (`agy`)** installed and authenticated (`agy` available on `PATH` or `~/.local/bin` / `/usr/local/bin`).

---

## Quick Setup

### Linux (tested on Ubuntu 24.04 LTS — GNOME / MATE)

```bash
git clone https://github.com/pszaflarski/TechSupport-Template.git ~/TechSupport
cd ~/TechSupport
chmod +x setup-ubuntu.sh launch.sh pair-ssh.sh
./setup-ubuntu.sh
```

What `setup-ubuntu.sh` does:
- Copies `LOCAL_ENV.example.md` to `LOCAL_ENV.md` if missing.
- Creates `~/Desktop/TechSupport.desktop` (`Terminal=false`; `launch.sh` opens `mate-terminal` / `gnome-terminal` / `ptyxis` / `kgx` / `xfce4-terminal` / `konsole` directly to avoid `uxterm -x` issues).
- Marks the desktop launcher trusted for both GNOME (`metadata::trusted`) and MATE Caja (`metadata::caja-trusted-launcher`).
- Also installs `~/.local/share/applications/com.canonical.Terminal.TechSupport.desktop` with `StartupWMClass` so Wayland/X11 docks display the Tech Support icon instead of a generic gear/terminal icon.
- Adds this folder to `trustedWorkspaces` in `~/.gemini/antigravity-cli/settings.json`.

### Windows (Windows 10 / 11, tested on Windows 11)

Clone into `C:\TechSupport` (or your chosen folder), open PowerShell inside it, and run:

```powershell
git clone https://github.com/pszaflarski/TechSupport-Template.git C:\TechSupport
cd C:\TechSupport
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

What `setup-windows.ps1` does:
- Copies `LOCAL_ENV.example.md` to `LOCAL_ENV.md` if missing.
- Creates `Tech Support.lnk` on the user's Desktop pointing to `cmd.exe /c "<ProjectDir>\launch.bat"`.
- Adds the folder to `trustedWorkspaces` in `%USERPROFILE%\.gemini\antigravity-cli\settings.json`.

---

## Configure `LOCAL_ENV.md`

Edit the untracked `LOCAL_ENV.md` on each machine with its real:
- Machine hostname, user, OS/desktop, and `<PROJECT_DIR>`
- Optional (for Moonlight/Sunshine): Tailscale IP/hostname, SSH alias, streaming service/logs/ports, and LAN IP/MAC (for same-LAN Wake-on-LAN)
- Default printer name (if any)

---

## Model Selection (Free vs. Paid Tier)

- **Default (`gemini-3.8-flash-high`):** `launch.sh` and `launch.bat` pass `--model gemini-3.8-flash-high` by default so users on the $0 free tier work out of the box without altering global `agy` settings for your other CLI sessions.
- **Paid-tier upgrade (`gemini-4-hydrogen-high`):** If you have a paid tier, upgrading to **Gemini 4 Hydrogen (High)** is recommended. Create a git-ignored `.env` file in the TechSupport folder with:
  ```dotenv
  TECHSUPPORT_MODEL=gemini-4-hydrogen-high
  ```
- **Use `agy`'s own default:** Set `TECHSUPPORT_MODEL=default` (or leave it blank) in `.env` to omit `--model`. Run `agy models` anytime to check current model IDs.

---

## Optional: Pair Passwordless SSH for Moonlight/Sunshine

If you use `.agents/skills/moonlight-sunshine` to inspect or restart Sunshine/Apollo remotely over Tailscale:

```bash
./pair-ssh.sh
```

You can also pass arguments directly: `./pair-ssh.sh <remote_user> <tailscale_host_or_ip> [ssh_alias]`.

- Resolves the host's Tailscale IPv4 (`100.x.y.z`) and writes `Host sunshine-host ...` to `~/.ssh/config` so local router DNS never overrides Tailscale.
- Automatically detects Windows OpenSSH (`authorized_keys` + `C:\ProgramData\ssh\administrators_authorized_keys` with `icacls` permissions) vs. Linux/POSIX OpenSSH (`~/.ssh/authorized_keys`), then verifies `ssh -o BatchMode=yes sunshine-host "echo OK"`.

---

## Safety Hooks & Privilege Escalation

- **Safety Gate (`PreToolUse`):** [.agents/hooks.json](.agents/hooks.json) enforces deterministic blocking of bare interactive `sudo`, disk formatting/partitioning, bootloader edits, system directory wipes, and disabling SSH/Tailscale/firewalls/Defender—both in `run_command` and inside generated `temp_fix.*` scripts.
- **Banana Escalation ("Fix Issue"):** When root or Administrator rights are genuinely needed, the assistant writes `temp_fix.sh` / `temp_fix.bat`, puts a trusted **Fix Issue** banana shortcut on the Desktop (`run_fix.sh` with `pkexec` on Linux, `run_fix.ps1` with `Start-Process -Verb RunAs` on Windows—showing a `"Working!"` progress dialog and `"Done!"` popup), asks the user to double-click it, checks `logs/last_fix.log`, and deletes both the temporary script and shortcut afterward.
- **Session Logs (`Stop`):** Each conversation exports a clean transcript to `logs/session_YYYY-MM-DD_<id>.log` (git-ignored).

---

## Deployment Verification

1. **Cold Launch:** Double-click **Tech Support** on the Desktop and verify `agy` starts a brand-new conversation (`-i "hi"`), responds as a helpful tech support assistant in 1 plain-English sentence per `AGENTS.md`, and shows no permission or trust prompts.
2. **Skill Trigger:** Say *"My game won't connect in Moonlight"* and verify the assistant reads `LOCAL_ENV.md` and `.agents/skills/moonlight-sunshine/SKILL.md` and runs read-only diagnostics.
3. **Privilege Escalation:** Ask *"Flush my DNS cache"* and verify it creates the **Fix Issue** banana shortcut, prompts via polkit/UAC on double-click, verifies the fix, and cleans up `temp_fix.*` and the Desktop shortcut once confirmed.
