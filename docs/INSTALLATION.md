# Installation

## Requirements

- **Subnautica 2**
- **[UE4SS](https://www.nexusmods.com/subnautica2/mods/36)** installed under `Subnautica2/Binaries/Win64/ue4ss/`

## Download

Get the latest release zips from:

- [GitHub Releases](https://github.com/AMcilraith/RealisticSurvival/releases)
- [Nexus Mods](https://www.nexusmods.com/subnautica2/mods/) (when published)

**Important:** Download version **0.6 or higher** if your game crashes after Hotfix 0.3.

## Install steps

1. Extract each zip into your Subnautica 2 install folder, merging into `Subnautica2/`.
2. Confirm UE4SS is installed and working.
3. Enable the mods (packaged zips include `enabled.txt`; or add entries to `ue4ss/Mods/mods.txt`).

## Load order

Enable mods in this order:

| Order | Mod folder | Package zip |
|-------|------------|-------------|
| 1 | `SDF` | `SN2-DF.zip` (bundled dependency; fetched at package time) |
| 2 | `RealisticCraft` | `RealisticCraft.zip` |
| 3 | `RealisticCraft_Plus` | `RealisticCraft_Plus.zip` (optional) |
| 4 | `RealisticStorage` | `RealisticStorage.zip` (optional) |
| 5 | `RealisticScans` | `RealisticScans.zip` (optional) |

Example `mods.txt` entries:

```
SDF : 1
RealisticCraft : 1
RealisticCraft_Plus : 1
RealisticStorage : 1
RealisticScans : 1
```

Only **SDF** ships a DLL (`dlls/main.dll`). Content mods use TOML and optional paks.

## Packaged layout

Each zip expands to:

```
Subnautica2/
  Binaries/Win64/ue4ss/Mods/<ModName>/
    SDF/...              # TOML (SN2-DF content mods)
    Scripts/...          # Lua (RealisticStorage only)
    enabled.txt
  Content/Paks/~mods/... # .utoc paks (RealisticCraft / Plus)
```

## Verify SN2-DF

Launch the game and check the UE4SS log for:

```
SN2-DF Version 1.0-beta Initialized
```

See the [SN2-DF Installation guide](https://github.com/AMcilraith/Subnautica2Mods/wiki/INSTALL) if the loader does not start.

## Optional packages

| Package | Enable when |
|---------|-------------|
| RealisticCraft | Always (core) |
| RealisticCraft_Plus | You want extra items and processor chains |
| RealisticStorage | You want hotbar/inventory/locker changes |
| RealisticScans | You want adjusted scan times |

RealisticCraft Plus requires RealisticCraft. Other add-ons are independent but share the SN2-DF loader.

## Troubleshooting

| Issue | Check |
|-------|-------|
| No recipe changes | `RealisticCraft` enabled; `SDF` loader running |
| Scans unchanged | `RealisticScans` enabled; remove any legacy Lua from old installs |
| Storage unchanged | `RealisticStorage` enabled (Lua mod, separate from SN2-DF) |
| Crash on load | Update to latest mod version; confirm UE4SS compatibility |
