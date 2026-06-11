local PlayerInventory = {}

local VERBOSE_LOGGING = false

local INV_START = 15
local INV_MAX = 35
local INV_INC = 5
local INV_UPG_MAX = 4

local function logVerbose(message)
    if VERBOSE_LOGGING then
        print(string.format("[PlayerInventoryMod] %s", message))
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
            if val >= INV_INC then
                -- Handle case where the tracker logs raw slot counts (5, 10, 15...)
                count = math.floor(val / INV_INC)
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
        if ok and v and v:IsValid() then
            return v
        end
        return nil
    end
    return try("Inventory") or try("UWEInventory") or try("InventoryComponent")
end

function PlayerInventory.Apply(player)
    if not player or not player:IsValid() then
        return
    end

    local currentTier = math.max(0, math.floor(getPlayerInventoryUpgradeCount(player) or 0))
    local cappedTier = math.min(currentTier, INV_UPG_MAX)
    local invTarget = math.min(INV_START + (cappedTier * INV_INC), INV_MAX)

    local invComp = getInventoryComponent(player)
    if invComp and invComp:IsValid() then
        if invComp.MaxItems ~= invTarget then
            logVerbose(string.format(
                "Upgrade Event! Force shifting layout size from %d to %d slots (Tier %d detected).", invComp.MaxItems,
                invTarget, cappedTier))
            pcall(function()
                invComp:SetMaxItems(invTarget)
            end)
            invComp.MaxItems = invTarget
        end
    end
end

function PlayerInventory.Clear(player)
end

return PlayerInventory
