# Top‑Down RTS Tactical Shooter (MVP Prototype)

**Current version:** v0.9 (playable playtest build).  
**Status:** v1 is **not** complete yet; the project focuses on the MVP vertical slice.

This repository follows **PRD v1.0** and delivers a playable top‑down tactics prototype in **Godot 4**. The focus is on real‑time orders (selection, movement, attack‑move, hold, spacing), cover and suppression, and early AI fireteam behaviors.

## What’s playable now

- Main menu flow: Menu → Game → AfterAction → Menu.
- Drag‑box selection (shift‑add) and double‑click select by role.
- Move, attack‑move, hold modes, and formation spacing.
- Cover checks, line‑of‑sight, suppression, and hitscan combat.
- Fireteam AI with base‑of‑fire, flank, screen, peel‑back, and reserve tactics.
- Basic roster screen showing persisted unit XP/rank.

## Setup

1. **Install Godot 4.2+**  
   Download the official editor for your OS from [godotengine.org](https://godotengine.org/).
2. **Open the project**  
   In the editor choose **Open Project**, browse to this repository, and select `project.godot`.

## Run Instructions

### Sandbox/CI (headless)

```bash
./scripts/install_godot.sh
./.tools/godot/godot --headless --quit --path .
```

### Automated playtest (headless)

```bash
./scripts/playtest_headless.sh
```

Playtest mode is enabled via user arguments after `--` (engine args are ignored):

```bash
./.tools/godot/godot --headless --path . -- --playtest
```

### Local GUI (Windows/macOS/Linux)

1. Launch the Godot 4 editor you downloaded.
2. Open the project by selecting `project.godot`.
3. Press **Play** (F5) to run the game.

> Note: the repo‑local installer (`./scripts/install_godot.sh`) is for Linux CI/sandbox usage. Use the official editor for Windows/macOS.

## Controls

- **Left mouse drag** — draw a selection box. **Shift** adds to selection.
- **Double‑click** — select all units of the same role.
- **Right mouse click** — issue a move order. **Shift‑right click** queues a second waypoint.
- **Hold A + right click** — attack‑move order.
- **H** — cycle hold mode (off → defensive → aggressive).
- **F** — cycle formation spacing (tight/normal/loose).
- **Space** — pause/unpause.
- **W/A/S/D or mouse edges** — pan the camera. **Mouse wheel** zooms.
- **F1** — toggle debug event log. **F2‑F6** toggle overlay stubs (nav paths/cover/LoS/suppression/tactics).

## Playtesting

See [docs/PLAYTEST.md](docs/PLAYTEST.md) for manual checklists.

## Export Instructions

Export preset names (from `export_presets.cfg`):

- **Windows Desktop** → `builds/playtest/SOCOM_Playtest.exe`
- **Linux/X11** → `builds/playtest/SOCOM_Playtest.x86_64`

See [docs/PLAYTEST_BUILD.md](docs/PLAYTEST_BUILD.md) for the full export steps and troubleshooting.

## Playtest RC checklist

- Headless boot succeeds.
- Automated playtest (`./scripts/playtest_headless.sh`) succeeds.
- Menu flow works (Menu → Game → AfterAction → Menu).
- Drag-box + shift-add selection works.
- Move / attack-move / hold / spacing orders work.
- Cover, LoS, suppression visuals show.
- Logs are produced in `user://` (match_log.txt, telemetry.jsonl).
- Export presets match docs and output paths.
- Build runs without script errors in the console.

Open **Project → Export** in the Godot editor, add a preset for your platform (Windows, Linux, or macOS), then click **Export Project**. Godot will generate the executable in the selected directory.

## Contributing

Work in small, playable increments. Avoid scope creep and prioritize completing the MVP vertical slice. Use `tasks.md` as the milestone source of truth.
