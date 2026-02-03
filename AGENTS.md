# AGENTS.md — Project Rules & Workflow

## Role
You are my senior game engineer + tech lead. Build this project from scratch based on PRD v1.0.

## Source of truth
- Read and follow: `PRD - SOCOM.md`
- Implement milestones as defined in: `tasks.md`
- If PRD and tasks conflict: PRD wins, then update tasks.md to match PRD.

## Hard rules (non-negotiable)
- No scope creep. Build MVP vertical slice first.
- Real-time with pause. Free-move (no grid).
- RTS selection: drag-box + shift-add.
- Unit scale: player 4–80; total 80–200 (with throttling).
- MVP orders: move, attack-move, hold, spread/spacing.
- Core systems are mandatory: cover + LoS + suppression (visible to player).
- AI is the core challenge and must follow SDAE:
  Sense → Decide → Act → Evaluate
  - Include self-preservation (fear/confidence/exposure)
  - No hive-mind behavior; individuals avoid dying
- Tactic cards structure is mandatory, minimum set:
  - base-of-fire (light)
  - flank subgroup
  - screen/security element
  - peel back
  - reserve
- Every milestone must be runnable and include:
  - README run/build instructions
  - debug overlays
  - logging from the beginning

## Workflow expectations
- Work in small, playable increments. Each milestone produces something that runs.
- Prefer simplest implementation that satisfies PRD.
- Before implementing a task:
  - Identify exact files to change/create
  - Identify how you will run/build/test
- After implementing a task:
  - Run the build/test commands in the sandbox
  - Fix failures (do not hand-wave)

## Output format for each task
When you complete a task, report:
1) What you changed (files + brief summary)
2) How to run it (exact commands)
3) What remains / next task pointer in tasks.md
4) Known issues (only factual, reproducible)
