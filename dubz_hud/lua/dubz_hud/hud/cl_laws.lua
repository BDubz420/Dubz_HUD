local DHUD = DHUD
DHUD.Laws = DHUD.Laws or {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Laws or {}
end

local function AnimSpeed(cfg)
    cfg = cfg or Cfg()
    return cfg.AnimSpeed or 13
end

local function CardLift()
    if string.lower(tostring(DHUD.Config and DHUD.Config.HUDStyle or "bar")) ~= "card" then return 0 end
    local bar = DHUD.Config and DHUD.Config.Bar or {}
    local layout = bar.Layout or {}
    return layout.Height or 42
end

local function EaseValue(value, target, speed)
    return Lerp(math.Clamp(FrameTime() * (tonumber(speed) or 13), 0, 1), value or 0, target or 0)
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function GetLaws()
    if DarkRP and DarkRP.getLaws then
        local laws = DarkRP.getLaws()
        if istable(laws) then return laws end
    end

    if GAMEMODE and GAMEMODE.Config and istable(GAMEMODE.Config.DefaultLaws) then
        return GAMEMODE.Config.DefaultLaws
    end

    return {}
end

local function WrapText(text, font, maxWide)
    if DubzLib and DubzLib.UI and DubzLib.UI.WrapText then
        return DubzLib.UI.WrapText(text, font, maxWide)
    end

    local words = string.Explode(" ", tostring(text or ""))
    local lines = {}
    local current = ""

    surface.SetFont(font)

    for _, word in ipairs(words) do
        local nextLine = current == "" and word or (current .. " " .. word)

        if surface.GetTextSize(nextLine) <= maxWide then
            current = nextLine
        else
            if current ~= "" then lines[#lines + 1] = current end
            current = word
        end
    end

    if current ~= "" then lines[#lines + 1] = current end

    return lines
end

local function DrawLayeredCard(x, y, w, h, accent, cfg, alpha)
    alpha = alpha or 255
    local radius = DubzLib.Radius("MD")
    local accentW = cfg.AccentWidth or 5
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local bg = cfg.Background or colors.LawsBackground or DubzLib.Color("Secondary")

    draw.RoundedBox(radius, x, y, w, h, WithAlpha(accent, alpha))
    DubzLib.Draw.Panel(x + accentW, y - 1, w - accentW + 1, h + 2, {
        Radius = "MD",
        Color = WithAlpha(bg, math.min(alpha, cfg.InnerAlpha or 255)),
        Border = WithAlpha(cfg.Border or DubzLib.Color("BorderSoft"), alpha),
        Shadow = false
    })
end

function DHUD.Laws.Toggle()
    DHUD.Laws.Open = not DHUD.Laws.Open
end

function DHUD.DrawLawsPanel()
    local cfg = Cfg()
    if cfg.Enabled == false or not DubzLib or not DubzLib.Draw then return end

    if DHUD.Laws.Open == nil then
        DHUD.Laws.Open = cfg.StartOpen == true
    end
    DHUD.Laws.Progress = EaseValue(DHUD.Laws.Progress or (DHUD.Laws.Open and 1 or 0), DHUD.Laws.Open and 1 or 0, AnimSpeed(cfg))

    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local accent = colors.LawsAccent or colors.Agenda or colors.Clock or Color(184, 116, 255)
    local barCfg = DHUD.Config and DHUD.Config.Bar or {}
    local barLayout = barCfg.Layout or {}
    local y = cfg.Y or 54

    if (DHUD.Config and DHUD.Config.HUDStyle or "card") == "bar" then
        y = (barLayout.Height or 42) + (cfg.BarGap or 10)
    else
        y = math.max(0, y - CardLift())
    end

    local laws = GetLaws()
    local w = cfg.Width or 360
    local fullX = cfg.TopRight ~= false and (ScrW() - w - (cfg.X or 20)) or (cfg.X or 20)
    local pad = cfg.Pad or 12
    local accentW = cfg.AccentWidth or 5
    local titleFont = DubzLib.Font("Header")
    local bodyFont = DubzLib.Font("Body")
    local textW = w - accentW - pad * 2
    local bodyLines = {}

    if #laws <= 0 then
        bodyLines[#bodyLines + 1] = cfg.EmptyText or "No laws are posted."
    else
        for i, law in ipairs(laws) do
            local wrapped = WrapText(i .. ". " .. tostring(law), bodyFont, textW)
            for _, line in ipairs(wrapped) do
                bodyLines[#bodyLines + 1] = line
            end
        end
    end

    local lineH = 18
    local h = pad * 2 + 24 + #bodyLines * lineH

    local p = math.Clamp(DHUD.Laws.Progress or 0, 0, 1)
    local tagW = cfg.TagWidth or 150
    local tagH = cfg.TagHeight or 28
    local tagX = cfg.TopRight ~= false and (ScrW() - tagW - (cfg.X or 20)) or (cfg.X or 20)
    local drawW = Lerp(p, tagW, w)
    local drawH = Lerp(p, tagH, h)
    local x = Lerp(p, tagX, fullX)
    local alpha = math.floor(255 * p)
    DHUD.Laws.Bounds = {X = x, Y = y, W = drawW, H = drawH}

    DrawLayeredCard(x, y, drawW, drawH, accent, cfg, 255)

    local contentX = x + accentW + pad
    if p < 0.55 then
        local tagAlpha = math.floor(255 * (1 - math.Clamp(p / 0.55, 0, 1)))
        if DHUD.Status and DHUD.Status.DrawIcon then
            DHUD.Status.DrawIcon(cfg.Icon or "admin/gavel", x + accentW + 9, y + 6, 16, WithAlpha(accent, tagAlpha))
        end
        DubzLib.Draw.Text(DHUD.L and DHUD.L(cfg.TagText or "Laws - F1") or (cfg.TagText or "Laws - F1"), DubzLib.Font("Small"), x + accentW + 30, y + tagH * 0.5, WithAlpha(accent, tagAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if p <= 0.35 then return end

    if DHUD.Status and DHUD.Status.DrawIcon then
        DHUD.Status.DrawIcon(cfg.Icon or "admin/gavel", contentX, y + pad + 2, 18, WithAlpha(accent, alpha))
    end

    DubzLib.Draw.Text(DHUD.L and DHUD.L(cfg.Title or "Laws of the Land") or (cfg.Title or "Laws of the Land"), titleFont, contentX + 26, y + pad, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    for i, line in ipairs(bodyLines) do
        DubzLib.Draw.Text(DHUD.L and DHUD.L(line) or line, bodyFont, contentX, y + pad + 28 + (i - 1) * lineH, WithAlpha(DubzLib.Color("Muted"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

local function ToggleLawsPanelHook()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Laws == false or cfg.Enabled == false then return nil end

    DHUD.Laws.Toggle()
    return true
end

hook.Add("ShowHelp", "DHUD.ToggleLawsPanel", ToggleLawsPanelHook)
