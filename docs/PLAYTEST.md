# Playtesting Guide

This document defines fast, repeatable playtests for the MVP vertical slice. Use it for manual QA in the editor and for headless automation in CI.

## 2-minute smoke test (manual)

1. Launch the project and reach the main menu.
2. Start the default map (Start).
3. Select units with a drag-box and issue a move order.
4. End the run and confirm the AfterAction screen appears.
5. Return to the main menu.

## 10-minute feature test (manual)

### Selection + Orders

- Drag-box select multiple units.
- Shift-drag to add units to the selection.
- Double-click a unit to select all of the same role.
- Right-click to issue a move order; Shift-right-click to queue a second waypoint.
- Hold **A** and right-click to issue an attack-move order.
- Press **H** to cycle hold modes (off → defensive → aggressive).
- Press **F** to cycle formation spacing (tight/normal/loose).

### Combat + Suppression + Cover

- Move units into cover and confirm cover indicators show.
- Let units exchange fire; confirm suppression bars fill and decay.
- Confirm units in cover take fewer hits than those in the open.

### Flow + Pause

- Press **Space** to pause/unpause the game.
- End the run; confirm AfterAction shows a summary.

### AI Behavior

- Observe AI units attempting to move, flank, screen, or peel back.
- Confirm AI slows down or retreats when suppressed or damaged.

## Regression checklist (manual)

- Game boots without errors.
- Menu loop works (Menu → Game → AfterAction → Menu).
- No crashes or script errors in the console.
- `user://match_log.txt` is created after a match.
- `user://campaign.json` updates after a match (roster data persisted).
