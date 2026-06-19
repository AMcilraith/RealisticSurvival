local config = require("config")
local combat = require("combat")
local creatures = require("creatures")
local food_chain = require("food_chain")
local utils = require("utils")

local M = {}

local pendingPreyByAddr = {}
local slugGatheredAtByAddr = {}
local lastFloraRatio = 1.0
local lastCreaturePreyBlocked = false

math.randomseed(os.time())

function M.setFloraRatio(ratio)
    lastFloraRatio = ratio or 1.0
end

function M.setCreaturePreyRespawnBlocked(blocked)
    lastCreaturePreyBlocked = blocked == true
end

function M.isPending(addr)
    return addr ~= nil and pendingPreyByAddr[addr] ~= nil
end

local function canRespawnCreaturePrey()
    if config.preyRespawnEnabled == false then return false end
    return not lastCreaturePreyBlocked
end

local function slugRespawnCooldownSeconds()
    local base = config.slugRespawnSeconds or 300
    local ratio = lastFloraRatio or 1.0
    local low = config.floraLowRatio or 0.30
    if ratio >= low then return base end

    local t = 1.0 - (ratio / low)
    local maxMult = config.slugFloraSlowMaxMultiplier or 5.0
    return math.floor(base * (1.0 + (t * (maxMult - 1.0))))
end

local function stopCreature(actor)
    local controller = nil
    if utils.safeGet(actor, "GetController") ~= nil then
        local ok, value = pcall(function() return actor:GetController() end)
        if ok then controller = value end
    end

    utils.callIfPresent(controller, "StopMovement")
    local brain = utils.safeGet(controller, "BrainComponent")
    utils.callIfPresent(brain, "StopLogic", "RealisticCreatures respawn")
    utils.callIfPresent(controller, "UnPossess")

    local movement = utils.safeGet(actor, "MovementComponent") or utils.safeGet(actor, "CharacterMovement")
    utils.callIfPresent(movement, "StopMovementImmediately")
    utils.callIfPresent(movement, "StopActiveMovement")
    utils.callIfPresent(actor, "SetCanBeDamaged", false)
    utils.callIfPresent(actor, "SetActorEnableCollision", false)
end

local function hideActor(actor)
    utils.callIfPresent(actor, "SetActorHiddenInGame", true)
    utils.callIfPresent(actor, "SetActorTickEnabled", false)
end

local function showActor(actor)
    utils.callIfPresent(actor, "SetActorHiddenInGame", false)
    utils.callIfPresent(actor, "SetActorTickEnabled", true)
    utils.callIfPresent(actor, "SetCanBeDamaged", true)
    utils.callIfPresent(actor, "SetActorEnableCollision", true)
end

local function restorePreyHealth(actor, addr, fullName)
    combat.purgeAddress(addr)
    local settings = creatures.getCreatureSettings(actor, fullName)
    combat.setHealth(actor, addr, settings.health)

    local healthComponent = creatures.getHealthComponent(actor)
    if healthComponent ~= nil then
        utils.callIfPresent(healthComponent, "RestoreHealth")
        utils.callIfPresent(healthComponent, "SetHealth", settings.health)
    end
end

local function respawnPrey(entry)
    local actor = entry.actor
    if not utils.isValid(actor) then
        pendingPreyByAddr[entry.addr] = nil
        return
    end

    showActor(actor)
    restorePreyHealth(actor, entry.addr, entry.fullName)
    pendingPreyByAddr[entry.addr] = nil

    if config.logEnabled then
        print(string.format("[RealisticCreatures] prey respawned %s\n", entry.fullName))
    end
end

function M.tryHandlePreyDeath(victim, addr, fullName)
    if not food_chain.isCreaturePrey(fullName) then return false end
    if not canRespawnCreaturePrey() then return false end
    if not utils.isValid(victim) or addr == nil then return false end

    stopCreature(victim)
    hideActor(victim)

    pendingPreyByAddr[addr] = {
        actor = victim,
        addr = addr,
        fullName = fullName,
        diedAt = os.time(),
    }

    if config.logEnabled then
        print(string.format("[RealisticCreatures] prey queued for respawn %s\n", fullName))
    end

    return true
end

local function isWaterSlug(actor)
    return food_chain.isSlug(utils.getFullName(actor))
end

local function newSlugGuid(actor)
    pcall(function()
        local guid = actor.ResourceId
        guid.A = math.random(-2147483648, 2147483647)
        guid.B = math.random(-2147483648, 2147483647)
        guid.C = math.random(-2147483648, 2147483647)
        guid.D = math.random(-2147483648, 2147483647)
    end)
end

local function bringBackSlug(actor)
    newSlugGuid(actor)
    pcall(function() actor.bHasBeenGathered = false end)
    utils.callIfPresent(actor, "OnRep_HasBeenGathered")
    utils.callIfPresent(actor, "OnHasBeenGathered")
    utils.callIfPresent(actor, "ShowSkeletalMesh")
end

function M.tick()
    if config.slugRespawnEnabled == false and config.preyRespawnEnabled == false then
        return
    end

    local now = os.time()
    local preyCooldown = config.preyRespawnSeconds or 300

    for addr, entry in pairs(pendingPreyByAddr) do
        if not utils.isValid(entry.actor) then
            pendingPreyByAddr[addr] = nil
        elseif canRespawnCreaturePrey() and now - entry.diedAt >= preyCooldown then
            respawnPrey(entry)
        end
    end

    if config.slugRespawnEnabled == false then return end

    local slugCooldown = slugRespawnCooldownSeconds()
    for _, actor in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
        if utils.isValid(actor) and isWaterSlug(actor) then
            local addr = tostring(actor:GetAddress())
            local gathered = utils.safeGet(actor, "bHasBeenGathered")

            if gathered == true then
                local diedAt = slugGatheredAtByAddr[addr]
                if diedAt == nil then
                    slugGatheredAtByAddr[addr] = now
                elseif now - diedAt >= slugCooldown then
                    bringBackSlug(actor)
                    slugGatheredAtByAddr[addr] = nil
                    if config.logEnabled then
                        print(string.format(
                            "[RealisticCreatures] water slug respawned (cooldown=%ds flora=%.2f)\n",
                            slugCooldown,
                            lastFloraRatio
                        ))
                    end
                end
            elseif gathered == false then
                slugGatheredAtByAddr[addr] = nil
            end
        end
    end
end

return M
