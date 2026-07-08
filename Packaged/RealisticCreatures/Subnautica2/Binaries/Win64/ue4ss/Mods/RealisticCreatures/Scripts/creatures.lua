local config = require("config")
local utils = require("utils")

local M = {}

local healthClass = nil
local settingsByAddr = {}
local creatureCheckByAddr = {}
local healthActorByAddr = {}

local KNOWN_CREATURE_PATTERNS = {
    -- Blueprint actors
    "BP_Halfmoon", "BP_Halfmoon_variant", "BP_Geordie", "BP_ElectricGeordie",
    "BP_Houndgar", "BP_Waxmoon", "BP_FlashFish", "BP_Bullethead", "BP_Cerathecan",
    "BP_CoralCrab", "BP_FourEye", "BP_JellyFisher", "BP_JellyRing", "BP_JetoCaris",
    "BP_Marrowbreach", "BP_NeedlerShark", "BP_NibblerShark", "BP_Pneumo", "BP_Quadrate",
    "BP_Sandspear", "BP_ScourgeHive", "BP_SeaOlive", "BP_SpineyTail", "BP_SpineyTail_Variant01",
    "BP_SpineyTailVariant01", "BP_SurgeJelly", "BP_TwinEel", "BP_EpicureanSymbiote",
    "BP_Epicurean", "BP_BlightParasite", "BP_AnemoneCrab",
    "BP_CollectorLeviathan", "BP_ShiverLeviathan", "BP_ShiverLeviathan_Male",
    -- Common / display names
    "Halfmoon", "GreaterHalfmoon", "HeatHalfmoon", "Geordie", "ElectricGeordie",
    "Houndgar", "Waxmoon", "FlashFish", "Bullethead", "Cerathecan", "CoralCrab",
    "FourEye", "JellyFisher", "JellyRing", "JellyRing_Static", "JetoCaris", "JetoCaris_Juvenile",
    "Marrowbreach", "Marrowbreach_Giant", "HeatMarrowbreach", "NeedlerShark", "NeedlerShark_Giant",
    "NibblerShark", "NibblerMango", "HeatNibblerMango", "Pneumo", "Quadrate", "Sandspear",
    "ScourgeHive", "SeaOlive", "SpineyTail", "SpineyTail_Variant01", "Hoverthorn", "HoverThorn",
    "SurgeJelly", "TwinEel", "Epicurean", "EpicureanSymbiote", "BlightParasite",
    "AnemoneCrab", "AnemoneCrabDark", "StalkerCreature", "SnorklebackAdult", "SnorklebackJuvenile",
    "GiantTubeSalp", "Hammerhead", "HeatHammerhead",
    -- Leviathans
    "CollectorLeviathan", "Collector Leviathan", "Collector_Leviathan", "Leviathan_01",
    "ShiverLeviathan", "Shiver Leviathan", "Shiver_Leviathan", "ShiverLeviathan_Male",
    "Shiver Leviathan Male", "Shiver_Leviathan_Male", "MaleShiverLeviathan", "Male Shiver Leviathan",
    "/CollectorLeviathan/", "/ShiverLeviathan/",
    -- AI archetypes
    "AI.Archetype.CollectorLeviathan", "AI.Archetype.ShiverLeviathan",
    "AI.Archetype.NeedlerShark", "AI.Archetype.NibblerShark", "AI.Archetype.JetoCaris",
    "AI.Archetype.JellyRing", "AI.Archetype.SpineyTail", "AI.Archetype.SurgeJelly",
    "AI.Archetype.TwinEels", "AI.Archetype.Sandspear", "AI.Archetype.Pneumo",
    -- Generic fallbacks
    "LargeFish", "SmallFish", "Tiny",
}

function M.isCreatureActor(actor)
    if not utils.isValid(actor) then return false end

    local address = utils.getAddress(actor)
    if address ~= nil and creatureCheckByAddr[address] ~= nil then
        return creatureCheckByAddr[address]
    end

    local fullName = utils.getFullName(actor)
    local lowerName = fullName:lower()
    if lowerName:find("player", 1, true) ~= nil or
        lowerName:find("vehicle", 1, true) ~= nil or
        lowerName:find("seatruck", 1, true) ~= nil or
        lowerName:find("seamoth", 1, true) ~= nil or
        lowerName:find("cyclops", 1, true) ~= nil then
        if address ~= nil then creatureCheckByAddr[address] = false end
        return false
    end

    if utils.safeIsA(actor, "/Script/UWEAI.UWEAIPawn") or
        utils.safeIsA(actor, "/Script/UWEAI.UWEAICharacter") or
        utils.safeIsA(actor, "/Script/UWEAI.UWEAISmallFish") or
        utils.safeIsA(actor, "/Script/UWEAI.UWEAILargeFish") then
        if address ~= nil then creatureCheckByAddr[address] = true end
        return true
    end

    for _, profile in ipairs(config.creatureHealth or {}) do
        if utils.nameMatchesPattern(fullName, profile.pattern) then
            if address ~= nil then creatureCheckByAddr[address] = true end
            return true
        end
    end

    local result = fullName:find("/AI/Agents/", 1, true) ~= nil
    if not result then
        for _, pattern in ipairs(KNOWN_CREATURE_PATTERNS) do
            if fullName:find(pattern, 1, true) ~= nil then
                result = true
                break
            end
        end
    end

    if address ~= nil then creatureCheckByAddr[address] = result end
    return result
end

function M.getHealthActor(actor)
    actor = utils.unwrap(actor)
    local address = utils.getAddress(actor)
    if address ~= nil then
        local cached = healthActorByAddr[address]
        if utils.isValid(cached) then return cached end
    end

    if M.getHealthComponent(actor) ~= nil then
        if address ~= nil then healthActorByAddr[address] = actor end
        return actor
    end

    if utils.isValid(actor) and utils.safeGet(actor, "GetOwner") ~= nil then
        local ok, owner = pcall(function() return actor:GetOwner() end)
        if ok and M.getHealthComponent(owner) ~= nil then
            if address ~= nil then healthActorByAddr[address] = owner end
            return owner
        end
    end

    if utils.isValid(actor) and utils.safeGet(actor, "GetAttachParentActor") ~= nil then
        local ok, parent = pcall(function() return actor:GetAttachParentActor() end)
        if ok and M.getHealthComponent(parent) ~= nil then
            if address ~= nil then healthActorByAddr[address] = parent end
            return parent
        end
    end

    if utils.isValid(actor) and utils.safeGet(actor, "GetOuter") ~= nil then
        local ok, parent = pcall(function() return actor:GetOuter() end)
        if ok and M.getHealthComponent(parent) ~= nil then
            if address ~= nil then healthActorByAddr[address] = parent end
            return parent
        end
    end

    if address ~= nil then healthActorByAddr[address] = actor end
    return actor
end

function M.getHealthComponent(actor)
    if not utils.isValid(actor) then return nil end

    local healthSet = utils.safeGet(actor, "HealthSetComponent")
    if utils.isValid(healthSet) then return healthSet end

    local healthComponent = utils.safeGet(actor, "HealthComponent")
    if utils.isValid(healthComponent) then return healthComponent end

    if utils.safeGet(actor, "GetComponentByClass") ~= nil then
        if healthClass == nil then
            healthClass = StaticFindObject("/Script/UWEAbilitySystem.UWEHealthSetComponent")
        end
        if healthClass ~= nil and healthClass:IsValid() then
            local ok, component = pcall(function()
                return actor:GetComponentByClass(healthClass)
            end)
            if ok and utils.isValid(component) then return component end
        end
    end

    return nil
end

function M.getCreatureSettings(actor, fullName)
    local address = utils.getAddress(actor)
    if address ~= nil and settingsByAddr[address] ~= nil then
        return settingsByAddr[address]
    end

    fullName = fullName or utils.getFullName(actor)
    local settings = {
        health = config.fallbackHealth,
        damage = config.fallbackDamage,
        pattern = nil,
    }

    for _, profile in ipairs(config.creatureHealth or {}) do
        if utils.nameMatchesPattern(fullName, profile.pattern) then
            settings.health = profile.health or settings.health
            settings.damage = profile.damage or settings.damage
            settings.pattern = profile.pattern
            break
        end
    end

    if settings.pattern == nil then
        if utils.safeIsA(actor, "/Script/UWEAI.UWEAILargeFish") or fullName:find("Large", 1, true) ~= nil then
            settings.health = 250.0
            settings.damage = 40.0
        elseif utils.safeIsA(actor, "/Script/UWEAI.UWEAISmallFish") or fullName:find("Small", 1, true) ~= nil then
            settings.health = 50.0
            settings.damage = 10.0
        elseif fullName:find("Leviathan", 1, true) ~= nil then
            settings.health = 3000.0
            settings.damage = 100.0
        end
    end

    if address ~= nil then settingsByAddr[address] = settings end
    return settings
end

function M.getDecisionTarget(actor)
    if not utils.isValid(actor) then return nil end
    local ok, target = utils.callIfPresentReturning(actor, "GetDecisionTarget")
    if ok and utils.isValid(target) then return target end
    return nil
end

function M.purgeCreature(address)
    settingsByAddr[address] = nil
    creatureCheckByAddr[address] = nil
    healthActorByAddr[address] = nil
end

function M.getSpeciesKey(fullName)
    for _, profile in ipairs(config.creatureHealth or {}) do
        if utils.nameMatchesPattern(fullName, profile.pattern) then
            return profile.pattern
        end
    end
    if fullName:find("Leviathan", 1, true) then return "Leviathan" end
    if fullName:find("Shark", 1, true) then return "Shark" end
    return "Unknown"
end

return M
