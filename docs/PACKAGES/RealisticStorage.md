# RealisticStorage

**Status:** Beta optional add-on

RealisticStorage changes hotbar size, player inventory capacity, and storage container grid sizes via UE4SS Lua scripts. It does **not** use SN2-DF TOML.

## Design goals

- Larger hotbar at game start
- Smaller base inventory (expanded through upgrades)
- Much larger locker and cache capacity
- Inventory upgrades scale with game progression (BioBed / upgrade tracker tiers)

## Tuning constants

Edit Lua files under `Packaged/RealisticStorage/.../Scripts/` before packaging.

### Hotbar (`Hotbar.lua`)

| Constant | Value | Effect |
|----------|-------|--------|
| `HOTBAR_START` | 5 | Starting hotbar slots |
| `HOTBAR_MAX` | 7 | Maximum hotbar slots |
| `HOTBAR_INC` | 1 | Slots gained per upgrade tier |
| `HOTBAR_UPG_MAX` | 3 | Maximum upgrade tiers tracked |

### Player inventory (`PlayerInventory.lua`)

| Constant | Value | Effect |
|----------|-------|--------|
| `INV_START` | 15 | Starting inventory slots |
| `INV_MAX` | 35 | Maximum inventory slots |
| `INV_INC` | 5 | Slots gained per upgrade tier |
| `INV_UPG_MAX` | 4 | Maximum upgrade tiers tracked |

Inventory expansion follows the game's `UWEEventTracker` upgrade tiers (BioBed and related progression).

### Storage containers (`main.lua` → `STORAGE_MAPPING`)

| Container | Rows × Cols | Slots |
|-----------|-------------|-------|
| Floor locker | 9 × 5 | 45 |
| Wall locker | 7 × 5 | 35 |
| Storage cache | 8 × 5 | 40 |
| Tailing chest | 6 × 5 | 30 |
| Floating locker (carryable) | 5 × 5 | 25 |
| Heavy floating locker | 6 × 5 | 30 |
| Super-heavy floating locker | 7 × 5 | 35 |
| Haul Tadpole chassis | 10 × 5 | 50 |
| Bioreactor | 2 × 5 | 10 |

### Processor station (`STATION_MAPPING`)

| Station | Rows × Cols | Slots |
|---------|-------------|-------|
| Processor station (input/output) | 4 × 5 | 20 each |

## Enable

Install `RealisticStorage.zip` and enable `RealisticStorage` in `mods.txt`. No SN2-DF `SDF/` folder is required for this mod, but SN2-DF content mods can run alongside it.

## Pending: biomod slot expansion

Integration of passive biomod slot scaling (from ExtraPassiveBiomodSlots) is planned. See [Pending Updates](PENDING-UPDATES).
