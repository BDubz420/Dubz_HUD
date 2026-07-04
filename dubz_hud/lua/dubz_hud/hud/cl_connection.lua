local DHUD = DHUD
DHUD.Connection = DHUD.Connection or {}

local lastCurTime = CurTime()
local lastAdvanceReal = RealTime()
local overlayProgress = 0
local retryAt
local screenClickerEnabled = false
local overlayDismissed = false
local blurMaterial = Material("pp/blurscreen")
local lastHeartbeatReal = RealTime()
local forceUntil = 0

local function CanRunReconnectCommand()
    if game and game.SinglePlayer and game.SinglePlayer() then return false end
    return true
end

local function RunReconnectCommand(command)
    if not CanRunReconnectCommand() then return false end
    RunConsoleCommand(command)
    return true
end

local function Cfg()
    return DHUD.Config and DHUD.Config.Connection or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function Primary()
    return Colors().Warning or Colors().Agenda or Color(238, 146, 80)
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha)
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then return DubzLib.Radius(name) end
    return name == "MD" and 8 or 5
end

local function Font(name)
    if DubzLib and DubzLib.Font then return DubzLib.Font(name) end
    return "DermaDefault"
end

local function Text(text, font, x, y, col, ax, ay)
    text = DHUD.L and DHUD.L(text) or tostring(text or "")
    if DubzLib and DubzLib.Draw and DubzLib.Draw.Text then
        DubzLib.Draw.Text(text, font, x, y, col, ax, ay)
    else
        draw.SimpleText(text, font, x, y, col, ax, ay)
    end
end

local function DrawIcon(path, x, y, size, col)
    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(path, x, y, size, col)
    elseif DubzLib and DubzLib.Icon then
        DubzLib.Icon.Draw(path, x, y, size, col)
    end
end

hook.Add("Think", "DHUD.Connection.TrackCurTime", function()
    local ct = CurTime()
    if ct ~= lastCurTime then
        lastCurTime = ct
        lastAdvanceReal = RealTime()
    end
end)

net.Receive("DHUD.Connection.Heartbeat", function()
    net.ReadUInt(16)
    lastHeartbeatReal = RealTime()
end)

local function TimeoutInfoStalled(timeout)
    if not isfunction(GetTimeoutInfo) then return false end

    local ok, a, b, c, d = pcall(GetTimeoutInfo)
    if not ok then return false end
    if isbool(a) then return a end

    local values = {a, b, c, d}
    for i = 1, #values do
        local value = tonumber(values[i])
        if value and value >= timeout then
            return true
        end
    end

    return false
end

local function ResetOverlay()
    retryAt = nil
    overlayDismissed = false

    if screenClickerEnabled then
        gui.EnableScreenClicker(false)
        screenClickerEnabled = false
    end
end

local function ConnectionStalled(cfg)
    local timeout = cfg.Timeout or 6
    if RealTime() < forceUntil then return true end
    if TimeoutInfoStalled(timeout) then return true end
    if RealTime() - (lastHeartbeatReal or RealTime()) > timeout then return true end

    return RealTime() - (lastAdvanceReal or RealTime()) > timeout
end

hook.Add("HUDPaint", "DHUD.Connection.Overlay", function()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Connection == false or cfg.Enabled == false then
        overlayProgress = 0
        ResetOverlay()
        return
    end

    local stalled = ConnectionStalled(cfg)
    if stalled and not retryAt then
        retryAt = RealTime() + (cfg.RetryDelay or 30)
    elseif not stalled then
        ResetOverlay()
    end

    if stalled and overlayDismissed then
        overlayProgress = Lerp(math.Clamp(FrameTime() * 10, 0, 1), overlayProgress or 0, 0)
        if screenClickerEnabled then
            gui.EnableScreenClicker(false)
            screenClickerEnabled = false
        end
        return
    end

    overlayProgress = Lerp(math.Clamp(FrameTime() * 8, 0, 1), overlayProgress or 0, stalled and 1 or 0)
    if overlayProgress <= 0.01 then return end
    if overlayProgress > 0.65 and not screenClickerEnabled then
        gui.EnableScreenClicker(true)
        screenClickerEnabled = true
    end

    local alpha = math.floor(255 * overlayProgress)
    local sw, sh = ScrW(), ScrH()
    local accent = Primary()
    local ww = cfg.WindowWidth or 420
    local wh = cfg.WindowHeight or 198
    local x = sw * math.Clamp(tonumber(cfg.XPercent) or 0.5, 0.05, 0.95) - ww * 0.5
    local y = sh * math.Clamp(tonumber(cfg.YPercent) or 0.5, 0.05, 0.95) - wh * 0.5

    if cfg.Blur ~= false and render and render.UpdateScreenEffectTexture then
        render.UpdateScreenEffectTexture()
        surface.SetMaterial(blurMaterial)
        surface.SetDrawColor(255, 255, 255, math.min(alpha, 160))
        for i = 1, 3 do
            surface.DrawTexturedRect(0, 0, sw, sh)
        end
    end

    draw.RoundedBox(0, 0, 0, sw, sh, Color(0, 0, 0, (cfg.OverlayAlpha or 205) * overlayProgress))
    draw.RoundedBox(Radius("MD"), x, y, ww, wh, WithAlpha(accent, alpha))
    draw.RoundedBox(Radius("MD"), x + 6, y - 1, ww - 6, wh + 2, Color(27, 28, 33, alpha))
    draw.RoundedBox(Radius("SM"), x + 28, y + 36, 64, 64, WithAlpha(accent, 42 * overlayProgress))
    DrawIcon(cfg.Icon or "communication/no_connection", x + 44, y + 52, 32, WithAlpha(accent, alpha))
    Text(cfg.Title or "Connection Interrupted", Font("Header"), x + 112, y + 42, WithAlpha(color_white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    Text(cfg.Subtitle or "Trying to reconnect to the server...", Font("Body"), x + 112, y + 76, WithAlpha(Color(190, 190, 196), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.RoundedBox(Radius("SM"), x + ww - 40, y + 14, 24, 24, WithAlpha(Color(232, 84, 84), 26 * overlayProgress))
    Text("x", Font("Body"), x + ww - 28, y + 26, WithAlpha(Color(232, 84, 84), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local seconds = math.max(0, math.ceil((retryAt or RealTime()) - RealTime()))
    local autoRetry = cfg.AutoRetry ~= false and CanRunReconnectCommand()
    local retryText = not autoRetry and (DHUD.L and DHUD.L("Waiting for server response") or "Waiting for server response") or (DHUD.LFormat and DHUD.LFormat("Auto reconnect in {seconds}s", "Auto reconnect in {seconds}s", {seconds = seconds}) or ("Auto reconnect in " .. seconds .. "s"))
    Text(retryText, Font("Small"), x + 112, y + 108, WithAlpha(accent, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local btnY = y + wh - 44
    local btnH = 28
    local retryW = 118
    draw.RoundedBox(Radius("SM"), x + ww - retryW - 28, btnY, retryW, btnH, WithAlpha(accent, 38 * overlayProgress))
    Text("Retry Now", Font("Small"), x + ww - retryW * 0.5 - 28, btnY + btnH * 0.5 - 1, WithAlpha(accent, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if cfg.ShowDisconnect ~= false then
        local discW = 104
        draw.RoundedBox(Radius("SM"), x + 28, btnY, discW, btnH, WithAlpha(Color(232, 84, 84), 34 * overlayProgress))
        Text("Disconnect", Font("Small"), x + 28 + discW * 0.5, btnY + btnH * 0.5 - 1, WithAlpha(Color(232, 84, 84), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if autoRetry and retryAt and RealTime() >= retryAt then
        retryAt = RealTime() + (cfg.RetryDelay or 30)
        RunReconnectCommand("retry")
    end
end)

hook.Add("GUIMousePressed", "DHUD.Connection.ClickActions", function(code)
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if code ~= MOUSE_LEFT or systems.Connection == false or cfg.Enabled == false then return end
    if overlayProgress <= 0.5 then return end

    local sw, sh = ScrW(), ScrH()
    local ww = cfg.WindowWidth or 420
    local wh = cfg.WindowHeight or 198
    local x = sw * math.Clamp(tonumber(cfg.XPercent) or 0.5, 0.05, 0.95) - ww * 0.5
    local y = sh * math.Clamp(tonumber(cfg.YPercent) or 0.5, 0.05, 0.95) - wh * 0.5
    local mx, my = gui.MousePos()
    local btnY = y + wh - 44

    if mx >= x + ww - 40 and mx <= x + ww - 16 and my >= y + 14 and my <= y + 38 then
        overlayDismissed = true
        if screenClickerEnabled then
            gui.EnableScreenClicker(false)
            screenClickerEnabled = false
        end
        return true
    end

    if mx >= x + ww - 146 and mx <= x + ww - 28 and my >= btnY and my <= btnY + 28 then
        RunReconnectCommand("retry")
        return true
    end

    if cfg.ShowDisconnect ~= false and mx >= x + 28 and mx <= x + 132 and my >= btnY and my <= btnY + 28 then
        RunReconnectCommand("disconnect")
        return true
    end
end)
