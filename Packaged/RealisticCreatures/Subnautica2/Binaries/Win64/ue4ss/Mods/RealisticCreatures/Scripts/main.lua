local config = require("config")
local cache = require("cache")
local cascade = require("cascade")
local combat = require("combat")
local creatures = require("creatures")
local ecosystem = require("ecosystem")
local flora = require("flora")
local respawn = require("respawn")
local utils = require("utils")
local vehicles = require("vehicles")

local MOD = "[RealisticCreatures]"

local function log(message)
    if config.logEnabled then
        print(string.format("%s %s\n", MOD, message))
    end
end

local function tryHook(functionName, callback)
    local ok = pcall(RegisterHook, functionName, callback)
    if ok then log("hooked " .. functionName) else log("failed to hook " .. functionName) end
    return ok
end

local function getPlayerVehicleLocation()
    local UEHelpers = require("UEHelpers")
    local pc = UEHelpers.GetPlayerController()
    if not utils.isValid(pc) or not utils.isValid(pc.Pawn) then return nil end

    local pawnName = utils.getFullName(pc.Pawn):lower()
    if pawnName:find("tadpole", 1, true) or pawnName:find("seatruck", 1, true) or
        pawnName:find("seamoth", 1, true) or pawnName:find("cyclops", 1, true) or
        pawnName:find("submarine", 1, true) then
        local ok, loc = pcall(function() return pc.Pawn:K2_GetActorLocation() end)
        return ok and loc or nil
    end
    return nil
end

local function getNearestBaseLocation(playerLoc)
    if playerLoc == nil then return nil end
    local best, bestDist = nil, math.huge
    for _, base in ipairs(FindAllOf("SN2Base") or {}) do
        if utils.isValid(base) then
            local ok, loc = pcall(function() return base:K2_GetActorLocation() end)
            if ok and loc ~= nil then
                local dist = utils.dist3D(playerLoc, loc)
                if dist < bestDist then bestDist = dist; best = loc end
            end
        end
    end
    return best
end

local function runAiTick()
    local snapshot, playerLoc = cache.buildTickSnapshot(config.maxDetectionRadius, config.maxActiveCreatures)
    if #snapshot == 0 then return end
    ecosystem.tickAi(snapshot, playerLoc, getPlayerVehicleLocation(), getNearestBaseLocation(playerLoc))
end

local function runPopulationTick()
    local snapshot = cache.buildTickSnapshot(config.maxDetectionRadius * 2, 9999)
    ecosystem.tickPopulation(snapshot)
    flora.tickPopulation()

    local floraRatio = flora.getFloraPopulationRatio()
    local creaturePreyRatio = ecosystem.getCreaturePreyPopulationRatio()
    local totalPreyRatio = ecosystem.getPreyPopulationRatio()
    local cascadeState = cascade.tick(floraRatio, creaturePreyRatio, totalPreyRatio)

    respawn.setFloraRatio(floraRatio)
    respawn.setCreaturePreyRespawnBlocked(cascadeState.blockFloraRegrowth)
    if config.floraEnabled ~= false then
        flora.applyGrowthMultiplier(cascadeState.floraGrowthMultiplier)
    end
end

_G.RealisticCreatures = _G.RealisticCreatures or {}
_G.RealisticCreatures.NotifyCreatureKilled = function(victim, killer, reason)
    if not utils.isValid(victim) then return end
    local addr = utils.getAddress(victim)
    if addr == nil or combat.isDead(addr) then return end
    combat.killCreature(victim, killer, reason or "external")
end
_G.CustomLogic = _G.RealisticCreatures

combat.registerOnDeath(function(victim, killer, reason)
    ecosystem.onCreatureKilled(victim, killer, reason)
end)

log("loaded")

-- Do NOT hook native Kill/OnDied: they fire during creature spawn and cause mass death at load.

tryHook("/Script/Subnautica2.SN2CollisionDamageComponent:OnCollisionImpact", function(context, otherComponent, payload, hit)
    pcall(function() vehicles.onCollisionImpact(context, otherComponent, payload, hit) end)
end)

combat.installPlayerHooks()

LoopInGameThreadWithDelay(config.aiTickMs or 500, function() pcall(runAiTick) end)

LoopInGameThreadWithDelay(config.slugCheckIntervalMs or 30000, function()
    pcall(function()
        flora.tickPopulation()
        respawn.setFloraRatio(flora.getFloraPopulationRatio())
        respawn.setCreaturePreyRespawnBlocked(cascade.getState().blockFloraRegrowth)
        respawn.tick()
    end)
end)

LoopInGameThreadWithDelay(config.populationTickMs or 300000, function() pcall(runPopulationTick) end)

ExecuteInGameThreadWithDelay(config.ecosystemGracePeriodMs or 60000, function() pcall(runPopulationTick) end)

log("reactive ecosystem active")
