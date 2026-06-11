local Storage = {}

local function getInventory(actor)
    if not actor or not actor:IsValid() then
        return nil
    end
    local function try(name)
        local ok, v = pcall(function()
            return actor[name]
        end)
        if ok and v and v:IsValid() then
            return v
        end
        return nil
    end
    return try("Inventory") or try("UWEInventory") or try("InventoryComponent")
end

function Storage.ApplyLocker(locker, rows, cols)
    if not locker or not locker:IsValid() then
        return
    end
    local inv = getInventory(locker)
    if inv and inv:IsValid() then
        local targetSlots = rows * cols
        if inv.Columns ~= cols or inv.MaxItems ~= targetSlots then
            pcall(function()
                inv:SetMaxItems(targetSlots)
            end)
            inv.MaxItems = targetSlots
            inv.Columns = cols
        end
    end
end

function Storage.ApplyStation(station, rows, cols)
    if not station or not station:IsValid() then
        return
    end
    local targetSlots = rows * cols
    local inputComp = station.InputInventory
    local outputComp = station.OutputInventory
    if inputComp and inputComp:IsValid() then
        if inputComp.Columns ~= cols or inputComp.MaxItems ~= targetSlots then
            pcall(function()
                inputComp:SetMaxItems(targetSlots)
            end)
            inputComp.MaxItems = targetSlots
            inputComp.Columns = cols
        end
    end
    if outputComp and outputComp:IsValid() then
        if outputComp.Columns ~= cols or outputComp.MaxItems ~= targetSlots then
            pcall(function()
                outputComp:SetMaxItems(targetSlots)
            end)
            outputComp.MaxItems = targetSlots
            outputComp.Columns = cols
        end
    end
end

return Storage
