local config = require("config")
local utils = require("utils")

local M = {}

local baseGrowthRateByAddr = {}
local baseRipenTimeByAddr = {}
local baseGrowthMultiplierByAddr = {}
local baseSpawnRateByAddr = {}
local lastAppliedMultiplier = 1.0
local floraBaseline = nil
local floraCurrent = 0

function M.tickPopulation()
    local count = 0

    for _, plant in ipairs(FindAllOf("UWERegrowablePlant") or {}) do
        if utils.isValid(plant) then
            local growthData = utils.safeGet(plant, "GrowthData")
            local growth = growthData ~= nil and growthData.Growth or nil
            local maxGrowth = utils.safeGet(plant, "MaxGrowth")
            if growth == nil or maxGrowth == nil or growth < maxGrowth then
                count = count + 1
            end
        end
    end

    for _, component in ipairs(FindAllOf("UWEPlantGrowerComponent") or {}) do
        if utils.isValid(component) then
            local fullyGrown = false
            local ok, value = utils.callIfPresentReturning(component, "IsFullyGrown")
            if ok then fullyGrown = value end
            if not fullyGrown then
                count = count + 1
            end
        end
    end

    for _, component in ipairs(FindAllOf("UWESeedGrowerComponent") or {}) do
        if utils.isValid(component) then
            local hasSeed = false
            local ok, value = utils.callIfPresentReturning(component, "HasSeed")
            if ok then hasSeed = value end
            local fullyGrown = false
            ok, value = utils.callIfPresentReturning(component, "HasFullyRipenedSeed")
            if ok then fullyGrown = value end
            if hasSeed and not fullyGrown then
                count = count + 1
            end
        end
    end

    floraCurrent = count
    if floraBaseline == nil then
        floraBaseline = math.max(count, 1)
    end
end

function M.getFloraPopulationRatio()
    if floraBaseline == nil or floraBaseline <= 0 then return 1.0 end
    return floraCurrent / floraBaseline
end

local function rememberBase(store, addr, value)
    if addr == nil or value == nil or value < 0.0 then return nil end
    if store[addr] == nil then
        store[addr] = value
    end
    return store[addr]
end

local function applyPlantGrower(component, multiplier)
    if not utils.isValid(component) then return end

    local addr = utils.getAddress(component)
    local rate = utils.safeGet(component, "GrowthRate")
    if rate == nil then return end

    local base = rememberBase(baseGrowthRateByAddr, addr, rate > 0.0 and rate or (baseGrowthRateByAddr[addr] or 0.0))
    if base == nil or base <= 0.0 then return end

    pcall(function()
        component.GrowthRate = base * multiplier
    end)
end

local function applySeedGrower(component, multiplier)
    if not utils.isValid(component) then return end

    local addr = utils.getAddress(component)
    local growthData = utils.safeGet(component, "GrowthData")
    if growthData ~= nil and growthData.Growth ~= nil and growthData.Growth > 0.0 then
        local base = rememberBase(baseGrowthRateByAddr, addr, growthData.Growth)
        utils.callIfPresent(component, "SetGrowthRate", base * multiplier)
    end

    local ripenTime = utils.safeGet(component, "RipenTime")
    if ripenTime ~= nil and ripenTime > 0.0 then
        local baseRipen = rememberBase(baseRipenTimeByAddr, addr, ripenTime)
        pcall(function()
            if multiplier <= 0.0 then
                component.RipenTime = math.huge
            else
                component.RipenTime = baseRipen / multiplier
            end
        end)
    end

    local spawnRate = utils.safeGet(component, "SpawnRate")
    if spawnRate ~= nil and spawnRate > 0.0 then
        local baseSpawn = rememberBase(baseSpawnRateByAddr, "spawn:" .. tostring(addr), spawnRate)
        pcall(function()
            component.SpawnRate = baseSpawn * multiplier
        end)
    end
end

local function applyRegrowablePlant(plant, multiplier)
    if not utils.isValid(plant) then return end

    local addr = utils.getAddress(plant)
    local growthData = utils.safeGet(plant, "GrowthData")
    if growthData == nil then return end

    local baseMult = rememberBase(baseGrowthMultiplierByAddr, addr, growthData.GrowthMultiplier or 1.0)
    pcall(function()
        growthData.GrowthMultiplier = baseMult * multiplier
        plant.GrowthData = growthData
    end)
end

function M.applyGrowthMultiplier(multiplier)
    if config.floraEnabled == false then return end
    if multiplier == nil then return end

    multiplier = math.max(0.0, math.min(1.0, multiplier))
    if math.abs(multiplier - lastAppliedMultiplier) < 0.01 then return end
    lastAppliedMultiplier = multiplier

    for _, component in ipairs(FindAllOf("UWEPlantGrowerComponent") or {}) do
        applyPlantGrower(component, multiplier)
    end

    for _, component in ipairs(FindAllOf("UWESeedGrowerComponent") or {}) do
        applySeedGrower(component, multiplier)
    end

    for _, plant in ipairs(FindAllOf("UWERegrowablePlant") or {}) do
        applyRegrowablePlant(plant, multiplier)
    end

    if config.logEnabled then
        print(string.format(
            "[RealisticCreatures] flora growth multiplier=%.2f floraRatio=%.2f\n",
            multiplier,
            M.getFloraPopulationRatio()
        ))
    end
end

return M
