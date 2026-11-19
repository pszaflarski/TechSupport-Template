---
name: printer-spooler
description: >-
  Use this skill when the user reports the printer won't print, the printer shows offline
  or paused, print jobs are stuck in the queue, or the print spooler is hung.
---

# RUNBOOK: Printer Queue & Spooler Recovery

## Procedure (Ubuntu — CUPS)

1. **Read-Only Printer & Service Diagnostics:**
   - Check `LOCAL_ENV.md` for the expected default printer name.
   - Inspect CUPS printer states, URIs, and queued jobs:
     - `lpstat -p -d -o`
     - `lpstat -v`
     - `systemctl is-active cups cups-browsed`
   - Check physical/network reachability:
     - If the printer URI uses a network IP or hostname (`ipp://`, `socket://`, `dnssd://`), ping it (`ping -c 2 -W 2 <PRINTER_IP>`) to confirm the printer is powered on and connected to Wi-Fi.
     - If USB-connected, check `lsusb`.

2. **Clear Stuck Print Jobs (Unprivileged First):**
   - If queued jobs belong to the current user and appear stuck, clear them:
     `cancel -a` (or `cancel <JOB_ID>`)
   - Re-check `lpstat -o` to confirm the queue is empty.

3. **Recover Disabled Printer or Hung CUPS Service (Privileged Escalation):**
   - If `lpstat -p` reports `disabled since ...` or `not accepting requests`, or `cups`/`cups-browsed` is inactive or hung:
   - Escalate via the `Fix Issue` Banana protocol in `AGENTS.md` with `temp_fix.sh` containing only the needed commands (for example):
     ```bash
     /usr/sbin/cupsaccept "<PRINTER_NAME>" || true
     /usr/sbin/cupsenable "<PRINTER_NAME>" || true
     systemctl restart cups cups-browsed
     ```
   - After the user says "done", inspect `logs/last_fix.log`, verify `lpstat -p -d -o` shows `idle` and `enabled`, delete `temp_fix.sh` and `~/Desktop/FixIssue.desktop`, and ask the user to print a test page.

---

## Procedure (Windows 11)

1. **Read-Only Print Queue & Spooler Diagnostics:**
   - Run PowerShell diagnostics:
     `powershell -NoProfile -Command "Get-Service Spooler | Format-Table -AutoSize; Get-Printer | Format-Table Name, PrinterStatus, WorkOffline -AutoSize; Get-PrintJob -PrinterName * -ErrorAction SilentlyContinue | Format-Table PrinterName, Id, DocumentName, JobStatus -AutoSize"`

2. **Clear Hung Spooler Queue (Privileged Escalation):**
   - If print jobs are stuck or the `Spooler` service is stopped/hung, escalate via the `Fix Issue` Banana protocol in `AGENTS.md` with `temp_fix.bat` running:
     ```bat
     net stop spooler
     del /Q /F "%SystemRoot%\System32\spool\PRINTERS\*.*"
     net start spooler
     ```
   - After the user confirms, check `logs\last_fix.log`, re-run the read-only PowerShell status check, clean up `temp_fix.bat` and `Fix Issue.lnk`, and ask the user to retry printing.
