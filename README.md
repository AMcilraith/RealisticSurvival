# Realistic Survival

**Download the latest version of the mod (0.6 or higher) if your game client is crashing after Hotfix 0.3!**

---

**If you have any ideas for improving and supplementing the mod, please let me know. I will definitely try to make it a reality!**

---

## License

**Realistic Survival** mod content is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (see [LICENSE](LICENSE)).

The **SN2-DF** data loader shipped with this pack is licensed under **GPL-3.0** (see `Licence/license/SN2-DF_LICENSE` and third-party notices `LICENSE_SDF`, `LICENSE_tomlplusplus` in the same folder).

## About Realistic Survival

Developed by TerryTie and addi-4th.

Some time ago, I made the [Realistic Craft 2.0](https://www.nexusmods.com/subnautica/mods/767) mod for Subnautica 1, focused on more realistic and varied crafting.

After finishing the second game, I got the desire to create a similar mod for Subnautica 2. Unfortunately, at the moment, a lot of the flora in the game cannot be harvested, even though it can be scanned.

I started a new playthrough and have been gradually changing recipes as I progress through the game story, following these principles:

- More diverse crafting, making greater use of rarely used resources.
- More challenging survival, but without making it tedious. I'm trying to maintain a good balance. In the original game, gathering and crafting take up only a small portion of the total playtime. I want to shift those proportions a bit so players have more motivation to explore the hidden corners of the planet.
- More realistic item crafting, as much as possible. The crafting logic is preserved across similar types of items.

---

## Development plans

The mod will consist of several packages. You will be able to choose which ones to enable for your survival experience:

1. **Realistic Craft.** This is the core of the mod. It will completely overhaul crafting recipes. Only base-building blueprints will remain unchanged.
2. **Realistic Craft Plus.** Currently in Beta as an optional add-on module. This has been converted to an add-on, which adds additional recipes and items to the game, such as new oxygen items, ingot-to-metal recipes, and more!
3. **Realistic Scan.** Currently in Alpha as an optional add-on module. Adjusts scan times and quantities to be more realistic and based on number of items in the world, as well as size and complexity of the object or lifeform.
4. **Realistic Storage.** Currently in Beta as an optional add-on module. Increases Hotbar slots at game start, but decreases inventory. Storage is massively increased, along with biobeds granting x5 inventory slots instead of just x3.

Hopefully this list will continue to grow over time for a more comprehensive overhaul of the game.

If there are any developers who like the concept of my mod and are interested in further developing it or contributing new survival elements to Subnautica 2, I would be happy to collaborate in any way.

I have no experience in modding or working with 3D software, but I have plenty of ideas and motivation.

I would also really like to see the ability to harvest flora that currently can only be scanned, and use it in crafting. This would make the mod even more interesting and engaging.

---

## Main features of Realistic Craft

You can view most of the recipes in the Media section. Below, I will describe only the most significant crafting changes.

### Changes in Material crafting

- Salvaged Titanium now gives 6 Titanium.
- Wiring (Copper, Silver, Gold) now requires actual metal and Fiber, Rubber, Fiber Mesh as insulation/braiding.
- Fiber now requires Acidic Raion Pouch and Rubber requires Mild Acid.
- Mild Acid now requires Pent instead of Acidic Raion.
- Strong Acid now additionally requires Lead.
- Basic Battery now additionally requires Pent. Power Cell needs Lead.
- Chips now require Coral Shavings.
- Enameled Glass now requires Celestine instead of Glass.

### Changes in Personal Tools crafting

- All items require Titanium for the casing and Rubber for grip handling.
- Electrical tools require Copper Wire.
- If the tool has moving parts, Grease is also required.
- For buoyant tools, the Water Slug fish has been added. Its air bladder is used for storing air inside the tool.

### Changes in Builder crafting

- All electrical machines require a Chip (except the Fabricator) and Wiring.
- Crafting machines require Sulfur, Coral Shavings, and Quartz to power their laser during crafting.
- All machines require Titanium for their casing, with the amount depending on the size of the structure. If the model includes glass, Glass is also required for crafting.
- If the machine has moving parts, Grease is also required.

### Changes in Modification Station

- Modification Station and all clever modules now require Dedicated Core and Wiring Kit.
- Modules for tools now require Dedicated Core and Wiring Kit too.

### Changes in Food crafting

- All Food crafting recipes and their stats have been completely reworked to encourage crafting proper meals instead of surviving only on cooked fish.
- Prepared meals now provide both Food and Water in different proportions. The meal recipes have been designed to be as varied as possible.

### Changes in Base building

- All light fixtures require Quartz instead of Copper.
- Chairs now require Rubber, Tables require Glass, Signs use Quartz instead of Copper, and Posters now require 1 Lead. Other recipes have also received small adjustments to the amount of basic crafting ingredients.
- All other base crafting remains as default, as intended by the developers. There is no need to complicate these recipes or make them expensive. Build large and creative bases in terms of size and structure, just like in the original game, without having to worry too much about resources.

---

## Installation instructions

Unpack and drop all files into the `/Subnautica2` folder. That should be it, as long as the requirements are installed.

---

## GitHub Actions (CI)

CI is workflow-only (bash steps on `windows-latest`; no PowerShell in pipelines).

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Package And Release** | Push to `main`/`master` (mod content paths) or manual | Check changes → package mods → GitHub release → bump `ci/MOD_VERSION` |
| **Check Mod Changes** | Reusable | Detect changes under `Packaged/`, `Source/`, `Images/`, `Licence/` |
| **Package Mods** | Reusable | Fetch SN2-DF, build paks with retoc, zip content mods |
| **Publish GitHub Release** | Reusable | Create GitHub release with mod zip assets |
| **Bump Mod Version** | Reusable | Commit next `ci/MOD_VERSION` after a successful GitHub release |
| **Publish To Nexus** | **Manual only** (`workflow_dispatch`) | Upload mod zips to Nexus; requires `package_run_id` from a **Package And Release** run. Version comes from `version_override`, `release_version`, or `ci/MOD_VERSION` (first non-empty wins). |

Nexus upload never runs on push. After **Package And Release** completes, run **Publish To Nexus** manually with the workflow run ID. Leave version fields empty to use `ci/MOD_VERSION`, or set `version_override` to publish under a different Nexus file version without repackaging.

---

## Requirements

[UE4SS](https://www.nexusmods.com/subnautica2/mods/36) for Subnautica 2 is required for all included mods.

---

## Basic tips for new players

### Where to find first Pent for crafting Mild Acid and Lucifer Rotsac for Rubber

Swim from Lifepod exactly 100 meters North, and you'll find blue flora below you. That is Pent.

The yellow spheres are Lucifer Rotsac.

![](https://files.catbox.moe/9x6dxm.jpg)
![](https://files.catbox.moe/qjs1o1.jpg)

### Where to find first Copper for crafting Mild Acid

Beneath the Lifepod there is a cave, where you will find Copper.

![](https://files.catbox.moe/3wkqkk.jpg)
![](https://files.catbox.moe/gwqayz.jpg)

### Where to find first Silver

Swim 230 meters North from the Lifepod, and you will find Silver on the slope.

![](https://files.catbox.moe/rdi3l8.jpg)

### Good starter cave with Copper and Silver

Swim 130 meters North from the Lifepod to entrance. The cave is large, and inside you will find plenty of Copper and Silver. There are also several places where you can surface for air.

![](https://files.catbox.moe/wwrabf.jpg)

### Where to find first Sulfur

Swim 230 meters South East from the Lifepod.

![](https://files.catbox.moe/0lszgl.jpg)
![](https://files.catbox.moe/8zp9my.jpg)

---

## Shout outs

Since I have almost no experience in modding, [marksmango](https://www.nexusmods.com/profile/marksmango) really helped me a lot with advice in the early stages. A very responsive and great person!

Huge thanks to [addi-4th](https://www.nexusmods.com/profile/addi4th) for taking the initiative to rewrite the descriptions for the modified crafting recipes. They came up with and implemented great item descriptions and also created two new icons for the advanced water variants. They've also been helping maintain the mod in my absence, while I am attending to personal matters. Very creative person!

Thanks to [Limo](https://www.nexusmods.com/profile/LimoDerEchte) on the SN2 Modding Discord for working to create some of the amazing item frameworks we now use!
