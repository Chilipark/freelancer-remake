# Starlane Rogue

A **Freelancer-style space roguelite** with **Diablo-style loot**, built in
**Godot 4.3+**. (Working title — rename it whenever you like.)

Fly a light fighter through 15 sectors linked by jump gates. Every sector
holds something: pirate packs, an elite champion, a trade station, or an
unknown signal. Pirates drop loot. Reach the Warlord's Bastion at the end
and destroy the dreadnought to win. When you die, you keep **salvage** to
spend on permanent upgrades and new ships.

## Running

Open the folder in the Godot 4.3+ editor and press **F5**, or run
`godot --path .`.

## Controls (Freelancer defaults)

| Key | Action |
| --- | --- |
| Mouse | Steer toward the cursor (Space toggles mouse flight) |
| Left mouse | Fire. Guns swivel up to 22° toward the cursor |
| W / S | Throttle up / down · Backspace: full stop |
| Shift+W or C | Cruise: charges 5 s, then 300 m/s, guns offline |
| Tab | Afterburner (drains power) |
| A / D · Q / E | Strafe · Roll |
| R | Cycle target (green diamond = where to aim to hit it) |
| T | Tractor beam: pull in nearby loot |
| F | Dock at a station / investigate a signal |
| I · M · Esc | Cargo & loadout · Sector map · Pause |

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
| `scripts/core` | Run state, meta progression, sector map, game world |
| `scripts/loot` | Item bases, affixes, uniques, generator |
| `scripts/ship` | Flight model, ship/player/enemy, projectiles, camera |
| `scripts/world` | Sector builder, gates, stations, loot pods, events, effects |
| `scripts/ui` | HUD, inventory/shop, map, events, menus |

All models are built from primitive shapes in code, so the project has no
art assets yet.

## Tests

```
godot --headless --path . --script res://tests/run_tests.gd
```

These cover the loot rules (over 6,000 generated items), rarity rates, flight
physics, ship stats, map generation, damage, and a scripted playthrough.
`tests/screenshot.gd` renders screenshots when run under a display, for
example with `xvfb-run`.
