DHUD = DHUD or {}
DHUD.Version = "1.0.24"

if not DubzLib and file.Exists("autorun/dubzframework.lua", "LUA") then
    include("autorun/dubzframework.lua")
end

if not DubzLib then
    local message = "[DHUD] DubzFramework is required. Install/subscribe to DubzFramework and mount it before Dubz HUD."
    if SERVER then
        print(message)
    else
        MsgC(Color(232, 84, 84), message .. "\n")
    end

    return
end

if DubzLib and DubzLib.RegisterAddon then
    DubzLib.RegisterAddon("dhud", {
        Name = "Dubz HUD",
        Version = DHUD.Version,
        Author = "Dubz",
        Description = "Main HUD and UI suite built on DubzFramework."
    })
end

DHUD.ClientFiles = {
    "dubz_hud/core/cl_config.lua",
    "dubz_hud/core/cl_language.lua",
    "dubz_hud/core/cl_theme.lua",
    "dubz_hud/core/cl_icons.lua",
    "dubz_hud/hud/cl_hud_card.lua",
    "dubz_hud/hud/cl_hud_bar.lua",
    "dubz_hud/hud/cl_status.lua",
    "dubz_hud/hud/cl_doors.lua",
    "dubz_hud/hud/cl_door_options.lua",
    "dubz_hud/hud/cl_laws.lua",
    "dubz_hud/hud/cl_overhead.lua",
    "dubz_hud/hud/cl_ammo.lua",
    "dubz_hud/hud/cl_weapon_selector.lua",
    "dubz_hud/hud/cl_notifications.lua",
    "dubz_hud/hud/cl_vote.lua",
    "dubz_hud/hud/cl_darkrp_menus.lua",
    "dubz_hud/hud/cl_animations.lua",
    "dubz_hud/hud/cl_scoreboard.lua",
    "dubz_hud/hud/cl_hud.lua",
    "dubz_hud/hud/cl_voice.lua",
    "dubz_hud/hud/cl_deathnotice.lua",
    "dubz_hud/hud/cl_deathscreen.lua",
    "dubz_hud/hud/cl_motd.lua",
    "dubz_hud/hud/cl_placement.lua",
    "dubz_hud/hud/cl_vehicle.lua",
    "dubz_hud/hud/cl_connection.lua",
    "dubz_hud/hud/cl_config_menu.lua"
}

if SERVER then
    for _, path in ipairs(DHUD.ClientFiles) do
        AddCSLuaFile(path)
    end

    include("dubz_hud/server/sv_atmos_clock.lua")
    include("dubz_hud/server/sv_door_admin.lua")
    include("dubz_hud/server/sv_scoreboard.lua")
    include("dubz_hud/server/sv_config.lua")
    include("dubz_hud/server/sv_connection.lua")

    print("[DHUD] Sent client HUD files.")
    return
end

function DHUD.TrackPanel(pnl)
    if not IsValid(pnl) then return pnl end

    DHUD.LivePanels = DHUD.LivePanels or {}
    DHUD.LivePanels[#DHUD.LivePanels + 1] = pnl
    pnl.DHUDLivePanel = true

    return pnl
end

function DHUD.CleanupLivePanels()
    for _, pnl in ipairs(DHUD.LivePanels or {}) do
        if IsValid(pnl) then
            pnl:Remove()
        end
    end

    DHUD.LivePanels = {}
end

function DHUD.AddCommand(name, callback)
    if concommand.Remove then
        concommand.Remove(name)
    end

    concommand.Add(name, callback)
end

function DHUD.Reload()
    DHUD.CleanupLivePanels()

    for _, path in ipairs(DHUD.ClientFiles) do
        include(path)
    end

    print("[DHUD] Client HUD reloaded.")
end

DHUD.Reload()
