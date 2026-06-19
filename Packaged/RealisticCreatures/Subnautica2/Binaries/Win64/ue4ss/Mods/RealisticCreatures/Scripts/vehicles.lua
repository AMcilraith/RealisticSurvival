local config = require("config")
local combat = require("combat")
local creatures = require("creatures")
local utils = require("utils")

local M = {}

local lastImpactByVictimAddr = {}

local function isTadpoleActor(actor)
    if not utils.isValid(actor) then return false end
    local name = utils.getFullName(actor):lower()
    return name:find("tadpole", 1, true) ~= nil or utils.safeIsA(actor, "/Script/Subnautica2.SN2Tadpole")
end

local function getActorFromComponent(component)
    if not utils.isValid(component) then return nil end
    local ok, owner = utils.callIfPresentReturning(component, "GetOwner")
    if ok and utils.isValid(owner) then return owner end
    return nil
end

local function getComponentOwner(context)
    if not utils.isValid(context) then return nil end
    local owner = utils.safeGet(context, "GetOwner")
    if utils.isValid(owner) then return owner end
    local ok, outer = pcall(function() return context:GetOuter() end)
    if ok and utils.isValid(outer) then return outer end
    return nil
end

local function scaleDamage(component, payload)
    local minDamage = utils.safeGet(component, "MinCollisionDamage") or config.tadpoleImpactDamage or 25.0
    local maxDamage = utils.safeGet(component, "MaxCollisionDamage") or minDamage * 2.0
    local minSpeed = utils.safeGet(component, "MinCollisionSpeed") or 300.0
    local maxSpeed = utils.safeGet(component, "MaxCollisionSpeed") or 2000.0

    local speed = nil
    if payload ~= nil then
        speed = payload.Speed or payload.ImpactSpeed or payload.Velocity
        if type(speed) == "table" and speed.X ~= nil then
            speed = math.sqrt((speed.X * speed.X) + (speed.Y * speed.Y) + (speed.Z * speed.Z))
        end
    end

    if speed == nil or maxSpeed <= minSpeed then
        return (minDamage + maxDamage) * 0.5
    end

    local t = math.max(0.0, math.min(1.0, (speed - minSpeed) / (maxSpeed - minSpeed)))
    return minDamage + ((maxDamage - minDamage) * t)
end

function M.onCollisionImpact(context, otherComponent, payload, hit)
    if config.tadpoleImpactDamageEnabled == false then return end

    local sourceActor = getComponentOwner(context)
    if not isTadpoleActor(sourceActor) then return end

    local victim = getActorFromComponent(otherComponent)
    if not utils.isValid(victim) and hit ~= nil then
        victim = hit.Actor or hit.GetActor and hit:GetActor() or utils.safeGet(hit, "Actor")
        if type(victim) == "userdata" and victim.get then
            local ok, value = pcall(function() return victim:get() end)
            if ok then victim = value end
        end
    end

    if not creatures.isCreatureActor(victim) then return end

    local addr = utils.getAddress(victim)
    if addr == nil then return end

    local now = os.clock()
    local cooldown = config.tadpoleImpactCooldownSeconds or 0.75
    if lastImpactByVictimAddr[addr] ~= nil and now - lastImpactByVictimAddr[addr] < cooldown then
        return
    end
    lastImpactByVictimAddr[addr] = now

    local damage = scaleDamage(context, payload)
    combat.damageCreature(victim, damage, sourceActor, utils.getFullName(victim), "tadpole")

    if config.logEnabled then
        print(string.format(
            "[RealisticCreatures] tadpole impact damaged %s for %.1f\n",
            utils.getFullName(victim),
            damage
        ))
    end
end

return M
