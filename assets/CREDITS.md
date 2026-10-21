# Asset credits

Everything in `assets/` is free to use, including commercially. No credit is
required, but here's where it came from.

| Folder | What | Source | License |
| --- | --- | --- | --- |
| `ships/` | All ship models (player hulls, pirates, elite, interdictor, jammer, dreadnought, freighter, miner) | Generated with [Shipyard](https://github.com/exoticspices/shipyard) by exoticspices. Regenerate or change with `tools/shipyard/export-set.mjs` | Generated ships are CC0 (tool is MIT) |
| `models/` | Asteroids, rocks, satellite dish, turrets | [Kenney Space Kit](https://kenney.nl/assets/space-kit) via the [tge-assets mirror](https://github.com/Hidencod/tge-assets) | CC0 (see `LICENSE-kenney-space-kit.txt`) |
| `sounds/` | Lasers, explosions, hits, shields, engines, doors | [Kenney Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) via [CC0-Public-Domain-Sounds](https://github.com/lavenderdotpet/CC0-Public-Domain-Sounds) | CC0 (see `LICENSE-kenney-scifi-sounds.txt`) |

## Swapping assets

Replace any file with one of the same name and the game picks it up; delete
it and the game falls back to its built-in shapes or silence.

- Ships: `assets/ships/<name>.glb` plus `<name>.json` (size and engine positions). Models face +Z (glTF default); the game turns them around.
- Rocks / props: `assets/models/<name>.glb`.
- Sounds: `assets/sounds/<name>.ogg` (names listed in `scripts/core/sfx.gd`).
