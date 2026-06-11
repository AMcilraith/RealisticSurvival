local config = require("config")

local PassiveBiomods = {}

local UNLOCKED_STATE = 1

local INCREASE_TAG = { TagName = FName("EventTracker.IncreasePassiveBiomodSlots") }
local PERMANENT_TAG = { TagName = FName("PermanentUpgrades.PassiveBiomodSlots") }

local lastModSlotsGranted = 0

local function logVerbose(message)
    if config.VerboseLogging then
        print(string.format("[RealisticStorage:PassiveBiomods] %s", message))
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
    local tracker = fn(ctx, ctx)
    if tracker and tracker:IsValid() then
        return tracker
    end
    return nil
end

local function getPlayerState(player)
    if not player or not player:IsValid() then
        return nil
    end
    local ok, ps = pcall(function()
        return player.PlayerState
    end)
    if ok and ps and ps:IsValid() then
        return ps
    end
    ok, ps = pcall(function()
        return player:GetPlayerState()
    end)
    if ok and ps and ps:IsValid() then
        return ps
    end
    return nil
end

local function isCreatureBioScan(scanData)
    if not config.ScansPerCreatureOnly then
        return true
    end
    local ok, fullName = pcall(function()
        return scanData:GetFullName()
    end)
    if not ok or not fullName then
        return false
    end
    return string.find(fullName, "/Game/Data/BioScans/", 1, true) ~= nil
end

local function countUnlockedCreatureBioScans(playerState)
    if not playerState or not playerState:IsValid() then
        return 0
    end

    local getUnlockStateFn = StaticFindObject("/Script/UWEBiomods.UWEBioScanData:GetUnlockState")
    if not getUnlockStateFn or not getUnlockStateFn:IsValid() then
        return 0
    end

    local scans = FindAllOf("UWEBioScanData")
    if not scans then
        return 0
    end

    local unlocked = 0
    for _, scanData in ipairs(scans) do
        if scanData and scanData:IsValid() and isCreatureBioScan(scanData) then
            local ok, state = pcall(function()
                return scanData:GetUnlockState(playerState)
            end)
            if ok and state == UNLOCKED_STATE then
                unlocked = unlocked + 1
            end
        end
    end
    return unlocked
end

local function milestoneSlotsForScanCount(scanCount)
    local slots = 0
    for _, threshold in ipairs(config.PassiveBiomodMilestones) do
        if scanCount >= threshold then
            slots = slots + 1
        end
    end
    return math.min(slots, config.MaxModPassiveSlots)
end

function PassiveBiomods.Apply(player)
    if not player or not player:IsValid() then
        return
    end

    local playerState = getPlayerState(player)
    if not playerState then
        return
    end

    local tracker = getTracker()
    if not tracker then
        return
    end

    local scanCount = countUnlockedCreatureBioScans(playerState)
    local modSlots = milestoneSlotsForScanCount(scanCount)

    if modSlots > lastModSlotsGranted then
        local delta = modSlots - lastModSlotsGranted
        tracker:Notify(INCREASE_TAG, PERMANENT_TAG, delta)
        logVerbose(string.format(
            "Granted %d passive biomod slot(s) (%d creature bioscans, mod total %d).",
            delta, scanCount, modSlots))
        lastModSlotsGranted = modSlots
    end
end

function PassiveBiomods.Clear(player)
end

return PassiveBiomods
