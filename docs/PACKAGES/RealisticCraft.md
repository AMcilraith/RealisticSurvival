# RealisticCraft

**Status:** Core module (required for crafting overhaul)

RealisticCraft replaces most Subnautica 2 crafting recipes with more realistic ingredient chains. Base structural blueprints are intentionally preserved.

## What it changes

- Fabricator, Builder, Processor, Modification Station, Vehicle Crafter, and Food recipes
- Custom fabricator category subdivisions (Resources, Tools, Equipment)
- Optional `.utoc` paks for string/asset overrides

## Data layout

| Location | Role |
|----------|------|
| `Toml/RealisticCraft/SDF/` | Authoring source (categories + ~150 recipe TOMLs) |
| `Packaged/RealisticCraft/.../SDF/` | Shipped install tree |

Key paths under `SDF/`:

```
Categories/     # Tools.toml, Equipment.toml, Resources.toml
Recipes/        # Organized by crafter (Fabricator, Builder, Processor, ...)
```

## Dependencies

- UE4SS
- SN2-DF loader (`SDF` mod folder)

## Gameplay summary

See the [Gameplay Guide](GAMEPLAY) for material, tool, machine, food, and base-building rules.

## TOML authoring

Recipe and category TOML follows the [SN2-DF TOML Reference](https://github.com/AMcilraith/Subnautica2Mods/wiki/TOML_REFERENCE). Validate changes with the workspace `tools/Scripts/validate_toml.py` before packaging.
