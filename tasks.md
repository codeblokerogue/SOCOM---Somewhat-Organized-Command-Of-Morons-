# Project Tasks and Milestones

This file lays out the development plan derived from **PRD v1.0**. Each milestone enumerates concrete tasks to realise the feature set while respecting the strict MVP boundaries (no scope creep). All systems must be runnable at the end of each milestone, with debug overlays and logging enabling inspection.

## MVP — Vertical Slice

### Setup & Infrastructure

* [x] **Project scaffolding:** initialise a Godot 4 project in this repository. Create folders for `scenes/`, `scripts/`, `ai/`, `data/`, `maps/`, `ui/` and `overlays/`. Add `project.godot` with project name, version, default window size and main scene (`MainMenu.tscn`).
* [x] **README:** document installation, run instructions, controls and debug overlay toggles. Mention export steps and how to contribute.
* [x] **Debug logging & overlay:** implement a simple logging system that writes events to both the console and an on-screen overlay. The overlay should be toggled by a function key and display the latest 20 events.
* **Milestone 1 validation:** `./.tools/godot/godot --headless --quit --path .`

### Core Loop & Flow

* [x] **Main menu:** build `MainMenu.tscn` with Start and Quit buttons. Hook Start to load the `Game` scene and Quit to exit the application.
* [x] **Game & AfterAction scenes:** create `Game.tscn` and `AfterAction.tscn`. `Game` contains the playable match; `AfterAction` shows a summary after win/lose and returns to the menu.
* [x] **State flow:** wire up transitions: Menu → Game → AfterAction → Menu. Implement a pause (spacebar) that halts all in-game processing.

### Unit Spawning & Camera

* [x] **Data-driven units:** create a JSON file in `data/` describing archetypes (Rifle, Scout/SMG, Support/LMG) with stats (HP, speed, accuracy, suppression resistance, role tags). Load this data at runtime.
* [x] **Unique IDs:** implement a unique ID generator and assign IDs to all spawned units. Maintain a data structure for persistence (ID, XP, rank).
* [x] **Spawn player & AI units:** in the `Game` scene spawn 4–80 player units (mission dependent) and enough AI units to reach a total of 80–200. Group units into `player_units` and `enemy_units`. Assign AI units to fireteams.
* [x] **Camera:** add a `Camera2D` with edge scrolling and WASD panning, adjustable zoom and real-time pause. The camera should clamp to the map bounds.

### Selection & UI

* [x] **RTS selection:** implement drag-box selection using the left mouse button. Shift-drag adds to the current selection; click selects a single unit. Provide visual feedback (highlight or outline) on selected units.
* [x] **Selection panel:** display the count and roles of currently selected units in a minimal UI element.

### Movement & Orders

* [x] **Free-move navigation:** implement movement without tiles using `Navigation2D` or steering behaviours. Include local avoidance and separation to prevent clumping when large groups move.
* [x] **Move order:** right-click issues a move order to all selected units. Shift-right-click queues a second waypoint (max two waypoints).
* [x] **Attack-move order:** while holding **A**, right-click issues an attack-move order. Units move toward the point and automatically engage enemies on the way.
* [x] **Hold order:** pressing **H** toggles a hold command; units remain in place and either return fire (defensive) or free fire (aggressive), with two states for the MVP.
* [x] **Spread/Spacing order:** press **F** to cycle formation spacing (tight, normal, loose). This adjusts the separation radius used during path following.

### Cover, LoS & Suppression

* [x] **Cover system:** place light and heavy cover objects in the map. Determine if a unit is in cover relative to incoming fire and apply modifiers (reduced hit chance/damage). Show cover indicators on the HUD.
* [x] **Line of Sight (LoS):** calculate visibility using obstacles. Implement last-known positions that fade over time. Show LoS preview for selected units.
* [x] **Suppression:** when a unit is under fire increase its suppression meter. Suppression reduces accuracy and movement speed. Display suppression state as a bar over each unit. Support weapons (LMGs) apply stronger suppression.

### Combat

* [x] **Hitscan shooting:** implement hitscan weapons with rate of fire, damage and range. Accuracy is affected by cover, suppression, distance and movement. Use an HP model for damage; units die when HP ≤ 0.
* [x] **Archetypes:** use the archetype data to assign stats and behaviours (e.g. Rifle as baseline, Scout for speed/flanking, Support for suppression). Load from JSON to allow tuning.

### AI — v0

* [x] **AI architecture:** implement the Sense→Decide→Act→Evaluate loop for AI fireteams. Each fireteam consists of 2–6 units. Maintain a commander intent with high-level goals (hold, probe, fix, disengage) and individual brains for micro decisions (cover, peek, reload, retreat).
* [x] **Self-preservation:** track fear, confidence and exposure per unit. Fear increases with incoming fire, nearby casualties, low HP and lack of cover; it decreases with good cover, allies nearby, a nearby leader and winning exchanges. Fear influences micro-behaviour (e.g. shorter peeks, hugging cover, refusing to cross open ground). High fear triggers retreats and calls for help.
* [x] **Tactic cards:** implement a tactic catalogue with triggers, requirements, act plans, success and abort conditions and cooldowns. The MVP must support at least:
  * **Base of Fire (light):** units occupy cover and suppress a lane to pin the enemy.
  * **Flank Subgroup:** a small subgroup manoeuvres to flank.
  * **Screen:** units watch and deny exposed flank routes.
  * **Peel Back:** units conduct a controlled retreat when losing.
  * **Reserve:** a fraction of the force holds back to reinforce where needed.
* [x] **Tactic selection & switching:** choose tactic cards based on a score (gain vs risk vs feasibility vs time). Evaluate during execution; abort and switch if conditions change (e.g. heavy losses, suppression, enemy flank).
* [x] **Tick throttling & LOD:** update nearby AI more frequently than distant AI to ensure performance at 80–200 units. Simulate comms delays so AI intent propagates gradually rather than instantaneously.

### Win/Lose & After-Action

* [x] **Victory conditions:** implement elimination and a simple objective (e.g. hold a zone for X seconds). At match end determine win or lose and transition to the `AfterAction` scene.
* [x] **After-action summary:** present a summary with key events: casualties by cause (cover vs open), successful flanks, suppression heat map and timeline of actions. List XP gained and surviving units.

### Persistence Foundation

* [x] **Persistent unit data:** store unique IDs, XP and rank for every unit. Logging XP events during a match is required even if rank effects are not active yet.
* [x] **Save/load stub:** implement a stub to save and load the persistent campaign state. For the MVP this may simply serialise to a JSON file.

### Debug & Telemetry

* [ ] **Debug overlays:** implement toggles for nav paths, cover edges, LoS rays, suppression heat and current AI tactic. Use F-keys to toggle each overlay on/off.
* [ ] **Event log:** maintain an event log overlay showing the most recent 20 events (orders, kills, AI plan changes). Dump logs to a file when the match ends.
* [ ] **Telemetry hooks:** instrument AI decision points and combat outcomes for later analysis. Use these hooks to adjust tactic weights and detect stuck behaviours.

## v0.9

* [ ] **Roster UI:** add a roster screen where the player can view persistent units, XP and ranks, assign them to missions, and replace casualties. XP/ranks should have visible effects (e.g. increased accuracy, suppression resistance).
* [ ] **Extra map & objective:** add at least one additional map with a distinct layout and a simple *hold the zone* objective. Implement basic modifiers (e.g. fog, night) to test LoS and suppression.
* [ ] **Control groups:** implement control group shortcuts (Ctrl + 1–9) to assign selected units to numbered groups and double-click to select all units of the same archetype.
* [ ] **Expanded tactics:** add more tactic cards (Probe and Pull, Recon by Fire, Fix-and-Shift) and integrate them into the AI decision logic. Add more detailed telemetry to measure the success of each tactic.

## v1

* [ ] **Campaign flow:** implement an operations/mission chain where the player chooses missions, manages attrition and upgrades. Persistence becomes essential: losses matter and squads evolve over time.
* [ ] **Upgrades & unlocks:** introduce upgrade paths that unlock new weapons, abilities or tactical options. Keep them balanced so that no single upgrade trivialises tactics.
* [ ] **Rank effects:** activate rank effects: higher ranks improve leadership (reduce fear for nearby units), increase accuracy or unlock special orders.
* [ ] **Expanded AI tactics:** extend the tactic catalogue with manoeuvres such as Crossfire Trap, Counter-flank, Staggered Entry, Fire Discipline and Reserve Commitment. Improve AI telemetry so that every fireteam’s current tactic, fear/confidence state and plan evaluation can be inspected in real time.
