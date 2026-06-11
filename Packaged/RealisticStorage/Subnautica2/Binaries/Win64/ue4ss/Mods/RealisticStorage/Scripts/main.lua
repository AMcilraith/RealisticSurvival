local PlayerInventory = require("PlayerInventory")
local Hotbar = require("Hotbar")
local PassiveBiomods = require("PassiveBiomods")
local Storage = require("Storage")

local activeLockers = {}
local activeStations = {}
local activePlayers = {}

setmetatable(activeLockers, {
    __mode = "k"
})
setmetatable(activeStations, {
    __mode = "k"
})
setmetatable(activePlayers, {
    __mode = "k"
})

local STORAGE_MAPPING = {{
    paths = {"/Game/Blueprints/BaseBuilding/BP_Locker_Floor.BP_Locker_Floor_C",
             "/Game/Blueprints/Basebuilding/BP_Locker_Floor.BP_Locker_Floor_C"},
    rows = 9,
    cols = 5
}, {
    paths = {"/Game/Blueprints/BaseBuilding/BP_Locker_Wall.BP_Locker_Wall_C",
             "/Game/Blueprints/Basebuilding/BP_Locker_Wall.BP_Locker_Wall_C"},
    rows = 7,
    cols = 5
}, {
    paths = {"/Game/Blueprints/BaseBuilding/BP_Storage_Cache.BP_Storage_Cache_C",
             "/Game/Blueprints/Basebuilding/BP_Storage_Cache.BP_Storage_Cache_C",
             "/Game/Blueprints/BaseBuilding/BP_StorageCache.BP_StorageCache_C",
             "/Game/Blueprints/Basebuilding/BP_StorageCache.BP_StorageCache_C"},
    rows = 8,
    cols = 5
}, {
    paths = {"/Game/Blueprints/BaseBuilding/Tailing/BP_Tailing_Chest.BP_Tailing_Chest_C",
             "/Game/Blueprints/Basebuilding/Tailing/BP_Tailing_Chest.BP_Tailing_Chest_C",
             "/Game/Blueprints/BaseBuilding/BP_Tailing_Chest.BP_Tailing_Chest_C",
             "/Game/Blueprints/Basebuilding/BP_Tailing_Chest.BP_Tailing_Chest_C"},
    rows = 6,
    cols = 5
}, {
    paths = {"/Game/Blueprints/Items/Deployables/BP_FloatingLocker_Carryable.BP_FloatingLocker_Carryable_C",
             "/Game/Blueprints/Items/Deployables/BP_FloatingLockerCarryable.BP_FloatingLockerCarryable_C"},
    rows = 5,
    cols = 5
}, {
    paths = {"/Game/Blueprints/Items/Deployables/BP_HeavyFloatingLocker_Carryable.BP_HeavyFloatingLocker_Carryable_C",
             "/Game/Blueprints/Items/Deployables/BP_HeavyFloatingLockerCarryable.BP_HeavyFloatingLockerCarryable_C",
             "/Game/Blueprints/Items/Deployables/BP_HeavyPortableLocker.BP_HeavyPortableLocker_C"},
    rows = 6,
    cols = 5
}, {
    paths = {"/Game/Blueprints/Items/Deployables/BP_SuperHeavyFloatingLocker_Carryable.BP_SuperHeavyFloatingLocker_Carryable_C",
             "/Game/Blueprints/Items/Deployables/BP_SuperHeavyFloatingLockerCarryable.BP_SuperHeavyFloatingLockerCarryable_C",
             "/Game/Blueprints/Items/Deployables/BP_SuperheavyPortableLocker.BP_SuperheavyPortableLocker_C"},
    rows = 7,
    cols = 5
}, {
    paths = {"/Game/Blueprints/Vehicle/Tadpole/BP_Haul_TadpoleChassis.BP_Haul_TadpoleChassis_C"},
    rows = 10,
    cols = 5
}, {
    paths = {"/Game/Blueprints/BaseBuilding/BP_Bioreactor.BP_Bioreactor_C",
             "/Game/Blueprints/Basebuilding/BP_Bioreactor.BP_Bioreactor_C"},
    rows = 2,
    cols = 5
}}

local STATION_MAPPING = {{
    paths = {"/Game/Blueprints/Fabricator/BP_ProcessorStation.BP_ProcessorStation_C",
             "/Game/Blueprints/Crafting/BP_ProcessorStation.BP_ProcessorStation_C"},
    rows = 4,
    cols = 5
}}

NotifyOnNewObject("/Game/Blueprints/Core/BP_SN2PlayerCharacter.BP_SN2PlayerCharacter_C", function(player)
    if not player or not player:IsValid() then
        return
    end
    activePlayers[player] = true
    PlayerInventory.Apply(player)
    Hotbar.Apply(player)
    PassiveBiomods.Apply(player)
end)

local pendingLockers = {}
local pendingStations = {}

for _, entry in ipairs(STORAGE_MAPPING) do
    for _, path in ipairs(entry.paths) do
        NotifyOnNewObject(path, function(CreatedObject)
            if not CreatedObject or not CreatedObject:IsValid() then
                return
            end
            Storage.ApplyLocker(CreatedObject, entry.rows, entry.cols)
            table.insert(pendingLockers, {
                obj = CreatedObject,
                entry = entry,
                ticks = 0
            })
            activeLockers[CreatedObject] = entry
        end)
    end
end

for _, entry in ipairs(STATION_MAPPING) do
    for _, path in ipairs(entry.paths) do
        NotifyOnNewObject(path, function(CreatedObject)
            if not CreatedObject or not CreatedObject:IsValid() then
                return
            end
            Storage.ApplyStation(CreatedObject, entry.rows, entry.cols)
            table.insert(pendingStations, {
                obj = CreatedObject,
                entry = entry,
                ticks = 0
            })
            activeStations[CreatedObject] = entry
        end)
    end
end

LoopAsync(1000, function()
    for player, _ in pairs(activePlayers) do
        if player:IsValid() then
            PlayerInventory.Apply(player)
            Hotbar.Apply(player)
            PassiveBiomods.Apply(player)
        else
            activePlayers[player] = nil
            PlayerInventory.Clear(player)
            Hotbar.Clear(player)
            PassiveBiomods.Clear(player)
        end
    end
    if #pendingLockers > 0 then
        for i = #pendingLockers, 1, -1 do
            local data = pendingLockers[i]
            data.ticks = data.ticks + 1
            if data.ticks >= 2 then
                local locker = data.obj
                if locker and locker:IsValid() then
                    Storage.ApplyLocker(locker, data.entry.rows, data.entry.cols)
                end
                table.remove(pendingLockers, i)
            end
        end
    end
    if #pendingStations > 0 then
        for i = #pendingStations, 1, -1 do
            local data = pendingStations[i]
            data.ticks = data.ticks + 1
            if data.ticks >= 2 then
                local station = data.obj
                if station and station:IsValid() then
                    Storage.ApplyStation(station, data.entry.rows, data.entry.cols)
                end
                table.remove(pendingStations, i)
            end
        end
    end
    return false
end)
