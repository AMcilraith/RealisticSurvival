local Hotbar = {}

local VERBOSE_LOGGING = false

local HOTBAR_START = 5
local HOTBAR_MAX = 7
local HOTBAR_INC = 1
local HOTBAR_UPG_MAX = 3

local function logVerbose(message)
    if VERBOSE_LOGGING then
        print(string.format("[RealisticStorage] %s", message))
    end
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
        if ok and v and v:IsValid() then
            return v
        end
        return nil
    end
    return try("Toolbar") or try("ToolbarComponent") or try("QuickSlots") or try("QuickSlotsComponent")
end

function Hotbar.Apply(player)
    if not player or not player:IsValid() then
        return
    end

    local currentTier = math.max(0, math.floor(getHotbarUpgradeCount(player) or 0))
    local cappedTier = math.min(currentTier, HOTBAR_UPG_MAX)
    local hbTarget = math.min(HOTBAR_START + (cappedTier * HOTBAR_INC), HOTBAR_MAX)

    local toolbarComp = getToolbarComponent(player)
    if toolbarComp and toolbarComp:IsValid() then
        -- Handle whichever sizing properties the engine layout exposes
        local currentSlots = toolbarComp.MaxSlots or toolbarComp.SlotCount or toolbarComp.MaxItems
        if currentSlots ~= hbTarget then
            logVerbose(string.format("Directly overriding player toolbar layout size to %d slots.", hbTarget))

            pcall(function()
                if toolbarComp.SetMaxSlots then
                    toolbarComp:SetMaxSlots(hbTarget)
                end
            end)
            pcall(function()
                if toolbarComp.SetSlotCount then
                    toolbarComp:SetSlotCount(hbTarget)
                end
            end)

            if toolbarComp.MaxSlots then
                toolbarComp.MaxSlots = hbTarget
            end
            if toolbarComp.SlotCount then
                toolbarComp.SlotCount = hbTarget
            end
            if toolbarComp.MaxItems then
                toolbarComp.MaxItems = hbTarget
            end
        end
    else
        logVerbose("WARNING: Could not find Toolbar or QuickSlot Component directly on the player object.")
    end
end

function Hotbar.Clear(player)
end

return Hotbar
