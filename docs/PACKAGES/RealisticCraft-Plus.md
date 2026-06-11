# RealisticCraft Plus

**Status:** Beta optional add-on

RealisticCraft Plus adds new items and recipes on top of RealisticCraft. It is not required for the core overhaul.

## Features

- New items: Oxy-Candle, Cherimoya Smoothie, Biogenic PFC Emulsion
- Processor refinement chains (ingots to wires, fiber mesh, rubber, etc.)
- Raw-material reverse recipes (ingot back to ore)

## Requirements

- RealisticCraft (core)
- SN2-DF loader (`SDF`)
- Pak: `ExtraItems_P.utoc` (built from `Source/RealisticCraft_Items` during packaging)

## Data layout

| Location | Role |
|----------|------|
| `Toml/RealisticCraft_Plus/SDF/` | Authoring TOMLs (~17 files) |
| `Packaged/RealisticCraft_Plus/.../SDF/` | Shipped install tree |
| `Packaged/.../Content/Paks/~mods/` | Item paks |

## Enable

Install `RealisticCraft_Plus.zip` and enable `RealisticCraft_Plus` in `mods.txt` or via `enabled.txt`.
