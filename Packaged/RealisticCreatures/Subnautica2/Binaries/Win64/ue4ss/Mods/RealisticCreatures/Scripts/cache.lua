-- Centralized cache for expensive UE4SS calls.

local M = {}

local nameByAddr = {}

function M.getName(actor, addr)
    if addr == nil then return nil end
    if nameByAddr[addr] then return nameByAddr[addr] end
    local ok, name = pcall(function() return actor:GetFullName() end)
    if ok and name then nameByAddr[addr] = name end
    return ok and name or nil
end

function M.purgeName(addr)
    nameByAddr[addr] = nil
end

local locByAddr = {}

function M.getLocation(actor, addr)
    if addr == nil then return nil end
    if locByAddr[addr] then return locByAddr[addr] end
    local ok, loc = pcall(function() return actor:K2_GetActorLocation() end)
    if ok and loc then locByAddr[addr] = loc end
    return ok and loc or nil
end

function M.clearLocations()
    locByAddr = {}
end

local ctrlByAddr = {}
local ctrlExpiry = {}
local CTRL_TTL = 10.0

function M.getController(actor, addr)
    if addr == nil then return nil end
    local now = os.clock()
    local cached = ctrlByAddr[addr]
    if cached ~= nil and ctrlExpiry[addr] > now then
        if cached == false then return nil end
        if cached.IsValid ~= nil and cached:IsValid() then return cached end
    end
    local ok, ctrl = pcall(function() return actor:GetController() end)
    local valid = ok and ctrl ~= nil and ctrl.IsValid ~= nil and ctrl:IsValid()
    ctrlByAddr[addr] = valid and ctrl or false
    ctrlExpiry[addr] = now + CTRL_TTL
    return valid and ctrl or nil
end

function M.purgeController(addr)
    ctrlByAddr[addr] = nil
    ctrlExpiry[addr] = nil
end

local cachedSmall = {}
local cachedLarge = {}
local lastScanClock = -999
local SCAN_TTL = 3.0

function M.getCreatureActors(ttlOverride)
    local now = os.clock()
    local ttl = ttlOverride or SCAN_TTL

    if now - lastScanClock >= ttl then
        cachedSmall = FindAllOf("UWEAISmallFish") or {}
        cachedLarge = FindAllOf("UWEAILargeFish") or {}
        lastScanClock = now
    else
        local function filterValid(list)
            local out = {}
            for _, a in ipairs(list) do
                if a ~= nil and a.IsValid ~= nil and a:IsValid() then
                    out[#out + 1] = a
                end
            end
            return out
        end
        cachedSmall = filterValid(cachedSmall)
        cachedLarge = filterValid(cachedLarge)
    end

    return cachedSmall, cachedLarge
end

function M.invalidateCreatureCache()
    lastScanClock = -999
end

local UEHelpers = require("UEHelpers")

local function getPlayerLoc()
    local pc = UEHelpers.GetPlayerController()
    if pc == nil or pc.IsValid == nil or not pc:IsValid() then return nil end
    local ok, loc = pcall(function() return pc.Pawn:K2_GetActorLocation() end)
    return ok and loc or nil
end

local function dist3D(a, b)
    if a == nil or b == nil then return math.huge end
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function M.buildTickSnapshot(maxRadius, maxCount)
    M.clearLocations()

    local playerLoc = getPlayerLoc()
    local small, large = M.getCreatureActors()
    local snapshot = {}

    local function tryAdd(actor)
        if #snapshot >= maxCount then return end
        if actor == nil or actor.IsValid == nil or not actor:IsValid() then return end

        local ok, addr = pcall(function() return actor:GetAddress() end)
        if not ok or addr == nil then return end

        local ok2, loc = pcall(function() return actor:K2_GetActorLocation() end)
        if not ok2 or loc == nil then return end
        locByAddr[addr] = loc

        if playerLoc ~= nil and dist3D(loc, playerLoc) > maxRadius then return end

        local name = nameByAddr[addr]
        if name == nil then
            local ok3, n = pcall(function() return actor:GetFullName() end)
            if not ok3 or n == nil then return end
            name = n
            nameByAddr[addr] = name
        end

        snapshot[#snapshot + 1] = {
            actor = actor,
            addr = addr,
            name = name,
            lower = name:lower(),
            loc = loc,
        }
    end

    for _, a in ipairs(small) do tryAdd(a) end
    for _, a in ipairs(large) do tryAdd(a) end

    return snapshot, playerLoc
end

return M
