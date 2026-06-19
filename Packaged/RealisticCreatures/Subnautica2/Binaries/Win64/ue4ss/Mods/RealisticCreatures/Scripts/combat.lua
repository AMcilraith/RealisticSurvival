local config = require("config")
local cache = require("cache")
local creatures = require("creatures")
local utils = require("utils")
local UEHelpers = require("UEHelpers")

local respawnModule = nil
local function respawn()
    if respawnModule == nil then respawnModule = require("respawn") end
    return respawnModule
end

local M = {}

local healthByAddr = {}
local lastAttackByAddr = {}
local lastHitByAddr = {}
local lastHitFxByAddr = {}
local deadByAddr = {}
local corpseRollLoopByAddr = {}
local deadCorpseQueue = {}
local onDeathCallbacks = {}

local niagaraDefault = nil
local hitFxSystem = nil
local hitFxPreloadAttempted = false
local lastSwingInputTime = 0.0
local playerHooksInstalled = false

local function logHit(message)
    if config.logHits and config.logEnabled then
        print(string.format("[RealisticCreatures] %s\n", message))
    end
end

function M.registerOnDeath(callback)
    onDeathCallbacks[#onDeathCallbacks + 1] = callback
end

function M.isDead(address)
    return address ~= nil and (deadByAddr[address] == true or respawn().isPending(address))
end

function M.getHealth(actor, addr, fullName)
    if addr == nil then return nil end
    if deadByAddr[addr] then return 0.0 end
    if healthByAddr[addr] ~= nil then return healthByAddr[addr] end

    local settings = creatures.getCreatureSettings(actor, fullName)
    healthByAddr[addr] = settings.health
    return settings.health
end

function M.setHealth(actor, addr, value)
    if addr == nil then return end
    healthByAddr[addr] = value
end

local cancelCorpseTimers
local removeCorpseFromQueue

local function asObject(v) return utils.unwrap(v) end

local function unwrapWeak(v)
    if v == nil then return nil end
    if type(v) == "userdata" and v.Get ~= nil then
        local ok, o = pcall(function() return v:Get() end)
        if ok then return o end
    end
    return v
end

local function getAddr(actor) return utils.getAddress(actor) end

local function getLoc(actor)
    if not utils.isValid(actor) then return nil end
    local ok, loc = pcall(function() return actor:K2_GetActorLocation() end)
    return ok and loc or nil
end

local function getPlayerLoc()
    local pc = UEHelpers.GetPlayerController()
    if not utils.isValid(pc) then return nil end
    local loc = getLoc(pc.Pawn)
    if loc ~= nil then return loc end
    local cam = pc.PlayerCameraManager
    if utils.isValid(cam) then
        local ok, cl = pcall(function() return cam:GetCameraLocation() end)
        if ok then return cl end
    end
    return nil
end

local function getPlayerPawn()
    local pc = UEHelpers.GetPlayerController()
    return pc ~= nil and pc.Pawn or nil
end

local function distFromPlayer(actor)
    local a, p = getLoc(actor), getPlayerLoc()
    return utils.dist3D(a, p)
end

local function inHitRange(actor, maxDist)
    maxDist = maxDist or config.maxHitDistance or 260.0
    if maxDist <= 0 then return true end
    local d = distFromPlayer(actor)
    return d ~= nil and d <= maxDist
end

local function stopCreatureMovement(actor)
    local controller = nil
    if utils.safeGet(actor, "GetController") ~= nil then
        local ok, v = pcall(function() return actor:GetController() end)
        if ok then controller = v end
    end
    utils.callIfPresent(controller, "StopMovement")
    utils.callIfPresent(utils.safeGet(controller, "BrainComponent"), "StopLogic", "RealisticCreatures death")
    utils.callIfPresent(controller, "UnPossess")

    local mv = utils.safeGet(actor, "MovementComponent") or utils.safeGet(actor, "CharacterMovement")
    utils.callIfPresent(mv, "StopMovementImmediately")
    utils.callIfPresent(mv, "StopActiveMovement")
    utils.callIfPresent(mv, "Deactivate")
    utils.setIfPresent(mv, "Velocity", { X = 0.0, Y = 0.0, Z = 0.0 })
    utils.callIfPresent(actor, "SetCanBeDamaged", false)
    utils.callIfPresent(actor, "SetActorEnableCollision", false)
end

cancelCorpseTimers = function(addr)
    local h = corpseRollLoopByAddr[addr]
    if h ~= nil then pcall(function() CancelDelayedAction(h) end); corpseRollLoopByAddr[addr] = nil end
end

removeCorpseFromQueue = function(addr)
    local i = 1
    while i <= #deadCorpseQueue do
        if deadCorpseQueue[i].address == addr then table.remove(deadCorpseQueue, i)
        else i = i + 1 end
    end
end

local function freezeVisualComponent(c)
    if not utils.isValid(c) then return end
    utils.callIfPresent(c, "SetPauseAnims", true)
    utils.callIfPresent(c, "SetPlayRate", 0.0)
    utils.callIfPresent(c, "Stop")
    utils.setIfPresent(c, "bPauseAnims", true)
    utils.setIfPresent(c, "GlobalAnimRateScale", 0.0)
end

local function freezeCreatureVisuals(actor)
    for _, prop in ipairs({ "Mesh", "SkeletalMesh", "SkeletalMeshComponent" }) do
        freezeVisualComponent(utils.safeGet(actor, prop))
    end
end

local function registerDeadCorpse(actor, addr)
    removeCorpseFromQueue(addr)
    deadCorpseQueue[#deadCorpseQueue + 1] = { actor = actor, address = addr }
    local maxDead = config.maxDeadCreatures or 5
    while maxDead > 0 and #deadCorpseQueue > maxDead do
        local oldest = table.remove(deadCorpseQueue, 1)
        cancelCorpseTimers(oldest.address)
        if utils.isValid(oldest.actor) then pcall(function() oldest.actor:K2_DestroyActor() end) end
    end
end

local function rollCorpseOver(actor, addr)
    if not utils.isValid(actor) then return end
    cancelCorpseTimers(addr)

    local ok, rotation = pcall(function() return actor:K2_GetActorRotation() end)
    if not ok or rotation == nil then return end

    local startPitch, startRoll = rotation.Pitch, rotation.Roll
    local yaw = math.rad(rotation.Yaw or 0.0)
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local side = (type(addr) == "number" and addr % 2 == 0) and -1.0 or 1.0
    local targetRoll = 180.0
    local rollTicks = math.max(1, config.corpseRollTicks or 24)
    if config.moonCorpseSideRoll and utils.getFullName(actor):lower():find("moon", 1, true) then
        targetRoll = (config.moonCorpseRollAngle or 90.0) * side
        rollTicks = math.max(1, config.moonCorpseRollTicks or rollTicks)
    end
    local driftTicks = math.max(0, config.deadSinkTicks or 150)
    local ticks = math.max(rollTicks, driftTicks)
    local vStep = config.deadSinkStep or -0.75
    local fStep = config.deadForwardDriftStep or 0.12
    local sStep = config.deadSideDriftStep or 0.18
    local count = 0
    local loop = nil

    loop = LoopInGameThreadWithDelay(config.corpseRollIntervalMs or 80, function()
        if not utils.isValid(actor) then CancelDelayedAction(loop); corpseRollLoopByAddr[addr] = nil; return end
        count = count + 1
        local alpha = math.min(1.0, count / rollTicks)
        rotation.Pitch = startPitch + (0.0 - startPitch) * alpha
        rotation.Roll = startRoll + (targetRoll - startRoll) * alpha
        pcall(function() actor:K2_SetActorRotation(rotation, false) end)
        if count == rollTicks then freezeCreatureVisuals(actor) end
        if count <= driftTicks then
            local lok, loc = pcall(function() return actor:K2_GetActorLocation() end)
            if lok and loc then
                loc.X = loc.X + fx * fStep - fy * sStep * side
                loc.Y = loc.Y + fy * fStep + fx * sStep * side
                loc.Z = loc.Z - vStep
                pcall(function() actor:K2_SetActorLocation(loc, false, {}, false) end)
            end
        end
        if count >= ticks then freezeCreatureVisuals(actor); CancelDelayedAction(loop); corpseRollLoopByAddr[addr] = nil end
    end)
    corpseRollLoopByAddr[addr] = loop
end

local function applyVisualDeath(actor, addr)
    cancelCorpseTimers(addr)
    stopCreatureMovement(actor)
    rollCorpseOver(actor, addr)
    registerDeadCorpse(actor, addr)
    logHit("visual death " .. utils.getFullName(actor))
end

local function destroyActor(actor, addr)
    if not utils.isValid(actor) then return end
    stopCreatureMovement(actor)
    if config.destroyOnDeath then
        ExecuteInGameThreadWithDelay(config.deathDestroyDelayMs or 150, function()
            if utils.isValid(actor) then pcall(function() actor:K2_DestroyActor() end) end
            cache.purgeName(addr)
            cache.purgeController(addr)
            cache.invalidateCreatureCache()
        end)
    end
end

function M.killCreature(victim, killer, reason)
    if not utils.isValid(victim) then return false end
    local addr = getAddr(victim)
    if addr == nil or M.isDead(addr) then return false end

    deadByAddr[addr] = true
    healthByAddr[addr] = 0.0
    lastAttackByAddr[addr] = nil
    lastHitByAddr[addr] = nil

    local victimName = utils.getFullName(victim)
    if config.logEnabled then
        print(string.format("[RealisticCreatures] killed (%s) %s\n", reason or "combat", victimName))
    end

    for _, cb in ipairs(onDeathCallbacks) do pcall(cb, victim, killer, reason) end

    if respawn().tryHandlePreyDeath(victim, addr, victimName) then
        creatures.purgeCreature(addr)
        return true
    end

    if config.visualDeath and (reason == "player" or reason == "external") then
        applyVisualDeath(victim, addr)
    else
        destroyActor(victim, addr)
    end

    creatures.purgeCreature(addr)
    return true
end

function M.damageCreature(victim, damage, attacker, fullName, killReason)
    if not utils.isValid(victim) or damage == nil or damage <= 0.0 then return false end
    local addr = getAddr(victim)
    if addr == nil or M.isDead(addr) then return false end

    local current = M.getHealth(victim, addr, fullName) or 0.0
    local newHealth = current - damage
    M.setHealth(victim, addr, newHealth)

    if config.oneHitKill or newHealth <= 0.0 then
        M.killCreature(victim, attacker, killReason or "damage")
        return true
    end
    return false
end

function M.tryAttack(attacker, victim, attackerName, victimName)
    if not utils.isValid(attacker) or not utils.isValid(victim) then return false end
    local aAddr, vAddr = getAddr(attacker), getAddr(victim)
    if aAddr == nil or vAddr == nil or M.isDead(aAddr) or M.isDead(vAddr) then return false end

    local now = os.clock()
    if lastAttackByAddr[aAddr] ~= nil and now - lastAttackByAddr[aAddr] < (config.attackCooldownSeconds or 1.0) then
        return false
    end
    if utils.dist3D(cache.getLocation(attacker, aAddr), cache.getLocation(victim, vAddr)) > (config.killRange or 450.0) then
        return false
    end

    lastAttackByAddr[aAddr] = now
    local settings = creatures.getCreatureSettings(attacker, attackerName)
    return M.damageCreature(victim, settings.damage or config.defaultPredatorDamage or 30.0, attacker, victimName)
end

local function preloadHitFx()
    if hitFxPreloadAttempted or config.hitFxEnabled == false then return end
    hitFxPreloadAttempted = true
    niagaraDefault = StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
    for _, path in ipairs(config.hitFxAssetPaths or {}) do
        local ok, asset = pcall(function() return LoadAsset(path) end)
        if ok and utils.isValid(asset) then hitFxSystem = asset; return end
    end
end

local function spawnHitFx(actor, settings, hitLoc)
    if config.hitFxEnabled == false or not utils.isValid(hitFxSystem) then return end
    local addr = getAddr(actor)
    if addr ~= nil then
        local now = os.clock()
        local cd = config.hitFxCooldownSeconds or 0.28
        if lastHitFxByAddr[addr] ~= nil and now - lastHitFxByAddr[addr] < cd then return end
        lastHitFxByAddr[addr] = now
    end
    niagaraDefault = niagaraDefault or StaticFindObject("/Script/Niagara.Default__NiagaraFunctionLibrary")
    if not utils.isValid(niagaraDefault) then return end
    local loc = hitLoc or getLoc(actor)
    if loc == nil then return end
    local okRot, rot = pcall(function() return actor:K2_GetActorRotation() end)
    rot = okRot and rot or { Pitch = 0, Yaw = 0, Roll = 0 }
    local s = config.hitFxScale or 1.6
    local scale = { X = s, Y = s, Z = s }
    local ok, comp = utils.callIfPresentReturning(niagaraDefault, "SpawnSystemAtLocation",
        actor, hitFxSystem, loc, rot, scale, true, false, 0, true)
    if ok and utils.isValid(comp) then utils.callIfPresent(comp, "Activate", true) end
end

local function getPlayerToolDamage(actor)
    return config.toolDamage or config.fallbackDamage or 20.0
end

local function resolveCreatureVictim(primary, ctx)
    primary = asObject(primary)
    if creatures.isCreatureActor(primary) then return primary end
    if not utils.isValid(ctx) then return nil end

    local ok, hoverInfo = utils.callIfPresentReturning(ctx, "GetHoverInfoFromActorInfo")
    if ok and hoverInfo ~= nil then
        local a = unwrapWeak(hoverInfo.Actor)
        if creatures.isCreatureActor(a) then return a end
    end
    ok, hoverInfo = utils.callIfPresentReturning(ctx, "GetHoverActorFromActorInfo")
    if ok and creatures.isCreatureActor(hoverInfo) then return hoverInfo end

    local hover = asObject(utils.safeGet(ctx, "Hover Target Actor") or utils.safeGet(ctx, "Hover_Target_Actor"))
    if creatures.isCreatureActor(hover) then return hover end

    local hit = utils.safeGet(ctx, "HitResult")
    if hit ~= nil then
        local handle = utils.safeGet(hit, "HitObjectHandle")
        if handle ~= nil then
            local a = asObject(utils.safeGet(handle, "Actor"))
            if creatures.isCreatureActor(a) then return a end
        end
    end
    return nil
end

local function damagePlayerHit(actor, hitLoc, damageOverride, maxDist)
    actor = creatures.getHealthActor(actor)
    if not utils.isValid(actor) or not creatures.isCreatureActor(actor) then return false end
    local addr = getAddr(actor)
    if addr == nil or M.isDead(addr) then return true end
    if not inHitRange(actor, maxDist) then return false end

    local now = os.clock()
    if lastHitByAddr[addr] ~= nil and now - lastHitByAddr[addr] < (config.hitCooldownSeconds or 0.25) then
        return true
    end
    lastHitByAddr[addr] = now

    local settings = creatures.getCreatureSettings(actor)
    local old = healthByAddr[addr] or settings.health
    local dmg = damageOverride or getPlayerToolDamage(actor)
    local newHealth = old - dmg
    healthByAddr[addr] = newHealth
    spawnHitFx(actor, settings, hitLoc)
    logHit(string.format("player hit %s %.1f -> %.1f", utils.getFullName(actor), old, newHealth))

    if config.oneHitKill or newHealth <= 0.0 then
        return M.killCreature(actor, getPlayerPawn(), "player")
    end
    return true
end

local function damageTarget(target, hitLoc, dmg, maxDist)
    return damagePlayerHit(creatures.getHealthActor(asObject(target)), hitLoc, dmg, maxDist)
end

local function tryHook(name, cb)
    local ok = pcall(RegisterHook, name, cb)
    if ok and config.logEnabled then print("[RealisticCreatures] hooked " .. name .. "\n") end
    return ok
end

local function findClassByExactName(className)
    local function matches(cls)
        if not utils.isValid(cls) then return nil end
        local ok, fn = pcall(function() return cls:GetFullName() end)
        if ok and fn and fn:find("." .. className .. "$") then return fn end
        return nil
    end
    local cls, fn = StaticFindObject(className), matches(StaticFindObject(className))
    if fn then return cls, fn end
    local inst = FindFirstOf(className)
    if not utils.isValid(inst) then return nil, nil end
    local ok, cur = pcall(function() return inst:GetClass() end)
    while ok and utils.isValid(cur) do
        fn = matches(cur)
        if fn then return cur, fn end
        local pok, par = pcall(function() return cur:GetSuperStruct() end)
        if not pok or not utils.isValid(par) then break end
        cur = par
    end
    return nil, nil
end

local function installBPClassHooks(displayName, className, hookSpec)
    local installed, attempts = false, 0
    local function tryInstall()
        if installed then return true end
        attempts = attempts + 1
        local _, fn = findClassByExactName(className)
        if fn == nil then return false end
        local path = fn:match("(/Game/%S+_C)$") or fn:match("(%S+)$")
        if path == nil then return false end
        local any = false
        for fname, cb in pairs(hookSpec) do
            if tryHook(path .. ":" .. fname, cb) then any = true end
        end
        if any then installed = true; return true end
        return false
    end
    tryInstall()
    local loop = LoopInGameThreadWithDelay(2000, function()
        if tryInstall() or attempts >= 60 then CancelDelayedAction(loop) end
    end)
end

function M.installPlayerHooks()
    if playerHooksInstalled then return end
    playerHooksInstalled = true

    ExecuteInGameThreadWithDelay(config.hitFxPreloadDelayMs or 3500, function() preloadHitFx() end)

    if config.multiToolKnifeHitDamageEnabled ~= false then
        tryHook("/Script/UWEInterfaces.KnifeTarget:KnifeHit", function(context)
            pcall(function()
                local now = os.clock()
                if now - lastSwingInputTime < (config.swingInputCooldownSeconds or 0.22) then return end
                local victim = resolveCreatureVictim(context, context) or resolveCreatureVictim(context, nil)
                if victim ~= nil then
                    if damagePlayerHit(victim, getLoc(victim), nil, config.maxHitDistance) then
                        lastSwingInputTime = now
                    end
                elseif damageTarget(context, getLoc(asObject(context)), nil, config.maxHitDistance) then
                    lastSwingInputTime = now
                end
            end)
        end)
    end

    installBPClassHooks("MultitoolCut", "GA_SurvivalMultiTool_Cut_C", {
        DamageTarget = function(ctx, actorParam)
            pcall(function()
                local v = resolveCreatureVictim(actorParam, ctx)
                if v then damagePlayerHit(v, getLoc(v), nil, config.maxHitDistance) end
            end)
        end,
        PlayHitEffect = function(ctx, actorParam)
            pcall(function()
                local v = resolveCreatureVictim(actorParam, ctx)
                if v then damagePlayerHit(v, getLoc(v), nil, config.maxHitDistance) end
            end)
        end,
        DestroyTarget = function(ctx, actorParam)
            pcall(function()
                local v = resolveCreatureVictim(actorParam, ctx)
                if v then M.killCreature(v, getPlayerPawn(), "player") end
            end)
        end,
    })
end

function M.purgeAddress(addr)
    healthByAddr[addr] = nil
    lastAttackByAddr[addr] = nil
    lastHitByAddr[addr] = nil
    lastHitFxByAddr[addr] = nil
    deadByAddr[addr] = nil
    cancelCorpseTimers(addr)
    removeCorpseFromQueue(addr)
end

return M
