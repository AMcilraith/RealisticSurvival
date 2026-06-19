local config = require("config")
local combat = require("combat")
local food_chain = require("food_chain")
local utils = require("utils")

local M = {}

local floraStress = 0.0
local preyStress = 0.0
local predatorStress = 0.0
local sustainedLowFloraTicks = 0
local sustainedHighPreyTicks = 0
local sustainedLowPreyTicks = 0

local lastState = {
    starvePrey = false,
    starvePredators = false,
    blockFloraRegrowth = false,
    floraGrowthMultiplier = 1.0,
}

local function gain()
    return config.cascadeStressGainPerTick or 6.0
end

local function decay()
    return config.cascadeStressDecayPerTick or 2.0
end

local function stressThreshold()
    return config.cascadeStressThreshold or 75.0
end

local function sustainedTicksRequired()
    return config.cascadeSustainedTicksRequired or 4
end

function M.getState()
    return lastState
end

function M.tick(floraRatio, creaturePreyRatio, totalPreyRatio)
    floraRatio = floraRatio or 1.0
    creaturePreyRatio = creaturePreyRatio or 1.0
    totalPreyRatio = totalPreyRatio or 1.0

    local floraLow = config.floraLowRatio or 0.30
    local floraRecover = config.floraRecoverRatio or 0.45
    local preyBlock = config.floraPreyBlockRatio or 1.50
    local preyCollapse = config.preyCollapseRatio or 0.25
    local preyRecover = config.preyRecoverRatio or 0.40

    if floraRatio < floraLow then
        sustainedLowFloraTicks = sustainedLowFloraTicks + 1
        floraStress = math.min(100.0, floraStress + gain())
    else
        sustainedLowFloraTicks = math.max(0, sustainedLowFloraTicks - 1)
        if floraRatio >= floraRecover then
            floraStress = math.max(0.0, floraStress - decay())
        end
    end

    if creaturePreyRatio >= preyBlock then
        sustainedHighPreyTicks = sustainedHighPreyTicks + 1
    else
        sustainedHighPreyTicks = math.max(0, sustainedHighPreyTicks - 1)
    end

    if floraStress >= (config.preyStressFromFloraThreshold or 55.0) then
        preyStress = math.min(100.0, preyStress + gain() * 0.6)
    elseif floraRatio >= floraRecover then
        preyStress = math.max(0.0, preyStress - decay() * 0.5)
    end

    if totalPreyRatio < preyCollapse and preyStress >= (config.predatorStressFromPreyThreshold or 50.0) then
        sustainedLowPreyTicks = sustainedLowPreyTicks + 1
        predatorStress = math.min(100.0, predatorStress + gain() * 0.5)
    else
        sustainedLowPreyTicks = math.max(0, sustainedLowPreyTicks - 1)
        if totalPreyRatio >= preyRecover then
            predatorStress = math.max(0.0, predatorStress - decay() * 0.5)
        end
    end

    local required = sustainedTicksRequired()
    local threshold = stressThreshold()

    lastState.starvePrey = floraStress >= threshold
        and sustainedLowFloraTicks >= required
    lastState.starvePredators = predatorStress >= threshold
        and sustainedLowPreyTicks >= required
    lastState.blockFloraRegrowth = sustainedHighPreyTicks >= required

    if lastState.blockFloraRegrowth then
        lastState.floraGrowthMultiplier = 0.0
    elseif sustainedHighPreyTicks > 0 and creaturePreyRatio > (config.floraPreyHighRatio or 1.20) then
        local t = math.min(1.0, sustainedHighPreyTicks / required)
        lastState.floraGrowthMultiplier = math.max(0.0, 1.0 - t)
    else
        lastState.floraGrowthMultiplier = 1.0
    end

    if config.logEnabled and (lastState.starvePrey or lastState.starvePredators or lastState.blockFloraRegrowth) then
        print(string.format(
            "[RealisticCreatures] cascade flora=%.0f prey=%.0f pred=%.0f lowFlora=%d highPrey=%d lowPrey=%d\n",
            floraStress,
            preyStress,
            predatorStress,
            sustainedLowFloraTicks,
            sustainedHighPreyTicks,
            sustainedLowPreyTicks
        ))
    end

    return lastState
end

function M.applyAiPressure(snapshot)
    if not lastState.starvePrey and not lastState.starvePredators then
        return
    end

    local preyDamage = config.floraStarvationDamagePerTick or 2.0
    local predatorDamage = config.preyCollapsePredatorDamagePerTick or 3.0

    for _, entry in ipairs(snapshot) do
        if combat.isDead(entry.addr) then goto continue end

        if lastState.starvePrey and food_chain.isCreaturePrey(entry.name) then
            combat.damageCreature(entry.actor, preyDamage, nil, entry.name, "cascade")
        end

        if lastState.starvePredators and food_chain.isPredator(entry.name) then
            combat.damageCreature(entry.actor, predatorDamage, nil, entry.name, "cascade")
        end

        ::continue::
    end
end

return M
