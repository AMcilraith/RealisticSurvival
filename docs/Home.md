# Realistic Survival

**Version:** 2.1

A multi-package Subnautica 2 mod overhaul focused on realistic crafting, survival balance, and expanded storage — built on [UE4SS](https://www.nexusmods.com/subnautica2/mods/36) and [SN2-DF](https://github.com/AMcilraith/Subnautica2Mods/wiki).

Developed by TerryTie. Inspired by [Realistic Craft 2.0](https://www.nexusmods.com/subnautica/mods/767) for Subnautica 1.

## Packages

| Package | Status | Required | Description |
|---------|--------|----------|-------------|
| [RealisticCraft](PACKAGES/RealisticCraft) | Stable core | Yes (for crafting overhaul) | ~150+ recipe changes across all crafters |
| [RealisticCraft Plus](PACKAGES/RealisticCraft-Plus) | Beta add-on | No | New items, processor chains, ingot reversal |
| [RealisticScans](PACKAGES/RealisticScans) | Alpha add-on | No | Scan duration and quantity overrides |
| [RealisticStorage](PACKAGES/RealisticStorage) | Beta add-on | No | Hotbar, inventory, and locker sizing |

The **SN2-DF loader** (`SDF` mod folder) is required for all TOML-based packages. It is fetched automatically during packaging and bundled as `SN2-DF.zip` (not published separately to Nexus).

## Quick links

- [Overview](OVERVIEW) — design philosophy
- [Installation](INSTALLATION) — setup and load order
- [Gameplay Guide](GAMEPLAY) — major crafting changes
- [Developer Guide](DEVELOPER) — authoring and build workflow
- [CI and Releases](CI-AND-RELEASES) — GitHub Actions and Nexus publish
- [Changelog](CHANGELOG)
- [SN2-DF Wiki](https://github.com/AMcilraith/Subnautica2Mods/wiki) — TOML reference and loader install

## License

Mod content: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). SN2-DF loader: GPL-3.0 (see `Licence/license/`).
