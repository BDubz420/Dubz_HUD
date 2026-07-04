local DHUD = DHUD
DHUD.Status = DHUD.Status or {}
DHUD.Status.ArrestTimers = DHUD.Status.ArrestTimers or {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Status or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function GetDarkRPVar(ply, key)
    if not IsValid(ply) or not ply.getDarkRPVar then return nil end
    return ply:getDarkRPVar(key)
end

local function PreviewStatus()
    return DHUD.IsPreviewFeature and DHUD.IsPreviewFeature("status")
end

local function CardLift()
    if string.lower(tostring(DHUD.Config and DHUD.Config.HUDStyle or "bar")) ~= "card" then return 0 end
    local bar = DHUD.Config and DHUD.Config.Bar or {}
    local layout = bar.Layout or {}
    return layout.Height or 42
end

function DHUD.Status.IsWanted(ply)
    if PreviewStatus() then return true end
    return GetDarkRPVar(ply, "wanted") == true
end

function DHUD.Status.IsArrested(ply)
    if PreviewStatus() then return true end
    return GetDarkRPVar(ply, "Arrested") == true
        or GetDarkRPVar(ply, "arrested") == true
end

local function ArrestKey(ply)
    if not IsValid(ply) then return nil end
    if ply.SteamID64 then
        local sid64 = tostring(ply:SteamID64() or "")
        if sid64 ~= "" and sid64 ~= "0" then return sid64 end
    end

    return string.format("%d", ply:EntIndex() or 0)
end

local function DefaultArrestDuration()
    local cfg = Cfg()
    local gmCfg = GAMEMODE and GAMEMODE.Config or {}
    local darkRPCfg = DarkRP and DarkRP.Config or {}
    return math.max(tonumber(cfg.ArrestedDefaultDuration) or tonumber(gmCfg.jailtimer) or tonumber(darkRPCfg.jailtimer) or 120, 1)
end

local function InferredArrestTimeLeft(ply)
    local key = ArrestKey(ply)
    if not key then return nil end

    if not DHUD.Status.IsArrested(ply) then
        DHUD.Status.ArrestTimers[key] = nil
        return nil
    end

    local timerData = DHUD.Status.ArrestTimers[key]
    if not timerData then
        timerData = {
            Started = CurTime(),
            Ends = CurTime() + DefaultArrestDuration()
        }
        DHUD.Status.ArrestTimers[key] = timerData
    end

    return math.max((timerData.Ends or CurTime()) - CurTime(), 0)
end

local function FormatTime(seconds)
    seconds = math.max(math.ceil(tonumber(seconds) or 0), 0)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60

    return string.format("%d:%02d", mins, secs)
end

function DHUD.Status.GetArrestedTimeLeft(ply)
    if PreviewStatus() then return 118 end

    local candidates = {
        GetDarkRPVar(ply, "ArrestedUntil"),
        GetDarkRPVar(ply, "arrestedUntil"),
        GetDarkRPVar(ply, "ArrestUntil"),
        GetDarkRPVar(ply, "arrestUntil"),
        GetDarkRPVar(ply, "ArrestTime"),
        GetDarkRPVar(ply, "arrestTime"),
        GetDarkRPVar(ply, "jailtime"),
        GetDarkRPVar(ply, "JailTime"),
        GetDarkRPVar(ply, "JailedUntil"),
        GetDarkRPVar(ply, "jailedUntil")
    }

    for _, value in ipairs(candidates) do
        value = tonumber(value)
        if value and value > 0 then
            if value > CurTime() then
                return math.max(value - CurTime(), 0)
            end

            return value
        end
    end

    return InferredArrestTimeLeft(ply)
end

function DHUD.Status.GetArrestedText(ply)
    local cfg = Cfg()
    local base = cfg.ArrestedText or "Arrested!"
    local left = DHUD.Status.GetArrestedTimeLeft(ply)

    if left then
        return base .. " " .. FormatTime(left)
    end

    return base .. " " .. tostring(cfg.ArrestedTimerFallback or "Time left unknown")
end

function DHUD.Status.HasGunLicense(ply)
    if PreviewStatus() then return true end
    return GetDarkRPVar(ply, "HasGunlicense") == true or GetDarkRPVar(ply, "HasGunLicense") == true
end

function DHUD.Status.IsLockdown()
    if PreviewStatus() then return true end
    return GetGlobalBool("DarkRP_LockDown", false) == true or GetGlobalBool("DarkRP_Lockdown", false) == true
end

function DHUD.Status.GetAgenda(ply)
    if PreviewStatus() then
        return "Watch for wanted suspects and keep patrol routes clear."
    end

    local agenda = GetDarkRPVar(ply, "agenda")
    if not agenda or agenda == "" then return nil end

    return tostring(agenda)
end

function DHUD.Status.GetAccent(name)
    local colors = Colors()

    if name == "wanted" then return colors.Wanted or colors.Health or Color(232, 84, 84) end
    if name == "arrested" then return colors.Arrested or colors.Armor or Color(91, 159, 232) end
    if name == "gunlicense" then return colors.License or colors.Cash or Color(91, 201, 121) end
    if name == "lockdown" then return colors.Lockdown or colors.Warning or Color(238, 146, 80) end
    if name == "agenda" then return colors.Agenda or colors.Clock or Color(184, 116, 255) end

    return colors.Gold or Color(221, 177, 74)
end

function DHUD.Status.GetIcon(name)
    local icons = Cfg().Icons or {}

    if name == "wanted" then return icons.Wanted or "admin/warning" end
    if name == "arrested" then return icons.Arrested or "darkrp/local_police" end
    if name == "gunlicense" then return icons.GunLicense or "economy/house" end
    if name == "lockdown" then return icons.Lockdown or "admin/gavel" end
    if name == "agenda" then return icons.Agenda or "communication/forum" end

    return "misc/question_mark"
end

function DHUD.Status.DrawIcon(icon, x, y, size, col)
    if DHUD.Icon and DHUD.Icon.Draw then
        return DHUD.Icon.Draw(icon, x, y, size, col)
    end

    if DubzLib and DubzLib.Icon and DubzLib.Icon.Draw then
        return DubzLib.Icon.Draw(icon, x, y, size, col)
    end
end

function DHUD.Status.DrawStatusChip(name, x, y, size, alpha)
    alpha = alpha or 255

    local accent = DHUD.Status.GetAccent(name)
    draw.RoundedBox(DubzLib.Radius("SM"), x, y, size, size, WithAlpha(accent, 38 * (alpha / 255)))
    DHUD.Status.DrawIcon(DHUD.Status.GetIcon(name), x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
end

function DHUD.Status.GetActiveChips(ply)
    local chips = {}

    if DHUD.Status.HasGunLicense(ply) then chips[#chips + 1] = "gunlicense" end
    if DHUD.Status.IsWanted(ply) then chips[#chips + 1] = "wanted" end
    if DHUD.Status.IsArrested(ply) then chips[#chips + 1] = "arrested" end

    return chips
end

local function ShadowText(text, font, x, y, col, ax, ay)
    draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, math.min(col.a or 255, 190)), ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

local function TextWide(font, text)
    surface.SetFont(font)
    return surface.GetTextSize(tostring(text or ""))
end

local function TrimText(text, font, maxWide)
    text = tostring(text or "")
    surface.SetFont(font)

    if surface.GetTextSize(text) <= maxWide then return text end

    local suffix = "..."
    local suffixWide = surface.GetTextSize(suffix)

    for i = #text, 1, -1 do
        local cut = string.sub(text, 1, i)
        if surface.GetTextSize(cut) + suffixWide <= maxWide then
            return cut .. suffix
        end
    end

    return suffix
end

local function DrawAnnouncementLine(icon, text, accent, y)
    local cfg = Cfg()
    local font = DubzLib.Font("Header")
    local iconSize = cfg.AnnouncementIconSize or 18
    local text = TrimText(text, font, ScrW() - 120)
    local tw = TextWide(font, text)
    local gap = 8
    local totalW = iconSize + gap + tw
    local x = ScrW() * 0.5 - totalW * 0.5

    DHUD.Status.DrawIcon(icon, x, y + 1, iconSize, accent)
    ShadowText(text, font, x + iconSize + gap, y - 1, WithAlpha(accent, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function WrapText(text, font, maxWide, maxLines)
    if DubzLib and DubzLib.UI and DubzLib.UI.WrapText then
        return DubzLib.UI.WrapText(text, font, maxWide, maxLines)
    end

    local words = string.Explode(" ", tostring(text or ""))
    local lines = {}
    local current = ""

    surface.SetFont(font)

    local function PushLine(line)
        if line == "" then return false end
        if maxLines and #lines >= maxLines then return false end
        lines[#lines + 1] = line
        return true
    end

    local function SplitLongWord(word)
        local chunks = {}
        local chunk = ""

        for i = 1, #word do
            local char = string.sub(word, i, i)
            local test = chunk .. char

            if chunk ~= "" and surface.GetTextSize(test) > maxWide then
                chunks[#chunks + 1] = chunk
                chunk = char
            else
                chunk = test
            end
        end

        if chunk ~= "" then chunks[#chunks + 1] = chunk end
        return chunks
    end

    for _, word in ipairs(words) do
        if surface.GetTextSize(word) > maxWide then
            if current ~= "" then
                if not PushLine(current) then break end
                current = ""
            end

            for _, chunk in ipairs(SplitLongWord(word)) do
                if not maxLines or #lines < maxLines then
                    lines[#lines + 1] = chunk
                end
            end

            if maxLines and #lines >= maxLines then break end
            continue
        end

        local nextLine = current == "" and word or (current .. " " .. word)

        if surface.GetTextSize(nextLine) <= maxWide then
            current = nextLine
        else
            if current ~= "" then
                if not PushLine(current) then break end
            end

            current = word

            if maxLines and #lines >= maxLines then
                break
            end
        end
    end

    if current ~= "" then
        PushLine(current)
    end

    if maxLines and #lines > maxLines then
        lines[maxLines] = TrimText(lines[maxLines], font, maxWide)
    end

    return lines
end

local function DrawLayeredCard(x, y, w, h, accent, bg, cfg)
    local radius = DubzLib.Radius("MD")
    local accentW = cfg.AccentWidth or 5
    local innerAlpha = cfg.InnerAlpha or 255

    if cfg.Shadow ~= false and DubzLib.Draw.Shadow then
        DubzLib.Draw.Shadow(x, y, w, h, radius, cfg.ShadowAlpha or 70)
    end

    draw.RoundedBox(radius, x, y, w, h, accent)
    DubzLib.Draw.Panel(x + accentW, y - 1, w - accentW + 1, h + 2, {
        Radius = "MD",
        Color = WithAlpha(bg or DubzLib.Color("Secondary"), innerAlpha),
        Border = cfg.Border or DubzLib.Color("BorderSoft"),
        Shadow = false
    })
end

function DHUD.DrawAgendaCard()
    local cfg = Cfg()
    local card = cfg.AgendaCard or {}
    if cfg.Enabled == false or card.Enabled == false then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local agenda = DHUD.Status.GetAgenda(ply)
    if not agenda then return end

    local barCfg = DHUD.Config and DHUD.Config.Bar or {}
    local barLayout = barCfg.Layout or {}
    local x = card.X or 20
    local y = card.Y or 54

    if (DHUD.Config and DHUD.Config.HUDStyle or "card") == "bar" then
        y = (barLayout.Height or 42) + (card.BarGap or 10)
    else
        y = math.max(0, y - CardLift())
    end

    local w = card.Width or 360
    local pad = card.Pad or 12
    local accentW = card.AccentWidth or 5
    local titleFont = DubzLib.Font("Small")
    local bodyFont = DubzLib.Font("Body")
    local textX = x + accentW + pad
    local textW = w - accentW - pad * 2
    local lines = WrapText(agenda, bodyFont, textW, card.MaxLines or 3)
    local lineH = 18
    local h = math.max(card.MinHeight or 64, pad * 2 + 16 + #lines * lineH)
    local accent = DHUD.Status.GetAccent("agenda")

    DrawLayeredCard(x, y, w, h, accent, card.Background or DubzLib.Color("Secondary"), card)
    DHUD.Status.DrawIcon(DHUD.Status.GetIcon("agenda"), textX, y + pad - 1, 16, accent)
    DubzLib.Draw.Text(DHUD.L and DHUD.L(cfg.AgendaPrefix or "Agenda") or (cfg.AgendaPrefix or "Agenda"), titleFont, textX + 22, y + pad, WithAlpha(accent, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    for i, line in ipairs(lines) do
        DubzLib.Draw.Text(line, bodyFont, textX, y + pad + 18 + (i - 1) * lineH, DubzLib.Color("Foreground"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

function DHUD.DrawStatusAnnouncements()
    local cfg = Cfg()
    if cfg.Enabled == false or cfg.AnnouncementEnabled == false then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local lines = {}

    if DHUD.Status.IsWanted(ply) then
        lines[#lines + 1] = {"wanted", cfg.WantedText or "Wanted!"}
    end

    if DHUD.Status.IsArrested(ply) then
        lines[#lines + 1] = {"arrested", DHUD.Status.GetArrestedText(ply)}
    end

    if DHUD.Status.IsLockdown() then
        lines[#lines + 1] = {"lockdown", cfg.LockdownText or "Lockdown in progress"}
    end

    local y = math.max(0, (cfg.AnnouncementY or 82) - CardLift())
    local gap = cfg.AnnouncementGap or 22

    for i, line in ipairs(lines) do
        local name = line[1]
        DrawAnnouncementLine(DHUD.Status.GetIcon(name), line[2], DHUD.Status.GetAccent(name), y + (i - 1) * gap)
    end
end
