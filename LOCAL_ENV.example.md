# LOCAL MACHINE ENVIRONMENT

Copy or let `setup-ubuntu.sh` / `setup-windows.ps1` create `LOCAL_ENV.md` from this template, then fill in the real values for this machine. (`LOCAL_ENV.md` is git-ignored.)

- **Machine / Hostname:** `<MACHINE_HOSTNAME>`
- **User / Home / Project Directory:** `<USERNAME>` (`<PROJECT_DIR>`, e.g., `/home/<USERNAME>/TechSupport` or `C:\TechSupport`)
- **Client OS & Desktop:** `<CLIENT_OS>` (e.g., Ubuntu 24.04 LTS MATE / Windows 11)
- **Audio Stack:** PipeWire + WirePlumber (`wpctl`, `pulsemixer`) / Windows Audio (`AudioSrv`)
- **Network & Overlay:** Tailscale active (`100.x.y.z`)
- **Streaming Client:** Moonlight (apps: `Desktop`, `Steam Big Picture`)
- **Remote Gaming Host:**
  - **Tailscale Hostname & IP:** `<GAMING_HOST_TAILSCALE>` (`100.x.y.z`, Windows 11 / Linux)
  - **SSH Alias:** `sunshine-host` (user `<SSH_USER>`, passwordless key configured in `~/.ssh/config`, remote shell PowerShell / bash)
  - **Host Streaming Server (Standard Sunshine):** service `SunshineService` / `sunshinesvc` (or `sunshine` user systemd unit on Linux), log path `C:\Program Files\Sunshine\config\sunshine.log` (or `~/.config/sunshine/sunshine.log`), TCP port `47989`
  - **Optional MultiSeat / ApolloVibe Host (remove if unused):** service `MultiSeatService`, seat account `<SEAT_ACCOUNT>`, log path `C:\ProgramData\MultiSeat\apollo\<SEAT_ACCOUNT>\apollo.log`, seat config `C:\ProgramData\MultiSeat\apollo\<SEAT_ACCOUNT>\sunshine.conf`, loopback API `http://127.0.0.1:9550/api/seats` (`X-MultiSeat-Key` from `C:\ProgramData\MultiSeat\api-key.txt`), TCP ports `48095` / `48100`
  - **Host LAN IP & MAC:** `192.168.x.y`, MAC `AA:BB:CC:DD:EE:FF` (Wake-on-LAN only works on the same local LAN, never across Tailscale)
- **Default Printer:** `<PRINTER_NAME_OR_NONE>`
