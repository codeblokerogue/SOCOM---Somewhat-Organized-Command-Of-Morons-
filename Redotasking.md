# Redotasking Audit (v0.9 and earlier)

This audit reviews **only** tasks up to and including **v0.9** in `tasks.md`.

## Issues Found

### 1) AI architecture
- **Task name:** **AI architecture:** implement the Sense→Decide→Act→Evaluate loop for AI fireteams. Each fireteam consists of 2–6 units. Maintain a commander intent with high-level goals (hold, probe, fix, disengage) and individual brains for micro decisions (cover, peek, reload, retreat).
- **Status:** VERIFIED
- **Expected behavior:** Fireteams must run SDAE with commander intent, while individual AI brains handle micro decisions like cover usage, peeking, reloading, and retreating.
- **Fix note:** Added explicit cover-seek, peek, and reload micro behavior handling to the per-unit AI brain, including simple timers and cover targeting logic.
- **Evidence:**
  - `ai/fireteam_ai.gd`: `_process()` calls `_tick()` → `_sense/_decide/_act/_evaluate()` and maintains `commander_intent` with high-level goals.
  - `scripts/ai_unit.gd`: `_apply_micro_behaviors()` routes to `_update_cover_seek()`, `_update_peeking()`, `_update_reload_state()`, and `_retreat_from_enemy()`.
  - `scripts/game.gd`: `spawn_enemy_units()` assigns `ai_unit.gd` and `_setup_fireteam_ai()` creates `FireteamAI` nodes with fireteam membership.
- **Runtime path:** Main menu → Start → `Game.tscn` (`scripts/main_menu.gd::_on_start_pressed`) → `scripts/game.gd::_ready` spawns AI units and fireteam AI; each frame `FireteamAI._process` and `AIUnit._physics_process` execute the SDAE + micro behaviors.

### 2) Self-preservation
- **Task name:** **Self-preservation:** track fear, confidence and exposure per unit. Fear increases with incoming fire, nearby casualties, low HP and lack of cover; it decreases with good cover, allies nearby, a nearby leader and winning exchanges. Fear influences micro-behaviour (e.g. shorter peeks, hugging cover, refusing to cross open ground). High fear triggers retreats and calls for help.
- **Status:** VERIFIED
- **Expected behavior:** Fear/confidence/exposure must influence micro behaviors (peeking, hugging cover, refusing open ground), and high fear should trigger retreats **and calls for help**.
- **Fix note:** Added fear/exposure-driven micro behaviors (shorter peeks, cover hugging, and refusing open ground) plus help-request signaling that notifies fireteam AI and updates commander intent.
- **Evidence:**
  - `scripts/ai_unit.gd`: `_update_self_preservation()` computes fear/confidence/exposure; `_apply_self_preservation()` retreats; `_update_open_ground_refusal()` + `_update_cover_hugging()` change movement; `_update_peeking()` shortens peeks; `_maybe_call_for_help()` sends help requests.
  - `ai/fireteam_ai.gd`: `receive_help_request()` logs and updates `commander_intent` based on panic/suppression.
- **Runtime path:** AI unit `_physics_process` runs each frame in Game; help request uses `call_group("ai_fireteams", "receive_help_request")`, which is handled by active `FireteamAI` nodes created in `scripts/game.gd::_setup_fireteam_ai()`.

### 3) Tactic cards
- **Task name:** **Tactic cards:** implement a tactic catalogue with triggers, requirements, act plans, success and abort conditions and cooldowns.
- **Status:** VERIFIED
- **Expected behavior:** Tactic cards should be represented as catalog entries with explicit triggers/requirements, execution plans, and success/abort conditions plus cooldowns.
- **Fix note:** Added a structured tactic catalogue in `ai/fireteam_ai.gd` and wired selection, execution, success, and abort checks to use it.
- **Evidence:**
  - `ai/fireteam_ai.gd`: `TACTIC_CATALOGUE` entries include `triggers`, `requirements`, `act_plan`, `success_conditions`, `abort_conditions`, and `cooldown`.
  - `ai/fireteam_ai.gd`: `_tactic_is_available()`, `_tactic_success()`, and `_tactic_should_abort()` read the catalogue during decision and evaluation.
- **Runtime path:** Each `FireteamAI` node executes `_tick()` from `_process()`, pulling the tactic catalogue for decisions and act plans.

### 4) Tactic selection & switching
- **Task name:** **Tactic selection & switching:** choose tactic cards based on a score (gain vs risk vs feasibility vs time). Evaluate during execution; abort and switch if conditions change (e.g. heavy losses, suppression, enemy flank).
- **Status:** VERIFIED
- **Expected behavior:** Scoring should explicitly weigh gain/risk/feasibility/time and abort/switch based on changing conditions including suppression or enemy flanking.
- **Fix note:** Added explicit gain/risk/feasibility/time scoring breakdown per tactic, plus heavy suppression/loss/flank detection that triggers tactic abort/switch decisions with telemetry.
- **Evidence:**
  - `ai/fireteam_ai.gd`: `_score_tactic()` returns `gain`, `risk`, `feasibility`, `time`, and `final`; `_decide()` uses these scores.
  - `ai/fireteam_ai.gd`: `_should_switch()` triggers on `heavy_suppression`, `heavy_losses`, and `enemy_flank`, plus `_tactic_should_abort()` results.
- **Runtime path:** `FireteamAI._tick()` senses pressure (`_sense()`), runs `_decide()`, then `pending_tactic` changes are applied with comms delay.

### 5) Victory conditions
- **Task name:** **Victory conditions:** implement elimination and a simple objective (e.g. hold a zone for X seconds). At match end determine win or lose and transition to the `AfterAction` scene.
- **Status:** VERIFIED
- **Expected behavior:** Both elimination and a hold-zone objective should be available in the main match flow.
- **Fix note:** Added an `ObjectiveMarker` to the default `Game` scene and exposed objective progress in the debug overlay so the hold-zone evaluation is visible during the primary match flow.
- **Evidence:**
  - `scripts/game.gd`: `_check_victory_conditions()` handles elimination; `_update_objective()` checks hold-zone timers and calls `_end_run()`.
  - `scenes/Game.tscn`: includes `ObjectiveMarker` node wired with `scripts/objective_marker.gd`.
  - `scripts/debug_overlay.gd`: draws objective counts/hold timers for active matches.
- **Runtime path:** Main menu → Start → `Game.tscn` → `scripts/game.gd::_process` calls `_update_objective` and `_check_victory_conditions`, which call `_end_run()` and transition to `AfterAction.tscn`.

### 6) Roster UI
- **Task name:** **Roster UI:** add a roster screen where the player can view persistent units, XP and ranks, assign them to missions, and replace casualties. XP/ranks should have visible effects (e.g. increased accuracy, suppression resistance).
- **Status:** VERIFIED
- **Expected behavior:** The roster should support assignment **and** replacement of casualties, with XP/rank effects visible.
- **Fix note:** Added KIA status tracking in the roster data, kept fallen units visible, and added a Replace action to create fresh roster entries for casualties.
- **Evidence:**
  - `scenes/Roster.tscn` + `scripts/roster.gd`: roster list, Assign/Unassign/Replace actions; `_on_replace_pressed()` adds replacements.
  - `scripts/unit.gd`: death calls `game.mark_unit_lost(id, "KIA")` for player units.
  - `scripts/game.gd`: `mark_unit_lost()` sets roster status; `_save_campaign_state()` persists `campaign.json` used by the roster.
- **Runtime path:** Main menu → Roster button (`scripts/main_menu.gd::_on_roster_pressed`) loads `Roster.tscn`; in matches, player deaths mark KIA and the roster view reflects status on reload.
