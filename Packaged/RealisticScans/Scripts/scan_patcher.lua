local ScanPatcher = {}

local patched = {}
local patchedAddrs = {}
local originals = {}

local function log(config, msg)
    if config and config.debug then
        print("[RealisticScans] " .. msg .. "\n")
    end
end

local function getAddr(obj)
    if not obj then
        return nil
    end
    local ok, addr = pcall(function()
        return obj:GetAddress()
    end)
    return ok and addr or nil
end

local function getObjectKey(scanData)
    if not scanData or not scanData:IsValid() then
        return nil
    end
    local ok, fullName = pcall(function()
        return scanData:GetFullName()
    end)
    if ok and fullName then
        return fullName
    end
    return tostring(scanData)
end

function ScanPatcher.extractId(scanData)
    if not scanData or not scanData:IsValid() then
        return nil
    end

    local ok, name = pcall(function()
        return scanData:GetName()
    end)
    if ok and name then
        local id = name:match("^DA_(.+)_ScanData%d*$")
        if id then
            return id
        end
        return name
    end
    return nil
end

function ScanPatcher.extractAssetPath(scanData)
    if not scanData or not scanData:IsValid() then
        return nil
    end
    local ok, fullName = pcall(function()
        return scanData:GetFullName()
    end)
    if not ok or not fullName then
        return nil
    end
    local path = fullName:match("(/Game/[^%s]+)")
    return path
end

local function storeOriginal(scanData, key)
    if originals[key] then
        return originals[key]
    end
    originals[key] = {
        ScanDuration = scanData.ScanDuration,
        NumRequired = scanData.NumRequired,
    }
    return originals[key]
end

local function resolveOverride(config, scanData)
    local assetPath = ScanPatcher.extractAssetPath(scanData)
    if assetPath and config.byAsset[assetPath] then
        return config.byAsset[assetPath]
    end

    local id = ScanPatcher.extractId(scanData)
    if id and config.byId[id] then
        return config.byId[id]
    end

    return nil
end

local function applyValues(scanData, override, original)
    if override.scan_duration then
        scanData.ScanDuration = override.scan_duration
    elseif override.scan_duration_multiplier and original.ScanDuration then
        scanData.ScanDuration = original.ScanDuration * override.scan_duration_multiplier
    end

    if override.num_required then
        scanData.NumRequired = math.floor(override.num_required)
    elseif override.num_required_multiplier and original.NumRequired then
        scanData.NumRequired = math.max(1, math.floor(original.NumRequired * override.num_required_multiplier + 0.5))
    end
end

function ScanPatcher.apply(config, scanData)
    if not scanData or not scanData:IsValid() then
        return false
    end

    local addr = getAddr(scanData)
    if addr and patchedAddrs[addr] then
        return false
    end

    local override = resolveOverride(config, scanData)
    if not override then
        return false
    end

    local key = getObjectKey(scanData)
    if not key then
        return false
    end

    local original = storeOriginal(scanData, key)
    applyValues(scanData, override, original)
    patched[key] = true
    if addr then
        patchedAddrs[addr] = true
    end

    log(config, string.format(
        "Patched %s -> duration=%.2f, required=%d",
        ScanPatcher.extractId(scanData) or key,
        scanData.ScanDuration,
        scanData.NumRequired
    ))
    return true
end

function ScanPatcher.patchFromAssets(config)
    local count = 0
    for assetPath, _ in pairs(config.byAsset) do
        local scanData = StaticFindObject(assetPath)
        if scanData and scanData:IsValid() then
            if ScanPatcher.apply(config, scanData) then
                count = count + 1
            end
        end
    end
    return count
end

function ScanPatcher.patchAll(config)
    local count = ScanPatcher.patchFromAssets(config)

    local assets = FindAllOf("UWEScanData") or {}
    for _, scanData in ipairs(assets) do
        if ScanPatcher.apply(config, scanData) then
            count = count + 1
        end
    end
    return count
end

function ScanPatcher.isPatched(scanData)
    local addr = getAddr(scanData)
    return addr ~= nil and patchedAddrs[addr] == true
end

return ScanPatcher
