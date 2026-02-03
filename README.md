# Top‑Down RTS Tactical Shooter (MVP Vertical Slice)

This repository is the starting point for a top‑down real‑time tactics game inspired by *War of Dots* and *Running with Rifles*.  It follows the design outlined in **PRD v1.0** and delivers a playable MVP vertical slice using **Godot 4** as the engine.  The focus is on giving orders rather than twitch reflexes: positioning, timing, flanking and suppression win fights.

## What’s included

* A Godot 4 project scaffold with scenes (`MainMenu`, `Game`, `AfterAction`, `Unit`) and scripts organised in `scripts/`, `ai/`, `data/` and `overlays/` folders.
* A first implementation of selection, movement and simple combat so you can already spawn units, select them with a drag‑box and issue move or attack‑move orders.
* A debug overlay that logs events and shows suppression bars above units.  More overlays (nav paths, LoS rays, cover heat, AI tactics) can be toggled via function keys as they are implemented.
* A `tasks.md` file detailing milestones and tasks derived directly from the PRD.

## Setup (Codex sandbox)

The Codex sandbox uses a local Godot binary committed outside of git, not a system install.

1. **Install the pinned Godot build**:
   ```bash
   ./scripts/install_godot.sh
   ```
2. **Run the project headless (sanity check)**:
   ```bash
   ./.tools/godot/godot --headless --quit --path .
   ```

## Setup (local editor)

1. **Install Godot 4.2+** – download the official editor from [godotengine.org](https://godotengine.org/) or use the repo-local installer below. The project uses 2D features exclusively and should run on any desktop platform.
2. **Open the project** – in the editor choose “Open Project”, browse to this repository and select `project.godot`.

## How to Run

1. **Install the repo-local Godot binary**:
   ```bash
   ./scripts/install_godot.sh
   ```
2. **Run the game (GUI)** – from the repo root:
   ```bash
   ./.tools/godot/godot --path .
   ```
3. **Optional local convenience** (if you already have it installed):
   ```bash
   godot4 --path .
   ```

### Controls (MVP)

* **Left mouse drag** – draw a selection box.  All player units inside are selected.  Hold **Shift** while dragging to add to the existing selection.
* **Right mouse click** – issue a move order to selected units.  With an **A** key held, it becomes an *attack‑move* order.  Hold **Shift** when issuing a move to queue a second waypoint.
* **H** – toggle *hold* order.  Selected units will stop and hold position, returning fire only.
* **F** – cycle through formation spacing (tight, normal, loose).  Not yet implemented in the MVP but hooked for future development.
* **Space** – pause/unpause the game (real‑time with pause).
* **W/A/S/D or mouse edges** – move the camera.  **Mouse wheel** zooms in/out.
* **F1** – toggle the debug event log.  Additional overlays will be bound to F‑keys as they are added.

### Debugging and Logging

From the very first milestone the game logs key events (unit spawn, orders issued, kills).  Press **F1** in‑game to toggle the on‑screen event log.  Debug overlays for navigation paths, cover edges, line‑of‑sight and suppression heat maps will be implemented incrementally; their toggles are stubbed in the code.

## Testing

1. Install the repo-local Godot binary:
   ```bash
   ./scripts/install_godot.sh
   ```
2. Run a headless smoke check:
   ```bash
   ./.tools/godot/godot --headless --quit --path .
   ```
3. Optional local convenience:
   ```bash
   godot4 --headless --quit --path .
   ```

## Running exports

To make a release build, open **Project → Export** in the Godot editor and create an export preset for your platform (e.g. Windows, Linux or macOS).  Click **Add…**, select a template and press **Export Project**.  Godot produces a portable executable in the chosen directory.

If you want to script a headless build check in the sandbox, run:

```bash
./.tools/godot/godot --headless --quit --path .
```

## Contributing

The game is built iteratively.  Please read `tasks.md` to see the work ahead.  Focus on completing the MVP vertical slice before tackling v0.9 or v1 features.  Avoid scope creep; each feature should be runnable and stable before moving on.  Use the debug overlays to verify behaviour and collect telemetry – it will be invaluable for tuning AI and balance.
