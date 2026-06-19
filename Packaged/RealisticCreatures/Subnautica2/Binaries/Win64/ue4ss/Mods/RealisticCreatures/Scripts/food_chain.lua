local config = require("config")

local M = {}

local predatorPatterns = {}
local preyOf = {}
local allPreyPatterns = {}
local preyPatternSet = {}
local slugPatterns = {}

for _, pattern in ipairs(config.slugPatterns or { "waterslug", "WaterSlug" }) do
    slugPatterns[#slugPatterns + 1] = pattern:lower()
end

local function addPreyPattern(pattern)
    local preyPat = pattern:lower()
    if preyPatternSet[preyPat] then return end
    preyPatternSet[preyPat] = true
    allPreyPatterns[#allPreyPatterns + 1] = preyPat
end

for _, pattern in ipairs(slugPatterns) do
    addPreyPattern(pattern)
end

for _, entry in ipairs(config.foodChain or {}) do
    local pred = entry.predator:lower()
    predatorPatterns[#predatorPatterns + 1] = pred
    preyOf[pred] = {}
    for _, p in ipairs(entry.prey or {}) do
        local preyPat = p:lower()
        preyOf[pred][#preyOf[pred] + 1] = preyPat
        addPreyPattern(preyPat)
    end
end

local function nameContains(fullName, pattern)
    return fullName:lower():find(pattern, 1, true) ~= nil
end

function M.isSlug(fullName)
    for _, pat in ipairs(slugPatterns) do
        if nameContains(fullName, pat) then return true end
    end
    return false
end

function M.isSlugPattern(pattern)
    return M.isSlug(pattern)
end

function M.isPredator(fullName)
    for _, pat in ipairs(predatorPatterns) do
        if nameContains(fullName, pat) then return true end
    end
    return false
end

function M.isPreyOf(actorName, predatorName)
    for _, predPat in ipairs(predatorPatterns) do
        if nameContains(predatorName, predPat) then
            for _, preyPat in ipairs(preyOf[predPat] or {}) do
                if nameContains(actorName, preyPat) then return true end
            end
        end
    end
    return false
end

function M.isPredatorOf(actorName, targetName)
    return M.isPreyOf(targetName, actorName)
end

function M.isPrey(fullName)
    for _, pat in ipairs(allPreyPatterns) do
        if nameContains(fullName, pat) then return true end
    end
    return false
end

function M.isCreaturePrey(fullName)
    return M.isPrey(fullName) and not M.isSlug(fullName)
end

function M.allPredatorPatterns()
    return predatorPatterns
end

function M.allPreyPatterns()
    return allPreyPatterns
end

return M
