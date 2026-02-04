# Redotasking Audit (v0.9 and earlier)

This audit reviews **only** tasks up to and including **v0.9** in `tasks.md`.

## Issues Found

### 1) AI architecture
- **Task name:** **AI architecture:** implement the Sense→Decide→Act→Evaluate loop for AI fireteams. Each fireteam consists of 2–6 units. Maintain a commander intent with high-level goals (hold, probe, fix, disengage) and individual brains for micro decisions (cover, peek, reload, retreat).
- **Status:** RESOLVED
- **Expected behavior:** Fireteams must run SDAE with commander intent, while individual AI brains handle micro decisions like cover usage, peeking, reloading, and retreating.
- **What I found instead:** Fireteam SDAE loop and commander intent exist, and AI units can retreat, but there are no explicit micro behaviors for cover-seeking, peeking, or reloading.
- **Fix note:** Added explicit cover-seek, peek, and reload micro behavior handling to the per-unit AI brain, including simple timers and cover targeting logic.
- **Evidence:**
  - `ai/fireteam_ai.gd` (Sense/Decide/Act/Evaluate loop, commander intent). 
  - `scripts/ai_unit.gd` (added cover-seek, peek, and reload micro behaviors). 
- **Suggested fix location:** Extend `scripts/ai_unit.gd` with explicit cover/peek/reload behaviors, and integrate any per-unit micro decision hooks from `ai/fireteam_ai.gd` if needed.

### 2) Self-preservation
- **Task name:** **Self-preservation:** track fear, confidence and exposure per unit. Fear increases with incoming fire, nearby casualties, low HP and lack of cover; it decreases with good cover, allies nearby, a nearby leader and winning exchanges. Fear influences micro-behaviour (e.g. shorter peeks, hugging cover, refusing to cross open ground). High fear triggers retreats and calls for help.
- **Status:** RESOLVED
- **Expected behavior:** Fear/confidence/exposure must influence micro behaviors (peeking, hugging cover, refusing open ground), and high fear should trigger retreats **and calls for help**.
- **Fix note:** Added fear/exposure-driven micro behaviors (shorter peeks, cover hugging, and refusing open ground) plus help-request signaling that notifies fireteam AI and updates commander intent.
- **Evidence:**
  - `scripts/ai_unit.gd` (micro behaviors, open-ground refusal, help request logic).
  - `ai/fireteam_ai.gd` (help request receipt and commander intent signal).

### 3) Tactic cards
- **Task name:** **Tactic cards:** implement a tactic catalogue with triggers, requirements, act plans, success and abort conditions and cooldowns.
- **Status:** RESOLVED
- **Expected behavior:** Tactic cards should be represented as catalog entries with explicit triggers/requirements, execution plans, and success/abort conditions plus cooldowns.
- **Fix note:** Added a structured tactic catalogue in `ai/fireteam_ai.gd` and wired selection, execution, success, and abort checks to use it.
- **Evidence:**
  - `ai/fireteam_ai.gd` (tactic catalogue with triggers/requirements/act plans/success+abort conditions/cooldowns).

### 4) Tactic selection & switching
- **Task name:** **Tactic selection & switching:** choose tactic cards based on a score (gain vs risk vs feasibility vs time). Evaluate during execution; abort and switch if conditions change (e.g. heavy losses, suppression, enemy flank).
- **Status:** RESOLVED
- **Expected behavior:** Scoring should explicitly weigh gain/risk/feasibility/time and abort/switch based on changing conditions including suppression or enemy flanking.
- **Fix note:** Added explicit gain/risk/feasibility/time scoring breakdown per tactic, plus heavy suppression/loss/flank detection that triggers tactic abort/switch decisions with telemetry.
- **Evidence:**
  - `ai/fireteam_ai.gd` (score breakdown with gain/risk/feasibility/time; heavy suppression/loss/flank sensing and abort checks).

### 5) Victory conditions
- **Task name:** **Victory conditions:** implement elimination and a simple objective (e.g. hold a zone for X seconds). At match end determine win or lose and transition to the `AfterAction` scene.
- **Status:** RESOLVED
- **Expected behavior:** Both elimination and a hold-zone objective should be available in the main match flow.
- **Fix note:** Added an `ObjectiveMarker` to the default `Game` scene and exposed objective progress in the debug overlay so the hold-zone evaluation is visible during the primary match flow.
- **Evidence:**
  - `scenes/Game.tscn` (now includes `ObjectiveMarker`).
  - `scripts/debug_overlay.gd` (objective status line).

### 6) Roster UI
- **Task name:** **Roster UI:** add a roster screen where the player can view persistent units, XP and ranks, assign them to missions, and replace casualties. XP/ranks should have visible effects (e.g. increased accuracy, suppression resistance).
- **Status:** RESOLVED
- **Expected behavior:** The roster should support assignment **and** replacement of casualties, with XP/rank effects visible.
- **Fix note:** Added KIA status tracking in the roster data, kept fallen units visible, and added a Replace action to create fresh roster entries for casualties.
- **Evidence:**
  - `scripts/unit.gd` (mark player units as KIA on death).
  - `scripts/game.gd` (store roster status on loss).
  - `scripts/roster.gd` (replace action + status display).
  - `scenes/Roster.tscn` (Replace button).
