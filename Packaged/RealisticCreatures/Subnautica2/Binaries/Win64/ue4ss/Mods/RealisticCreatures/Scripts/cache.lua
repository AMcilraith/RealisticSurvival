-- Centralized cache for expensive UE4SS calls.

local config = require("config")
local utils = require("utils")

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

local function scanTtl()
    return config.creatureScanTtlSeconds or 5.0
end

function M.getCreatureActors()
    local now = os.clock()

    if now - lastScanClock >= scanTtl() then
        cachedSmall = FindAllOf("UWEAISmallFish") or {}
        cachedLarge = FindAllOf("UWEAILargeFish") or {}
        lastScanClock = now
    end

    return cachedSmall, cachedLarge
end

function M.invalidateCreatureCache()
    lastScanClock = -999
end

local UEHelpers = require("UEHelpers")

local function getPlayerLoc()
    local pc = UEHelpers.GetPlayerController()
    local pawn = utils.getPlayerPawn(pc)
    if not utils.isValid(pawn) then return nil end
    local ok, loc = pcall(function() return pawn:K2_GetActorLocation() end)
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
    local maxRadiusSq = maxRadius ~= nil and (maxRadius * maxRadius) or nil

    local function tryAdd(actor)
        if #snapshot >= maxCount then return end
        if not utils.isValid(actor) then return end

        local addr = utils.getAddress(actor)
        if addr == nil then return end

        local loc = M.getLocation(actor, addr)
        if loc == nil then return end

        if playerLoc ~= nil and maxRadiusSq ~= nil then
            local dx = loc.X - playerLoc.X
            local dy = loc.Y - playerLoc.Y
            local dz = loc.Z - playerLoc.Z
            if (dx * dx + dy * dy + dz * dz) > maxRadiusSq then return end
        end

        local name = nameByAddr[addr]
        if name == nil then
            name = M.getName(actor, addr)
            if name == nil then return end
        end

        snapshot[#snapshot + 1] = {
            actor = actor,
            addr = addr,
            name = name,
            lower = name:lower(),
            loc = loc,
        }
    end

    for _, a in ipairs(small) do
        if #snapshot >= maxCount then break end
        tryAdd(a)
    end
    for _, a in ipairs(large) do
        if #snapshot >= maxCount then break end
        tryAdd(a)
    end

    return snapshot, playerLoc
end

return M
