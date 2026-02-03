# PRD v1.0 — SOCOM: Somewhat organized Command of Morons — Top-Down RTS Tactical Shooter  
**Free-Move • Cover • Suppression • Persistent Campaign**

> **Status:** Draft v1.0  
> **Doel:** Klaar om als basis te dienen voor repo-setup, tasks.md en agent-handoff.  
> **Kernprincipe:** AI is *core to the challenge* en volgt **Sense → Decide → Act → Evaluate** met **self-preservation** (geen hive-mind, geen terminator-runs).

---

## Inhoud
- [0) Samenvatting](#0-samenvatting)
- [1) Product doelen](#1-product-doelen)
- [2) Scope](#2-scope)
- [3) Target experience](#3-target-experience)
- [4) Core loop](#4-core-loop)
- [5) Controls & UX](#5-controls--ux)
- [6) Movement & formation (free-move)](#6-movement--formation-free-move)
- [7) Combat model (MVP)](#7-combat-model-mvp)
- [8) Units & roles (MVP)](#8-units--roles-mvp)
- [9) Maps & objectives](#9-maps--objectives)
- [10) AI — Core to the challenge](#10-ai--core-to-the-challenge)
- [11) Persistence & campaign layer](#11-persistence--campaign-layer-roadmap-met-verplicht-fundament)
- [12) Technical requirements](#12-technical-requirements)
- [13) Risks & mitigations](#13-risks--mitigations)
- [14) Milestones (ready-to-build)](#14-milestones-ready-to-build)
- [15) Acceptance Criteria (MVP)](#15-acceptance-criteria-mvp)

---

## 0) Samenvatting
Een top-down **RTS-meets-tactical shooter** met **simpel beeld**, maar **diepe tactiek**.  
De speler geeft orders aan **4–80 units** via standaard RTS-selectie (drag-box, shift-add) en tekent verplaatsingen/posities/hoeken zodat units cover pakken, vuurlijnen controleren en pushes op timing gebeuren.

**Inspiratie (richting, niet kopiëren):**
- Schaal/feel richting *War of Dots*
- Tactisch terrein/cover/LoS/suppress richting *Running with Rifles*

**Kernchallenge:** AI is niet dom kanonnenvoer.  
AI is “core to the challenge” en handelt volgens **Sense → Decide → Act → Evaluate**, met realistisch zelfbehoud/morale (geen hive mind, geen terminator-runs).

**Daarnaast:** persistence moet voelbaar zijn (XP/ranks), met een duidelijke roadmap naar een campaign/meta layer.

---

## 1) Product doelen

### 1.1 Design pillars
1) **Orders > Reflexen**  
Tactiek komt uit plaatsing, timing, lanes, suppressie, reserves, flank/screen gedrag.

2) **Leesbaarheid boven simulatie**  
Speler snapt waarom iets gebeurt: cover/LoS/suppressie/targeting is zichtbaar.

3) **Scale zonder chaos**  
Het systeem moet zowel 4–12 micro als 30–80 platoon-control aan kunnen.

4) **AI is een tegenstander, niet decor**  
Geen perfecte script-AI, wel consistent, adaptief en niet-stuck.

### 1.2 Definition of done (MVP)
Een speelbare vertical slice:  
**menu → match → tactische fight → win/lose + after-action**, met:
- betrouwbare selectie/orders
- cover/LoS/suppressie als core systems
- basis AI die “smart enough” voelt
- debug overlays vanaf dag 1

---

## 2) Scope

### 2.1 MVP (must-have)
- Free-move movement (geen grid/tiles)
- RTS selectie: drag-box + shift-add
- Groepsorders: move, attack-move, hold, spread/spacing
- Cover + LoS + suppressie (functioneel en zichtbaar)
- Combat (simpel maar consistent; hitscan oké)
- AI (core challenge): cover response + objective pressure + early flank/screen/BoF behavior + plan switching
- 1 map + 1 mode (Elimination default; optioneel eenvoudige objective)
- After-action: “wat gebeurde er” feedback
- Basis persistence model (minimaal: unit IDs + XP/rank data structuur), ook als gameplay unlocks later komen
- Save/load (minimaal voor campaign state stub)

### 2.2 v1 (should-have)
- Campaign flow (operations/mission chain)
- XP/ranks actief met merkbare effecten
- Extra maps + objectives + modifiers
- Expanded AI tactics catalog (meer cards, betere telemetrie)
- Control groups (Ctrl+1..9) en dubbele klik “select same type”

### 2.3 Out of scope (nu expliciet)
- Multiplayer
- AAA art/cinematics/voice acting
- Volledige ballistics sim / physics chaos (later alleen als het tactiek versterkt)
- Diepe RPG equipment crafting (later mogelijk, maar niet in MVP)

---

## 3) Target experience
Speler geeft orders als commandant, niet als shooter.

In fights draait het om:
- lanes onderdrukken (base of fire)
- safe pushes (bounding)
- flanks timen
- screens neerzetten tegen counter-flanks
- traps en crossfires creëren
- “peel back” als het misgaat

Verlies voelt fair: speler ziet waarom (LoS, cover, suppressie, flank vector).

---

## 4) Core loop
### Pre-match (MVP-light)
Start match met preset forces of simpele roster selector (optioneel).  
**Persistence foundation blijft sowieso.**

### Match
- Select units (RTS)
- Geef groepsorders (move/attack-move/hold/spread)
- Contact: cover/LoS/suppressie domineren
- AI voert tactische plannen uit en switcht waar nodig

### End
- Win/lose
- After-action: key events, casualty causes, “hot zones”, suppress impact

### Meta (roadmap)
- XP/ranks en campaign progression (v1)

---

## 5) Controls & UX

### 5.1 Selectie (hard requirements)
- Drag-box selectie
- Shift-click / shift-drag: toevoegen aan selectie
- (Optioneel) Ctrl-click: toggle
- Click: single select
- Visuele selectie: outline + marker + panel

### 5.2 Orders (MVP set)
- **Move:** click-to-move; optional shift-queue (max 2–3)
- **Attack-move:** move + engage onderweg
- **Hold:** positie houden; return fire / free fire (MVP: 2 standen)
- **Spread/Spacing:** tight/normal/loose (anti-clump)
- (Optional later) Facing/fire arc voor subsets (niet default voor grote blobs)

### 5.3 Camera & pacing
- Real-time met pause (hard)
- (Optional) slow-mo toggle
- Zoom in/out; edge pan + WASD optional

### 5.4 Feedback & overlays (hard)
- Cover indicators (light/heavy)
- LoS preview (selected unit/selection)
- Suppression state (per unit + zone hints)
- Path/debug lines (voor dev; toggle)
- Event log (laatste ~10–20 events)
- After-action: “wat raakte je”, “van welke angle”, “waar werd je pinned”

---

## 6) Movement & formation (free-move)

### 6.1 Movement model (MVP)
- 2D world-space movement (geen tiles)
- Navmesh pathfinding rond obstakels
- Local avoidance/steering om clumping te voorkomen
- Basic collision/spacing (separation force + caps)

### 6.2 Scale target
- Player command scale: **4–80 units** (mission dependent)
- Total units: **80–200** (player + AI), met throttling/LOD in AI updates

---

## 7) Combat model (MVP)

### 7.1 Basics
- Hitscan shooting
- HP-based damage (simpel)
- Accuracy beïnvloed door:
  - cover
  - suppression/stress
  - distance
  - movement state (moving/steady)

### 7.2 Cover
- Light/Heavy cover
- Cover effect: hit chance en/of damage reduction (consistent, zichtbaar)

### 7.3 Line of Sight
- Obstacles blokkeren LoS
- Last-known positions vervagen over tijd (uncertainty)

### 7.4 Suppression (core)
- Incoming fire → suppression stijgt
- Suppression effecten (MVP):
  - accuracy down
  - movement slows / “hesitation”
  - prefer hug cover / shorter peeks
- Support/LMG archetypes leveren lane control

---

## 8) Units & roles (MVP)
Minimaal 3 archetypes (data-driven):
- **Rifle:** baseline
- **Scout/SMG:** speed/flank
- **Support/LMG:** suppress/anchor

Unit stats (MVP):
- HP, speed, accuracy, suppression resistance, role tag, cost tag (voor later)

---

## 9) Maps & objectives

### 9.1 Map style
Low-fi top-down: gebouwen, muren, zandzakken, bomen/hedges, streets, chokepoints, flank routes.

### 9.2 MVP content
- 1 map: “town + outskirts” met duidelijke lanes en minstens 2 flank routes
- 1 mode: **Elimination** (default)  
  Optional: simpele **Hold objective** variant (1 zone, timer), v1 uitbreiden

---

## 10) AI — Core to the challenge

### 10.1 Niet-hive-mind architectuur
- **Individual brain:** micro survival/cover/peek/reload/retreat
- **Fireteam brain (2–6):** lokaal coördineren (bounding, base-of-fire, screen)
- **Commander intent:** high-level goals (hold, probe, fix, disengage), geen telepathische perfectie

### 10.2 Self-preservation & morale (hard requirement)
Per unit:
- Fear (0–1), Confidence, Exposure budget  
Fear stijgt door incoming fire, casualties nearby, low HP, no cover; daalt door good cover, allies nearby, leader nearby, winning exchange.

Gedrag:
- **Medium fear:** hug cover, shorter peeks, suppress preference
- **High fear:** fallback/retreat, refuse open-ground crossings, call for help (conceptueel)

### 10.3 SDAE loop (hard requirement)
Alle AI beslissingen lopen via:
- **Sense:** threats/cover/LoS/team state/objective state
- **Decide:** score-based keuze uit tactic cards (gain vs risk vs feasibility vs time)
- **Act:** group orders + individual micro behaviors
- **Evaluate:** success/failure/abort criteria; switch tactic; avoid “stuck in one plan”

### 10.4 AI Tactics Catalog (MVP subset + uitbreidbaar)
Implementatie als “tactic cards” met:
- triggers
- required roles
- act plan
- success conditions
- abort conditions
- cooldown

#### Core 5 (must for v1 AI catalog)
1) Base of Fire (lane suppress)  
2) Bounding Overwatch push  
3) Flank met kleine subgroep  
4) Screen/Security element  
5) Crossfire trap (kill zone)

#### Extra manoeuvres (minimaal beschikbaar als cards; MVP kan subset)
- Peel Back (controlled retreat)
- Probe and Pull
- Recon by Fire
- Fix-and-Shift
- Counter-flank Response
- Reserve Commitment
- Staggered Entry (chokes)
- Cross-Cover Leap
- Fire Discipline (ambush hold fire)
- Local Leadership Anchor (rank effect)
- Casualty Aversion / Buddy Drag (later)
- Threat Budgeting (refuse suicidal pushes)

**MVP minimum behavior set (realistisch haalbaar):**
- Contact response → cover + suppress lane
- Early flank subgroup
- Screen on exposed flank
- Peel back when losing
- Reserve commitment (klein percentage)  
De rest staat als roadmap, maar tactic card structuur moet uitbreiding makkelijk maken.

### 10.5 AI performance & realism
- Tick throttling/LOD:
  - dichtbij: updates vaker
  - ver weg: minder vaak
- Comms delay: intent verspreidt over ticks (geen instant hive sync)
- Uncertainty: last-known positions decay

---

## 11) Persistence & campaign layer (roadmap met verplicht fundament)

### 11.1 Persistence requirement
- Soldiers hebben unieke IDs en persistent stats
- XP en rank bestaan als data en opslag vanaf MVP (zelfs als effecten pas v1 actief worden)

### 11.2 v1 Meta layer (beoogd)
- Campaign/operations flow
- Upgrades/unlocks die tactische variatie vergroten
- Squad composition over tijd (losses matter)
- Ranks geven merkbare voordelen (maar niet “low rank useless”)

### 11.3 Roadmap checkpoints
- MVP: data model + save/load stub + after-action logging (XP events gelogd)
- v0.9: roster UI + XP/rank progression zichtbaar
- v1: campaign loop + upgrades + AI tactics uitgebreid

---

## 12) Technical requirements

### 12.1 Stack choice (default)
- Godot 4 (2D)

### 12.2 Repo & build
- README: install/run/controls
- One-click run voor dev
- Export/build instructions voor release (portable zip)

### 12.3 Data-driven
- Units/weapons/tactic weights in JSON/CFG
- Map descriptors (cover objects, nav obstacles) data-driven waar haalbaar

### 12.4 Debug & telemetry (hard)
Toggle overlays:
- nav paths
- cover slots/edges
- LoS rays
- suppression heat / unit suppression
- AI tactic currently active (per fireteam, dev overlay)
- event log & after-action summary

---

## 13) Risks & mitigations
- **AI voelt dom of unfair** → SDAE + telemetrie + duidelijke abort criteria
- **Scale performance** → throttling/LOD, simpele hitscan, limited perception updates
- **Clumping en pathing chaos** → separation/spacing order + local avoidance + staggered entry behavior
- **Scope creep** → strict MVP milestones, tactic card uitbreiding pas na stable slice

---

## 14) Milestones (ready-to-build)

### MVP (Vertical Slice)
1) Project scaffolding + main menu  
2) Unit spawning (player+AI) + camera  
3) RTS selectie (drag-box + shift-add) + selection UI  
4) Free-move navmesh + local avoidance  
5) Group orders: move / attack-move / hold / spread  
6) Cover system + LoS overlay  
7) Combat + suppression  
8) AI v0: contact→cover+suppress + flank subgroup + screen + peel back + reserve  
9) Win/lose + after-action log  
10) Persistence foundation: unit IDs + XP/rank data + save/load stub  
11) Debug overlays polish + README  

### v0.9
- Roster UI + XP/rank zichtbaar
- Extra map + objective mode
- AI tactic cards uitbreiden (probe/recon/fix-and-shift)

### v1
- Campaign flow + upgrades
- Rank effects actief
- AI tactics catalog uitgebreid + betere telemetrie

---

## 15) Acceptance Criteria (MVP)

### Playable loop
- [ ] Menu → start match → win/lose → after-action scherm werkt end-to-end.

### Scale & usability
- [ ] Speler kan 4–80 units selecteren met drag-box + shift-add zonder UI lag.
- [ ] Group orders werken betrouwbaar voor grote selecties.

### Movement
- [ ] Vrije beweging zonder grid.
- [ ] Pathfinding rond obstakels werkt.
- [ ] Local avoidance voorkomt blob-clumping (zichtbare spacing).

### Tactics systems
- [ ] Cover beïnvloedt combat zichtbaar (indicator + effect).
- [ ] LoS werkt consistent (obstacles blokkeren).
- [ ] Suppression werkt en is tactisch bruikbaar.

### AI (core challenge, MVP minimum)
- [ ] AI zoekt cover bij contact en vormt een lijn (base-of-fire light).
- [ ] AI kan een flank subgroup sturen (niet elke keer, maar regelmatig).
- [ ] AI zet soms een screen element op exposed flank routes.
- [ ] AI peelt back bij duidelijk verlies (geen terminator push).
- [ ] AI blijft niet stuck in één plan (abort/switch zichtbaar in behavior).
- [ ] AI toont self-preservation: high suppression/low HP units vermijden open terrein.

### Persistence foundation
- [ ] Units hebben unieke IDs.
- [ ] XP/rank events worden gelogd en opgeslagen (ook als effecten nog stub zijn).
- [ ] Save/load werkt voor minimaal campaign state stub.

### Tech
- [ ] README met run/export instructions.
- [ ] Debug overlays toggles aanwezig.
