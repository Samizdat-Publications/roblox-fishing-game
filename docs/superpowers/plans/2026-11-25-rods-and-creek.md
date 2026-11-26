# Rods and Cedar Creek Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Better rods to buy (longer casts, an easier fight) and a second fishing spot to unlock, Cedar Creek, with three new fish that live only there. The boat comes after this.

**Architecture:** Rod stats are a shared data table applied by the server when it computes cast distance and the fight profile it sends; the client never chooses a bonus. The creek is more gray-box world from `WorldBuilder` (new water boxes and zones), gated by a Creek Pass bought once: the server refuses creek casts without it, and the gate barrier turns off only on the owner's own screen.

**Tech Stack:** As before (Luau, Studio MCP, `docs/superpowers/plans/2026-11-25-fishing-game-v1.md`).

**Spec:** `docs/DESIGN.md`, later versions item 2 ("Better rods and reels, a boat, a second fishing spot to unlock"). Stewart asked Claude to make the design calls for now.

## Global Constraints

- Server-authoritative: rod bonuses, pass purchase and creek access are checked on the server.
- No em dashes in player-facing text, docs or commits. Keyboard and mouse, touch and gamepad.
- Older progress stays useful: rods add to what you have; the lake keeps all its fish. Data version 4 adds `rods`, `rod` and `creekPass`.
- Making-of step for each piece: before still first, after still when done.

## Rules (the numbers)

- Rods (reel included): Willow Rod (start, free): no bonus. Fiberglass Rod, 120 coins: cast +8 studs, catch zone x1.15. Graphite Rod, 350 coins: cast +16 studs, catch zone x1.3, heavy fish pull 50 percent less. Buying equips; owned rods can be switched in the shop.
- Creek Pass: 250 coins, once. Gate on the west shore path.
- Creek spots and fish (real habits):
  - Riffle (fast shallow water): Rainbow Trout, dawn and day, crickets and spinner; 20 to 50 cm.
  - Rocks (boulders mid-stream): Smallmouth Bass, day and dusk, spinner, crickets, minnows; 20 to 50 cm.
  - Pool (deep slow bend): Walleye, dusk and night, minnows and worms; 30 to 75 cm.
  Creek fish sell well (base 22 to 40) and fight hard and fast (trout jumpy, smallmouth strong runs, walleye steady and heavy).

## Review Focus

1. Casting into the creek without a pass: refused with a hint pointing to the gate; nothing caught.
2. Buying a rod you already own or can't afford: refused, coins unchanged.
3. Equipping a rod you don't own: ignored.
4. Old saves: Willow Rod owned and equipped, no pass.
5. The creek water must count as water for cast checks, and lake casts must not land in the creek box (separate boxes).

---

### Task 1: Rods

**Files:** create `Shared/RodData.luau`; modify `Inventory.luau` (v4, `buyRod`, `equipRod`, snapshot), `FishingService.luau` (cast bonus, fight profile adjusted by rod), `EconomyService.luau` (RF `BuyRod`, RE `EquipRod`), `Remotes.luau`, `RodService.luau` (rod color and length by rod), `UI.luau` (Rods section in the shop), tests.

**Interfaces:** `RodData.list/byId` with `{id, name, price, castBonus, zoneMult, heavyResist, color, length, blurb}`; `RodData.applyFight(profile, rodId) -> profile` (copy with zone and heavy adjusted); `Inventory.buyRod(data, id) -> (ok, msg)`, `Inventory.equipRod(data, id) -> boolean`.

- [ ] Spec: new players own and use the Willow Rod; buying Fiberglass with 100 coins fails, with 200 succeeds and equips; buying it twice fails; equipping an unowned rod fails; `applyFight` on the catfish with Graphite gives zone x1.3 and half the heaviness and leaves the original untouched; v3 saves reconcile to v4 with the Willow Rod.
- [ ] Playtest: buy the Fiberglass Rod in the shop, see it in hand, cast lands further, fight zone is bigger.

### Task 2: Cedar Creek

**Files:** modify `WorldBuilder.luau` (creek world west of the lake, `waters()` list, creek zones, gate with `CreekPrompt`), `FishLogic.luau` (`isOnWaterAny(pos, waters)`, spot names), `FishData.luau` (3 species), `FishingService.luau` (water list, pass check), `EconomyService.luau` (RF `BuyPass` via the gate prompt), client gate (barrier off when you own the pass), `FishShadows.luau` (creek zones), tests.

- [ ] Spec: Riffle at dawn on crickets is top Rainbow Trout; Pool at night on minnows is top Walleye; Rocks by day on a spinner is top Smallmouth Bass; none of the three bite in the lake; a point in the creek counts as water and one on the creek bank does not.
- [ ] Playtest: the gate blocks the path; buying the pass opens it; trout at the riffle at dawn, walleye at the pool at night; journal shows 11 species.
