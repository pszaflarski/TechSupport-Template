---
name: audio-output
description: >-
  Use this skill when the user reports no sound, muted audio, low volume, sound coming
  from the wrong speakers or TV/HDMI output, or Bluetooth headphones not connecting or
  playing audio.
---

# RUNBOOK: Audio Output & Bluetooth Recovery

## Procedure (Ubuntu — PipeWire / WirePlumber / ALSA / BlueZ)

1. **Inspect Current Audio State (Read-Only):**
   - Run diagnostics using PipeWire/WirePlumber tools (do NOT assume `pactl` is installed; check `LOCAL_ENV.md`):
     - `wpctl status`
     - `wpctl get-volume @DEFAULT_AUDIO_SINK@`
     - `pulsemixer --list-sinks`
     - `aplay -l`

2. **Check Mute & Volume Levels:**
   - If the default sink is `[MUTED]` or volume is below `0.20`, unmute and set a safe audible volume:
     `wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.75`
   - Also check ALSA Master if hardware output is still silent:
     `amixer sget Master` (and unmute if `[off]` with `amixer sset Master unmute`).

3. **Switch Output Device (Wrong Speakers / TV / HDMI):**
   - Review the Sink IDs listed by `wpctl status` under `Audio -> Sinks:`.
   - Switch default output to the desired speakers, headphones, or HDMI/TV sink:
     `wpctl set-default <SINK_ID>`
   - Re-check `wpctl get-volume @DEFAULT_AUDIO_SINK@` and ensure it is unmuted.

4. **Bluetooth Headphones Recovery:**
   - Check Bluetooth radio state: `rfkill list bluetooth`
     - If `Soft blocked: yes`, unblock it: `rfkill unblock bluetooth`
   - List paired devices and inspect connection state:
     `bluetoothctl devices`
     `bluetoothctl info <MAC>`
   - If disconnected, attempt reconnect: `bluetoothctl connect <MAC>`
   - Once connected, re-run `wpctl status`, select the Bluetooth sink via `wpctl set-default <SINK_ID>`, and verify it is unmuted.

5. **Recover Stuck PipeWire / `(null)` Dummy Sink:**
   - If `wpctl status` shows only `(null)` sinks or WirePlumber is unresponsive, restart user audio services **without `sudo`**:
     `systemctl --user restart wireplumber pipewire pipewire-pulse`
   - Sleep 2 seconds and re-verify `wpctl status` shows real audio devices.
   - If sound still fails after confirming devices and unmuting, ask the user to test audio (or check physical cable/headphone power).

---

## Procedure (Windows 11)

1. **Inspect Audio Services & Endpoints (Read-Only):**
   - `powershell -NoProfile -Command "Get-Service AudioSrv, AudioEndpointBuilder | Format-Table -AutoSize; Get-PnpDevice -Class AudioEndpoint -Status OK | Format-Table FriendlyName, Status -AutoSize"`

2. **Recover Wedged Windows Audio Services:**
   - If `AudioSrv` or `AudioEndpointBuilder` is stopped, or endpoints appear stuck, escalate via the `Fix Issue` Banana protocol in `AGENTS.md` to run:
     ```bat
     net stop AudioSrv /y
     net stop AudioEndpointBuilder /y
     net start AudioEndpointBuilder
     net start AudioSrv
     ```
   - After user confirmation, re-run the read-only service check and ask the user to test sound.
