# Incremental Plan: Simultaneous Turn-Based Conversion

This document outlines how to convert the hex-strategy-game from **sequential turns** (one unit at a time) to **simultaneous turns** (like server3.js), where all units plan actions, then all execute together.

---

## Current vs Target Model

| Aspect | Current (Sequential) | Target (Simultaneous) |
|--------|----------------------|------------------------|
| **Planning** | One unit at a time | All units plan before execution |
| **Action choice** | Move then Attack (2 choices per unit) | One action per unit (move OR attack) |
| **Execution** | Immediate on click | Batched after all plans are committed |
| **Readiness** | Per-unit (has_moved, has_attacked) | Per-turn (all units have an action) |

---

## Incremental Phases

### Phase 1: Action assignment model (foundation)
**Goal:** Introduce the concept of "planned action per unit" without changing execution.

**Changes:**
- Add `planned_action: ActionInstance | null` (or equivalent) to each unit.
- Add a `BattlePhase` enum: `PLANNING` | `EXECUTING`.
- During `PLANNING`, clicking an action stores it on the unit instead of executing.
- Add a "Confirm" / "Execute" button that ends planning.
- **Execution stays sequential for now** – when Confirm is pressed, execute each unit's planned action one by one (same logic as today).

**Test:** Run a turn: assign move to unit A, attack to unit B, press Confirm. Both actions run in sequence. No behavior change yet except you plan before executing.

---

### Phase 2: One action per unit (move OR attack)
**Goal:** Each unit gets exactly one action per turn (move XOR attack), matching server3.

**Changes:**
- Remove the "move then attack" flow. Each unit picks one: move OR attack (or "wait" / "reload" if you add that later).
- Update UI: when selecting a unit, show both move and attack options; picking one commits and moves to next unit.
- `planned_action` stores the single chosen action.

**Test:** Unit A moves, Unit B attacks. Turn executes. No unit does both move and attack.

---

### Phase 3: Simultaneous execution (order by type) ✓ DONE
**Goal:** Execute all planned actions in a single batch, ordered by action type (like server3).

**Implemented:** All moves execute first, then all attacks. Actions use `block_mode = Ignore` so paths are not blocked by units (simultaneous turn semantics).

**Changes:**
- Add action-type ordering (e.g. `["move", "attack"]` or match server3: fast move → fast attack → move → attack → slow move → slow attack).
- When Execute is pressed:
  1. Collect all valid planned actions.
  2. Group by action type.
  3. Process moves first (resolve collisions – see Phase 4).
  4. Process attacks second (from **new** positions after moves).

**Important:** Attacks must use the unit's position *after* movement. Store `path` and `end_point` in the planned action; resolve final position at execution time.

**Test:** Unit A moves into range, Unit B attacks where A was. After execution, A has moved, B has attacked empty space (or vice versa depending on order). Add case: A attacks B, B moves away – B survives (attack from old position).

---

### Phase 4: Movement collision resolution
**Goal:** Handle multiple units moving to the same tile or swapping.

**Options (pick one to start):**
- **A) Block:** If target hex occupied after all moves resolved, unit doesn't move (or moves as far as possible).
- **B) Swap allowed:** Two units can swap tiles (common in simultaneous games).
- **C) First-come:** Process moves in deterministic order; later mover is blocked if hex is taken.

**server3.js** uses sequential processing: `moveUnit` removes from source and adds to target. Swaps work; double occupancy would put both on same tile. Start simple: **Block** – unit stays if destination occupied after moves.

**Test:** Two units try to move to same hex → one succeeds, one stays. Two units swap → both succeed.

---

### Phase 5: Multi-player / AI planning (optional)
**Goal:** Support two sides (e.g. hotseat or vs AI).

**Changes:**
- Each player/team has a set of units.
- Planning: active player assigns actions to their units.
- "Ready" when all of *your* units have actions.
- For hotseat: switch sides, other player plans.
- For AI: AI assigns actions when it's their turn.
- Execute when *all* sides are ready.

**Test:** Two players, each with units. P1 plans, P2 plans, Execute. All actions run.

---

### Phase 6: Polish
- **Power / resources** (if you want server3-style power consumption).
- **Turn indicator** and phase label ("Planning" vs "Executing").
- **Animation batching** – optionally animate all moves together, then all attacks.
- **Fog of war** (optional) – only show enemy positions from last known state.

---

## Suggested File Structure

```
src/battle/
  battle_phase.gd         # Enum: PLANNING, EXECUTING
  turn_manager.gd         # Tracks planned actions, triggers execution
  execution_resolver.gd   # Phase 4: collision resolution, action ordering

src/unit/
  unit.gd                 # Add planned_action
```

---

## Execution Order Reference (server3.js)

```text
fast move → fast attack → stun → move → attack → slow move → slow attack → spawn → reload → extract
```

For hex-strategy-game initially: **move → attack** is enough. Extend later if you add fast/slow variants.

---

## Testing Checklist (per phase)

1. **Phase 1:** Plan 2 actions, confirm, both run.
2. **Phase 2:** Each unit gets exactly one action.
3. **Phase 3:** Move then attack order; attacks use post-move positions.
4. **Phase 4:** Collision cases (block, swap).
5. **Phase 5:** Two players complete a full turn.

---

## Risk: Breaking Existing Behavior

To minimize risk:
- Keep `UnitsContainer` and `Unit` largely unchanged at first.
- Add new code paths (e.g. `TurnManager`) that delegate to existing `move_along_path`, `attack`, etc.
- Use feature flags or a config var if you want to toggle sequential vs simultaneous during development.
