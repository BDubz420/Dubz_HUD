local DHUD = DHUD
DHUD.DeathScreen = DHUD.DeathScreen or {}
DHUD.DeathScreen.Installed = true

local pressedLast = false
local nextRespawnTry = 0
local selectedRandomMessage
local blurMaterial = Material("pp/blurscreen")

local function Cfg()
    return DHUD.Config and DHUD.Config.DeathScreen or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function Accent()
    local colors = Colors()
    return colors.Health or colors.ScoreboardAccent or colors.Agenda or Color(190, 86, 82)
end

local function Font(name, fallback)
    if DubzLib and DubzLib.Font then return DubzLib.Font(name) end
    return fallback or "DermaDefault"
end

local function Text(value, font, x, y, col, ax, ay)
    value = DHUD.L and DHUD.L(value) or tostring(value or "")
    if DubzLib and DubzLib.Draw and DubzLib.Draw.Text then
        DubzLib.Draw.Text(value, font, x, y, col, ax, ay)
    else
        draw.SimpleText(value, font, x, y, col, ax, ay)
    end
end

local function ShadowText(value, font, x, y, col, ax, ay)
    Text(value, font, x + 2, y + 2, Color(0, 0, 0, 150), ax, ay)
    Text(value, font, x, y, col, ax, ay)
end

local function PickRandomMessage(cfg)
    if cfg.RandomMessagesEnabled ~= true then return tostring(cfg.Title or "You Died") end
    if selectedRandomMessage then return selectedRandomMessage end

    local messages = istable(cfg.RandomMessages) and cfg.RandomMessages or {}
    local clean = {}
    for _, value in ipairs(messages) do
        value = string.Trim(tostring(value or ""))
        if value ~= "" then clean[#clean + 1] = value end
    end

    selectedRandomMessage = clean[math.random(1, math.max(#clean, 1))] or tostring(cfg.Title or "You Died")
    return selectedRandomMessage
end

local keyMap = {
    space = KEY_SPACE,
    r = KEY_R,
    e = KEY_E,
    enter = KEY_ENTER,
    mouse1 = MOUSE_LEFT
}

local function KeyLabel(key)
    key = string.lower(tostring(key or "any"))
    if key == "mouse1" then return "Mouse 1" end
    if key == "space" then return "Space" end
    if key == "enter" then return "Enter" end
    if key == "any" then return "Any Key" end
    return string.upper(key)
end

local function WantedKeyDown()
    local cfg = Cfg()
    local key = string.lower(tostring(cfg.RespawnKey or "any"))

    if key == "any" then
        for code = 1, 159 do
            if input.IsKeyDown(code) then return true end
        end

        return input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT)
    end

    local mapped = keyMap[key]
    if mapped == MOUSE_LEFT then return input.IsMouseDown(MOUSE_LEFT) end
    if mapped then return input.IsKeyDown(mapped) end

    return false
end

local function TryRespawn()
    if CurTime() < nextRespawnTry then return end
    nextRespawnTry = CurTime() + 0.65

    RunConsoleCommand("+attack")
    timer.Simple(0, function()
        RunConsoleCommand("-attack")
    end)
end

local function DeathScreenRespawnKeyHook()
    local cfg = Cfg()
    local ply = LocalPlayer()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DeathScreen == false or cfg.Enabled == false or not IsValid(ply) or ply:Alive() then
        if IsValid(ply) and ply:Alive() then selectedRandomMessage = nil end
        pressedLast = false
    else
        local down = WantedKeyDown()
        if down and not pressedLast then
            TryRespawn()
        end
        pressedLast = down
    end
end

local function DeathScreenPaintHook()
    local cfg = Cfg()
    local ply = LocalPlayer()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DeathScreen == false or cfg.Enabled == false or not IsValid(ply) or ply:Alive() then return end

    local sw, sh = ScrW(), ScrH()
    local accent = Accent()
    local title = PickRandomMessage(cfg)
    local subtitle = tostring(cfg.Subtitle or "")
    local hint = DHUD.LFormat and DHUD.LFormat(cfg.Hint or "Press {key} to respawn", cfg.Hint or "Press {key} to respawn", {
        key = DHUD.L and DHUD.L(KeyLabel(cfg.RespawnKey)) or KeyLabel(cfg.RespawnKey)
    }) or string.Replace(tostring(cfg.Hint or "Press {key} to respawn"), "{key}", KeyLabel(cfg.RespawnKey))

    local cx = sw * math.Clamp(tonumber(cfg.XPercent) or 0.5, 0.05, 0.95)
    local cy = sh * math.Clamp(tonumber(cfg.YPercent) or 0.44, 0.05, 0.95)
    local titleFont = Font("Title", "DermaLarge")
    local subtitleFont = Font("Body", "DermaDefault")
    local hintFont = Font("Header", "DermaDefaultBold")

    if cfg.Blur ~= false and blurMaterial and not blurMaterial:IsError() then
        surface.SetMaterial(blurMaterial)
        surface.SetDrawColor(255, 255, 255, 255)
        for i = 1, 4 do
            blurMaterial:SetFloat("$blur", i * 1.6)
            blurMaterial:Recompute()
            render.UpdateScreenEffectTexture()
            surface.DrawTexturedRect(0, 0, sw, sh)
        end
    end

    draw.RoundedBox(0, 0, 0, sw, sh, Color(0, 0, 0, math.Clamp(tonumber(cfg.DimAlpha) or 175, 0, 255)))

    ShadowText(title, titleFont, cx, cy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    if subtitle ~= "" then
        ShadowText(subtitle, subtitleFont, cx, cy + 34, Color(190, 190, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    ShadowText(hint, hintFont, cx, cy + (subtitle ~= "" and 58 or 38), accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("Think", "DHUD.DeathScreenRespawnKey", DeathScreenRespawnKeyHook)
hook.Add("HUDPaint", "DHUD.DeathScreen", DeathScreenPaintHook)
