# Playtest Build Guide

This guide explains how to export a playtest build and what testers should send back.

## Export prerequisites

- Godot 4.x with export templates installed.
- The export presets live in `export_presets.cfg` at the repo root.

> Note: If you are running in a sandbox/CI environment without export templates, the export will fail. Install templates from the official Godot download page or via the editor before exporting.

## Export (Windows)

From the repo root, provide the full path to the Godot executable you want to use:

```powershell
./scripts/export_playtest_windows.ps1 -GodotPath "C:\Path\To\Godot.exe"
```

The build is exported to:

```
builds/playtest/SOCOM_Playtest.exe
```

## Export (Linux)

Provide the full path to the Godot executable you want to use:

```bash
./scripts/export_playtest_linux.sh /path/to/Godot
```

The build is exported to:

```
builds/playtest/SOCOM_Playtest.x86_64
```

## Controls quick list

- Drag-box to select units.
- **Shift** + drag-box to add to the selection.
- Right-click to issue a move order.
- Hold **A** + right-click to issue an attack-move order.
- Press **H** to cycle hold modes.
- Press **F** to cycle formation spacing.
- Press **Space** to pause/unpause.

## Logs & save data

The game writes logs and state to `user://` (Godot user data directory):

- `user://match_log.txt` (match summary)
- `user://telemetry.jsonl` (telemetry log)
- `user://campaign.json` (roster persistence)

## Bug reporting checklist

When reporting a bug, include:

- Build version (file name + date/time exported).
- OS and hardware info.
- Steps to reproduce (numbered list).
- Expected vs. actual result.
- `match_log.txt` and `telemetry.jsonl` from `user://`.
- Screenshot or short video if it helps.
