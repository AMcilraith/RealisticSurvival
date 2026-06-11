local TomlParser = require("tomlparser")

local Config = {}

local MOD_ROOT = (debug.getinfo(1, "S").source:match("@(.+[\\/])") or ""):gsub("Scripts[\\/]$", "")
local BLUEPRINTS_DIR = MOD_ROOT:gsub("/", "\\") .. "Blueprints"

local KNOWN_FILES = {
    "_defaults.toml",
    "Basebuilding.toml",
    "Basebuilding_Axum.toml",
    "Basebuilding_Posters.toml",
    "Fauna.toml",
    "Flora.toml",
    "Resources.toml",
    "Ruins.toml",
    "Story.toml",
    "Tools.toml",
    "Vehicles.toml",
    "Wrecks.toml",
}

local function log(msg)
    print("[RealisticScans] " .. msg .. "\n")
end

local function normalizePath(path)
    return path:gsub("/", "\\")
end

local function listTomlFiles(dir)
    local files = {}
    local seen = {}

    local handle = io.popen('dir /b /s "' .. dir .. '\\*.toml" 2>nul')
    if handle then
        for path in handle:lines() do
            local normalized = normalizePath(path)
            if not seen[normalized] then
                seen[normalized] = true
                table.insert(files, normalized)
            end
        end
        handle:close()
    end

    if #files == 0 then
        for _, name in ipairs(KNOWN_FILES) do
            local path = normalizePath(dir .. "\\" .. name)
            local file = io.open(path, "r")
            if file then
                file:close()
                if not seen[path] then
                    seen[path] = true
                    table.insert(files, path)
                end
            end
        end
    end

    table.sort(files)
    return files
end

local function mergeOverride(target, source)
    for k, v in pairs(source) do
        target[k] = v
    end
end

local function addOverride(overridesById, overridesByAsset, entry, defaults)
    if not entry or not entry.id then
        return false
    end

    local id = entry.id
    local merged = overridesById[id] or {}
    mergeOverride(merged, defaults or {})
    mergeOverride(merged, entry)
    overridesById[id] = merged

    if merged.asset and merged.asset ~= "" then
        overridesByAsset[merged.asset] = merged
    end

    return true
end

function Config.load()
    local defaults = { debug = false }
    local overridesById = {}
    local overridesByAsset = {}

    local files = listTomlFiles(BLUEPRINTS_DIR)
    if #files == 0 then
        log("No blueprint TOML files found in " .. BLUEPRINTS_DIR)
        return {
            defaults = defaults,
            byId = overridesById,
            byAsset = overridesByAsset,
            debug = false,
        }
    end

    local parsedEntries = 0
    local parseErrors = 0

    for _, path in ipairs(files) do
        local file = io.open(path, "r")
        if not file then
            parseErrors = parseErrors + 1
            log("Could not open blueprint file: " .. path)
        else
            local content = file:read("*a")
            file:close()

            local ok, doc = pcall(TomlParser.parse, content)
            if not ok or type(doc) ~= "table" then
                parseErrors = parseErrors + 1
                log("Failed to parse blueprint file: " .. path)
            else
                if doc.defaults then
                    mergeOverride(defaults, doc.defaults)
                end
                if doc.scan_modify then
                    for _, entry in ipairs(doc.scan_modify) do
                        if addOverride(overridesById, overridesByAsset, entry, defaults) then
                            parsedEntries = parsedEntries + 1
                        end
                    end
                end
            end
        end
    end

    local idCount = 0
    for _ in pairs(overridesById) do
        idCount = idCount + 1
    end

    local assetCount = 0
    for _ in pairs(overridesByAsset) do
        assetCount = assetCount + 1
    end

    log(string.format(
        "Parsed %d scan override(s) (%d with asset paths) from %d blueprint file(s).",
        idCount, assetCount, #files))

    if parseErrors > 0 then
        log(string.format("Blueprint parse/open errors: %d", parseErrors))
    end

    return {
        defaults = defaults,
        byId = overridesById,
        byAsset = overridesByAsset,
        debug = defaults.debug == true,
    }
end

return Config
