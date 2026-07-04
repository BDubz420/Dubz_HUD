local DHUD = DHUD
DHUD.MOTD = DHUD.MOTD or {}

local frame
local previewConfig
local openingPreview = false
local pendingOpen = false
local hoverSoundsReadyAt = 0

local function RequestConfig()
    if not net then return end

    net.Start("DHUD.Config.Request")
    net.SendToServer()
end

local function Cfg()
    local cfg = previewConfig or (DHUD.Config and DHUD.Config.MOTD) or {}
    cfg.Buttons = istable(cfg.Buttons) and cfg.Buttons or {}

    local visible = 0
    for _, data in ipairs(cfg.Buttons) do
        if data.Enabled ~= false then visible = visible + 1 end
    end

    if visible <= 1 and #cfg.Buttons >= 5 then
        for index = 1, 4 do
            if istable(cfg.Buttons[index]) then
                cfg.Buttons[index].Enabled = true
            end
        end
    end

    return cfg
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Primary()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.MOTDAccent or colors.HUDAccent or colors.ConfigAccent or colors.ScoreboardAccent or colors.Primary or colors.Agenda or Color(184, 116, 255)
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

local function Lang(text)
    return DHUD.L and DHUD.L(text) or tostring(text or "")
end

local function Text(text, font, x, y, col, ax, ay)
    text = Lang(text)
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

local function ButtonBase(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local bg = colors.MOTDCardBackground or colors.Background2 or Color(38, 39, 46)
    local page = colors.MOTDBackground or colors.Background or Color(27, 28, 33)

    if bg.r == page.r and bg.g == page.g and bg.b == page.b then
        bg = Color(math.min(bg.r + 12, 255), math.min(bg.g + 12, 255), math.min(bg.b + 14, 255))
    end

    return Color(bg.r, bg.g, bg.b, math.min(alpha or 255, 255))
end

local function HandleHoverSound(btn)
    if RealTime() < hoverSoundsReadyAt then return end

    if DubzLib and DubzLib.UI and DubzLib.UI.HandleHoverSound then
        DubzLib.UI.HandleHoverSound(btn)
    end
end

local function CardShadow(x, y, w, h, alpha, radius, strength)
    local cfg = Cfg()
    if cfg.Shadow == false then return end

    local frac = math.Clamp((alpha or 255) / 255, 0, 1)
    if frac <= 0 then return end

    local r = radius or Radius("MD")
    local amount = math.Clamp((strength or cfg.ShadowAlpha or 92) * frac, 0, 180)

    draw.RoundedBox(r, x + 1, y + 3, w - 2, h - 1, Color(0, 0, 0, amount * 0.30))
    draw.RoundedBox(r, x + 1, y + 1, w - 2, h - 1, Color(0, 0, 0, amount * 0.16))
end

local function Close()
    if not IsValid(frame) then return end

    frame.TargetAlpha = 0
    frame:SetMouseInputEnabled(false)
    frame:SetKeyboardInputEnabled(false)
end

local function OpenURL(url)
    url = string.Trim(tostring(url or ""))
    if url == "" then return end

    if not string.StartWith(url, "https://") and not string.StartWith(url, "http://") then
        return
    end

    gui.OpenURL(url)
end

local function AddIconButton(parent, x, y, icon, callback, hoverColor)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetSize(28, 28)
    btn:SetPos(x, y)
    btn.Hover = 0
    btn.Paint = function(self, bw, bh)
        HandleHoverSound(self)
        self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
        local col = self.Hover > 0.02 and (hoverColor or Primary()) or Color(170, 171, 178)
        CardShadow(0, 1, bw, bh - 1, parent:GetAlpha(), Radius("SM"), 26)
        draw.RoundedBox(Radius("SM"), 0, 0, bw, bh - 1, ButtonBase(255))
        if self.Hover > 0.01 then
            draw.RoundedBox(Radius("SM"), 0, 0, bw, bh - 1, WithAlpha(col, 20 + self.Hover * 42))
        end
        DrawIcon(icon, 6, 6, 16, WithAlpha(col, parent:GetAlpha()))
    end
    btn.DoClick = callback
    return btn
end

local function AddFooterButton(parent, label, x, y, w, callback, accent)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetSize(w, 34)
    btn:SetPos(x, y)
    btn.Hover = 0
    btn.Paint = function(self, bw, bh)
        HandleHoverSound(self)
        self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
        local alpha = parent:GetAlpha()
        CardShadow(0, 2, bw, bh - 2, alpha, Radius("SM"), 24)
        draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, ButtonBase(alpha))
        if self.Hover > 0.01 then
            draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, WithAlpha(accent or Primary(), 22 + self.Hover * 44))
        end
        Text(self.Label or label, Font("Small", "DermaDefault"), bw * 0.5, bh * 0.5 - 1, WithAlpha(color_white, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = callback
    return btn
end

function DHUD.MOTD.Open()
    if not previewConfig and not DHUD.ConfigLoaded then
        pendingOpen = true
        RequestConfig()
        return
    end

    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.MOTD == false or cfg.Enabled == false then return end
    if IsValid(frame) then frame:Remove() end

    local previewMode = openingPreview == true
    openingPreview = false
    local w = math.min(ScrW() - 90, math.max(tonumber(cfg.Width or 0) or 0, 920))
    local h = math.min(ScrH() - 90, math.max(tonumber(cfg.Height or 0) or 0, 620))
    if previewMode then
        w = math.min(w, math.max(720, ScrW() - 650))
        h = math.min(h, ScrH() - 70)
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    if previewMode then
        frame:SetPos(28, math.max(28, math.floor((ScrH() - h) * 0.5)))
    else
        frame:Center()
    end
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    if frame.SetPaintBackground then frame:SetPaintBackground(false) end
    frame:MakePopup()
    frame:SetAlpha(0)
    frame.Progress = 0
    frame.TargetAlpha = 255
    frame.DHUDPreview = previewMode
    hoverSoundsReadyAt = RealTime() + 1
    if DHUD.TrackPanel then DHUD.TrackPanel(frame) end

    local baseX, baseY = frame:GetPos()
    frame.OnRemove = function(self)
        if self.DHUDPreview then previewConfig = nil end
        if frame == self then frame = nil end
    end

    frame.Paint = function(self, pw, ph)
        local alpha = self:GetAlpha()
        local accent = Primary()

        CardShadow(0, 0, pw, ph, alpha, Radius("MD"), 58)
        draw.RoundedBox(Radius("MD"), 3, 4, pw - 3, ph - 4, Color(0, 0, 0, 62 * (alpha / 255)))
        draw.RoundedBox(Radius("MD"), 0, 0, pw, ph, WithAlpha(accent, alpha))
        local colors = DHUD.Config and DHUD.Config.Colors or {}
        local bg = colors.MOTDBackground or colors.Background or Color(27, 28, 33)
        draw.RoundedBox(Radius("MD"), 6, 0, pw - 6, ph, WithAlpha(bg, 255))

        CardShadow(24, 20, pw - 48, 86, alpha, Radius("MD"), 30)
        draw.RoundedBox(Radius("MD"), 24, 20, pw - 48, 86, WithAlpha(ButtonBase(alpha), alpha))
        local showIcon = cfg.ShowHeaderIcon ~= false
        local titleX = showIcon and 106 or 42
        if showIcon then
            draw.RoundedBox(Radius("SM"), 42, 39, 48, 48, WithAlpha(accent, 34 * (alpha / 255)))
            DrawIcon(cfg.Icon or "communication/notifications", 54, 51, 24, WithAlpha(accent, alpha))
        end

        Text(cfg.Title or "Welcome", Font("Header", "DermaDefaultBold"), titleX, 41, WithAlpha(color_white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text(cfg.Subtitle or "", Font("Body", "DermaDefault"), titleX, 69, WithAlpha(Color(170, 171, 178), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    AddIconButton(frame, w - 58, 38, "navigation/close", Close, Color(232, 84, 84))

    local updates = vgui.Create("DPanel", frame)
    updates:SetPos(32, 126)
    updates:SetSize(w - 64, 86)
    updates.Paint = function(_, pw, ph)
        local alpha = IsValid(frame) and frame:GetAlpha() or 255
        CardShadow(0, 2, pw, ph - 2, alpha, Radius("MD"), 24)
        draw.RoundedBox(Radius("MD"), 0, 0, pw, ph, WithAlpha(ButtonBase(alpha), alpha))
        Text("Server Updates", Font("Body", "DermaDefaultBold"), 14, 12, WithAlpha(color_white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local y = 38
        for _, line in ipairs(cfg.ServerUpdates or {}) do
            Text("- " .. tostring(line), Font("Small", "DermaDefault"), 14, y, WithAlpha(Color(170, 171, 178), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + 18
            if y > ph - 14 then break end
        end
    end

    local body = vgui.Create("DScrollPanel", frame)
    if body.SetPaintBackground then body:SetPaintBackground(false) end
    local bodyY = 226
    local footerTop = h - 66
    body:SetPos(32, bodyY)
    body:SetSize(w - 64, math.max(150, footerTop - bodyY))
    if DubzLib and DubzLib.UI and DubzLib.UI.StyleScrollBar then
        DubzLib.UI.StyleScrollBar(body, Primary())
    else
        local bar = body:GetVBar()
        if IsValid(bar) then
            bar:SetWide(6)
            bar.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, Color(0, 0, 0, 70)) end
            bar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, WithAlpha(Primary(), 160)) end
            bar.btnUp.Paint = function() end
            bar.btnDown.Paint = function() end
        end
    end

    local content = vgui.Create("DPanel", body)
    local rules = istable(cfg.Body) and cfg.Body or {}
    local contentHeight = math.max(body:GetTall(), #rules * 46 + 68)
    content:SetTall(contentHeight)
    content:SetWide(body:GetWide() - 8)
    body:AddItem(content)
    content.Paint = function(_, pw)
        local alpha = IsValid(frame) and frame:GetAlpha() or 255
        local accent = Primary()
        local y = 10
        Text("Rules", Font("Body", "DermaDefaultBold"), 0, y, WithAlpha(color_white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        y = y + 30
        for index, line in ipairs(rules) do
            CardShadow(0, y - 4, pw - 8, 36, alpha, Radius("SM"), 16)
            draw.RoundedBox(Radius("SM"), 0, y - 4, pw - 8, 36, WithAlpha(ButtonBase(alpha), alpha))
            Text(string.format("%d.", index), Font("Small", "DermaDefault"), 14, y + 14, WithAlpha(accent, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            Text(tostring(line), Font("Body", "DermaDefault"), 42, y + 14, WithAlpha(color_white, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            y = y + 46
        end
    end

    body.PerformLayout = function(self, bw, bh)
        content:SetWide(bw - 8)
        content:SetTall(math.max(bh, #rules * 46 + 68))
    end

    local buttons = {}
    for _, data in ipairs(cfg.Buttons or {}) do
        if data.Enabled ~= false then
            buttons[#buttons + 1] = data
        end
    end

    local gap = 8
    local bw = 104
    local total = #buttons * bw + math.max(#buttons - 1, 0) * gap
    local x = (w - total) * 0.5
    local y = h - 50
    local footerAccent = Primary()

    for _, data in ipairs(buttons) do
        local buttonData = data
        local label = tostring(buttonData.Label or "Link")
        AddFooterButton(frame, label, x, y, bw, function()
            if tostring(buttonData.Action or "") == "close" then
                Close()
            else
                OpenURL(buttonData.URL)
            end
        end, footerAccent)
        x = x + bw + gap
    end

    frame.Think = function(self)
        self.Progress = Lerp(math.Clamp(FrameTime() * 13, 0, 1), self.Progress or 0, self.TargetAlpha == 0 and 0 or 1)
        self:SetAlpha(math.floor(255 * self.Progress))
        self:SetPos(baseX + (1 - self.Progress) * 22, baseY)
        if self.TargetAlpha == 0 and self.Progress <= 0.02 then
            self:Remove()
        end
    end
end

function DHUD.MOTD.OpenPreviewLeft()
    openingPreview = true
    DHUD.MOTD.Open()
end

function DHUD.MOTD.PreviewExternalConfig(cfg)
    previewConfig = istable(cfg) and table.Copy(cfg) or nil

    if IsValid(frame) and frame.DHUDPreview then
        openingPreview = true
        DHUD.MOTD.Open()
    end
end

function DHUD.MOTD.GetFrame()
    return frame
end

function DHUD.MOTD.Close()
    Close()
end

concommand.Add("dhud_motd", function()
    DHUD.MOTD.Open()
end)

hook.Add("OnPlayerChat", "DHUD.MOTD.ChatCommand", function(ply, text)
    if ply ~= LocalPlayer() then return end
    text = string.lower(string.Trim(tostring(text or "")))
    if text == "!motd" or text == "/motd" then
        DHUD.MOTD.Open()
        return true
    end
end)

hook.Add("InitPostEntity", "DHUD.MOTD.ShowOnJoin", function()
    RequestConfig()

    local function TryOpen()
        local cfg = Cfg()
        if cfg.Enabled ~= false and cfg.ShowOnJoin ~= false then
            if DHUD.ConfigLoaded then
                DHUD.MOTD.Open()
                return
            end

            timer.Simple(0.25, TryOpen)
        end
    end

    timer.Simple(1.25, TryOpen)
end)

hook.Add("DHUD.ConfigLoaded", "DHUD.MOTD.OpenPending", function()
    if not pendingOpen then return end

    pendingOpen = false
    timer.Simple(0, function()
        if DHUD.MOTD and DHUD.MOTD.Open then
            DHUD.MOTD.Open()
        end
    end)
end)
