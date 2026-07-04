local DHUD = DHUD
DHUD.AnimationMenu = DHUD.AnimationMenu or {}

local frame
local backdrop
local gestures = {}
local oldAddGesture
local oldRemoveGesture
local oldAnimCommand
local installed = false

local defaultGestures = {
    {ACT_GMOD_GESTURE_BOW, "bow", "Bow"},
    {ACT_GMOD_TAUNT_MUSCLE, "sexy_dance", "Sexy Dance"},
    {ACT_GMOD_GESTURE_BECON, "follow_me", "Follow Me"},
    {ACT_GMOD_TAUNT_LAUGH, "laugh", "Laugh"},
    {ACT_GMOD_TAUNT_PERSISTENCE, "lion_pose", "Lion Pose"},
    {ACT_GMOD_GESTURE_DISAGREE, "nonverbal_no", "No"},
    {ACT_GMOD_GESTURE_AGREE, "thumbs_up", "Thumbs Up"},
    {ACT_GMOD_GESTURE_WAVE, "wave", "Wave"},
    {ACT_GMOD_TAUNT_DANCE, "dance", "Dance"}
}

local function Cfg()
    return DHUD.Config and DHUD.Config.DarkRPMenus or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha)
end

local function Accent()
    local colors = Colors()
    return colors.DoorAccent or colors.Agenda or colors.Clock or Color(184, 116, 255)
end

local function Background()
    local colors = Colors()
    return colors.DoorBackground or colors.Background or Color(27, 28, 33)
end

local function PanelColor()
    local colors = Colors()
    return colors.ScoreboardPanel or colors.Background2 or Color(32, 33, 38)
end

local function Muted()
    if DubzLib and DubzLib.Color then return DubzLib.Color("Muted") end
    return Color(170, 171, 178)
end

local function Foreground()
    if DubzLib and DubzLib.Color then return DubzLib.Color("Foreground") end
    return color_white
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then return DubzLib.Radius(name) end
    return name == "MD" and 8 or 5
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

local function DrawIcon(path, x, y, size, col)
    if DHUD.Icon and DHUD.Icon.Draw and DHUD.Icon.Draw(path, x, y, size, col) then return end
    if DubzLib and DubzLib.Icon and DubzLib.Icon.Draw then
        DubzLib.Icon.Draw(path, x, y, size, col)
    end
end

local function GestureText(phrase, fallback)
    if DarkRP and DarkRP.getPhrase then
        local ok, value = pcall(DarkRP.getPhrase, phrase)
        if ok and value and value ~= phrase then return tostring(value) end
    end

    return fallback or tostring(phrase or "Gesture")
end

local function SeedDefaults()
    for _, data in ipairs(defaultGestures) do
        local act = data[1]
        if act and gestures[act] == nil then
            gestures[act] = GestureText(data[2], data[3])
        end
    end
end

local function Close()
    if IsValid(backdrop) then backdrop:Remove() end
    if IsValid(frame) then frame:Remove() end
    backdrop = nil
    frame = nil
end

local function SortedGestures()
    SeedDefaults()

    local out = {}
    for act, label in next, (gestures) do
        if tonumber(act) then
            out[#out + 1] = {Act = tonumber(act), Label = tostring(label or act)}
        end
    end

    table.sort(out, function(a, b)
        return string.lower(a.Label) < string.lower(b.Label)
    end)

    return out
end

local function StyleButton(btn, label, act)
    btn:SetText("")
    btn:SetDrawBackground(false)
    btn:SetTextColor(Color(0, 0, 0, 0))
    btn.Hover = 0
    btn.Paint = function(self, w, h)
        self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
        local accent = Accent()

        draw.RoundedBox(Radius("SM"), 0, 1, w, h - 1, Color(0, 0, 0, 34))
        draw.RoundedBox(Radius("SM"), 0, 0, w, h - 1, WithAlpha(PanelColor(), 255))
        if self.Hover > 0.01 then
            draw.RoundedBox(Radius("SM"), 0, 0, w, h - 1, WithAlpha(accent, 24 + self.Hover * 42))
        end

        draw.RoundedBox(Radius("SM"), 8, h * 0.5 - 10, 20, 20, WithAlpha(accent, 34 + self.Hover * 28))
        DrawIcon("misc/directions_run", 10, h * 0.5 - 8, 16, accent)
        Text(label, Font("Small", "DermaDefault"), 36, h * 0.5 - 1, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        RunConsoleCommand("_DarkRP_DoAnimation", tostring(act))
        Close()
    end
end

local function OpenMenu()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DarkRPMenus == false or Cfg().Enabled == false or Cfg().AnimationMenu == false then
        if isfunction(oldAnimCommand) and oldAnimCommand ~= OpenMenu then
            return oldAnimCommand(LocalPlayer(), "_DarkRP_AnimationMenu", {}, "")
        end
        return
    end

    if IsValid(frame) then return end

    local rows = SortedGestures()
    local rowH = math.Clamp(tonumber(Cfg().AnimationRowHeight) or 36, 30, 56)
    local width = math.max(250, tonumber(Cfg().AnimationWidth) or 278)
    local height = math.Clamp(58 + #rows * rowH + 16, 132, ScrH() - 80)
    local xPct = math.Clamp(tonumber(Cfg().AnimationXPercent) or 0.61, 0.05, 0.9)
    local x = math.floor(ScrW() * xPct)
    local y = math.floor((ScrH() - height) * 0.5)

    backdrop = vgui.Create("DPanel")
    backdrop:SetSize(ScrW(), ScrH())
    backdrop:SetPos(0, 0)
    backdrop:SetMouseInputEnabled(true)
    backdrop:SetKeyboardInputEnabled(true)
    backdrop:MakePopup()
    backdrop.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 34)
        surface.DrawRect(0, 0, w, h)
    end
    backdrop.OnMousePressed = Close
    if backdrop.ParentToHUD then backdrop:ParentToHUD() end

    frame = vgui.Create("DPanel", backdrop)
    frame:SetSize(width, height)
    frame:SetPos(x, y)
    frame:SetMouseInputEnabled(true)
    frame.Progress = 0
    frame.Paint = function(self, w, h)
        self.Progress = Lerp(math.Clamp(FrameTime() * 13, 0, 1), self.Progress or 0, 1)
        local alpha = math.floor(255 * (self.Progress or 1))
        local accentW = Cfg().AccentWidth or 5

        draw.RoundedBox(Radius("MD"), 3, 5, w - 3, h - 3, Color(0, 0, 0, 70 * (alpha / 255)))
        draw.RoundedBox(Radius("MD"), 0, 0, w, h, WithAlpha(Accent(), alpha))
        draw.RoundedBox(Radius("MD"), accentW, 0, w - accentW, h, WithAlpha(Background(), alpha))
        draw.RoundedBox(Radius("MD"), accentW + 12, 12, w - accentW - 24, 40, WithAlpha(PanelColor(), alpha))
        DrawIcon("misc/directions_run", accentW + 25, 22, 20, WithAlpha(Accent(), alpha))
        Text(tostring(Cfg().AnimationTitle or "Actions Menu"), Font("Body", "DermaDefaultBold"), accentW + 56, 22, WithAlpha(Foreground(), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text(tostring(Cfg().AnimationSubtitle or "Choose a gesture"), Font("Small", "DermaDefault"), accentW + 56, 38, WithAlpha(Muted(), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("")
    close:SetPos(width - 38, 18)
    close:SetSize(24, 24)
    close.Paint = function(self, w, h)
        local hot = self:IsHovered()
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(hot and Color(232, 84, 84) or PanelColor(), hot and 72 or 255))
        DrawIcon("navigation/close", 5, 5, 14, hot and Color(232, 84, 84) or Muted())
    end
    close.DoClick = Close

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(16, 62)
    scroll:SetSize(width - 32, height - 76)
    local bar = scroll:GetVBar()
    if IsValid(bar) then
        bar:SetWide(5)
        bar.Paint = function() end
        bar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 1, bh, WithAlpha(Accent(), 165)) end
        bar.btnUp.Paint = function() end
        bar.btnDown.Paint = function() end
    end

    for _, row in ipairs(rows) do
        local btn = vgui.Create("DButton", scroll)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 6)
        btn:SetTall(math.max(30, rowH - 4))
        StyleButton(btn, row.Label, row.Act)
    end
end

local function WrapGestureAPI()
    if not DarkRP then return end

    if not oldAddGesture and isfunction(DarkRP.addPlayerGesture) and DarkRP.addPlayerGesture ~= DHUD.AnimationMenu.AddGestureBridge then
        oldAddGesture = DarkRP.addPlayerGesture
    end

    if not oldRemoveGesture and isfunction(DarkRP.removePlayerGesture) and DarkRP.removePlayerGesture ~= DHUD.AnimationMenu.RemoveGestureBridge then
        oldRemoveGesture = DarkRP.removePlayerGesture
    end

    DHUD.AnimationMenu.AddGestureBridge = DHUD.AnimationMenu.AddGestureBridge or function(anim, text)
        if anim then gestures[tonumber(anim) or anim] = tostring(text or anim) end
        if isfunction(oldAddGesture) then return oldAddGesture(anim, text) end
    end

    DHUD.AnimationMenu.RemoveGestureBridge = DHUD.AnimationMenu.RemoveGestureBridge or function(anim)
        if anim then gestures[tonumber(anim) or anim] = nil end
        if isfunction(oldRemoveGesture) then return oldRemoveGesture(anim) end
    end

    DarkRP.addPlayerGesture = DHUD.AnimationMenu.AddGestureBridge
    DarkRP.removePlayerGesture = DHUD.AnimationMenu.RemoveGestureBridge
end

local function Install()
    SeedDefaults()
    WrapGestureAPI()

    if not oldAnimCommand and concommand.GetTable then
        local commands = concommand.GetTable()
        local existing = commands and commands._DarkRP_AnimationMenu
        if isfunction(existing) and existing ~= OpenMenu then
            oldAnimCommand = existing
        end
    end

    if concommand.Remove then concommand.Remove("_DarkRP_AnimationMenu") end
    concommand.Add("_DarkRP_AnimationMenu", OpenMenu)
    installed = true
end

timer.Simple(0, Install)
timer.Simple(1, Install)
timer.Simple(3, Install)

hook.Add("loadCustomDarkRPItems", "DHUD.AnimationMenu.Seed", function()
    SeedDefaults()
    WrapGestureAPI()
end)

hook.Add("InitPostEntity", "DHUD.AnimationMenu.Install", Install)
hook.Add("OnReloaded", "DHUD.AnimationMenu.Install", Install)

DHUD.AnimationMenu.Open = OpenMenu
DHUD.AnimationMenu.Close = Close
DHUD.AnimationMenu.IsInstalled = function() return installed end
