local config = require("config")

local PlayerInventory = {}

local VERBOSE_LOGGING = false

local function logVerbose(message)
    if VERBOSE_LOGGING then
        print(string.format("[PlayerInventoryMod] %s", message))
    end
end

local function unwrap(value)
    if value == nil then return nil end
    if type(value) ~= "userdata" then return value end
    if value.Get ~= nil then
        local ok, got = pcall(function() return value:Get() end)
        if ok then return got end
        return nil
    end
    if value.get ~= nil then
        local ok, got = pcall(function() return value:get() end)
        if ok then return got end
        return nil
    end
    return value
end

local function isValid(object)
    if object == nil then return false end
    object = unwrap(object)
    if object == nil then return false end
    local ok, valid = pcall(function() return object:IsValid() end)
    return ok and valid == true
end

local function safeGet(object, property)
    if not isValid(object) then return nil end
    local ok, value = pcall(function() return object[property] end)
    return ok and value or nil
end

local function safeSet(object, property, value)
    if not isValid(object) then return false end
    return pcall(function() object[property] = value end)
end

local function safeCall(object, functionName, ...)
    if not isValid(object) then return false end
    local args = { ... }
    return pcall(function()
        object[functionName](object, table.unpack(args))
    end)
end

local function getTracker()
    local ctx = StaticFindObject("/Script/UWEEventTracker.UWEEventTrackerStatics")
    if not ctx or not ctx:IsValid() then
        return nil
    end
    local fn = StaticFindObject("/Script/UWEEventTracker.UWEEventTrackerStatics:GetLocalPlayerEventTracker")
    if not fn or not fn:IsValid() then
        return nil
    end
    local t = fn(ctx, ctx)
    if t and t:IsValid() then
        return t
    end
    return nil
end

local inventoryUpgradePropName = nil
local function getPlayerInventoryUpgradeProp(player)
    if inventoryUpgradePropName then
        return inventoryUpgradePropName
    end
    local MyClass = player:GetClass()
    MyClass:ForEachProperty(function(Property)
        local name = Property:GetFName():ToString()
        if (name:find("Endurance") or name:find("Inventory")) and name:find("Expanded") and
            (name:find("Steps") or name:find("Count") or name:find("Amount") or name:find("Level")) then
            inventoryUpgradePropName = name
            return true
        end
        return false
    end)
    return inventoryUpgradePropName
end

local function getPlayerInventoryUpgradeCount(player)
    local count = 0

    local prop = getPlayerInventoryUpgradeProp(player)
    if prop then
        local steps = player[prop]
        if type(steps) == "number" and steps > 0 then
            logVerbose(string.format("Detected upgrade via player component property [%s]: %d", prop, steps))
            return steps
        end
    end

    local tracker = getTracker()
    if tracker then
        local val = tracker:GetValue({
            TagName = FName("EventTracker.IncreaseInventory")
        }, {
            TagName = FName("PermanentUpgrades.Inventory")
        })

        if val and type(val) == "number" and val > 0 then
            logVerbose(string.format("Raw upgrade tracker value read: %d", val))

            -- Dynamic tier parsing fallback logic:
            if val >= config.inventory.Increment then
                -- Handle case where the tracker logs raw slot counts (5, 10, 15...)
                count = math.floor(val / config.inventory.Increment)
            elseif val % 3 == 0 then
                -- Handle case where the tracker logs old hardcoded game steps (3, 6, 9...)
                count = math.floor(val / 3)
            else
                -- Handle case where the tracker logs single tiers cleanly (1, 2, 3...)
                count = val
            end
            logVerbose(string.format("Parsed raw tracker value into upgrade tier: %d", count))
        end
    end

    return count
end

local function getInventoryComponent(player)
    local function try(name)
        local ok, v = pcall(function()
            return player[name]
        end)
        v = unwrap(v)
        if ok and isValid(v) then
            return v
        end
        return nil
    end
    return try("Inventory") or try("UWEInventory") or try("InventoryComponent")
end

function PlayerInventory.Apply(player)
    if not isValid(player) then
        return
    end

    local currentTier = math.max(0, math.floor(getPlayerInventoryUpgradeCount(player) or 0))
    local cappedTier = math.min(currentTier, config.inventory.MaxUpgrades)
    local invTarget = math.min(config.inventory.StartingSlots + (cappedTier * config.inventory.Increment),
        config.inventory.MaxSlots)

    local invComp = getInventoryComponent(player)
    if not isValid(invComp) then
        return
    end

    local currentItems = safeGet(invComp, "MaxItems")
    if currentItems == invTarget then
        return
    end

    logVerbose(string.format(
        "Upgrade Event! Force shifting layout size from %d to %d slots (Tier %d detected).",
        currentItems or 0, invTarget, cappedTier))
    safeCall(invComp, "SetMaxItems", invTarget)
    safeSet(invComp, "MaxItems", invTarget)
end

function PlayerInventory.Clear(player)
end

return PlayerInventory
