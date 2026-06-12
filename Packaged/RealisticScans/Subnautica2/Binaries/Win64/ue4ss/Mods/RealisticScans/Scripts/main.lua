local Config = require("config")
local ScanPatcher = require("scan_patcher")
local ScanHooks = require("scan_hooks")

local config = Config.load()

ScanHooks.install(config, ScanPatcher)

local overrideCount = 0
for _ in pairs(config.byId) do
    overrideCount = overrideCount + 1
end

local initialCount = ScanPatcher.patchAll(config)
print(string.format(
    "[RealisticScans] Initial patch pass applied %d scan data asset(s) from %d configured override(s).\n",
    initialCount,
    overrideCount))

-- Catch scan data assets that load after mod startup.
local warmupPasses = 0
LoopAsync(5000, function()
    warmupPasses = warmupPasses + 1
    ScanPatcher.patchAll(config)
    return warmupPasses >= 6
end)
