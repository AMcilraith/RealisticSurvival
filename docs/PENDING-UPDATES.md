# Pending Documentation Updates

This checklist tracks documentation that should be refreshed when parallel development work lands. After each item is implemented, update the listed pages, check the box, commit, and let **Publish Wiki** sync to GitHub.

## Open items

- [ ] **ExtraPassiveBiomodSlots → RealisticStorage** — Integrate passive biomod slot expansion tied to creature bioscans; SN2-DF support for unpublished biomod discovery.
  - Update: `PACKAGES/RealisticStorage.md`, `OVERVIEW.md`
  - SN2-DF side (if applicable): `TOML_REFERENCE`, `ARCHITECTURE` on Subnautica2Mods wiki

- [ ] **Category archive script** — Script to archive old category TOMLs after publishing a new version; hook into release workflow.
  - Update: `DEVELOPER.md`, `CI-AND-RELEASES.md`

## Completed

- [x] **Nexus changelog + file_category** — `upload_description` and `file_category` on Publish To Nexus workflow.
  - Documented in: `CI-AND-RELEASES.md`

- [x] **Contributor list cleanup** — No documentation changes required.

## Process

1. Implement the feature in code/CI.
2. Update the wiki source files under `docs/`.
3. Check off the item on this page.
4. Push to `main`/`master` (triggers wiki publish) or run **Publish Wiki** manually.
