local ScanHooks = {}

local UWEScanData
local UWEScanData_GetScanDataForActor

pcall(function()
    UWEScanData = StaticFindObject("/Script/UWEScanner.Default__UWEScanData")
    UWEScanData_GetScanDataForActor = StaticFindObject("/Script/UWEScanner.UWEScanData:GetScanDataForActor")
end)

local function unwrap(value)
    if value == nil then
        return nil
    end

    local ok, got = pcall(function()
        if value.get then
            return value:get()
        end
        return nil
    end)
    if ok and got ~= nil then
        return got
    end

    return value
end

local function isValid(obj)
    if obj == nil then
        return false
    end

    local ok, result = pcall(function()
        return obj:IsValid()
    end)
    return ok and result == true
end

local function patchScanData(patcher, config, scanData)
    if not isValid(scanData) or patcher.isPatched(scanData) then
        return
    end
    patcher.apply(config, scanData)
end

local function patchFromActor(patcher, config, actorParam)
    local actor = unwrap(actorParam)
    if not isValid(actor) or not UWEScanData or not UWEScanData_GetScanDataForActor then
        return
    end

    local ok, scanData = pcall(function()
        return UWEScanData_GetScanDataForActor(UWEScanData, actor)
    end)
    if ok then
        patchScanData(patcher, config, scanData)
    end
end

function ScanHooks.install(config, patcher)
    -- Do not hook GetScanDataForActor itself; calling it from that hook re-enters every scan tick.

    local progressHook = "/Script/UWEScanner.UWEScannedActorsComponent:GetScanCountTowardsCompletion"
    if StaticFindObject(progressHook) then
        RegisterHook(progressHook, function(_, scanDataParam)
            patchScanData(patcher, config, unwrap(scanDataParam))
        end)
    end

    local progressForPlayerHook =
        "/Script/UWEScanner.UWEScannedActorsComponent:GetActorInstanceScannedProgressForPlayer"
    if StaticFindObject(progressForPlayerHook) then
        RegisterHook(progressForPlayerHook, function(_, actorParam)
            patchFromActor(patcher, config, actorParam)
        end)
    end
end

return ScanHooks
