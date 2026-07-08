local config = require("config")

local Hotbar = {}

local VERBOSE_LOGGING = false

local function logVerbose(message)
    if VERBOSE_LOGGING then
        print(string.format("[RealisticStorage] %s", message))
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

local hotbarUpgradePropName = nil
local function getHotbarUpgradeProp(player)
    if hotbarUpgradePropName then
        return hotbarUpgradePropName
    end
    local MyClass = player:GetClass()
    MyClass:ForEachProperty(function(Property)
        local name = Property:GetFName():ToString()
        if (name:find("Dexterity") or name:find("Toolbar")) and name:find("Improved") and
            (name:find("Steps") or name:find("Count") or name:find("Amount") or name:find("Level")) then
            hotbarUpgradePropName = name
            return true
        end
        return false
    end)
    return hotbarUpgradePropName
end

local function getHotbarUpgradeCount(player)
    local count = 0
    local prop = getHotbarUpgradeProp(player)
    if prop then
        local steps = player[prop]
        if type(steps) == "number" and steps > 0 then
            return steps
        end
    end
    local tracker = getTracker()
    if tracker then
        local val = tracker:GetValue({
            TagName = FName("EventTracker.IncreaseToolbar")
        }, {
            TagName = FName("PermanentUpgrades.Toolbar")
        })
        if val and type(val) == "number" and val > 0 then
            count = math.floor(val / 1)
        end
    end
    return count
end

local function getToolbarComponent(player)
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
    return try("Toolbar") or try("ToolbarComponent") or try("QuickSlots") or try("QuickSlotsComponent")
end

function Hotbar.Apply(player)
    if not isValid(player) then
        return
    end

    local currentTier = math.max(0, math.floor(getHotbarUpgradeCount(player) or 0))
    local cappedTier = math.min(currentTier, config.hotbar.MaxUpgrades)
    local hbTarget = math.min(config.hotbar.StartingSlots + (cappedTier * config.hotbar.Increment),
        config.hotbar.MaxSlots)

    local toolbarComp = getToolbarComponent(player)
    if not isValid(toolbarComp) then
        logVerbose("WARNING: Could not find Toolbar or QuickSlot Component directly on the player object.")
        return
    end

    local currentSlots = safeGet(toolbarComp, "MaxSlots")
        or safeGet(toolbarComp, "SlotCount")
        or safeGet(toolbarComp, "MaxItems")
    if currentSlots == hbTarget then
        return
    end

    logVerbose(string.format("Directly overriding player toolbar layout size to %d slots.", hbTarget))

    safeCall(toolbarComp, "SetMaxSlots", hbTarget)
    safeCall(toolbarComp, "SetSlotCount", hbTarget)
    safeSet(toolbarComp, "MaxSlots", hbTarget)
    safeSet(toolbarComp, "SlotCount", hbTarget)
    safeSet(toolbarComp, "MaxItems", hbTarget)
end

function Hotbar.Clear(player)
end

return Hotbar
