# Starlane Rogue

A **Freelancer-style space roguelite** with **Diablo-style loot**, built in
**Godot 4.3+**. (Working title — rename it whenever you like.)

One open-world star system, about 450 km end to end. Sectors (pirate
packs, elite champions, trade stations, unknown signals) are linked by
Freelancer-style **trade lanes**: fly through any ring and you're carried
along at ~2,200 m/s. You can also cruise anywhere yourself at 300 m/s, it
just takes a while. The further east you go, the tougher it gets. Reach the
Warlord's Bastion, destroy the dreadnought and fly out through the escape
gate to win. When you die, you keep **salvage** to spend on permanent
upgrades and new ships.

**Ambushes and jammers:**
- Lane trips can be **disrupted** mid-way: you drop out among pirates who
  bring a jammer, so you can't just cruise away.
- Some lanes are **jammed** by a guarded pirate jammer. Lane travel stops
  short of it until you destroy it (jammed lanes show red on the nav map
  once you've found them).
- Long cruises through open space attract **interdictors**: pirate ships
  whose jamming field knocks you out of cruise.
- Jammers and interdictors show a faint red bubble. Inside it, cruise and
  lanes are offline.

## Running

**Without Godot:** download the latest Windows build from the
[Actions tab](../../actions) (open the newest "Build game" run, then
*StarlaneRogue-Windows* under Artifacts), unzip it and run
`StarlaneRogue.exe`. On older graphics cards use
`Play (compatibility mode).bat`.

**With Godot:** open the folder in the Godot 4.3+ editor and press **F5**,
or run `godot --path .`.

**Building yourself:** install the Godot 4.3 export templates, then
`godot --headless --path . --export-release "Windows Desktop" build/windows/StarlaneRogue.exe`
(or `"Linux"`). Presets are in `export_presets.cfg`.

## Controls (Freelancer defaults)

| Key | Action |
| --- | --- |
| Mouse | Steer toward the cursor (Space toggles mouse flight) |
| Left mouse | Fire. Guns swivel up to 22° toward the cursor |
| W / S | Throttle up / down · Backspace: full stop |
| Shift+W or C | Cruise: charges 5 s, then 300 m/s, guns offline |
| Fly through a lane ring, or F next to one | Ride the trade lane |
| Tab | Afterburner (drains power) |
| A / D · Q / E | Strafe · Roll |
| R | Cycle target (green diamond = where to aim to hit it) |
| T | Tractor beam: pull in nearby loot |
| F | Dock at a station / investigate a signal / enter a lane |
| I · M · Esc | Cargo & loadout · Nav map (click a sector for a waypoint) · Pause |
| G | Autopilot to the waypoint. Plans the fastest route over trade lanes, cruises to each lane, rides it, and hands back control on arrival. Any flight key, taking fire, getting jammed or a lane ambush cancels it |

## How it fits together

**Flight** (`scripts/ship/flight_model.gd`) follows the Freelancer decomp's
`CEEngine` / `CSteering`: engine force works against linear drag, so speed
eases toward throttle × top speed and sideways drift bleeds off. Cruise uses
the decomp's constants (`CRUISING_SPEED = 300`, `CRUISE_ACCEL_TIME = 5`).

**Loot** (`scripts/loot/`) follows Diablo's item rules from DevilutionX
(`Source/items.cpp`), with Diablo 2's rare tier added:

- Unique roll first: d100 ≤ 1 (pirates), 5 (elites) or 15 (bosses). Boss drops get +4 item level.
- Magic roll: d100 ≤ 10 or d100 ≤ item level. Bosses, elites and vendors always roll magic.
- Magic items: prefix 1 in 4, suffix 2 in 3, at least one, picked from affixes
  with level in [ilvl/2, ilvl], weighted by each affix's drop weight.
- Rare (D2): 3–6 affixes, max 3 prefixes and 3 suffixes, no repeated stat, two-word name.
- Colours: white normal, blue magic, yellow rare, gold unique.
- Loot find works like D2 magic find, with diminishing returns for uniques/rares.
- Weapon damage mods are local to that weapon; everything else is ship-wide.

**Damage types:** Thermal (all-round), EMP (2× vs shields, weak vs hull),
Kinetic (125% vs hull, 60% vs shields).

**Elites** get Diablo 2-style champion modifiers (Swift, Warded, Brutal,
Leech, Volatile). The **boss** calls in escorts at 66% and 33% hull.

| Folder | What's in it |
| --- | --- |
| `scripts/core` | Run state, meta progression, sector map and layout, game world |
| `scripts/loot` | Item bases, affixes, uniques, generator |
| `scripts/ship` | Flight model, ship/player/enemy, projectiles, camera |
| `scripts/world` | Galaxy (lanes, streaming, ambushes, jamming, floating origin), sector contents, stations, loot pods, events, effects |
| `scripts/ui` | HUD, inventory/shop, map, events, menus |

Ships, asteroids and sounds come from free CC0 sources (see
`assets/CREDITS.md`). Every asset is optional: swap a file for another with
the same name, or delete it and the game falls back to built-in shapes.

## Tests

```
godot --headless --path . --script res://tests/run_tests.gd
```

These cover the loot rules (over 6,000 generated items), rarity rates, flight
physics, ship stats, map generation, damage, and a scripted playthrough
(fights, loot, riding a lane end to end, jammed lanes, jammers and
interdictors, the floating origin, death).

The world keeps the player near (0,0,0) and shifts everything else around
them ("floating origin"), so positions stay precise across hundreds of
kilometres. Sectors load within 15 km and unload past 21 km, remembering
which pirates you've killed.
`tests/screenshot.gd` renders screenshots when run under a display, for
example with `xvfb-run`.
