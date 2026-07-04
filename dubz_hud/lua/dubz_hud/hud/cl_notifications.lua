local DHUD = DHUD
DHUD.Notify = DHUD.Notify or {}

local active = {}
local progress = {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Notifications or {}
end

local function Enabled()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    return systems.Notifications ~= false and Cfg().Enabled ~= false
end

local function ClearAll()
    for i = #active, 1, -1 do
        local pnl = active[i]
        if IsValid(pnl) then pnl:Remove() end
        active[i] = nil
    end

    for id, pnl in next, (progress) do
        if IsValid(pnl) then pnl:Remove() end
        progress[id] = nil
    end

    DHUD.Notify.Bounds = nil
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Font(name)
    if DubzLib and DubzLib.Font then
        return DubzLib.Font(name or "Body")
    end

    return "DermaDefault"
end

local function Accent(name)
    local colors = Colors()

    if istable(name) and name.r then return name end
    if name == "error" then return colors.Health or Color(232, 84, 84) end
    if name == "undo" then return Color(80, 190, 230) end
    if name == "hint" then return Color(0, 160, 245) end
    if name == "cleanup" or name == "success" or name == "progress" then return colors.Cash or Color(91, 201, 121) end
    if name == "warning" then return colors.Warning or Color(238, 146, 80) end

    return colors.Gold or Color(221, 177, 74)
end

local function NormalizeKind(kind)
    if kind == NOTIFY_ERROR then return "error" end
    if kind == NOTIFY_UNDO then return "undo" end
    if kind == NOTIFY_HINT then return "hint" end
    if kind == NOTIFY_CLEANUP then return "cleanup" end
    if kind == 0 then return "hint" end
    if kind == 1 then return "error" end
    if kind == 2 then return "undo" end
    if kind == 4 then return "cleanup" end

    return tostring(kind or "generic")
end

local function IconFor(kind)
    local cfg = Cfg()
    local icons = cfg.Icons or {}

    return icons[kind] or icons.generic or "misc/lightbulb"
end

local function TextWide(font, text)
    surface.SetFont(font)
    local wide = surface.GetTextSize(tostring(text or ""))
    return wide or 0
end

local function DrawIconChip(icon, x, y, accent, alpha, size)
    size = size or 26
    alpha = alpha or 255

    draw.RoundedBox(DubzLib.Radius("SM"), x, y, size, size, WithAlpha(accent, 34 * (alpha / 255)))

    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(icon, x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
    elseif DubzLib and DubzLib.Icon then
        DubzLib.Icon.Draw(icon, x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
    end
end

local function DrawInnerCard(x, y, w, h, alpha)
    local cfg = Cfg()
    local bg = cfg.Background or (DubzLib and DubzLib.Color and DubzLib.Color("Secondary")) or Color(35, 35, 35)
    local border = cfg.Border or (DubzLib and DubzLib.Color and DubzLib.Color("BorderSoft")) or Color(55, 55, 55)
    local innerAlpha = math.min(alpha, (cfg.InnerAlpha or 255) * (alpha / 255))

    if DubzLib and DubzLib.Draw and DubzLib.Draw.Panel then
        DubzLib.Draw.Panel(x, y, w, h, {
            Radius = "MD",
            Color = WithAlpha(bg, innerAlpha),
            Border = nil,
            Shadow = false
        })
        return
    end

    draw.RoundedBox(8, x, y, w, h, WithAlpha(bg, innerAlpha))
end

local function DrawLayeredCard(x, y, w, h, accent, alpha)
    local cfg = Cfg()
    local radius = DubzLib and DubzLib.Radius and DubzLib.Radius("MD") or 6
    local accentW = cfg.AccentWidth or 5

    if cfg.Shadow ~= false and DubzLib and DubzLib.Draw and DubzLib.Draw.Shadow then
        DubzLib.Draw.Shadow(x, y, w, h, radius, cfg.ShadowAlpha or 70)
    end

    draw.RoundedBox(radius, x, y, w, h, WithAlpha(accent, alpha))
    DrawInnerCard(x + accentW, y - 1, w - accentW + 1, h + 2, alpha)
end

local function Anchor(width)
    local cfg = Cfg()
    local scrw, scrh = ScrW(), ScrH()
    local w = width or cfg.Width or cfg.MinWidth or 320
    local right = cfg.RightPadding or cfg.X or 24
    local bottom = cfg.BottomOffset or 245
    local x = scrw - w - right
    local y = scrh - bottom

    if cfg.AnchorX then x = cfg.AnchorX end
    if cfg.AnchorY then y = cfg.AnchorY end

    return x, y, w
end

local function Restack()
    local cfg = Cfg()
    local _, baseY = Anchor()
    local gap = cfg.Gap or 8
    local minX, minY, maxX, maxY

    for i, pnl in ipairs(active) do
        if IsValid(pnl) then
            local x = Anchor(pnl:GetWide())
            pnl.TargetX = x
            pnl.TargetY = baseY - ((i - 1) * (pnl:GetTall() + gap))
            minX = minX and math.min(minX, pnl.TargetX) or pnl.TargetX
            minY = minY and math.min(minY, pnl.TargetY) or pnl.TargetY
            maxX = maxX and math.max(maxX, pnl.TargetX + pnl:GetWide()) or (pnl.TargetX + pnl:GetWide())
            maxY = maxY and math.max(maxY, pnl.TargetY + pnl:GetTall()) or (pnl.TargetY + pnl:GetTall())
        end
    end

    DHUD.Notify.Bounds = minX and {X = minX, Y = minY, W = maxX - minX, H = maxY - minY, Bottom = maxY} or nil
end

local function RemovePanel(pnl)
    if not IsValid(pnl) or pnl.Removing then return end

    pnl.Removing = true
    table.RemoveByValue(active, pnl)
    pnl.TargetX = ScrW() + pnl:GetWide() + 40
    pnl.TargetAlpha = 0

    Restack()

    timer.Simple(Cfg().RemoveDelay or 0.35, function()
        if IsValid(pnl) then
            pnl:Remove()
        end
    end)
end

function DHUD.Notify.Add(text, kind, lifetime)
    local cfg = Cfg()
    if not Enabled() then
        ClearAll()
        return
    end

    text = tostring(text or "")
    kind = NormalizeKind(kind)
    lifetime = tonumber(lifetime) or cfg.Life or 4

    local _, baseY, cfgWide = Anchor()
    local font = Font("Body")
    local h = cfg.Height or 44
    local iconSize = cfg.IconChipSize or 26
    local padX = cfg.PadX or 10
    local accentW = cfg.AccentWidth or 5
    local minWidth = cfg.MinWidth or cfgWide
    local maxWidth = math.min(cfg.MaxWidth or ScrW(), math.max(180, ScrW() - (cfg.RightPadding or 24) * 2))
    local textWidth = TextWide(font, text)
    local contentWidth = accentW + padX * 2 + iconSize + 10 + textWidth
    local w = cfg.FixedWidth and (cfg.Width or minWidth) or math.max(minWidth, contentWidth)

    w = math.Clamp(w, minWidth, maxWidth)
    local x = Anchor(w)

    local pnl = vgui.Create("DPanel")
    if DHUD.TrackPanel then DHUD.TrackPanel(pnl) end
    pnl:SetSize(w, h)
    pnl:SetPaintBackground(false)
    pnl:SetMouseInputEnabled(false)
    pnl.Text = text
    pnl.Kind = kind
    pnl.Icon = IconFor(kind)
    pnl.Accent = Accent(kind)
    pnl.Start = CurTime()
    pnl.DieTime = CurTime() + lifetime
    pnl.Life = lifetime
    pnl.DrawAlpha = 0
    pnl.TargetAlpha = 255
    pnl.ProgressWide = w - padX * 2
    pnl.TargetX = x
    pnl.TargetY = baseY
    pnl:SetPos(ScrW() + w + 40, baseY)

    table.insert(active, 1, pnl)
    Restack()

    pnl.Think = function(self)
        local cfgNow = Cfg()
        local speed = cfgNow.MoveLerpSpeed or cfgNow.LerpSpeed or 16
        local fadeSpeed = cfgNow.FadeLerpSpeed or speed
        local px, py = self:GetPos()

        self:SetPos(
            Lerp(FrameTime() * speed, px, self.TargetX or px),
            Lerp(FrameTime() * speed, py, self.TargetY or py)
        )

        self.DrawAlpha = Lerp(FrameTime() * fadeSpeed, self.DrawAlpha or 0, self.TargetAlpha or 255)

        if not self.Removing and CurTime() >= (self.DieTime or 0) then
            RemovePanel(self)
        end
    end

    pnl.Paint = function(self, pw, ph)
        local alpha = math.Clamp(self.DrawAlpha or 255, 0, 255)
        if alpha <= 1 then return end

        local accent = self.Accent or Accent(self.Kind)
        local innerPad = cfg.PadX or 10
        local accentW = cfg.AccentWidth or 5
        local lineH = cfg.ProgressHeight or 2
        local frac = math.Clamp(((self.DieTime or 0) - CurTime()) / math.max(self.Life or 0.1, 0.1), 0, 1)
        local contentX = accentW + innerPad
        local contentW = pw - accentW

        self.ProgressWide = Lerp(FrameTime() * (cfg.ProgressLerpSpeed or 10), self.ProgressWide or pw, (contentW - innerPad * 2) * frac)

        DrawLayeredCard(0, 0, pw, ph, accent, alpha)
        DrawIconChip(self.Icon, contentX, ph * 0.5 - (cfg.IconChipSize or 26) * 0.5, accent, alpha, cfg.IconChipSize or 26)

        DubzLib.Draw.Text(self.Text, font, contentX + (cfg.IconChipSize or 26) + 10, ph * 0.5, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if cfg.ProgressLine ~= false then
            draw.RoundedBox(DubzLib.Radius("XS"), contentX, ph - lineH - 1, contentW - innerPad * 2, lineH, WithAlpha(DubzLib.Color("Background2"), math.min(alpha, 120)))
            draw.RoundedBox(DubzLib.Radius("XS"), contentX, ph - lineH - 1, self.ProgressWide, lineH, WithAlpha(accent, alpha))
        end
    end

    local maxVisible = cfg.MaxVisible or 5
    while #active > maxVisible do
        RemovePanel(active[#active])
    end

    return pnl
end

local nextDisabledCheck = 0
local function ClearDisabledNotificationsHook()
    if CurTime() >= nextDisabledCheck then
        nextDisabledCheck = CurTime() + 0.25
        if not Enabled() and (#active > 0 or next(progress) ~= nil) then
            ClearAll()
        end
    end
end

hook.Add("Think", "DHUD.Notifications.ClearDisabled", ClearDisabledNotificationsHook)

function DHUD.Notify.AddProgress(id, text)
    id = id and tostring(id) or text and tostring(text) or string.format("%.3f", CurTime())

    if IsValid(progress[id]) then
        progress[id].Text = tostring(text or "")
        progress[id].DieTime = CurTime() + 9999
        return progress[id]
    end

    local pnl = DHUD.Notify.Add(text, "progress", 9999)
    progress[id] = pnl
    return pnl
end

function DHUD.Notify.Kill(id)
    id = tostring(id or "")
    local pnl = progress[id]
    progress[id] = nil
    RemovePanel(pnl)
end

local function InstallNotificationBridge()
    if DHUD.Notify.BridgeInstalled then return end
    DHUD.Notify.BridgeInstalled = true

    notification = notification or {}
    DarkRP = DarkRP or {}

    DHUD.Notify.OldAddLegacy = notification.AddLegacy
    DHUD.Notify.OldAddProgress = notification.AddProgress
    DHUD.Notify.OldKill = notification.Kill

    function notification.AddLegacy(text, kind, lifetime)
        return DHUD.Notify.Add(text, kind, lifetime)
    end

    function notification.AddProgress(id, text)
        return DHUD.Notify.AddProgress(id, text)
    end

    function notification.Kill(id)
        return DHUD.Notify.Kill(id)
    end

    function DarkRP.notify(a, b, c, d)
        local kind, life, msg

        if IsValid(a) or a == LocalPlayer() then
            if a ~= LocalPlayer() then return end
            kind, life, msg = b, c, d
        else
            kind, life, msg = a, b, c
        end

        return DHUD.Notify.Add(msg, kind, life)
    end

    function DarkRP.notifyAll(kind, life, msg)
        return DHUD.Notify.Add(msg, kind, life)
    end

    function DarkRP.notifyInDistance(origin, range, kind, life, msg)
        local ply = LocalPlayer()
        if not IsValid(ply) or not isvector(origin) then return end

        if origin:DistToSqr(ply:GetPos()) <= (range * range) then
            return DHUD.Notify.Add(msg, kind, life)
        end
    end
end

InstallNotificationBridge()

local function WeaponPickupNotifyHook(weapon)
    if not Enabled() or Cfg().PickupOverride == false then return nil end
    if IsValid(weapon) then
        local name = weapon.PrintName or (weapon.GetPrintName and weapon:GetPrintName()) or weapon:GetClass()
        DHUD.Notify.Add("Received " .. tostring(name), "hint", 3)
    end

    return true
end

local function ItemPickupNotifyHook(itemName)
    if not Enabled() or Cfg().PickupOverride == false then return nil end
    DHUD.Notify.Add("Picked up " .. tostring(itemName or "item"), "hint", 3)
    return true
end

local function AmmoPickupNotifyHook(itemName, amount)
    if not Enabled() or Cfg().PickupOverride == false then return nil end
    DHUD.Notify.Add("Picked up " .. string.format("%d", tonumber(amount) or 0) .. " " .. tostring(itemName or "ammo"), "hint", 3)
    return true
end

hook.Add("HUDWeaponPickedUp", "DHUD.WeaponPickupNotify", WeaponPickupNotifyHook)
hook.Add("HUDItemPickedUp", "DHUD.ItemPickupNotify", ItemPickupNotifyHook)
hook.Add("HUDAmmoPickedUp", "DHUD.AmmoPickupNotify", AmmoPickupNotifyHook)
