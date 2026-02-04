# Verification Report (v0.9 and earlier)

## Scope
Re-audit limited to **tasks.md up to and including v0.9** and all **RESOLVED issues in Redotasking.md**. No v1 inspection performed.

## ✅ Redotasking issues verified (with evidence)

1) **AI architecture (SDAE + commander intent + per-unit micro behaviors)**
   - Evidence:
     - `ai/fireteam_ai.gd`: `_process()` → `_tick()` → `_sense/_decide/_act/_evaluate()`; `commander_intent` maintained.
     - `scripts/ai_unit.gd`: `_apply_micro_behaviors()` routes to `_update_cover_seek()`, `_update_peeking()`, `_update_reload_state()`, `_retreat_from_enemy()`.
     - `scripts/game.gd`: `spawn_enemy_units()` assigns `ai_unit.gd`; `_setup_fireteam_ai()` instantiates `FireteamAI` nodes.
   - Runtime path: Main menu → Start → `Game.tscn` → `scripts/game.gd::_ready` spawns AI units & fireteam AI; per-frame `_process/_physics_process` runs SDAE + micro behaviors.

2) **Self-preservation (fear/confidence/exposure + help calls)**
   - Evidence:
     - `scripts/ai_unit.gd`: `_update_self_preservation()`, `_apply_self_preservation()`, `_update_open_ground_refusal()`, `_update_cover_hugging()`, `_update_peeking()`, `_maybe_call_for_help()`.
     - `ai/fireteam_ai.gd`: `receive_help_request()` reacts to panic/suppression.
   - Runtime path: AI unit `_physics_process` emits help requests to `ai_fireteams` group; `FireteamAI.receive_help_request()` handles them in active matches.

3) **Tactic cards catalogue (triggers/requirements/act/success/abort/cooldowns)**
   - Evidence:
     - `ai/fireteam_ai.gd`: `TACTIC_CATALOGUE` entries include `triggers`, `requirements`, `act_plan`, `success_conditions`, `abort_conditions`, `cooldown`.
     - `ai/fireteam_ai.gd`: `_tactic_is_available()`, `_tactic_success()`, `_tactic_should_abort()` read the catalogue.
   - Runtime path: `FireteamAI._tick()` selects tactics every update cycle.

4) **Tactic selection & switching (gain/risk/feasibility/time + abort)**
   - Evidence:
     - `ai/fireteam_ai.gd`: `_score_tactic()` returns gain/risk/feasibility/time components; `_decide()` chooses highest score.
     - `ai/fireteam_ai.gd`: `_should_switch()` aborts on heavy suppression/loss/flank or `_tactic_should_abort()`.
   - Runtime path: `FireteamAI._tick()` evaluates changing conditions and switches tactics.

5) **Victory conditions (elimination + objective hold)**
   - Evidence:
     - `scripts/game.gd`: `_check_victory_conditions()` for elimination; `_update_objective()` handles hold timers and calls `_end_run()`.
     - `scenes/Game.tscn`: `ObjectiveMarker` node present.
     - `scripts/debug_overlay.gd`: objective line displays counts/hold progress.
   - Runtime path: Main menu → Start → `Game.tscn` → `scripts/game.gd::_process` invokes objective + elimination checks and transitions to `AfterAction.tscn`.

6) **Roster UI (assignment + replacement + visible XP/rank effects)**
   - Evidence:
     - `scenes/Roster.tscn` + `scripts/roster.gd`: Assign/Unassign/Replace UI; `_on_replace_pressed()` adds replacements.
     - `scripts/unit.gd`: death calls `game.mark_unit_lost(id, "KIA")` for player units.
     - `scripts/game.gd`: `mark_unit_lost()` marks roster status; `_save_campaign_state()` persists to `campaign.json`.
   - Runtime path: Main menu → Roster button loads roster scene; roster reads `user://campaign.json` from matches and exposes replacement action.

## ✅ tasks.md checked items verified (v0.9 and earlier)

### Setup & Infrastructure
- **Project scaffolding**: `project.godot` sets main scene; repo contains `scenes/`, `scripts/`, `ai/`, `data/`, `maps/`, `ui/`, `overlays/`.
- **README**: `README.md` includes setup, run instructions, controls, overlays, playtesting, and export guidance.
- **Debug logging & overlay**: `scripts/logger.gd` + `scripts/debug_overlay.gd` implement console logging and in-game event overlay.
- **Playtest automation & docs**: `scripts/playtest_headless.sh` and `docs/PLAYTEST.md` provide automation and manual checklists.

### Core Loop & Flow
- **Main menu**: `scenes/MainMenu.tscn` + `scripts/main_menu.gd` with Start/Quit/Map2/Roster buttons.
- **Game & AfterAction scenes**: `scenes/Game.tscn`, `scenes/AfterAction.tscn` wired to `scripts/game.gd` and `scripts/after_action.gd`.
- **State flow**: `scripts/main_menu.gd` transitions to Game/Map2/Roster; `scripts/game.gd::_end_run()` loads AfterAction; `scripts/after_action.gd` returns to menu; `scripts/game.gd::_unhandled_input()` toggles pause with spacebar.

### Unit Spawning & Camera
- **Data-driven units**: `data/units.json`; `scripts/game.gd::_load_unit_archetypes()` + `_apply_unit_archetype()` load data at runtime.
- **Unique IDs**: `scripts/id_generator.gd` with `next_id()`; `scripts/game.gd::spawn_player_units/spawn_enemy_units` assign IDs.
- **Spawn player & AI units**: `scripts/game.gd::_spawn_match_units()` + `spawn_player_units()` + `spawn_enemy_units()` create units and fireteams.
- **Camera**: `scripts/game.gd::_handle_camera_movement()` (edge/WASD) + `_adjust_camera_zoom()` + `_clamp_camera_to_bounds()`; `scenes/Game.tscn` includes `Camera2D`.

### Selection & UI
- **RTS selection**: `scripts/selection_handler.gd` implements drag-box, shift-add, and double-click select-by-role.
- **Selection panel**: `scenes/Game.tscn`/`scenes/GameMap2.tscn` SelectionPanel nodes; `scripts/game.gd::_update_selection_panel()` updates label.

### Movement & Orders
- **Free-move navigation**: `scripts/unit.gd::_update_movement()` steering with separation/avoidance.
- **Move order**: `scripts/game.gd::_unhandled_input()` issues `issue_move_order()`; `scripts/unit.gd::issue_move_order()` queues waypoints.
- **Attack-move order**: `scripts/game.gd::_unhandled_input()` checks `KEY_A` and sets `attack_move`.
- **Hold order**: `scripts/game.gd::_toggle_hold_mode()` cycles off/defensive/aggressive.
- **Spread/Spacing order**: `scripts/game.gd::_unhandled_input()` handles `KEY_F` spacing adjustments.

### Cover, LoS & Suppression
- **Cover system**: `scripts/cover.gd` cover objects; `scripts/game.gd::get_cover_state()` applies cover modifiers; `scripts/unit.gd::_draw_cover_indicator()` shows HUD indicator.
- **Line of Sight (LoS)**: `scripts/game.gd::is_line_of_sight()` + `scripts/unit.gd::_has_line_of_sight()`; `scripts/unit.gd::_sense_enemies()` stores last-known positions; `scripts/debug_overlay.gd` draws LoS preview lines.
- **Suppression**: `scripts/unit.gd` increases suppression on hit and draws suppression bars in `_draw_suppression_bar()`.

### Combat
- **Hitscan shooting**: `scripts/unit.gd::_attack_logic()` uses LoS checks and hit chance with damage.
- **Archetypes**: `data/units.json` + `scripts/game.gd::_apply_unit_archetype()`.

### AI — v0
- **Tick throttling & LOD**: `ai/fireteam_ai.gd::_should_update()` adjusts update interval based on camera distance.

### Win/Lose & After-Action
- **After-action summary**: `scripts/game.gd::_finalize_match_summary()` saves match data; `scripts/after_action.gd::_populate_summary()` renders summary.

### Persistence Foundation
- **Persistent unit data**: `scripts/game.gd` `unit_roster`, `_register_unit()`, `award_xp()`.
- **Save/load stub**: `scripts/game.gd::_load_campaign_state()` + `_save_campaign_state()` for `user://campaign.json`.

### Debug & Telemetry
- **Debug overlays**: `scripts/debug_overlay.gd` toggles F1–F6 and draws nav/cover/LoS/suppression/AI tactic overlays.
- **Event log**: `scripts/logger.gd::log_event()` forwards to overlay; `scripts/game.gd::_finalize_match_summary()` dumps `user://match_log.txt`.
- **Telemetry hooks**: `scripts/logger.gd::log_telemetry()` used in `scripts/game.gd`, `scripts/unit.gd`, and `ai/fireteam_ai.gd`.

## v0.9
- **Extra map & objective**: `scenes/GameMap2.tscn` includes `ObjectiveMarker` and `MapModifiers`; `scripts/map_modifiers.gd` applies fog/night modifiers.
- **Control groups**: `scripts/game.gd::_handle_control_group_input()` supports Ctrl+1–9 assign and select.
- **Expanded tactics**: `ai/fireteam_ai.gd` adds `probe_and_pull`, `recon_by_fire`, `fix_and_shift` in `TACTIC_CATALOGUE` + `_act_*` methods.

## ❌ Reopened items
- None.

## Mismatched checkboxes corrected in tasks.md
- None.

## Commands executed + results
1. `./scripts/install_godot.sh` — **OK** (downloaded and installed Godot 4.2.2).
2. `./.tools/godot/godot --headless --quit --path .` — **OK** (`Godot Engine v4.2.2.stable.official.15073afe3`).
3. `./scripts/playtest_headless.sh` — **OK** (`Playtest completed; exiting with code 0`).

## Next unchecked task after v0.9
- **v1 → Campaign flow** (first unchecked item after v0.9).
