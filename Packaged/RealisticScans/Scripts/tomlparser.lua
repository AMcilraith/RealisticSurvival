-- TOML parser for RealisticScans blueprint files.
local M = {}

local function trim(s)
    return (s:match("^%s*(.-)%s*$"))
end

local function parseValue(raw)
    raw = trim(raw)
    if raw == "" then
        return ""
    end
    if raw == "true" then
        return true
    end
    if raw == "false" then
        return false
    end
    if raw:sub(1, 1) == '"' and raw:sub(-1) == '"' then
        return raw:sub(2, -2):gsub('\\"', '"'):gsub("\\\\", "\\")
    end
    if raw:sub(1, 1) == "'" and raw:sub(-1) == "'" then
        return raw:sub(2, -2)
    end
    if raw:sub(1, 1) == "[" and raw:sub(-1) == "]" then
        local arr = {}
        local inner = raw:sub(2, -2)
        for item in inner:gmatch("[^,]+") do
            table.insert(arr, parseValue(item))
        end
        return arr
    end
    local n = tonumber(raw)
    if n then
        return n
    end
    return raw
end

function M.parse(text)
    local root = {}
    local current = root

    for line in text:gmatch("[^\r\n]+") do
        line = trim(line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local arrayHeader = line:match("^%[%[(.+)%]%]$")
            if arrayHeader then
                local key = trim(arrayHeader)
                root[key] = root[key] or {}
                local entry = {}
                table.insert(root[key], entry)
                current = entry
            else
                local section = line:match("^%[(.+)%]$")
                if section then
                    local key = trim(section)
                    root[key] = root[key] or {}
                    current = root[key]
                else
                    local key, value = line:match("^([%w_%-]+)%s*=%s*(.+)$")
                    if key and value then
                        current[key] = parseValue(value)
                    end
                end
            end
        end
    end

    return root
end

return M
