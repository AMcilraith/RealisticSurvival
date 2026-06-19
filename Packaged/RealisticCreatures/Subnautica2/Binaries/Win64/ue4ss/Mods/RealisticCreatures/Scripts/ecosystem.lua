local config = require("config")
local cache = require("cache")
local cascade = require("cascade")
local combat = require("combat")
local creatures = require("creatures")
local food_chain = require("food_chain")
local utils = require("utils")

local M = {}

local STATE_IDLE = "IDLE"
local STATE_HUNT = "HUNT"
local STATE_FLEE = "FLEE"
local STATE_REST = "REST"

local creatureState = {}
local populationBaseline = {}
local populationCurrent = {}
local preyBaseline = {}
local preyCurrent = {}
local creaturePreyBaseline = {}
local creaturePreyCurrent = {}
local slugPreyBaseline = {}
local slugPreyCurrent = {}

local preyBoostUntil = 0.0
local preyBoostPatterns = {}
local feedingCalmUntilByAddr = {}
local modStartedAt = os.clock()

local function inGracePeriod()
    return (os.clock() - modStartedAt) < ((config.ecosystemGracePeriodMs or 60000) / 1000.0)
end

local function now()
    return os.clock()
end

local function getState(addr)
    if creatureState[addr] == nil then
        creatureState[addr] = {
            mode = STATE_IDLE,
            hunger = math.random(20, 60),
            energy = math.random(60, 100),
            fear = 0.0,
            huntTargetAddr = nil,
            huntStartedAt = 0.0,
            restUntil = 0.0,
            fleeUntil = 0.0,
            calmUntil = 0.0,
        }
    end
    return creatureState[addr]
end

local function findEntryByAddr(snapshot, addr)
    for _, entry in ipairs(snapshot) do
        if entry.addr == addr then return entry end
    end
    return nil
end

local function nearestThreat(selfEntry, snapshot)
    local best = nil
    local bestDist = math.huge

    for _, other in ipairs(snapshot) do
        if other.addr ~= selfEntry.addr and not combat.isDead(other.addr) then
            if food_chain.isPredatorOf(other.name, selfEntry.name) then
                local dist = utils.dist3D(selfEntry.loc, other.loc)
                if dist < bestDist and dist <= config.maxDetectionRadius then
                    bestDist = dist
                    best = other
                end
            end
        end
    end

    return best, bestDist
end

local function nearestPrey(selfEntry, snapshot)
    if not food_chain.isPredator(selfEntry.name) then return nil end
    if now() < (feedingCalmUntilByAddr[selfEntry.addr] or 0.0) then return nil end

    local best = nil
    local bestDist = math.huge

    for _, other in ipairs(snapshot) do
        if other.addr ~= selfEntry.addr and not combat.isDead(other.addr) then
            if food_chain.isPreyOf(other.name, selfEntry.name) then
                local dist = utils.dist3D(selfEntry.loc, other.loc)
                if dist < bestDist and dist <= config.maxDetectionRadius then
                    bestDist = dist
                    best = other
                end
            end
        end
    end

    return best, bestDist
end

local function nudgeToward(actor, fromLoc, toLoc, step)
    if not utils.isValid(actor) or fromLoc == nil or toLoc == nil then return end
    local dx, dy, dz = utils.normalize3D(toLoc.X - fromLoc.X, toLoc.Y - fromLoc.Y, toLoc.Z - fromLoc.Z)
    local newLoc = {
        X = fromLoc.X + dx * step,
        Y = fromLoc.Y + dy * step,
        Z = fromLoc.Z + dz * step,
    }
    pcall(function()
        actor:K2_SetActorLocation(newLoc, false, {}, false)
    end)
end

local function nudgeAway(actor, fromLoc, threatLoc, step)
    if not utils.isValid(actor) or fromLoc == nil or threatLoc == nil then return end
    local dx, dy, dz = utils.normalize3D(fromLoc.X - threatLoc.X, fromLoc.Y - threatLoc.Y, fromLoc.Z - threatLoc.Z)
    local newLoc = {
        X = fromLoc.X + dx * step,
        Y = fromLoc.Y + dy * step,
        Z = fromLoc.Z + dz * step,
    }
    pcall(function()
        actor:K2_SetActorLocation(newLoc, false, {}, false)
    end)
end

local function applyPopulationPressure(entry, speciesKey, ratio)
    if ratio < config.populationLowRatio then
        local state = getState(entry.addr)
        state.hunger = math.max(0.0, state.hunger - 0.5)
    elseif ratio > config.populationHighRatio and cascade.getState().blockFloraRegrowth then
        combat.damageCreature(entry.actor, config.overcrowdDamagePerTick or 1.0, nil, entry.name)
    end
end

local function isPreyBoosted(fullName)
    if now() > preyBoostUntil then return false end
    for _, pattern in ipairs(preyBoostPatterns) do
        if utils.nameMatchesPattern(fullName, pattern) then return true end
    end
    return false
end

function M.onCreatureKilled(victim, killer, reason)
    local victimName = utils.getFullName(victim)
    local speciesKey = creatures.getSpeciesKey(victimName)
    populationCurrent[speciesKey] = math.max(0, (populationCurrent[speciesKey] or 1) - 1)

    if killer ~= nil and utils.isValid(killer) then
        local killerName = utils.getFullName(killer)
        if food_chain.isPredator(killerName) and food_chain.isPreyOf(victimName, killerName) then
            local killerAddr = utils.getAddress(killer)
            if killerAddr ~= nil then
                local state = getState(killerAddr)
                state.hunger = math.max(0.0, state.hunger - 40.0)
                state.energy = math.min(100.0, state.energy + 15.0)
                state.mode = STATE_IDLE
                state.huntTargetAddr = nil
            end
        end
    end

    if reason == "player" and food_chain.isPredator(victimName) then
        preyBoostUntil = now() + (config.predatorKillBoostSeconds or 600)
        preyBoostPatterns = {}
        for _, chain in ipairs(config.foodChain or {}) do
            if utils.nameMatchesPattern(victimName, chain.predator) then
                for _, preyPattern in ipairs(chain.prey or {}) do
                    if not food_chain.isSlugPattern(preyPattern) then
                        preyBoostPatterns[#preyBoostPatterns + 1] = preyPattern
                    end
                end
                break
            end
        end
        if config.logEnabled then
            print(string.format("[RealisticCreatures] predator killed by player, prey boost active for %ds\n",
                config.predatorKillBoostSeconds or 600))
        end
    end
end

function M.onPlayerFedCreature(actor)
    local addr = utils.getAddress(actor)
    if addr == nil then return end
    local state = getState(addr)
    state.hunger = math.max(0.0, state.hunger - (config.feedingHungerReduction or 50.0))
    state.fear = math.max(0.0, state.fear - 20.0)
    feedingCalmUntilByAddr[addr] = now() + (config.feedingCalmSeconds or 300)
    state.calmUntil = feedingCalmUntilByAddr[addr]
end

function M.onVehicleNearby(entry)
    local state = getState(entry.addr)
    state.fear = math.min(100.0, state.fear + config.baseFleeFearBoost or 40.0)
    if state.mode ~= STATE_FLEE then
        state.mode = STATE_FLEE
        state.fleeUntil = now() + (config.fleeCooldownSeconds or 8)
    end
end

function M.onBaseNearby(entry)
    local state = getState(entry.addr)
    state.fear = math.min(100.0, state.fear + 25.0)
    state.mode = STATE_FLEE
    state.fleeUntil = now() + (config.fleeCooldownSeconds or 8)
end

function M.tickAi(snapshot, playerLoc, vehicleLoc, baseLoc)
    if inGracePeriod() then return end

    local tickNow = now()

    cascade.applyAiPressure(snapshot)

    for _, entry in ipairs(snapshot) do
        if combat.isDead(entry.addr) then goto continue end

        local state = getState(entry.addr)
        local speciesKey = creatures.getSpeciesKey(entry.name)
        local baseline = populationBaseline[speciesKey]
        local current = populationCurrent[speciesKey]
        if baseline ~= nil and current ~= nil and baseline > 0 then
            applyPopulationPressure(entry, speciesKey, current / baseline)
        end

        if isPreyBoosted(entry.name) and food_chain.isCreaturePrey(entry.name) then
            state.hunger = math.max(0.0, state.hunger - (config.predatorKillBoostHungerReduction or 0.5))
        end

        state.hunger = math.min(100.0, state.hunger + (config.hungerRatePerTick or 0.5))
        if state.hunger >= 100.0 then
            combat.damageCreature(entry.actor, config.starvationDamagePerTick or 2.0, nil, entry.name)
        end

        if state.fear > 0.0 then
            state.fear = math.max(0.0, state.fear - (config.fearDecayPerTick or 5.0))
        end

        local threat, threatDist = nearestThreat(entry, snapshot)
        if threat ~= nil then
            state.fear = math.min(100.0, state.fear + (config.fearFromPredatorPerTick or 12.0))
            if threatDist <= config.maxDetectionRadius * 0.5 then
                state.mode = STATE_FLEE
                state.fleeUntil = tickNow + (config.fleeCooldownSeconds or 8)
            end
        end

        if vehicleLoc ~= nil and utils.dist3D(entry.loc, vehicleLoc) <= (config.vehicleNoiseRadius or 4000) then
            M.onVehicleNearby(entry)
        end

        if baseLoc ~= nil and utils.dist3D(entry.loc, baseLoc) <= (config.baseConstructionRadius or 5000) then
            M.onBaseNearby(entry)
        end

        if state.fear >= (config.fleeFearThreshold or 60) or state.mode == STATE_FLEE then
            state.mode = STATE_FLEE
            if threat ~= nil then
                nudgeAway(entry.actor, entry.loc, threat.loc, (config.fleeMoveStep or 100.0) * (config.fleeSpeedMultiplier or 1.0))
            end
            if tickNow >= state.fleeUntil then
                state.mode = STATE_IDLE
                state.fear = math.max(0.0, state.fear - 20.0)
            end
            goto continue
        end

        if state.energy <= (config.restEnergyThreshold or 20) or state.mode == STATE_REST then
            state.mode = STATE_REST
            state.energy = math.min(100.0, state.energy + (config.energyRestorePerTick or 2.0))
            if tickNow >= state.restUntil then
                state.mode = STATE_IDLE
            end
            goto continue
        end

        if state.mode == STATE_HUNT then
            state.energy = math.max(0.0, state.energy - (config.energyCostPerTick or 1.5))
            local prey = findEntryByAddr(snapshot, state.huntTargetAddr)
            if prey == nil or tickNow - state.huntStartedAt > (config.huntAbandonSeconds or 15) then
                state.mode = STATE_IDLE
                state.huntTargetAddr = nil
            else
                nudgeToward(entry.actor, entry.loc, prey.loc, (config.huntMoveStep or 80.0) * (config.huntSpeedMultiplier or 1.0))
                combat.tryAttack(entry.actor, prey.actor, entry.name, prey.name)
                if combat.isDead(prey.addr) then
                    state.mode = STATE_IDLE
                    state.huntTargetAddr = nil
                end
            end
            goto continue
        end

        if food_chain.isPredator(entry.name) and state.hunger >= (config.huntHungerThreshold or 70) then
            local prey = nearestPrey(entry, snapshot)
            if prey ~= nil then
                state.mode = STATE_HUNT
                state.huntTargetAddr = prey.addr
                state.huntStartedAt = tickNow
                state.energy = math.max(0.0, state.energy - (config.energyCostPerTick or 1.5))
                nudgeToward(entry.actor, entry.loc, prey.loc, (config.huntMoveStep or 80.0) * (config.huntSpeedMultiplier or 1.0))
                combat.tryAttack(entry.actor, prey.actor, entry.name, prey.name)
            end
        end

        ::continue::
    end
end

function M.tickPopulation(snapshot)
    local counts = {}
    local preyCounts = {}
    local creaturePreyCounts = {}
    local slugCounts = {}

    for _, entry in ipairs(snapshot) do
        if not combat.isDead(entry.addr) then
            local key = creatures.getSpeciesKey(entry.name)
            counts[key] = (counts[key] or 0) + 1

            if food_chain.isPrey(entry.name) then
                preyCounts[key] = (preyCounts[key] or 0) + 1
                if food_chain.isSlug(entry.name) then
                    slugCounts[key] = (slugCounts[key] or 0) + 1
                elseif food_chain.isCreaturePrey(entry.name) then
                    creaturePreyCounts[key] = (creaturePreyCounts[key] or 0) + 1
                end
            end
        end
    end

    for _, actor in ipairs(FindAllOf("UWEWorldPopResourceBaseActor") or {}) do
        if utils.isValid(actor) and food_chain.isSlug(utils.getFullName(actor)) then
            if utils.safeGet(actor, "bHasBeenGathered") ~= true then
                slugCounts.WaterSlug = (slugCounts.WaterSlug or 0) + 1
                preyCounts.WaterSlug = (preyCounts.WaterSlug or 0) + 1
            end
        end
    end

    for key, count in pairs(counts) do
        populationCurrent[key] = count
        if populationBaseline[key] == nil then
            populationBaseline[key] = math.max(count, 1)
        end
    end

    for key, count in pairs(preyCounts) do
        preyCurrent[key] = count
        if preyBaseline[key] == nil then
            preyBaseline[key] = math.max(count, 1)
        end
    end

    for key, count in pairs(creaturePreyCounts) do
        creaturePreyCurrent[key] = count
        if creaturePreyBaseline[key] == nil then
            creaturePreyBaseline[key] = math.max(count, 1)
        end
    end

    for key, count in pairs(slugCounts) do
        slugPreyCurrent[key] = count
        if slugPreyBaseline[key] == nil then
            slugPreyBaseline[key] = math.max(count, 1)
        end
    end

    if config.logEnabled then
        local parts = {}
        for key, count in pairs(counts) do
            parts[#parts + 1] = string.format("%s=%d", key, count)
        end
        if #parts > 0 then
            print("[RealisticCreatures] population: " .. table.concat(parts, ", ") .. "\n")
        end
    end
end

function M.getPreyPopulationRatio()
    local current = 0
    local baseline = 0

    for key, count in pairs(preyCurrent) do
        current = current + count
        baseline = baseline + (preyBaseline[key] or count)
    end

    if baseline <= 0 then return 1.0 end
    return current / baseline
end

function M.getCreaturePreyPopulationRatio()
    local current = 0
    local baseline = 0

    for key, count in pairs(creaturePreyCurrent) do
        current = current + count
        baseline = baseline + (creaturePreyBaseline[key] or count)
    end

    if baseline <= 0 then return 1.0 end
    return current / baseline
end

function M.purgeAddress(addr)
    creatureState[addr] = nil
    feedingCalmUntilByAddr[addr] = nil
end

return M
