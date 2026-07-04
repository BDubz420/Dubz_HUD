local DHUD = DHUD
DHUD.DeathNotice = DHUD.DeathNotice or {}

local queue = {}
local active = {}

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Font(name, fallback)
    if DubzLib and DubzLib.Font then
        return DubzLib.Font(name)
    end

    return fallback or "DermaDefault"
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then
        return DubzLib.Radius(name)
    end

    return name == "MD" and 8 or 5
end

local function ColorFromTeam(teamID)
    if teamID and team and team.GetColor then
        local col = team.GetColor(teamID)
        if col then return col end
    end

    return Color(170, 171, 178)
end

local function Primary()
    return DHUD.Config and DHUD.Config.Colors and (DHUD.Config.Colors.Primary or DHUD.Config.Colors.Accent) or Color(184, 116, 255)
end

local function Secondary()
    if DubzLib and DubzLib.Color then
        return DubzLib.Color("Secondary")
    end

    return Color(27, 28, 33)
end

local function Text(text, font, x, y, col, ax, ay)
    text = DHUD.L and DHUD.L(text) or tostring(text or "")
    if DubzLib and DubzLib.Draw and DubzLib.Draw.Text then
        DubzLib.Draw.Text(text, font, x, y, col, ax, ay)
    else
        draw.SimpleText(text, font, x, y, col, ax, ay)
    end
end

local function Icon(path, x, y, size, col)
    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(path, x, y, size, col)
    elseif DHUD.Status and DHUD.Status.DrawIcon then
        DHUD.Status.DrawIcon(path, x, y, size, col)
    end
end

local function FitText(text, font, maxWidth)
    text = tostring(text or "")
    if not maxWidth or maxWidth <= 0 then return text end

    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end

    local suffix = "..."
    local lo, hi = 0, #text
    while lo < hi do
        local mid = math.ceil((lo + hi) * 0.5)
        local candidate = string.sub(text, 1, mid) .. suffix
        if surface.GetTextSize(candidate) <= maxWidth then
            lo = mid
        else
            hi = mid - 1
        end
    end

    return string.sub(text, 1, lo) .. suffix
end

local function FormatInflictor(inflictor, attacker, victim)
    inflictor = string.Trim(tostring(inflictor or ""))

    if inflictor == "" then
        return attacker == victim and "suicide" or "killed"
    end

    local lower = string.lower(inflictor)
    if lower == "worldspawn" or lower == "world" then return "world" end
    if lower == "prop_physics" then return "prop" end

    if weapons and weapons.GetStored then
        local stored = weapons.GetStored(inflictor)
        if stored and stored.PrintName and stored.PrintName ~= "" then
            return tostring(stored.PrintName)
        end
    end

    inflictor = string.gsub(inflictor, "^weapon_", "")
    inflictor = string.gsub(inflictor, "^gmod_", "")
    inflictor = string.gsub(inflictor, "^npc_", "")
    inflictor = string.gsub(inflictor, "[_%-%s]+", " ")
    inflictor = string.Trim(inflictor)

    if inflictor == "" then return "killed" end

    return string.gsub(inflictor, "(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest or "")
    end)
end

local function Cfg()
    return DHUD.Config and DHUD.Config.DeathNotice or {}
end

local function MaxVisible()
    return Cfg().MaxVisible or 3
end

local function ActivateQueued()
    while #active < MaxVisible() and #queue > 0 do
        local item = table.remove(queue, 1)
        item.Expire = CurTime() + (Cfg().Life or 5.5)
        item.Progress = 0
        active[#active + 1] = item
    end
end

local function AddNotice(attacker, attackerTeam, inflictor, victim, victimTeam)
    local now = CurTime()
    local attackerName = tostring(attacker or "")
    local victimName = tostring(victim or "")

    if attackerName == "" then attackerName = "Unknown" end
    if victimName == "" then victimName = "Unknown" end

    queue[#queue + 1] = {
        Attacker = attackerName,
        Victim = victimName,
        Inflictor = tostring(inflictor or ""),
        AttackerColor = ColorFromTeam(attackerTeam),
        VictimColor = ColorFromTeam(victimTeam),
        Created = now,
        Expire = 0,
        Progress = 0
    }

    while #queue > (Cfg().MaxQueued or 8) do
        table.remove(queue, 1)
    end

    ActivateQueued()
end

local function HideDefaultDeathNoticeHook(name)
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if name == "CHudDeathNotice" and systems.DeathNotice ~= false and Cfg().Enabled ~= false then return false end
end

local function CustomDeathNoticeHook(attacker, attackerTeam, inflictor, victim, victimTeam)
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DeathNotice == false or Cfg().Enabled == false then return end
    AddNotice(attacker, attackerTeam, inflictor, victim, victimTeam)
    return true
end

hook.Add("HUDShouldDraw", "DHUD.HideDefaultDeathNotice", HideDefaultDeathNoticeHook)
hook.Add("AddDeathNotice", "DHUD.CustomDeathNotice", CustomDeathNoticeHook)

local function DrawDeathNoticeHook()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DeathNotice == false or Cfg().Enabled == false then
        queue = {}
        active = {}
        return
    end

    ActivateQueued()
    if #active <= 0 then return end

    local cfg = Cfg()

    local w = cfg.Width or 330
    local h = cfg.Height or 34
    local gap = cfg.Gap or 7
    local right = cfg.Right or 24
    local top = cfg.Top or 84
    local lawGap = cfg.LawsGap or 10
    if DHUD.Laws and DHUD.Laws.Bounds then
        top = math.max(top, (DHUD.Laws.Bounds.Y or top) + (DHUD.Laws.Bounds.H or 0) + lawGap)
    end
    local x = ScrW() - w - right
    local radius = Radius("MD")
    local accent = Primary()
    local font = Font("Small", "DermaDefault")
    local body = Font("Body", "DermaDefault")

    for i = #active, 1, -1 do
        local item = active[i]
        local alive = CurTime() < (item.Expire or 0)
        local target = alive and 1 or 0
        item.Progress = Lerp(math.Clamp(FrameTime() * 13, 0, 1), item.Progress or 0, target)

        if not alive and (item.Progress or 0) <= 0.02 then
            table.remove(active, i)
        else
            local alpha = math.floor(255 * item.Progress)
            local y = top + ((i - 1) * (h + gap))
            local slide = (1 - item.Progress) * 22
            local drawX = x + slide

            draw.RoundedBox(radius, drawX + 1, y + 2, w - 1, h, Color(0, 0, 0, 46 * (alpha / 255)))
            draw.RoundedBox(radius, drawX, y, w, h, WithAlpha(Secondary(), math.min(alpha, 255)))
            draw.RoundedBox(Radius("SM"), drawX + 8, y + 7, 20, 20, WithAlpha(accent, 36 * (alpha / 255)))
            Icon("players/skull", drawX + 10, y + 9, 16, WithAlpha(accent, alpha))

            local cause = FormatInflictor(item.Inflictor, item.Attacker, item.Victim)
            local leftX = drawX + 38
            local rightX = drawX + w - 12
            local causeW = math.Clamp(cfg.CauseWidth or 92, 64, 132)
            local causeX = drawX + w * 0.5
            local nameW = math.max((w - 58 - causeW - 22) * 0.5, 70)

            draw.RoundedBox(Radius("SM"), causeX - causeW * 0.5, y + 7, causeW, 20, WithAlpha(Color(0, 0, 0), 36 * (alpha / 255)))
            Text(FitText(item.Attacker, body, nameW), body, leftX, y + h * 0.5, WithAlpha(item.AttackerColor, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            Text(FitText(cause, font, causeW - 14), font, causeX, y + h * 0.5, WithAlpha(Color(190, 191, 198), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            Text(FitText(item.Victim, body, nameW), body, rightX, y + h * 0.5, WithAlpha(item.VictimColor, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

hook.Add("HUDPaint", "DHUD.DrawDeathNotice", DrawDeathNoticeHook)
