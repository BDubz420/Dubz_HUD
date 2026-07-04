local DHUD = DHUD
DHUD.Icon = DHUD.Icon or {}

local materialCache = {}

local aliases = {
    health = "misc/health_cross",
    armor = "admin/shield",
    money = "economy/attach_money",
    wallet = "darkrp/wallet",
    gunlicense = "economy/house",
    license = "economy/house",
    agenda = "darkrp/agenda",
    warning = "admin/warning",
    settings = "navigation/settings"
}

local function Normalize(path)
    if not path or path == "" then return nil end

    path = string.lower(tostring(path))
    path = string.Replace(path, "\\", "/")
    path = string.gsub(path, "^materials/", "")
    path = string.gsub(path, "%.png$", "")
    path = string.gsub(path, "^/+", "")

    return aliases[path] or path
end

local function MaterialFor(path)
    path = Normalize(path)
    if not path then return nil end

    if materialCache[path] ~= nil then
        return materialCache[path] or nil
    end

    local candidates = {
        "dubzlib/icons/" .. path .. ".png",
        "dlib/icons/" .. path .. ".png",
        path .. ".png"
    }

    for _, candidate in ipairs(candidates) do
        local mat = Material(candidate, "smooth mips")
        if mat and not mat:IsError() then
            materialCache[path] = mat
            return mat
        end
    end

    materialCache[path] = false
    return nil
end

function DHUD.Icon.Draw(path, x, y, size, color)
    path = Normalize(path)
    if not path then return false end

    if DubzLib and DubzLib.Icon and DubzLib.Icon.Draw then
        DubzLib.Icon.Draw(path, x, y, size, color)
    end

    local mat = MaterialFor(path)
    if not mat then return false end

    surface.SetMaterial(mat)
    surface.SetDrawColor(color or color_white)
    surface.DrawTexturedRect(x, y, size, size)
    return true
end

function DHUD.Icon.ClearCache()
    materialCache = {}
end
