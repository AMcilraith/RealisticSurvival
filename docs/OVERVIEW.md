# Overview

Realistic Survival rebalances Subnautica 2 crafting and survival to encourage exploration, resource diversity, and more grounded item recipes — without making the game tedious.

## Design principles

- **More diverse crafting** — greater use of rarely used resources.
- **Challenging but fair survival** — gathering and crafting take a larger share of playtime than vanilla, motivating exploration of hidden areas.
- **Consistent crafting logic** — similar item types follow the same material rules (e.g. all tools need Titanium casing and Rubber grips).

## Modular packages

You choose which packages to enable:

1. **RealisticCraft** — core crafting overhaul (required for the recipe changes).
2. **RealisticCraft Plus** — optional recipes and new items.
3. **RealisticScans** — optional scan time/quantity adjustments.
4. **RealisticStorage** — optional inventory and storage changes.

Base-building recipes are intentionally left close to vanilla so large creative bases remain feasible.

## Technology stack

| Layer | Technology |
|-------|------------|
| Mod loader | UE4SS |
| Data framework | SN2-DF (loader mod folder `SDF`) |
| Crafting / scans | TOML under each mod's `SDF/` tree |
| Storage tweaks | UE4SS Lua (`RealisticStorage`) |
| Custom items (Plus) | `.utoc` paks + TOML |

For framework details, see the [SN2-DF Wiki](https://github.com/AMcilraith/Subnautica2Mods/wiki).

## Future goals

- Harvestable flora that is currently scan-only.
- Additional survival packages as the game and tooling mature.

Contributors interested in expanding the mod are welcome to reach out via GitHub issues or Nexus.
