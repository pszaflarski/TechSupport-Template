---
name: moonlight-sunshine
description: >-
  Use this skill when the user reports Moonlight cannot connect, game streaming fails,
  the gaming host appears offline, Steam Big Picture times out, or the stream shows a
  black screen or encoder error.
---

# RUNBOOK: Moonlight / Sunshine Connection Failure

## Procedure

1. **Read Local Environment & Check Connectivity:**
   - Read `LOCAL_ENV.md` first for the remote gaming host's Tailscale IP/hostname, SSH alias, remote shell, LAN IP, MAC address, active service (`MultiSeatService`, `SunshineService`, or `sunshinesvc`), exact log path(s) (e.g., `C:\ProgramData\MultiSeat\apollo\<SeatAccount>\apollo.log` on MultiSeat, or `C:\Program Files\Sunshine\config\sunshine.log`), and TCP port(s) (`48095`/`48100` for ApolloVibe/MultiSeat, or default `47989`).
   - Check Tailscale status (`tailscale status`) and ping the gaming host:
     - **Ubuntu:** `ping -c 2 -W 2 <HOST_IP_OR_NAME>`
     - **Windows:** `ping -n 2 -w 2000 <HOST_IP_OR_NAME>`
   - If Tailscale is stopped or disconnected, try `tailscale up`. If restarting the daemon is required, escalate `systemctl restart tailscaled` (Ubuntu) or `Restart-Service Tailscale` (Windows) using the `Fix Issue` Banana protocol in `AGENTS.md`.

2. **Non-Interactive SSH Probe & Wake-on-LAN:**
   - Test SSH without hanging on prompts (try the SSH alias first, then the Tailscale host/IP from `LOCAL_ENV.md`):
     `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "echo OK"`
   - **Fast Path:** When `LOCAL_ENV.md` already confirms passwordless SSH is configured for `<HOST>`, you may run the Step 3/4 read-only diagnostic command directly to check reachability and server state in a single SSH call.
   - Distinguish failures:
     - **`Permission denied` or `Connection refused`:** The host is reachable, so skip Wake-on-LAN. If key-based SSH is not configured on this machine, skip SSH steps and jump to Step 5 (client-side port check).
     - **Unreachable / Timed out:** Check if the client is on the same home LAN subnet as the host LAN IP in `LOCAL_ENV.md` (`ip -4 addr show` on Ubuntu; `ipconfig` on Windows). Remember Layer-2 Wake-on-LAN magic packets **cannot cross Tailscale** (`100.x.y.z`).
       - If on the same LAN and a MAC address is listed in `LOCAL_ENV.md`, send a Wake-on-LAN packet using built-in tools:
         - **Ubuntu:** `python3 -c "import socket; m=bytes.fromhex('<MAC_NO_COLONS>'); s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1); s.sendto(b'\xff'*6+m*16,('<BROADCAST_IP>',9))"`
         - **Windows:** `powershell -NoProfile -Command "$m='<MAC_NO_COLONS>'; $b=[byte[]](@(0xFF)*6 + (0..5 | % {[Convert]::ToByte($m.Substring($_*2,2),16)})*16); $u=New-Object System.Net.Sockets.UdpClient; $u.Connect('<BROADCAST_IP>',9); [void]$u.Send($b,$b.Length); $u.Close()"`
       - Wait 20 seconds and retry the ping/SSH probe once.
       - If still unreachable (or if the user is away from home over Tailscale), tell the user in plain English that the gaming computer appears turned off or asleep.

3. **Host Service & Seat Inspection / Recovery (When SSH Succeeds):**
   - **Windows Host:** Use PowerShell syntax (`;` separator, never `&`, since OpenSSH on Windows may use PowerShell 7 as the default shell). Do **NOT** enable or start `ApolloService` if `LOCAL_ENV.md` notes it is intentionally `Disabled`.
     - **MultiSeat + ApolloVibe Host (when `LOCAL_ENV.md` lists `MultiSeatService`):** Run one combined read-only check for `MultiSeatService`, live seat status (`http://127.0.0.1:9550/api/seats`), running `sunshine` processes, and recent `MultiSeat*` Event Log entries:
       ```bash
       ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "Get-Service MultiSeatService | Format-Table Name,Status -AutoSize; \$h=@{'X-MultiSeat-Key'=(Get-Content 'C:\ProgramData\MultiSeat\api-key.txt' -Raw).Trim()}; (Invoke-RestMethod 'http://127.0.0.1:9550/api/seats' -Headers \$h) | Select-Object accountName,sessionId,status,portBase,apolloProcessId,errorMessage | Format-List; Get-Process sunshine -ErrorAction SilentlyContinue | Format-Table Id,SessionId,ProcessName,Path -AutoSize; Get-WinEvent -FilterHashtable @{LogName='Application';ProviderName='MultiSeat*'} -MaxEvents 10 -ErrorAction SilentlyContinue | Select-Object TimeCreated,LevelDisplayName,Message | Format-List"
       ```
       - Only restart `MultiSeatService` (`Restart-Service -Name 'MultiSeatService' -Force`) if `MultiSeatService` itself is stopped or hung—avoid disturbing another user's active console or seat session unnecessarily.
       - For deeper MultiSeat history, run `& 'C:\Program Files\MultiSeat\scripts\show-logs.ps1' -Lines 40 -Hours 6`.
     - **Standard Sunshine Host:**
       `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "powershell -NoProfile -Command \"Get-Service SunshineService,sunshinesvc,ApolloService -ErrorAction SilentlyContinue | Format-Table Name,Status -AutoSize; Get-Process sunshine -ErrorAction SilentlyContinue | Format-Table Id,ProcessName,Path -AutoSize\""`
       If the active `<ServiceName>` from `LOCAL_ENV.md` is stopped or hung, restart it:
       `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "powershell -NoProfile -Command \"Restart-Service -Name '<ServiceName>' -Force\""`
   - **Linux Host:** Include `XDG_RUNTIME_DIR` for non-interactive user systemd checks:
     `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "XDG_RUNTIME_DIR=/run/user/\$(id -u) systemctl --user status sunshine --no-pager"`
     Restart if stopped or unhealthy:
     `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "XDG_RUNTIME_DIR=/run/user/\$(id -u) systemctl --user restart sunshine"`

4. **Display & Encoder Log Check (When SSH Succeeds):**
   - Inspect the last 30 lines of the exact `<LOG_PATH>` from `LOCAL_ENV.md` (e.g., `C:\ProgramData\MultiSeat\apollo\<SeatAccount>\apollo.log` on MultiSeat, or `C:\Program Files\ApolloVibe\config\sunshine.log` / `C:\Program Files\Sunshine\config\sunshine.log` on standalone installs):
     - **Windows Host:** `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "Get-Content '<LOG_PATH>' -Tail 30"`
     - **Linux Host:** `ssh -o BatchMode=yes -o ConnectTimeout=5 <HOST> "tail -n 30 ~/.config/sunshine/sunshine.log || XDG_RUNTIME_DIR=/run/user/\$(id -u) journalctl --user -u sunshine -n 30 --no-pager"`
   - If the logs show `No displays found`, display capture failure, or encoder initialization errors, explain in plain English to turn on the gaming PC's monitor—or select `Virtual Display` in Moonlight if configured in `LOCAL_ENV.md`.

5. **Verify From Client & Report:**
   - Confirm the host's Moonlight TCP port(s) from `LOCAL_ENV.md` (e.g., `48095` and `48100` for ApolloVibe/MultiSeat, or `47989` for standard Sunshine) are reachable from this client machine (to catch host firewall blocks):
     - **Ubuntu:** `nc -zv -w 3 <HOST_IP_OR_NAME> <PORT_1>` (repeat per port if multiple are listed)
     - **Windows:** `powershell -NoProfile -Command "Test-NetConnection -ComputerName '<HOST_IP_OR_NAME>' -Port <PORT>"`
   - Once reachable, ask the user in plain English to refresh Moonlight and try opening their game again.
