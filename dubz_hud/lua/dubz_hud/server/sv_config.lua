local DHUD = DHUD
DHUD.ConfigSync = DHUD.ConfigSync or {}

util.AddNetworkString("DHUD.Config.Request")
util.AddNetworkString("DHUD.Config.Data")
util.AddNetworkString("DHUD.Config.Save")
util.AddNetworkString("DHUD.Config.Notice")

local configPath = "dhud/system_config.txt"
local savedConfig = {}
local MAX_CONFIG_BITS = 512 * 1024
local REQUEST_COOLDOWN = 1
local SAVE_COOLDOWN = 1.5

local function IsConfigAdmin(ply)
    return not IsValid(ply) or ply:IsAdmin() or ply:IsSuperAdmin()
end

local function RateLimited(ply, key, cooldown)
    if not IsValid(ply) then return false end

    local field = "DHUD_" .. key
    local nextAllowed = tonumber(ply[field] or 0) or 0
    if CurTime() < nextAllowed then return true end

    ply[field] = CurTime() + cooldown
    return false
end

local function ReadConfig()
    if not file.Exists(configPath, "DATA") then
        savedConfig = {}
        return
    end

    local raw = file.Read(configPath, "DATA")
    local ok, decoded = pcall(function()
        return util.JSONToTable(raw or "")
    end)

    savedConfig = ok and istable(decoded) and decoded or {}
end

local function SaveConfig(tbl)
    file.CreateDir("dhud")
    savedConfig = istable(tbl) and tbl or {}
    file.Write(configPath, util.TableToJSON(savedConfig, true))
end

local function SendConfig(ply)
    net.Start("DHUD.Config.Data")
    net.WriteString(util.TableToJSON(savedConfig or {}) or "{}")

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

local function Notice(ply, text, kind)
    if not IsValid(ply) then return end

    net.Start("DHUD.Config.Notice")
    net.WriteString(tostring(text or ""))
    net.WriteString(tostring(kind or "hint"))
    net.Send(ply)
end

ReadConfig()

net.Receive("DHUD.Config.Request", function(_, ply)
    if not IsValid(ply) then return end
    if RateLimited(ply, "ConfigRequestCooldown", REQUEST_COOLDOWN) then return end

    SendConfig(ply)
end)

net.Receive("DHUD.Config.Save", function(length, ply)
    if not IsConfigAdmin(ply) then return end
    if length > MAX_CONFIG_BITS then
        Notice(ply, "Config payload is too large.", "warning")
        return
    end
    if RateLimited(ply, "ConfigSaveCooldown", SAVE_COOLDOWN) then return end

    local ok, incoming = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    if not ok then return end
    if not istable(incoming) then return end

    SaveConfig(incoming)
    SendConfig()
    Notice(ply, "Dubz HUD config saved.", "success")
end)
