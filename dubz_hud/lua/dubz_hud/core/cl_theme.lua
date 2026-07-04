local DHUD = DHUD
DHUD.Theme = DHUD.Theme or {}

local function SyncDubzLibTheme()
    if not DubzLib or not DubzLib.UI or not DubzLib.UI.RegisterThemeFromColors then return end
    if not DHUD.Config or not DHUD.Config.Colors then return end

    DubzLib.UI.RegisterThemeFromColors("dhud", "Dubz HUD", DHUD.Config.Colors)

    if istable(DHUD.Config.Radius) and DubzLib.Themes and DubzLib.Themes.dhud then
        DubzLib.Themes.dhud.Radius = table.Copy(DHUD.Config.Radius)
    end
end

function DHUD.Theme.Sync()
    DHUD.Theme.Normalize()
    SyncDubzLibTheme()
end

local redAccent = Color(190, 86, 82)
local redBg = Color(31, 25, 25)
local redPanel = Color(40, 32, 32)
local redField = Color(33, 27, 27)

local function IsColorNear(col, r, g, b)
    return istable(col)
        and math.abs((col.r or 0) - r) <= 2
        and math.abs((col.g or 0) - g) <= 2
        and math.abs((col.b or 0) - b) <= 2
end

function DHUD.Theme.Normalize()
    if not DHUD.Config or not istable(DHUD.Config.Colors) then return end

    local colors = DHUD.Config.Colors
    local accentKeys = {
        "Agenda", "Clock", "Identity", "HUDAccent", "VoiceAccent",
        "ScoreboardAccent", "MOTDAccent", "NotificationAccent",
        "ConfigAccent", "LawsAccent", "DoorAccent", "VoteAccent",
        "VehicleAccent"
    }

    for _, key in ipairs(accentKeys) do
        if IsColorNear(colors[key], 91, 201, 121) then
            colors[key] = Color(redAccent.r, redAccent.g, redAccent.b)
        end
    end

    local bgKeys = {"Background", "HUDBackground", "VoiceBackground", "ScoreboardBackground", "MOTDBackground", "NotificationBackground", "ConfigBackground", "LawsBackground", "DoorBackground", "VoteBackground", "VehicleBackground"}
    for _, key in ipairs(bgKeys) do
        if IsColorNear(colors[key], 27, 28, 33) then
            colors[key] = Color(redBg.r, redBg.g, redBg.b)
        end
    end

    local panelKeys = {"Background2", "ScoreboardPanel", "MOTDCardBackground", "ConfigPanel"}
    for _, key in ipairs(panelKeys) do
        if IsColorNear(colors[key], 32, 33, 38) or IsColorNear(colors[key], 38, 39, 46) then
            colors[key] = Color(redPanel.r, redPanel.g, redPanel.b)
        end
    end

    if IsColorNear(colors.ConfigField, 24, 25, 30) then
        colors.ConfigField = Color(redField.r, redField.g, redField.b)
    end
end

hook.Add("DHUD.ConfigLoaded", "DHUD.Theme.SyncDubzLib", DHUD.Theme.Sync)
hook.Add("OnReloaded", "DHUD.Theme.SyncDubzLib", DHUD.Theme.Sync)
timer.Simple(0, DHUD.Theme.Sync)
