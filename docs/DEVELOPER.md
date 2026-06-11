# Developer Guide

This guide covers the Realistic Survival authoring workflow in the **My_Mods** workspace.

## Repository layout

```
RealisticSurvival/
  Toml/<ModName>/SDF/     # Authoring TOML (preferred edit location)
  Packaged/<ModName>/     # Shippable game layout (what CI zips)
  Source/                 # uasset export intermediates for pak builds
  ci/                     # Packaging and publish scripts
```

## Toml vs Packaged

| Tree | Purpose |
|------|---------|
| `Toml/` | Working copies for recipe/category edits; easier to diff and organize |
| `Packaged/` | Staged install tree consumed by CI and player zips |

**Workflow:** Edit TOML in `Toml/`, sync to `Packaged/` before release (via export scripts or manual copy). CI packages from `Packaged/`, `Source/`, `Images/`, and `Licence/`.

## Local build (My_Mods workspace)

| Entry | Command |
|-------|---------|
| `Export.bat` | Interactive menu: export, zip, build SN2-DF, SDK export |
| `Export.bat export` | Fetch SN2-DF, build paks, stage Packaged |
| `Export.bat build-sn2-df` | Build loader DLL locally |
| `Deploy-ToModManager.bat` | Copy Packaged mods to Mod Manager |

Orchestration: `tools/Scripts/Operations.ps1`

## TOML validation

```powershell
python tools/Scripts/validate_toml.py <path>
python tools/Scripts/_validate_all_toml.py
```

## Asset pipeline

| Stage | Tool |
|-------|------|
| Game assets → JSON | uasset export to `Source/RealisticCraft_Test/` |
| JSON → TOML | `tools/Scripts/uassetgui_to_toml.py` |
| Source → pak | retoc (v0.1.4 default in CI) |
| Scan TOMLs | `tools/Scripts/generate_scan_blueprints.py` |

Pak source folders (`RealisticCraft_Main`, `RealisticCraft_Items`, `RealisticCraft_StringData`) are referenced by CI; prebuilt `.utoc` files may already exist under `Packaged/`.

## SN2-DF dependency

Packaging fetches `SN2-DF.zip` from [Subnautica2Mods Releases](https://github.com/AMcilraith/Subnautica2Mods/releases) unless `SN2_DF_USE_LOCAL_BUILD=1`.

Pin release tag via `SN2_DF_RELEASE` / `SN2_DF_RELEASE_TAG` environment variable.

## Submodule

`Subnautica2Mods/RealisticSurvival` is a git submodule mirror. Commit doc and content changes to the standalone `RealisticSurvival` repo; bump the submodule pointer in Subnautica2Mods when needed.

## Framework documentation

TOML schema, loader install, and architecture: [SN2-DF Wiki](https://github.com/AMcilraith/Subnautica2Mods/wiki).
