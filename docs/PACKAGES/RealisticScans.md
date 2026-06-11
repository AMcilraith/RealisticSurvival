# RealisticScans

**Status:** Alpha optional add-on

RealisticScans adjusts scan durations and required scan counts to better reflect object size, complexity, and world prevalence.

## Technology

- `[[scan_modify]]` TOML tables under `SDF/Scans/`
- Consumed by SN2-DF at runtime (no Lua)
- 12 category TOMLs (Fauna, Flora, Resources, Story, Wrecks, Vehicles, Tools, Basebuilding, etc.)

## Configuration

Global defaults in `Toml/RealisticScans/SDF/Scans/_defaults.toml`:

```toml
[defaults]
debug = false
```

Per-scan fields: `scan_duration`, `num_required`, optional `asset` path.

## Migration from Lua (deprecated)

Older RealisticScans builds used Lua scripts under `Scripts/` to patch scan blueprints. **That approach is deprecated.**

Current builds:

- Ship only `SDF/Scans/*.toml`
- Require the SN2-DF loader (`SDF`)
- Remove any legacy `Scripts/` folder from old installs

If upgrading from a pre-TOML release, delete old RealisticScans Lua scripts and reinstall the current zip.

## Authoring / regeneration

Scan TOMLs can be regenerated from game object dumps and wiki data:

| Script | Purpose |
|--------|---------|
| `tools/Scripts/fetch_wiki_scan_data.py` | Fetches scan metadata from wiki.subnautica.com |
| `tools/Scripts/generate_scan_blueprints.py` | Writes scan override TOMLs to Packaged RealisticScans |

`generate_scan_blueprints.py` uses `DURATION_SCALE = 0.5` by default. Wiki cache lives at `tools/cache/wiki_scan_data.json`.

## Enable

Install `RealisticScans.zip` and enable `RealisticScans` alongside the `SDF` loader.
