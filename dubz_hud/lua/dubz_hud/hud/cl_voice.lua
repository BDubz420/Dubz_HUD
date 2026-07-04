local DHUD = DHUD
DHUD.Voice = DHUD.Voice or {}

local speakers = {}
local panels = {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Voice or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Primary()
    return DHUD.Config and DHUD.Config.Colors and (DHUD.Config.Colors.VoiceAccent or DHUD.Config.Colors.Primary or DHUD.Config.Colors.Agenda) or Color(184, 116, 255)
end

local function PlayerJobColor(ply)
    if IsValid(ply) and ply.Team and team and team.GetColor then
        local col = team.GetColor(ply:Team())
        if col then return col end
    end

    return Primary()
end

local function PlayerJobName(ply)
    if IsValid(ply) and ply.Team and team and team.GetName then
        return team.GetName(ply:Team()) or "Talking"
    end

    return "Talking"
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then
        return DubzLib.Radius(name)
    end

    return name == "MD" and 8 or 5
end

local function Font(name, fallback)
    if DubzLib and DubzLib.Font then
        return DubzLib.Font(name)
    end

    return fallback or "DermaDefault"
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
    elseif DHUD.Status and DHUD.Status.DrawIcon then
        DHUD.Status.DrawIcon(path, x, y, size, col)
    end
end

local function FitText(text, font, maxWidth)
    text = tostring(text or "")
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end

    local suffix = "..."
    for i = #text, 1, -1 do
        local cut = string.sub(text, 1, i) .. suffix
        if surface.GetTextSize(cut) <= maxWidth then return cut end
    end

    return suffix
end

local function SpeakerKey(ply)
    if not IsValid(ply) then return nil end

    local steam64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    if steam64 ~= "" and steam64 ~= "0" then return steam64 end

    return string.format("%d", ply:EntIndex() or 0)
end

local function FeedTop()
    local cfg = Cfg()
    local top = cfg.Top or math.floor(ScrH() * 0.5)

    if DHUD.Notify and DHUD.Notify.Bounds then
        top = (DHUD.Notify.Bounds.Bottom or top) + (cfg.NotificationGap or cfg.Gap or 8)
    end

    return top
end

local function OrderedSpeakers()
    local rows = {}
    for key, item in next, (speakers) do
        if IsValid(item.Player) then
            rows[#rows + 1] = item
        else
            speakers[key] = nil
        end
    end

    table.sort(rows, function(a, b)
        return (a.Started or 0) < (b.Started or 0)
    end)

    return rows
end

local function RemovePanel(key)
    local pnl = panels[key]
    panels[key] = nil
    if not IsValid(pnl) then return end

    pnl.Removing = true
    pnl.TargetAlpha = 0
    pnl.TargetX = ScrW() + pnl:GetWide() + 40
    timer.Simple(0.28, function()
        if IsValid(pnl) then pnl:Remove() end
    end)
end

local function CreatePanel(item)
    local cfg = Cfg()
    local w = cfg.Width or 318
    local h = cfg.Height or 46
    local pnl = vgui.Create("DPanel")
    if DHUD.TrackPanel then DHUD.TrackPanel(pnl) end

    pnl:SetSize(w, h)
    pnl:SetPaintBackground(false)
    pnl:SetMouseInputEnabled(false)
    pnl:SetAlpha(0)
    pnl.DrawAlpha = 0
    pnl.TargetAlpha = 255
    pnl.TargetX = ScrW() + w + 40
    pnl.TargetY = FeedTop()
    pnl:SetPos(pnl.TargetX, pnl.TargetY)

    local avatar = vgui.Create("AvatarImage", pnl)
    avatar:SetSize(30, 30)
    avatar:SetPos(12, 6)
    if IsValid(item.Player) then
        avatar:SetPlayer(item.Player, 64)
    end
    pnl.Avatar = avatar
    pnl.DHUDPlayer = item.Player

    pnl.Think = function(self)
        local cfgNow = Cfg()
        local speed = cfgNow.LerpSpeed or 16
        local px, py = self:GetPos()

        self:SetPos(
            Lerp(FrameTime() * speed, px, self.TargetX or px),
            Lerp(FrameTime() * speed, py, self.TargetY or py)
        )
        self.DrawAlpha = Lerp(FrameTime() * speed, self.DrawAlpha or 0, self.TargetAlpha or 255)
        self:SetAlpha(math.Clamp(self.DrawAlpha or 0, 0, 255))
    end

    pnl.Paint = function(self, pw, ph)
        local alpha = math.Clamp(self.DrawAlpha or 0, 0, 255)
        local ply = self.DHUDPlayer
        local accent = PlayerJobColor(ply)
        local name = IsValid(ply) and ply:Nick() or "Speaking"
        local job = PlayerJobName(ply)
        local accentW = Cfg().AccentWidth or 5
        local avatarSize = 30
        local avatarX = accentW + 7
        local textX = avatarX + avatarSize + 10

        draw.RoundedBox(Radius("MD"), 1, 2, pw - 1, ph, Color(0, 0, 0, 42 * (alpha / 255)))
        draw.RoundedBox(Radius("MD"), 0, 0, pw, ph, WithAlpha(accent, alpha))
        local bg = DHUD.Config and DHUD.Config.Colors and (DHUD.Config.Colors.VoiceBackground or DHUD.Config.Colors.Background) or Color(27, 28, 33)
        draw.RoundedBox(Radius("MD"), accentW, -1, pw - accentW + 1, ph + 2, WithAlpha(bg, math.min(alpha, 255)))
        draw.RoundedBox(Radius("SM"), avatarX - 2, 4, avatarSize + 4, avatarSize + 4, WithAlpha(accent, 28 * (alpha / 255)))
        Text(FitText(name, Font("Body", "DermaDefault"), pw - textX - 12), Font("Body", "DermaDefault"), textX, 9, WithAlpha(color_white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text(FitText(job, Font("Small", "DermaDefault"), pw - textX - 12), Font("Small", "DermaDefault"), textX, 26, WithAlpha(accent, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    return pnl
end

local function AddSpeaker(ply)
    if not IsValid(ply) then return end
    local key = SpeakerKey(ply)
    if not key then return end

    speakers[key] = speakers[key] or {
        Player = ply,
        Started = CurTime()
    }

    speakers[key].Player = ply
    speakers[key].Speaking = true
    speakers[key].LastVoice = CurTime()
end

local function RemoveSpeaker(ply)
    local key = SpeakerKey(ply)
    if not key or not speakers[key] then return end

    speakers[key].Speaking = false
    speakers[key].LastVoice = CurTime()
end

hook.Add("HUDShouldDraw", "DHUD.HideDefaultVoice", function(name)
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Voice == false or Cfg().Enabled == false then return end
    if name == "CHudVoiceStatus" or name == "CHudVoiceSelfStatus" or name == "CHudVoice" then return false end
end)

hook.Add("PlayerStartVoice", "DHUD.VoiceStart", AddSpeaker)
hook.Add("PlayerEndVoice", "DHUD.VoiceEnd", RemoveSpeaker)

hook.Add("Think", "DHUD.SyncVoiceFeed", function()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Voice == false or cfg.Enabled == false then
        for key in next, (panels) do RemovePanel(key) end
        return
    end

    local rows = OrderedSpeakers()
    local visible = {}
    local w = cfg.Width or 318
    local h = cfg.Height or 46
    local gap = cfg.Gap or 7
    local right = cfg.Right or 24
    local x = ScrW() - w - right
    local top = FeedTop()
    local hold = cfg.HoldTime or 0.8
    local maxVisible = cfg.MaxVisible or 4

    for index, item in ipairs(rows) do
        local key = SpeakerKey(item.Player)
        local alive = item.Speaking or CurTime() - (item.LastVoice or 0) < hold

        if not alive then
            speakers[key] = nil
            RemovePanel(key)
        elseif index <= maxVisible then
            visible[key] = true
            local pnl = panels[key]
            if not IsValid(pnl) then
                pnl = CreatePanel(item)
                panels[key] = pnl
            end

            pnl.DHUDPlayer = item.Player
            if IsValid(pnl.Avatar) then
                pnl.Avatar:SetAlpha(pnl:GetAlpha())
            end
            pnl.TargetX = x
            pnl.TargetY = top + ((index - 1) * (h + gap))
            pnl.TargetAlpha = 255
        end
    end

    for key in next, (panels) do
        if not visible[key] then
            RemovePanel(key)
        end
    end
end)

hook.Add("HUDPaint", "DHUD.DrawVoiceOverhead", function()
    local cfg = Cfg()
    if cfg.Enabled == false or cfg.Overhead == false then return end

    local accent = cfg.Accent or Primary()
    local size = cfg.OverheadSize or 24
    local localPly = LocalPlayer()

    for _, item in next, (speakers) do
        local ply = item.Player
        if IsValid(ply) and ply ~= localPly and item.Speaking then
            local pos = (ply:EyePos() + Vector(0, 0, cfg.OverheadOffset or 16)):ToScreen()
            if pos.visible ~= false then
                draw.RoundedBox(Radius("SM"), pos.x - size * 0.5, pos.y - size * 0.5, size, size, WithAlpha(accent, 42))
                DrawIcon("actions/unmuted", pos.x - 8, pos.y - 8, 16, accent)
            end
        end
    end
end)
