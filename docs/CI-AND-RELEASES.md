# CI and Releases

Realistic Survival uses GitHub Actions on `windows-latest` with bash steps.

## Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Package And Release** | Push to `main`/`master` (content paths) or manual | Check changes → package → optional GitHub/Nexus publish → bump version |
| **Check Mod Changes** | Reusable | Detect changes under `Packaged/`, `Source/`, `Images/`, `Licence/`, `docs/` |
| **Package Mods** | Reusable | Fetch SN2-DF, build paks with retoc, zip content mods |
| **Publish GitHub Release** | Reusable | Create GitHub release with mod zip assets |
| **Bump Mod Version** | Reusable | Commit next `ci/MOD_VERSION` after GitHub publish |
| **Publish To Nexus** | Manual or via Package And Release | Upload mod zips to Nexus |
| **Publish Wiki** | Push to `docs/**` or manual | Sync `docs/` to GitHub Wiki (uses `WIKI_PUSH_TOKEN` secret) |

## Versioning

Current mod version: `ci/MOD_VERSION` (e.g. `2.1`). Git tags follow `v2.0`, etc.

## Release zips

Packaging produces:

- `RealisticCraft.zip`
- `RealisticCraft_Plus.zip`
- `RealisticStorage.zip`
- `RealisticScans.zip`

`SN2-DF.zip` is fetched as a build dependency and bundled internally; it is not a separate GitHub/Nexus release from this repo.

## Manual Package And Release

Checkboxes on manual dispatch:

- `publish_github` (default on)
- `publish_nexus` (default off)
- `nexus_version_override`
- `nexus_upload_description` — changelog / file description override
- `nexus_file_category` — `main`, `update`, `optional`, `old`, or `miscellaneous`

## Publish To Nexus (standalone)

Run manually after **Package And Release** completes:

| Input | Purpose |
|-------|---------|
| `package_run_id` | Workflow run ID from a package job (required for standalone) |
| `version_override` | Publish under a different Nexus file version |
| `upload_description` | Changelog / file description override |
| `file_category` | Nexus file slot (`main` replaces primary download; `old` archives previous main) |

`publish-nexus.sh` sends `file_category` to the Nexus v3 API as `NEXUS_FILE_CATEGORY`.

## SN2-DF sync

When Subnautica2Mods publishes a new SN2-DF release, `update-realistic-survival.sh` sets the `SN2_DF_RELEASE` repository variable and dispatches **Package And Release** with `force_publish=true`.

## Secrets

| Secret | Used for |
|--------|----------|
| `GITHUB_TOKEN` | Releases, wiki publish |
| `NEXUS_API_KEY` | Nexus uploads |
| `NEXUS_MOD_ID` | Target mod page |
