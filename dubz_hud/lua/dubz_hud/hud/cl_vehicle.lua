local DHUD = DHUD
DHUD.VehicleHUD = DHUD.VehicleHUD or {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Vehicle or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function SystemEnabled()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    return systems.Vehicle ~= false and Cfg().Enabled ~= false
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha)
end

local function DrawText(text, font, x, y, col, ax, ay)
    text = DHUD.L and DHUD.L(text) or tostring(text or "")
    if DubzLib and DubzLib.Draw and DubzLib.Draw.Text then
        DubzLib.Draw.Text(text, font, x, y, col, ax, ay)
        return
    end

    draw.SimpleText(text, font or "DermaDefault", x, y, col, ax, ay)
end

local function DrawIcon(path, x, y, size, col)
    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(path, x, y, size, col)
    elseif DubzLib and DubzLib.Icon then
        DubzLib.Icon.Draw(path, x, y, size, col)
    end
end

local function VehicleHealth(ent)
    if not IsValid(ent) then return nil end
    if isfunction(ent.VC_getHealth) then return tonumber(ent:VC_getHealth()) end
    if isfunction(ent.GetVehicleHealth) then return tonumber(ent:GetVehicleHealth()) end
    if isfunction(ent.Health) then return tonumber(ent:Health()) end
    return nil
end

local function VehicleFuel(ent)
    if not IsValid(ent) then return nil end
    if isfunction(ent.VC_getFuel) then return tonumber(ent:VC_getFuel()) end
    if isfunction(ent.GetFuel) then return tonumber(ent:GetFuel()) end
    if ent.VC_fuel ~= nil then return tonumber(ent.VC_fuel) end
    return nil
end

local function Speed(ent, unit)
    local mph = ent:GetVelocity():Length() * 0.0568182
    if string.lower(tostring(unit or "mph")) == "kph" then
        return math.floor(mph * 1.60934 + 0.5), "KPH"
    end

    return math.floor(mph + 0.5), "MPH"
end

local function KeyDown(ply, key)
    return IsValid(ply) and key ~= nil and isfunction(ply.KeyDown) and ply:KeyDown(key)
end

local function GearLabel(ply, ent)
    if KeyDown(ply, IN_BACK) then
        DHUD.VehicleHUD.LastGear = "R"
        return "R"
    end

    if KeyDown(ply, IN_FORWARD) then
        DHUD.VehicleHUD.LastGear = "D"
        return "D"
    end

    if not IsValid(ent) or ent:GetVelocity():Length() < 8 then
        DHUD.VehicleHUD.LastGear = nil
        return "N"
    end

    return DHUD.VehicleHUD.LastGear or "D"
end

local function RPMFraction(ply, ent, speed)
    local rpm
    if IsValid(ent) then
        if isfunction(ent.GetRPM) then rpm = tonumber(ent:GetRPM()) end
        if not rpm and isfunction(ent.getRPM) then rpm = tonumber(ent:getRPM()) end
    end

    if rpm then
        local maxRPM = 8000
        if IsValid(ent) and isfunction(ent.GetLimitRPM) then maxRPM = tonumber(ent:GetLimitRPM()) or maxRPM end
        return math.Clamp(rpm / math.max(maxRPM, 1), 0, 1)
    end

    local throttle = (KeyDown(ply, IN_FORWARD) or KeyDown(ply, IN_BACK)) and 0.22 or 0
    return math.Clamp((tonumber(speed) or 0) / 120 + throttle, 0, 1)
end

local function DrawGauge(x, y, w, h, label, value, suffix, col, muted, bg)
    local hasValue = value ~= nil
    local frac = hasValue and math.Clamp((tonumber(value) or 0) / 100, 0, 1) or 0
    local text = hasValue and (tostring(math.Clamp(math.floor(value + 0.5), 0, 100)) .. (suffix or "")) or "--"

    draw.RoundedBox(5, x, y + 18, w, h, WithAlpha(bg, 210))
    draw.RoundedBox(5, x, y + 18, math.max(4, w * frac), h, col)
    DrawText(label, DubzLib.Font and DubzLib.Font("Small") or "DermaDefault", x, y, muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawText(text, DubzLib.Font and DubzLib.Font("Small") or "DermaDefault", x + w, y, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

hook.Add("HUDPaint", "DHUD.VehicleHUD", function()
    if not SystemEnabled() then return end
    if not DHUD.Config or not DubzLib then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:InVehicle() then return end

    local veh = ply:GetVehicle()
    if not IsValid(veh) then return end

    local cfg = Cfg()
    local colors = Colors()
    local w = cfg.Width or 320
    local h = math.max(tonumber(cfg.Height) or 132, 112)
    local x = ScrW() - w - (cfg.RightPadding or 24)
    local y = ScrH() - h - (cfg.BottomPadding or 92)
    local radius = DubzLib.Radius and DubzLib.Radius("MD") or 8
    local accent = colors.VehicleAccent or colors.HUDAccent or Color(190, 86, 82)
    local bg = colors.VehicleBackground or colors.HUDBackground or colors.Background or Color(31, 25, 25)
    local panel = colors.Background2 or Color(40, 32, 32)
    local fg = colors.Text or color_white
    local muted = colors.Muted or Color(176, 176, 184)

    if cfg.Shadow ~= false and DubzLib.Draw and DubzLib.Draw.Shadow then
        DubzLib.Draw.Shadow(x, y, w, h, radius, 90)
    end

    draw.RoundedBox(radius, x, y, w, h, bg)
    draw.RoundedBox(radius, x, y, cfg.AccentWidth or 5, h, accent)
    draw.RoundedBox(radius, x + 12, y + 14, 52, 52, WithAlpha(panel, cfg.InnerAlpha or 235))

    local speed, unit = Speed(veh, cfg.Unit)
    local gear = cfg.ShowGear ~= false and GearLabel(ply, veh) or nil
    if gear then
        DrawText(gear, DubzLib.Font and DubzLib.Font("Title") or "DermaLarge", x + 38, y + 40, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        DrawIcon(cfg.Icon or "misc/directions_run", x + 26, y + 28, 24, accent)
    end

    DrawText(tostring(speed), DubzLib.Font and DubzLib.Font("Title") or "DermaLarge", x + 78, y + 13, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawText(unit, DubzLib.Font and DubzLib.Font("Small") or "DermaDefault", x + 80, y + 50, muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local health = cfg.ShowHealth ~= false and VehicleHealth(veh) or nil
    local fuel = cfg.ShowFuel ~= false and VehicleFuel(veh) or nil

    if cfg.ShowRPM ~= false then
        local rpmFrac = RPMFraction(ply, veh, speed)
        local rpmX = x + 12
        local rpmY = y + 84
        local rpmW = w - 24
        draw.RoundedBox(4, rpmX, rpmY, rpmW, 8, WithAlpha(panel, 225))
        draw.RoundedBox(4, rpmX, rpmY, math.max(5, rpmW * rpmFrac), 8, accent)
        DrawText("RPM", DubzLib.Font and DubzLib.Font("Small") or "DermaDefault", rpmX, rpmY - 18, muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local gaugeY = y + h - 34
    local gaugeW = math.floor((w - 34) * 0.5)
    if cfg.ShowHealth ~= false then
        DrawGauge(x + 12, gaugeY, gaugeW, 7, DHUD.T and DHUD.T("vehicle.health", "Health") or "Health", health, "", colors.Health or Color(232, 84, 84), muted, panel)
    end

    if cfg.ShowFuel ~= false then
        DrawGauge(x + 22 + gaugeW, gaugeY, gaugeW, 7, DHUD.T and DHUD.T("vehicle.fuel", "Fuel") or "Fuel", fuel, "%", colors.Gold or Color(221, 177, 74), muted, panel)
    end
end)
