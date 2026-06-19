local M = {}

local unpackArgs = table.unpack or unpack

function M.unwrap(value)
    if value == nil then return nil end
    if type(value) ~= "userdata" then return value end

    -- TWeakObjectPtr exposes Get/get; a null target returns nil from Get() but
    -- throws if get() is called on the expired wrapper — do not fall through.
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

function M.isValid(object)
    if object == nil then return false end
    object = M.unwrap(object)
    if object == nil then return false end
    local ok, valid = pcall(function() return object:IsValid() end)
    return ok and valid == true
end

function M.setIfPresent(object, propertyName, value)
    if not M.isValid(object) then return false end
    local ok = pcall(function() object[propertyName] = value end)
    return ok
end

function M.safeGet(object, property)
    if not M.isValid(object) then return nil end
    local ok, value = pcall(function() return object[property] end)
    return ok and value or nil
end

function M.safeIsA(actor, className)
    if not M.isValid(actor) then return false end
    local ok, result = pcall(function() return actor:IsA(className) end)
    return ok and result
end

function M.getAddress(object)
    if not M.isValid(object) then return nil end
    local ok, address = pcall(function() return object:GetAddress() end)
    return ok and address or nil
end

function M.getFullName(object)
    if not M.isValid(object) then return "" end
    local ok, name = pcall(function() return object:GetFullName() end)
    return ok and name or ""
end

function M.callIfPresent(object, functionName, ...)
    if not M.isValid(object) or M.safeGet(object, functionName) == nil then
        return false
    end
    local args = { ... }
    local ok = pcall(function()
        object[functionName](object, unpackArgs(args))
    end)
    return ok
end

function M.callIfPresentReturning(object, functionName, ...)
    if not M.isValid(object) or M.safeGet(object, functionName) == nil then
        return false, nil
    end
    local args = { ... }
    local ok, result = pcall(function()
        return object[functionName](object, unpackArgs(args))
    end)
    return ok, result
end

function M.dist3D(a, b)
    if a == nil or b == nil then return math.huge end
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function M.normalize2D(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return 0.0, 0.0 end
    return dx / len, dy / len
end

function M.normalize3D(dx, dy, dz)
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len < 0.001 then return 0.0, 0.0, 0.0 end
    return dx / len, dy / len, dz / len
end

function M.nameMatchesPattern(fullName, pattern)
    if pattern == nil then return false end
    local lowerName = tostring(fullName or ""):lower()
    local lowerPattern = tostring(pattern):lower()
    if lowerName:find(lowerPattern, 1, true) ~= nil then
        return true
    end
    local norm = lowerName:gsub("[_%s%-%.]", "")
    local normPat = lowerPattern:gsub("[_%s%-%.]", "")
    return norm:find(normPat, 1, true) ~= nil
end

return M
