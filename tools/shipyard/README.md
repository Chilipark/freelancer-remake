# Regenerating the ship models

The ships in `assets/ships/` come from [Shipyard](https://github.com/exoticspices/shipyard),
a seeded low-poly ship generator. Its output is CC0.

```
git clone https://github.com/exoticspices/shipyard
cd shipyard/_dev && npm install three@0.170.0
cp <this repo>/tools/shipyard/export-set.mjs .
node --import ./register.mjs export-set.mjs <this repo>/assets/ships
```

Edit the `SET` list in `export-set.mjs` to change seeds, classes (fighter,
hauler, surveyor, miner, corvette, racer), tiers (0-2) or liveries
(industrial, navy, salvage, corporate, stealth). You can preview seeds at
https://exoticspices.github.io/shipyard/.
