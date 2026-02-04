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
- **Status:** PARTIAL
- **Expected behavior:** Scoring should explicitly weigh gain/risk/feasibility/time and abort/switch based on changing conditions including suppression or enemy flanking.
- **What I found instead:** Scoring is static with minor adjustments; switching mainly checks `losing` or duration. No explicit risk/feasibility/time inputs or enemy flank detection.
- **Evidence:**
  - `ai/fireteam_ai.gd` (`_decide` uses static weights; `_should_switch` checks losing/duration only).
- **Suggested fix location:** Expand `ai/fireteam_ai.gd` scoring inputs with risk/feasibility/time metrics and add abort conditions tied to suppression/flank signals.

### 5) Victory conditions
- **Task name:** **Victory conditions:** implement elimination and a simple objective (e.g. hold a zone for X seconds). At match end determine win or lose and transition to the `AfterAction` scene.
- **Status:** PARTIAL
- **Expected behavior:** Both elimination and a hold-zone objective should be available in the main match flow.
- **What I found instead:** Elimination works in `Game`, but the objective zone only exists in `GameMap2`; the default `Game` scene lacks an `ObjectiveMarker`, so the objective win/lose path doesn’t run there.
- **Evidence:**
  - `scripts/game.gd` (`_update_objective` requires `ObjectiveMarker`).
  - `scenes/Game.tscn` (no `ObjectiveMarker` node).
  - `scenes/GameMap2.tscn` (has `ObjectiveMarker`).
- **Suggested fix location:** Add an `ObjectiveMarker` to the default `scenes/Game.tscn` or ensure objective mode is always part of the primary match flow.

### 6) Roster UI
- **Task name:** **Roster UI:** add a roster screen where the player can view persistent units, XP and ranks, assign them to missions, and replace casualties. XP/ranks should have visible effects (e.g. increased accuracy, suppression resistance).
- **Status:** PARTIAL
- **Expected behavior:** The roster should support assignment **and** replacement of casualties, with XP/rank effects visible.
- **What I found instead:** The roster shows units and allows assign/unassign, but there is no replacement workflow for casualties.
- **Evidence:**
  - `scripts/roster.gd` (assign/unassign only; no casualty replacement logic).
- **Suggested fix location:** Extend `scripts/roster.gd` and `scenes/Roster.tscn` with a replacement action (e.g., create a new unit entry for fallen units).
