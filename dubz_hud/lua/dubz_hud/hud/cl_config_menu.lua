local DHUD = DHUD
DHUD.ConfigMenu = DHUD.ConfigMenu or {}

local frame
local activeTab = "overview"
local BuildBody
local RefreshBodyTall
local StyleButton
local configSearchText = ""
local styledCombos = {}

local tabs = {
    {ID = "overview", Label = "Overview", Icon = "economy/leaderboard"},
    {ID = "theme", Label = "Theme", Icon = "navigation/settings"},
    {ID = "hud", Label = "HUD", Icon = "darkrp/health_cross"},
    {ID = "weaponselector", Label = "Weapon Selector", Icon = "misc/handyman"},
    {ID = "deathscreen", Label = "Death Screen", Icon = "admin/warning"},
    {ID = "scoreboard", Label = "Scoreboard", Icon = "players/groups"},
    {ID = "leaderboards", Label = "Leaderboards", Icon = "economy/leaderboard"},
    {ID = "motd", Label = "MOTD", Icon = "navigation/menu"},
    {ID = "feeds", Label = "Feeds", Icon = "actions/refresh"},
    {ID = "support", Label = "Supported Scripts", Icon = "admin/verified"},
    {ID = "credits", Label = "Credit System", Icon = "economy/attach_money"}
}

local function IsAdmin()
    local ply = LocalPlayer()
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha)
end

local function Primary()
    return DHUD.Config and DHUD.Config.Colors and (DHUD.Config.Colors.ConfigAccent or DHUD.Config.Colors.Agenda or DHUD.Config.Colors.Clock) or Color(184, 116, 255)
end

local function Muted()
    return DubzLib and DubzLib.Color and DubzLib.Color("Muted") or Color(170, 171, 178)
end

local function Foreground()
    return DubzLib and DubzLib.Color and DubzLib.Color("Foreground") or color_white
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then return DubzLib.Radius(name) end
    return name == "MD" and 8 or 5
end

local function Font(name, fallback)
    if DubzLib and DubzLib.Font then return DubzLib.Font(name) end
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
    elseif DubzLib and DubzLib.Icon then
        DubzLib.Icon.Draw(path, x, y, size, col)
    end
end

local function CardColor(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local col = colors.ConfigPanel or colors.Background or Color(27, 28, 33)
    return Color(col.r or 27, col.g or 28, col.b or 33, math.min(alpha or 255, 255))
end

local function FieldColor(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local col = colors.ConfigField or colors.Background2 or Color(24, 25, 30)
    return Color(col.r or 24, col.g or 25, col.b or 30, math.min(alpha or 255, 255))
end

local function ShellColor(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local col = colors.ConfigBackground or colors.Background or Color(27, 28, 33)
    return Color(col.r or 27, col.g or 28, col.b or 33, math.min(alpha or 255, 255))
end

local function AddSection(parent, title, subtitle)
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 2, 0, 12)
    panel:SetTall(subtitle and 48 or 32)
    panel:SetPaintBackground(false)
    panel.DHUDSearchText = string.lower(tostring(title or "") .. " " .. tostring(subtitle or ""))
    panel.Paint = function(_, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, Color(34, 35, 41, 255))
        draw.RoundedBox(Radius("SM"), 0, 0, 5, h, WithAlpha(Primary(), 255))
        Text(title, Font("Body", "DermaDefaultBold"), 16, subtitle and 9 or h * 0.5 - 1, Foreground(), TEXT_ALIGN_LEFT, subtitle and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
        if subtitle then
            Text(subtitle, Font("Small", "DermaDefault"), 16, 29, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    return panel
end

local function AddHeaderIconButton(parent, icon, callback, tooltip, hoverColor)
    local btn = vgui.Create("DButton", parent)
    StyleButton(btn)
    btn:SetSize(28, 28)
    btn.Hover = 0
    if tooltip and btn.SetTooltip then btn:SetTooltip(tooltip) end
    btn.Paint = function(self, w, h)
        self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
        local alpha = IsValid(frame) and frame:GetAlpha() or 255
        local hot = hoverColor or Primary()
        local iconColor = self.Hover > 0.05 and hot or Muted()
        draw.RoundedBox(Radius("SM"), 0, 1, w, h - 1, Color(0, 0, 0, 24))
        draw.RoundedBox(Radius("SM"), 0, 0, w, h - 1, CardColor(alpha))
        if self.Hover > 0.01 then
            draw.RoundedBox(Radius("SM"), 0, 0, w, h - 1, WithAlpha(hot, 20 + self.Hover * 42))
        end
        DrawIcon(icon, 6, 6, 16, WithAlpha(iconColor, alpha))
    end
    btn.DoClick = callback
    return btn
end

local function MergeConfig(dst, src)
    if not istable(src) then return dst end
    dst = istable(dst) and dst or {}

    for key, value in next, (src) do
        if istable(value) and istable(dst[key]) and not value.r then
            MergeConfig(dst[key], value)
        else
            dst[key] = value
        end
    end

    return dst
end

local function SaveConfig()
    if not net then return end

    net.Start("DHUD.Config.Save")
    net.WriteString(util.TableToJSON(DHUD.Config or {}) or "{}")
    net.SendToServer()
end

local function FrameworkPresetColors(themeID)
    if not DubzLib then return nil end

    if themeID == "framework" or themeID == nil or themeID == "" then
        local theme = DubzLib.GetTheme and DubzLib.GetTheme()
        return theme and theme.Colors
    end

    local preset = DubzLib.GetThemePreset and DubzLib.GetThemePreset(themeID)
    if not preset then return nil end

    return {
        Primary = preset.Accent,
        ConfigAccent = preset.Accent,
        HUDAccent = preset.Accent,
        VoiceAccent = preset.Accent,
        ScoreboardAccent = preset.Accent,
        MOTDAccent = preset.Accent,
        NotificationAccent = preset.Accent,
        LawsAccent = preset.Accent,
        DoorAccent = preset.Accent,
        Background = preset.Background,
        ConfigBackground = preset.Background,
        HUDBackground = preset.Background,
        VoiceBackground = preset.Background,
        ScoreboardBackground = preset.Background,
        MOTDBackground = preset.Background,
        NotificationBackground = preset.Background,
        LawsBackground = preset.Background,
        DoorBackground = preset.Background,
        Background2 = preset.Panel,
        Card = preset.Panel,
        ConfigPanel = preset.Panel,
        ScoreboardPanel = preset.Panel,
        MOTDCardBackground = preset.Panel,
        Secondary = preset.Field,
        Background3 = preset.Field,
        ConfigField = preset.Field
    }
end

local function ApplyFrameworkThemeToDHUD(themeID, save)
    local src = FrameworkPresetColors(themeID)
    if not src then return false end

    DHUD.Config = DHUD.Config or {}
    DHUD.Config.Colors = DHUD.Config.Colors or {}
    local colors = DHUD.Config.Colors

    local accent = src.Primary or src.ConfigAccent or src.HUDAccent or Color(190, 86, 82)
    local bg = src.ConfigBackground or src.Background or Color(27, 28, 33)
    local panel = src.ConfigPanel or src.Card or src.Background2 or Color(34, 36, 41)
    local field = src.ConfigField or src.Secondary or src.Background3 or Color(27, 29, 34)

    colors.Agenda = accent
    colors.Clock = accent
    colors.HUDAccent = src.HUDAccent or accent
    colors.VoiceAccent = src.VoiceAccent or accent
    colors.ScoreboardAccent = src.ScoreboardAccent or accent
    colors.MOTDAccent = src.MOTDAccent or accent
    colors.NotificationAccent = src.NotificationAccent or accent
    colors.ConfigAccent = src.ConfigAccent or accent
    colors.LawsAccent = src.LawsAccent or accent
    colors.DoorAccent = src.DoorAccent or accent
    colors.Background = bg
    colors.HUDBackground = src.HUDBackground or bg
    colors.VoiceBackground = src.VoiceBackground or bg
    colors.ScoreboardBackground = src.ScoreboardBackground or bg
    colors.MOTDBackground = src.MOTDBackground or bg
    colors.NotificationBackground = src.NotificationBackground or bg
    colors.ConfigBackground = bg
    colors.LawsBackground = src.LawsBackground or bg
    colors.DoorBackground = src.DoorBackground or bg
    colors.Background2 = panel
    colors.ScoreboardPanel = src.ScoreboardPanel or panel
    colors.MOTDCardBackground = src.MOTDCardBackground or panel
    colors.ConfigPanel = panel
    colors.ConfigField = field

    if themeID == "framework" or themeID == nil or themeID == "" then
        DHUD.Config.ThemeSource = "framework"
        DHUD.Config.FrameworkTheme = "framework"
    else
        DHUD.Config.ThemeSource = "preset"
        DHUD.Config.FrameworkTheme = themeID
    end

    if save then SaveConfig() end
    return true
end

DHUD.ConfigMenu.ApplyFrameworkTheme = ApplyFrameworkThemeToDHUD

local function RequestConfig()
    if not net then return end

    net.Start("DHUD.Config.Request")
    net.SendToServer()
end

local function ConfirmAction(title, message, onConfirm)
    if DubzLib and DubzLib.Confirm then
        DubzLib.Confirm(title or "Confirm", message or "Are you sure?", "Confirm", "Cancel", onConfirm)
        return
    end

    if Derma_Query then
        Derma_Query(message or "Are you sure?", title or "Confirm", "Confirm", onConfirm, "Cancel")
        return
    end

    if onConfirm then onConfirm() end
end

StyleButton = function(btn)
    btn:SetText("")
    btn:SetTextColor(Color(0, 0, 0, 0))
    btn:SetDrawBackground(false)
    if btn.SetDrawBorder then btn:SetDrawBorder(false) end
end

local function StyleEntry(entry)
    entry:SetFont(Font("Small", "DermaDefault"))
    entry:SetTextColor(Foreground())
    entry:SetCursorColor(Primary())
    entry:SetHighlightColor(WithAlpha(Primary(), 90))
    entry.Paint = function(self, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
        self:DrawTextEntryText(Foreground(), Primary(), Foreground())
    end
end

local function CloseOpenComboMenus()
    for combo in next, styledCombos do
        if not IsValid(combo) then
            styledCombos[combo] = nil
        elseif IsValid(combo.Menu) then
            if combo.CloseMenu then
                combo:CloseMenu()
            else
                combo.Menu:Remove()
                combo.Menu = nil
            end
        end
    end
end

local function CloseCombosOnScroll(panel)
    if not IsValid(panel) then return end

    panel.OnMouseWheeled = function(self, delta)
        CloseOpenComboMenus()
        local vbar = self.GetVBar and self:GetVBar()
        if IsValid(vbar) and vbar.OnMouseWheeled then
            return vbar:OnMouseWheeled(delta)
        end
    end

    local vbar = panel.GetVBar and panel:GetVBar()
    if not IsValid(vbar) or vbar.DHUDCloseComboWrapped then return end

    vbar.DHUDCloseComboWrapped = true
    vbar.DHUDSetScroll = vbar.SetScroll
    vbar.SetScroll = function(self, scroll)
        if math.floor(tonumber(scroll or 0)) ~= math.floor(tonumber(self:GetScroll() or 0)) then
            CloseOpenComboMenus()
        end
        return self:DHUDSetScroll(scroll)
    end
end

local function StyleCombo(combo)
    styledCombos[combo] = true
    combo:SetTextColor(Foreground())
    if combo.SetFont then combo:SetFont(Font("Small", "DermaDefault")) end

    local function SkinMenu()
        local menu = combo.Menu
        if not IsValid(menu) then return end
        if menu.SetMinimumWidth then menu:SetMinimumWidth(math.max(combo:GetWide(), 150)) end

        menu.OnMouseWheeled = function()
            if IsValid(combo) and combo.CloseMenu then
                combo:CloseMenu()
            elseif IsValid(menu) then
                menu:Remove()
                combo.Menu = nil
            end
            return true
        end

        menu.Paint = function(_, w, h)
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
        end

        local canvas = menu.GetCanvas and menu:GetCanvas() or menu
        for _, child in ipairs(IsValid(canvas) and canvas:GetChildren() or menu:GetChildren()) do
            if IsValid(child) then
                if child.SetTextColor then child:SetTextColor(Foreground()) end
                if child.SetFont then child:SetFont(Font("Small", "DermaDefault")) end
                if child.SetTall then child:SetTall(30) end
                child.Paint = function(self, w, h)
                    local hot = self:IsHovered()
                    if hot then
                        draw.RoundedBox(Radius("XS"), 4, 2, w - 8, h - 4, WithAlpha(Primary(), 165))
                    else
                        draw.RoundedBox(Radius("XS"), 4, 2, w - 8, h - 4, WithAlpha(CardColor(255), 70))
                    end
                end
            end
        end
    end

    if not combo.DHUDStyledOpenMenu then
        combo.DHUDStyledOpenMenu = combo.OpenMenu
        combo.OpenMenu = function(self, ...)
            local result = self.DHUDStyledOpenMenu(self, ...)
            SkinMenu()
            if timer and timer.Simple then
                timer.Simple(0, function()
                    if IsValid(self) then SkinMenu() end
                end)
            end
            return result
        end
    end

    combo.Paint = function(_, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
    end
end

local function StyleCheck(check)
    check:SetFont(Font("Small", "DermaDefault"))
    check:SetTextColor(Foreground())

    local box = check.Button
    if IsValid(box) then
        box:SetSize(18, 18)
        box.Paint = function() end
    end

    if IsValid(check.Label) then
        check.Label:SetFont(Font("Small", "DermaDefault"))
        check.Label:SetTextColor(Foreground())
    end

    check.PerformLayout = function(self)
        if IsValid(self.Button) then
            self.Button:SetPos(0, math.max(0, math.floor((self:GetTall() - 18) * 0.5)))
            self.Button:SetSize(18, 18)
        end
        if IsValid(self.Label) then
            self.Label:SetPos(28, 4)
            self.Label:SetSize(math.max(self:GetWide() - 28, 1), math.max(self:GetTall() - 4, 1))
            self.Label:SetContentAlignment(4)
        end
    end

    check.Paint = function() end
end

local function PaintCheckBoxAt(checked, x, y)
    local col = checked and Primary() or Muted()

    draw.RoundedBox(4, x, y, 16, 16, WithAlpha(col, checked and 230 or 135))
    draw.RoundedBox(3, x + 2, y + 2, 12, 12, FieldColor(255))

    if checked then
        surface.SetDrawColor(col)
        surface.DrawLine(x + 4, y + 8, x + 7, y + 11)
        surface.DrawLine(x + 5, y + 8, x + 7, y + 10)
        surface.DrawLine(x + 7, y + 11, x + 12, y + 5)
        surface.DrawLine(x + 7, y + 10, x + 11, y + 5)
    end
end

local function PaintCheckRow(field, check, w, h)
    local checked = IsValid(check) and check:GetChecked()
    draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
    draw.RoundedBox(Radius("SM"), 0, 0, 4, h, WithAlpha(checked and Primary() or Muted(), checked and 220 or 110))
    PaintCheckBoxAt(checked, 13, math.floor((h - 16) * 0.5))
end

local function StyleSlider(slider)
    if IsValid(slider.Label) then
        slider.Label:SetTextColor(Foreground())
        slider.Label:SetFont(Font("Small", "DermaDefault"))
    end

    if IsValid(slider.TextArea) then
        slider.TextArea:SetFont(Font("Small", "DermaDefault"))
        slider.TextArea:SetTextColor(Foreground())
        slider.TextArea:SetCursorColor(Primary())
        slider.TextArea:SetHighlightColor(WithAlpha(Primary(), 90))
        slider.TextArea.Paint = function(self, w, h)
            draw.RoundedBox(Radius("XS"), 0, 2, w, h - 4, CardColor(255))
            self:DrawTextEntryText(Foreground(), Primary(), Foreground())
        end
    end

    local track = slider.Slider
    if IsValid(track) then
        track.Paint = function(self, w, h)
            local frac = math.Clamp((slider:GetValue() - slider:GetMin()) / math.max(slider:GetMax() - slider:GetMin(), 0.001), 0, 1)
            draw.RoundedBox(4, 0, h * 0.5 - 3, w, 6, CardColor(255))
            draw.RoundedBox(4, 0, h * 0.5 - 3, math.max(6, w * frac), 6, WithAlpha(Primary(), 220))
        end

        if IsValid(track.Knob) then
            track.Knob:SetSize(14, 14)
            track.Knob.Paint = function(self, w, h)
                draw.RoundedBox(7, 1, 1, w - 2, h - 2, Primary())
                draw.RoundedBox(5, 4, 4, w - 8, h - 8, Foreground())
            end
        end
    end
end

local function AddField(parent, label, tall)
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, 10)
    panel:SetTall(tall or 60)
    panel:SetPaintBackground(false)
    panel.DHUDSearchText = string.lower(tostring(label or ""))
    panel.Paint = function(_, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
        draw.RoundedBox(Radius("SM"), 0, 0, 4, h, WithAlpha(Primary(), 180))
        Text(label, Font("Small", "DermaDefault"), 14, 9, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    return panel
end

local function AddLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:Dock(TOP)
    label:DockMargin(0, 0, 0, 5)
    label:SetTall(18)
    label:SetText(Lang(text))
    label:SetFont(Font("Small", "DermaDefault"))
    label:SetTextColor(Muted())
    label.DHUDSearchText = string.lower(tostring(text or ""))
    return label
end

local function AddEntry(parent, label, value)
    local field = AddField(parent, label, 66)
    local entry = vgui.Create("DTextEntry", field)
    entry:SetPos(12, 30)
    entry:SetSize(1, 28)
    field.PerformLayout = function(_, w)
        entry:SetWide(w - 24)
    end
    entry:SetText(tostring(value or ""))
    StyleEntry(entry)
    return entry
end

local function AddMulti(parent, label, value, tall)
    local h = tall or 84
    local field = AddField(parent, label, h + 38)
    local entry = vgui.Create("DTextEntry", field)
    entry:SetPos(12, 30)
    entry:SetSize(1, h)
    field.PerformLayout = function(_, w)
        entry:SetWide(w - 24)
    end
    if entry.SetMultiline then entry:SetMultiline(true) end
    entry:SetText(tostring(value or ""))
    StyleEntry(entry)
    return entry
end

local function AddCheck(parent, label, value)
    local field = AddField(parent, label, 34)
    local check = vgui.Create("DCheckBoxLabel", field)
    check:SetPos(12, 2)
    check:SetSize(1, 30)
    check:SetText(Lang(label))
    check:SetValue(value and 1 or 0)
    StyleCheck(check)
    field.Paint = function(_, w, h)
        PaintCheckRow(field, check, w, h)
    end
    field.PerformLayout = function(_, w)
        check:SetWide(w - 24)
    end
    return check
end

local function AddSlider(parent, label, value, minValue, maxValue, decimals)
    local field = AddField(parent, label, 72)
    local slider = vgui.Create("DNumSlider", field)
    slider:SetPos(12, 28)
    slider:SetSize(1, 34)
    slider:SetText("")
    slider:SetMin(minValue)
    slider:SetMax(maxValue)
    slider:SetDecimals(decimals or 0)
    slider:SetValue(tonumber(value or minValue) or minValue)
    StyleSlider(slider)
    field.PerformLayout = function(_, w)
        slider:SetWide(w - 24)
    end
    return slider
end

local function AddMenuButton(parent, label, callback, accent)
    local btn = vgui.Create("DButton", parent)
    StyleButton(btn)
    btn:Dock(LEFT)
    btn:DockMargin(0, 0, 8, 0)
    btn:SetWide(112)
    btn.Hover = 0
    btn.Paint = function(self, w, h)
        self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
        local col = accent or Primary()
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
        if self.Hover > 0.01 then
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(col, 24 + self.Hover * 38))
        end
        Text(label, Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = callback
    return btn
end

local function LinesFromText(value)
    local out = {}
    for line in string.gmatch(tostring(value or ""), "([^\n]+)") do
        line = string.Trim(line)
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end

local function CSVToList(value)
    local out = {}
    for token in string.gmatch(tostring(value or ""), "([^,]+)") do
        token = string.Trim(token)
        if token ~= "" then out[#out + 1] = token end
    end
    return out
end

local function ListToCSV(value)
    return table.concat(value or {}, ",")
end

local function ListHasValue(list, wanted)
    for _, value in ipairs(list or {}) do
        if value == wanted then return true end
    end

    return false
end

local function ColorToHex(col)
    if isstring(col) then return col end
    col = col or color_white
    return string.format("#%02X%02X%02X", math.Clamp(col.r or 255, 0, 255), math.Clamp(col.g or 255, 0, 255), math.Clamp(col.b or 255, 0, 255))
end

local function HexToColor(hex, fallback)
    hex = string.Trim(tostring(hex or "")):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1) .. hex:sub(1, 1) .. hex:sub(2, 2) .. hex:sub(2, 2) .. hex:sub(3, 3) .. hex:sub(3, 3)
    end

    local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
    if not r then return fallback or color_white end

    return Color(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function AddCombo(parent, label, choices, value)
    local field = AddField(parent, label, 70)
    local combo = vgui.Create("DComboBox", field)
    combo:SetPos(12, 30)
    combo:SetSize(1, 30)
    StyleCombo(combo)
    combo.SelectedData = value
    local displayValue = tostring(value or "")
    for _, choice in ipairs(choices or {}) do
        if istable(choice) then
            local choiceLabel = choice.Label or choice[1] or ""
            local choiceValue = choice.Value or choice[2] or choice.Label or choice[1]
            combo:AddChoice(Lang(choiceLabel), choiceValue)
            if tostring(choiceValue) == tostring(value) then
                displayValue = Lang(choiceLabel)
            end
        else
            combo:AddChoice(Lang(choice), choice)
            if tostring(choice) == tostring(value) then
                displayValue = Lang(choice)
            end
        end
    end
    combo:SetValue(displayValue)
    combo.OnSelect = function(_, _, _, data)
        combo.SelectedData = data
    end
    field.PerformLayout = function(_, w)
        combo:SetWide(w - 24)
    end
    return combo
end

local function AddOrderEditor(parent, label, list, names)
    AddLabel(parent, label .. " (drag chips to reorder)")
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, 10)
    panel:SetTall(44)
    panel:SetPaintBackground(false)
    panel.Chips = {}

    local function ChipWide(key)
        local text = (names and names[key]) or key
        surface.SetFont(Font("Small", "DermaDefault"))
        return math.max(72, (surface.GetTextSize(text) or 60) + 28)
    end

    local function LayoutTargets()
        local x = 0
        for index, chip in ipairs(panel.Chips or {}) do
            local key = list[index]
            chip.TargetX = x
            chip.TargetW = ChipWide(key)
            x = x + chip.TargetW + 6
        end
    end

    local function Reorder(fromIndex, toIndex)
        if fromIndex == toIndex or fromIndex < 1 or toIndex < 1 or fromIndex > #list or toIndex > #list then return end
        local item = table.remove(list, fromIndex)
        table.insert(list, toIndex, item)
        local chip = table.remove(panel.Chips, fromIndex)
        table.insert(panel.Chips, toIndex, chip)
        for index, itemChip in ipairs(panel.Chips) do
            itemChip.OrderIndex = index
        end
        LayoutTargets()
    end

    local function ClosestSlot(localX)
        local bestIndex = 1
        local bestDistance = math.huge

        for otherIndex, other in ipairs(panel.Chips or {}) do
            local ox = other.TargetX or other:GetX()
            local ow = other.TargetW or other:GetWide()
            local distance = math.abs(localX - (ox + ow * 0.5))
            if distance < bestDistance then
                bestDistance = distance
                bestIndex = otherIndex
            end
        end

        return bestIndex
    end

    for index, key in ipairs(list or {}) do
            local btn = vgui.Create("DButton", panel)
            StyleButton(btn)
            btn.OrderIndex = index
            btn:SetPos(0, 4)
            btn:SetSize(ChipWide(key), 30)
            btn.Paint = function(self, w, h)
                local keyNow = list[self.OrderIndex] or ""
                local text = (names and names[keyNow]) or keyNow
                draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
                if self:IsHovered() or self.Dragging then
                    draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), self.Dragging and 64 or 38))
                end
                Text(text, Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.OnMousePressed = function(self)
                local mx, _ = gui.MousePos()
                local screenX = self:LocalToScreen(0, 0)
                self.Dragging = mx - screenX
                self.PendingIndex = nil
                self.PendingSince = nil
                self.NextReorder = 0
                self:MouseCapture(true)
            end
            btn.OnMouseReleased = function(self)
                self.Dragging = nil
                self.PendingIndex = nil
                self.PendingSince = nil
                self:MouseCapture(false)
                LayoutTargets()
            end
            btn.Think = function(self)
                if self.Dragging then
                    local mx, _ = gui.MousePos()
                    local localX = panel:ScreenToLocal(mx, 0)
                    self:SetX(localX - self.Dragging)

                    local targetIndex = ClosestSlot(localX)
                    if targetIndex ~= self.OrderIndex then
                        if self.PendingIndex ~= targetIndex then
                            self.PendingIndex = targetIndex
                            self.PendingSince = CurTime()
                        elseif CurTime() - (self.PendingSince or 0) >= 0.08 and CurTime() >= (self.NextReorder or 0) then
                            self.NextReorder = CurTime() + 0.12
                            Reorder(self.OrderIndex, targetIndex)
                            self.PendingIndex = nil
                            self.PendingSince = nil
                        end
                    else
                        self.PendingIndex = nil
                        self.PendingSince = nil
                    end

                    return
                end

                self.OrderIndex = table.KeyFromValue(panel.Chips, self) or self.OrderIndex
                local tx = self.TargetX or self:GetX()
                local tw = self.TargetW or self:GetWide()
                self:SetX(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetX(), tx))
                self:SetWide(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetWide(), tw))
            end
            panel.Chips[#panel.Chips + 1] = btn
    end

    LayoutTargets()
    return panel
end

local function AddManagedOrderEditor(parent, label, list, names, allKeys, vertical)
    list = istable(list) and list or {}
    names = names or {}
    allKeys = istable(allKeys) and allKeys or list

    AddLabel(parent, label .. (vertical and " (drag up/down to reorder, x to hide)" or " (drag left/right to reorder, x to hide)"))
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, 10)
    panel:SetTall(vertical and 286 or 112)
    panel:SetPaintBackground(false)
    panel.DHUDSearchText = string.lower(tostring(label or "") .. " order drag hide show hud entries")

    local track = vgui.Create("DPanel", panel)
    track:SetPaintBackground(false)
    track.Chips = {}

    local combo = vgui.Create("DComboBox", panel)
    StyleCombo(combo)
    combo:SetValue("Add hidden item")
    combo.OnSelect = function(_, _, _, data)
        combo.SelectedData = data
    end

    local add = vgui.Create("DButton", panel)
    StyleButton(add)
    add.Paint = function(self, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
        if self:IsHovered() then draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), 42)) end
        Text("Add", Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local function ChipWide(key)
        local text = names[key] or key
        surface.SetFont(Font("Small", "DermaDefault"))
        return math.max(92, (surface.GetTextSize(text) or 70) + 52)
    end

    local function FillCombo()
        combo:Clear()
        combo:SetValue("Add hidden item")
        combo.SelectedData = nil
        for _, key in ipairs(allKeys) do
            if key ~= "" and not ListHasValue(list, key) then
                combo:AddChoice(names[key] or key, key)
            end
        end
    end

    local function LayoutTargets()
        local maxW = math.max(track:GetWide(), 220)
        local x = 0
        local y = 0
        for index, chip in ipairs(track.Chips or {}) do
            local key = list[index] or ""
            chip.TargetW = vertical and maxW or ChipWide(key)
            chip.TargetH = 30
            if vertical then
                chip.TargetX = 0
                chip.TargetY = y
                y = y + 36
            else
                if x > 0 and x + chip.TargetW > maxW then
                    x = 0
                    y = y + 36
                end
                chip.TargetX = x
                chip.TargetY = y
                x = x + chip.TargetW + 6
            end
        end

        local contentH = y + 36
        track:SetTall(math.max(contentH, 36))
        panel:SetTall(math.max(vertical and 286 or 112, track:GetTall() + 42))
    end

    local function ClosestSlot(localX, localY)
        local bestIndex = 1
        local bestDistance = math.huge
        for index, chip in ipairs(track.Chips or {}) do
            local cx = (chip.TargetX or chip:GetX()) + (chip.TargetW or chip:GetWide()) * 0.5
            local cy = (chip.TargetY or chip:GetY()) + (chip.TargetH or chip:GetTall()) * 0.5
            local distance
            if vertical then
                distance = math.abs(localY - cy)
            else
                distance = math.abs(localX - cx) + math.abs(localY - cy) * 0.35
            end
            if distance < bestDistance then
                bestDistance = distance
                bestIndex = index
            end
        end
        return bestIndex
    end

    local function Reorder(fromIndex, toIndex)
        if fromIndex == toIndex or fromIndex < 1 or toIndex < 1 or fromIndex > #list or toIndex > #list then return end
        local item = table.remove(list, fromIndex)
        table.insert(list, toIndex, item)
        local chip = table.remove(track.Chips, fromIndex)
        table.insert(track.Chips, toIndex, chip)
        for index, itemChip in ipairs(track.Chips) do
            itemChip.OrderIndex = index
        end
        LayoutTargets()
    end

    local function Rebuild()
        for _, child in ipairs(track:GetChildren()) do child:Remove() end
        track.Chips = {}

        for index, key in ipairs(list) do
            local chip = vgui.Create("DButton", track)
            StyleButton(chip)
            chip.OrderIndex = index
            chip:SetSize(vertical and math.max(track:GetWide(), 220) or ChipWide(key), 30)
            chip.Paint = function(self, w, h)
                local keyNow = list[self.OrderIndex] or key
                draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
                if self:IsHovered() or self.Dragging then
                    draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), self.Dragging and 64 or 36))
                end
                Text(names[keyNow] or keyNow, Font("Small", "DermaDefault"), 12, h * 0.5 - 1, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                Text("x", Font("Small", "DermaDefault"), w - 16, h * 0.5 - 1, Muted(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            chip.OnMousePressed = function(self)
                local cx = self:CursorPos()
                if cx >= self:GetWide() - 30 then
                    local removeIndex = self.OrderIndex or index
                    local removeKey = list[removeIndex] or key
                    ConfirmAction("Hide HUD Item", "Remove " .. tostring(names[removeKey] or removeKey) .. " from this HUD draw list?", function()
                        table.remove(list, removeIndex)
                        Rebuild()
                    end)
                    return
                end

                local mx, my = gui.MousePos()
                local sx, sy = self:LocalToScreen(0, 0)
                self.DraggingX = mx - sx
                self.DraggingY = my - sy
                self.Dragging = true
                self.PendingIndex = nil
                self.PendingSince = nil
                self.NextReorder = 0
                self:MouseCapture(true)
            end
            chip.OnMouseReleased = function(self)
                self.Dragging = false
                self.DraggingX = nil
                self.DraggingY = nil
                self.PendingIndex = nil
                self.PendingSince = nil
                self:MouseCapture(false)
                LayoutTargets()
            end
            chip.Think = function(self)
                if self.Dragging then
                    local mx, my = gui.MousePos()
                    local lx, ly = track:ScreenToLocal(mx, my)
                    self:SetPos(lx - (self.DraggingX or 0), ly - (self.DraggingY or 0))
                    local targetIndex = ClosestSlot(lx, ly)
                    if targetIndex ~= self.OrderIndex then
                        if self.PendingIndex ~= targetIndex then
                            self.PendingIndex = targetIndex
                            self.PendingSince = CurTime()
                        elseif CurTime() - (self.PendingSince or 0) >= 0.08 and CurTime() >= (self.NextReorder or 0) then
                            self.NextReorder = CurTime() + 0.12
                            Reorder(self.OrderIndex, targetIndex)
                            self.PendingIndex = nil
                            self.PendingSince = nil
                        end
                    else
                        self.PendingIndex = nil
                        self.PendingSince = nil
                    end
                    return
                end

                self.OrderIndex = table.KeyFromValue(track.Chips, self) or self.OrderIndex
                local tx = self.TargetX or self:GetX()
                local ty = self.TargetY or self:GetY()
                local tw = self.TargetW or self:GetWide()
                self:SetX(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetX(), tx))
                self:SetY(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetY(), ty))
                self:SetWide(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetWide(), tw))
            end
            track.Chips[#track.Chips + 1] = chip
        end

        LayoutTargets()
        FillCombo()
        timer.Simple(0, function()
            if IsValid(parent) then RefreshBodyTall(parent) end
        end)
    end

    add.DoClick = function()
        local key = combo.SelectedData
        if not key or key == "" then return end
        if not ListHasValue(list, key) then
            list[#list + 1] = key
            Rebuild()
        end
    end

    panel.PerformLayout = function(_, w)
        track:SetPos(0, 0)
        track:SetSize(w, math.max(36, panel:GetTall() - 40))
        LayoutTargets()
        combo:SetPos(0, panel:GetTall() - 32)
        combo:SetSize(math.max(160, w - 112), 28)
        add:SetPos(w - 100, panel:GetTall() - 32)
        add:SetSize(100, 28)
    end

    Rebuild()
    return panel
end

local function WeaponChoices()
    local out = {{Label = "None", Value = ""}}
    if weapons and weapons.GetList then
        for _, data in ipairs(weapons.GetList() or {}) do
            local class = data.ClassName or data.Class or data.class
            if class and class ~= "" then out[#out + 1] = {Label = class, Value = class} end
        end
    end
    table.SortByMember(out, "Label", true)
    return out
end

local function EntityChoices()
    local out = {{Label = "None", Value = ""}}
    if scripted_ents and scripted_ents.GetList then
        for class in next, (scripted_ents.GetList() or {}) do
            out[#out + 1] = {Label = class, Value = class}
        end
    end
    table.SortByMember(out, "Label", true)
    return out
end

local function DrawerActionsFromCSV(value, adminSystem)
    local known = {
        goto = {ID = "goto", Label = "Goto", Icon = "navigation/menu", Command = "ulx goto %steamid%"},
        bring = {ID = "bring", Label = "Bring", Icon = "actions/download", Command = "ulx bring %steamid%"},
        returnplayer = {ID = "returnplayer", Label = "Return", Icon = "actions/upload", Command = "ulx return %steamid%"},
        teleport = {ID = "teleport", Label = "Teleport", Icon = "misc/directions_run", Command = "ulx teleport %steamid%"},
        freeze = {ID = "freeze", Label = "Freeze", ToggleLabel = "Unfreeze", Icon = "admin/freeze", Command = "ulx freeze %steamid%", Toggle = true, ToggleCommand = "ulx unfreeze %steamid%"},
        jail = {ID = "jail", Label = "Jail", ToggleLabel = "Unjail", Icon = "admin/security", Command = "ulx jail %steamid%", Toggle = true, ToggleCommand = "ulx unjail %steamid%"},
        slay = {ID = "slay", Label = "Slay", Icon = "admin/gavel", Command = "ulx slay %steamid%"},
        strip = {ID = "strip", Label = "Strip", Icon = "actions/delete", Command = "ulx strip %steamid%"},
        kick = {ID = "kick", Label = "Kick", Icon = "admin/kick", Command = "ulx kick %steamid%"},
        ban = {ID = "ban", Label = "Ban", Icon = "admin/gavel", Command = "ulx ban %steamid% 60"},
        spectate = {ID = "spectate", Label = "Spectate", Icon = "players/person", Command = "ulx spectate %steamid%"},
        warn = {ID = "warn", Label = "Warn", Icon = "admin/warning", Command = "ulx warn %steamid%"},
        mute = {ID = "mute", Label = "Mute", ToggleLabel = "Unmute", Icon = "actions/muted", ToggleIcon = "actions/unmuted", Type = "mute"},
        steamid = {ID = "steamid", Label = "Steam ID", Icon = "players/id_card", Type = "copy"},
        copy = {ID = "copy", Label = "Copy ID", Icon = "communication/link", Type = "copy"},
        profile = {ID = "profile", Label = "Profile", Icon = "communication/link", Type = "profile"}
    }
    local presets = {
        sam = {goto = "sam goto %steamid%", bring = "sam bring %steamid%", freeze = "sam freeze %steamid%", jail = "sam jail %steamid%", kick = "sam kick %steamid%", ban = "sam ban %steamid% 60"},
        fadmin = {goto = "fadmin goto %steamid%", bring = "fadmin bring %steamid%", freeze = "fadmin freeze %steamid%", jail = "fadmin jail %steamid%", kick = "fadmin kick %steamid%", ban = "fadmin ban %steamid% 60"}
    }
    adminSystem = string.lower(tostring(adminSystem or "auto"))
    if adminSystem == "auto" then
        if SAM or sam then
            adminSystem = "sam"
        elseif FAdmin then
            adminSystem = "fadmin"
        else
            adminSystem = "ulx"
        end
    end
    local preset = presets[adminSystem] or {}
    local out = {}
    for _, id in ipairs(CSVToList(value)) do
        local action = table.Copy(known[string.lower(id)] or {ID = id, Label = id, Icon = "navigation/menu", Command = id .. " %steamid%"})
        if preset[action.ID] then action.Command = preset[action.ID] end
        out[#out + 1] = action
    end
    return out
end

local function AddDrawerCommandEditor(parent, label, actionIDs, onChange)
    local ids = {}
    for _, id in ipairs(actionIDs or {}) do
        id = string.Trim(tostring(id or ""))
        if id ~= "" and not ListHasValue(ids, id) then ids[#ids + 1] = id end
    end

    local choices = {
        {Label = "Goto", Value = "goto"},
        {Label = "Bring", Value = "bring"},
        {Label = "Return", Value = "returnplayer"},
        {Label = "Teleport", Value = "teleport"},
        {Label = "Freeze", Value = "freeze"},
        {Label = "Jail", Value = "jail"},
        {Label = "Slay", Value = "slay"},
        {Label = "Strip Weapons", Value = "strip"},
        {Label = "Spectate", Value = "spectate"},
        {Label = "Warn", Value = "warn"},
        {Label = "Kick", Value = "kick"},
        {Label = "Ban", Value = "ban"},
        {Label = "Local Mute", Value = "mute"},
        {Label = "Steam ID", Value = "steamid"},
        {Label = "Copy ID", Value = "copy"},
        {Label = "Profile", Value = "profile"}
    }

    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, 10)
    panel:SetTall(122)
    panel:SetPaintBackground(false)
    panel.DHUDSearchText = string.lower(tostring(label or "") .. " drawer commands admin actions mute kick ban freeze jail")
    panel.Paint = function(_, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
        draw.RoundedBox(Radius("SM"), 0, 0, 4, h, WithAlpha(Primary(), 180))
        Text(label, Font("Small", "DermaDefault"), 14, 10, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local track = vgui.Create("DPanel", panel)
    track:SetPaintBackground(false)
    track.Chips = {}

    local combo = vgui.Create("DComboBox", panel)
    StyleCombo(combo)
    combo:SetValue("Add command")
    combo.SelectedData = nil
    for _, choice in ipairs(choices) do
        combo:AddChoice(choice.Label, choice.Value)
    end
    combo.OnSelect = function(_, _, _, data)
        combo.SelectedData = data
    end

    local add = vgui.Create("DButton", panel)
    StyleButton(add)
    add.Hover = 0
    add.Paint = function(self, w, h)
        self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
        if self.Hover > 0.01 then draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), 28 + self.Hover * 42)) end
        Text("Add", Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local function ChipWide(id)
        return math.max(74, #tostring(id or "") * 8 + 34)
    end

    local function LayoutTargets()
        local maxW = math.max(track:GetWide(), 220)
        local x = 0
        local y = 0
        for index, chip in ipairs(track.Chips or {}) do
            local id = ids[index] or ""
            chip.TargetW = ChipWide(id)
            if x > 0 and x + chip.TargetW > maxW then
                x = 0
                y = y + 36
            end
            chip.TargetX = x
            chip.TargetY = y
            x = x + chip.TargetW + 6
        end
        track:SetTall(y + 36)
        panel:SetTall(math.max(122, track:GetTall() + 82))
    end

    local function NotifyChanged()
        if onChange then onChange(table.concat(ids, ",")) end
    end

    local function Reorder(fromIndex, toIndex)
        if fromIndex == toIndex or fromIndex < 1 or toIndex < 1 or fromIndex > #ids or toIndex > #ids then return end
        local id = table.remove(ids, fromIndex)
        table.insert(ids, toIndex, id)
        local chip = table.remove(track.Chips, fromIndex)
        table.insert(track.Chips, toIndex, chip)
        for index, item in ipairs(track.Chips) do
            item.OrderIndex = index
        end
        LayoutTargets()
        NotifyChanged()
    end

    local function ClosestSlot(localX)
        local bestIndex = 1
        local bestDistance = math.huge
        for index, chip in ipairs(track.Chips or {}) do
            local x = chip.TargetX or chip:GetX()
            local w = chip.TargetW or chip:GetWide()
            local distance = math.abs(localX - (x + w * 0.5))
            if distance < bestDistance then
                bestDistance = distance
                bestIndex = index
            end
        end
        return bestIndex
    end

    local function Rebuild()
        for _, child in ipairs(track:GetChildren()) do child:Remove() end
        track.Chips = {}

        local maxW = math.max(track:GetWide(), 220)
        local x = 0
        local y = 0
        for index, id in ipairs(ids) do
            local chip = vgui.Create("DButton", track)
            StyleButton(chip)
            chip.OrderIndex = index
            local chipW = ChipWide(id)
            if x > 0 and x + chipW > maxW then
                x = 0
                y = y + 36
            end
            chip:SetPos(x, y + 4)
            chip:SetSize(chipW, 30)
            chip.Hover = 0
            chip.Paint = function(self, w, h)
                self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
                draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
                if self.Hover > 0.01 then draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Color(232, 84, 84), 18 + self.Hover * 34)) end
                Text(id, Font("Small", "DermaDefault"), 12, h * 0.5 - 1, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                Text("x", Font("Small", "DermaDefault"), w - 14, h * 0.5 - 1, Muted(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            chip.OnMousePressed = function(self)
                local localX = self:CursorPos()
                if localX >= self:GetWide() - 26 then
                    local removeIndex = self.OrderIndex or index
                    local removeID = ids[removeIndex] or id
                    ConfirmAction("Remove Drawer Button", "Remove " .. tostring(removeID) .. " from the scoreboard drawer?", function()
                        table.remove(ids, removeIndex)
                        Rebuild()
                        NotifyChanged()
                    end)
                    return
                end

                local mx = gui.MousePos()
                local sx = self:LocalToScreen(0, 0)
                self.Dragging = mx - sx
                self.PendingIndex = nil
                self.PendingSince = nil
                self.NextReorder = 0
                self:MouseCapture(true)
            end
            chip.OnMouseReleased = function(self)
                self.Dragging = nil
                self.PendingIndex = nil
                self.PendingSince = nil
                self:MouseCapture(false)
                LayoutTargets()
            end
            chip.Think = function(self)
                if self.Dragging then
                    local mx = gui.MousePos()
                    local localX = track:ScreenToLocal(mx, 0)
                    self:SetX(localX - self.Dragging)

                    local targetIndex = ClosestSlot(localX)
                    if targetIndex ~= self.OrderIndex then
                        if self.PendingIndex ~= targetIndex then
                            self.PendingIndex = targetIndex
                            self.PendingSince = CurTime()
                        elseif CurTime() - (self.PendingSince or 0) >= 0.08 and CurTime() >= (self.NextReorder or 0) then
                            self.NextReorder = CurTime() + 0.12
                            Reorder(self.OrderIndex, targetIndex)
                            self.PendingIndex = nil
                            self.PendingSince = nil
                        end
                    else
                        self.PendingIndex = nil
                        self.PendingSince = nil
                    end

                    return
                end

                self.OrderIndex = table.KeyFromValue(track.Chips, self) or self.OrderIndex
                local tx = self.TargetX or self:GetX()
                local ty = (self.TargetY or 0) + 4
                local tw = self.TargetW or self:GetWide()
                self:SetX(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetX(), tx))
                self:SetY(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetY(), ty))
                self:SetWide(Lerp(math.Clamp(FrameTime() * 18, 0, 1), self:GetWide(), tw))
            end
            x = x + chip:GetWide() + 6
            track.Chips[#track.Chips + 1] = chip
        end
        LayoutTargets()
    end

    add.DoClick = function()
        local id = combo.SelectedData or combo:GetValue()
        id = string.Trim(string.lower(tostring(id or "")))
        local labelMap = {
            ["goto"] = "goto",
            ["go to"] = "goto",
            ["bring"] = "bring",
            ["return"] = "returnplayer",
            ["teleport"] = "teleport",
            ["freeze"] = "freeze",
            ["jail"] = "jail",
            ["slay"] = "slay",
            ["strip weapons"] = "strip",
            ["spectate"] = "spectate",
            ["warn"] = "warn",
            ["kick"] = "kick",
            ["ban"] = "ban",
            ["local mute"] = "mute",
            ["steam id"] = "steamid",
            ["copy id"] = "copy",
            ["profile"] = "profile"
        }
        id = labelMap[id] or id
        if id ~= "" and id ~= "add command" and not ListHasValue(ids, id) then
            ids[#ids + 1] = id
            Rebuild()
            NotifyChanged()
        end
    end

    panel.PerformLayout = function(_, w)
        track:SetPos(12, 34)
        track:SetSize(w - 24, math.max(42, panel:GetTall() - 82))
        LayoutTargets()
        combo:SetPos(12, panel:GetTall() - 38)
        combo:SetSize(math.max(160, w - 142), 28)
        add:SetPos(w - 112, panel:GetTall() - 38)
        add:SetSize(100, 28)
    end

    Rebuild()

    return {
        GetCSV = function()
            return table.concat(ids, ",")
        end
    }
end

local function SaveScoreboardConfig(cfg)
    DHUD.Config = DHUD.Config or {}
    DHUD.Config.Scoreboard = istable(cfg) and table.Copy(cfg) or {}
    if DHUD.Scoreboard and DHUD.Scoreboard.ApplyExternalConfig then
        DHUD.Scoreboard.ApplyExternalConfig(cfg)
    elseif net and istable(cfg) then
        net.Start("DHUD.Scoreboard.SaveConfig")
        net.WriteString(util.TableToJSON(cfg) or "{}")
        net.SendToServer()
    end
    timer.Simple(0, function()
        if IsValid(frame) and DHUD.Scoreboard and DHUD.Scoreboard.PreviewExternalConfig then
            DHUD.Scoreboard.PreviewExternalConfig(nil)
        end
    end)
end

local function SyncMOTDConfig(cfg)
    DHUD.Config = DHUD.Config or {}
    DHUD.Config.MOTD = table.Copy(cfg or {})

    if DHUD.Scoreboard and DHUD.Scoreboard.GetConfig and DHUD.Scoreboard.ApplyExternalConfig then
        local score = DHUD.Scoreboard.GetConfig()
        score.MOTD = table.Copy(cfg or {})
        DHUD.Scoreboard.ApplyExternalConfig(score)
    end

    SaveConfig()
end

local function CreditDetected()
    return DubzCreditSystem ~= nil
end

local function InventoryDetected()
    return DubzInventorySystem ~= nil
end

local function DeathScreenDetected()
    return true
end

local function ColorRow(parent, key, label)
    DHUD.Config = DHUD.Config or {}
    DHUD.Config.Colors = DHUD.Config.Colors or {}
    local colors = DHUD.Config.Colors
    local current = colors[key] or color_white

    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 10)
    row:SetTall(58)
    row:SetPaintBackground(false)
    row.DHUDSearchText = string.lower(tostring(key or "") .. " " .. tostring(label or "") .. " color theme")
    row.Paint = function(_, w, h)
        local col = colors[key] or current
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
        draw.RoundedBox(Radius("SM"), 0, 0, 4, h, WithAlpha(col, 220))
        Text(label, Font("Small", "DermaDefault"), 58, 11, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text(key, Font("Small", "DermaDefault"), 58, 31, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local swatch = vgui.Create("DButton", row)
    StyleButton(swatch)
    swatch:SetPos(14, 12)
    swatch:SetSize(34, 34)

    swatch.Paint = function(_, w, h)
        local col = colors[key] or current
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, col)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, Color(255, 255, 255, 18))
    end

    swatch.DoClick = function()
        local picker = vgui.Create("DFrame")
        picker:SetSize(360, 300)
        picker:Center()
        picker:SetTitle("")
        picker:ShowCloseButton(true)
        picker:MakePopup()
        picker.Paint = function(_, w, h)
            draw.RoundedBox(Radius("MD"), 0, 0, w, h, CardColor(255))
            Text(label, Font("Header", "DermaDefaultBold"), 16, 12, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local mixer = vgui.Create("DColorMixer", picker)
        mixer:SetPos(16, 48)
        mixer:SetSize(328, 190)
        mixer:SetPalette(false)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetColor(colors[key] or current)
        mixer.ValueChanged = function(_, col)
            colors[key] = Color(col.r, col.g, col.b)
        end

        local done = vgui.Create("DButton", picker)
        StyleButton(done)
        done:SetPos(232, 252)
        done:SetSize(112, 30)
        done.Paint = function(self, w, h)
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), self:IsHovered() and 92 or 52))
            Text("Done", Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        done.DoClick = function() picker:Remove() end
    end
end

local function AddRankTagRow(parent, group, data, fallback, onRemove, onSave)
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, 10)
    panel:SetTall(76)
    panel:SetPaintBackground(false)
    panel.DHUDSearchText = string.lower(tostring(group or "") .. " rank tag usergroup admin mod color label")

    local currentColor = data.Color or fallback.Color or color_white
    if isstring(currentColor) then
        currentColor = HexToColor(currentColor, color_white)
    end
    local labelEntry = vgui.Create("DTextEntry", panel)
    labelEntry:SetText(tostring(data.Name or fallback.Name or group))
    StyleEntry(labelEntry)

    local groupEntry = vgui.Create("DTextEntry", panel)
    groupEntry:SetText(tostring(group or ""))
    StyleEntry(groupEntry)

    local hexEntry = vgui.Create("DTextEntry", panel)
    hexEntry:SetText(ColorToHex(currentColor))
    StyleEntry(hexEntry)

    local swatch = vgui.Create("DButton", panel)
    StyleButton(swatch)

    panel.Paint = function(_, w, h)
        local col = HexToColor(hexEntry:GetValue(), currentColor)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
        draw.RoundedBox(Radius("SM"), 0, 0, 4, h, WithAlpha(col, 220))
        Text("Associated rank", Font("Small", "DermaDefault"), 14, 8, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text("Display label", Font("Small", "DermaDefault"), 178, 8, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text("Color", Font("Small", "DermaDefault"), w - 304, 8, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    panel.PerformLayout = function(_, w)
        groupEntry:SetPos(14, 30)
        groupEntry:SetSize(148, 28)
        labelEntry:SetPos(178, 30)
        labelEntry:SetSize(math.max(130, w - 526), 28)
        swatch:SetPos(w - 304, 30)
        swatch:SetSize(28, 28)
        hexEntry:SetPos(w - 266, 30)
        hexEntry:SetSize(94, 28)
    end

    swatch.Paint = function(_, w, h)
        local col = HexToColor(hexEntry:GetValue(), currentColor)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, col)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, Color(255, 255, 255, 18))
    end

    local save
    if onSave then
        save = vgui.Create("DButton", panel)
        StyleButton(save)
        save.Hover = 0
        save.Paint = function(self, w, h)
            self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
            if self.Hover > 0.01 then draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), 24 + self.Hover * 38)) end
            Text("Save", Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        save.DoClick = function()
            onSave(groupEntry:GetValue(), labelEntry:GetValue(), hexEntry:GetValue(), group)
        end

        local oldLayout = panel.PerformLayout
        panel.PerformLayout = function(self, w, h)
            oldLayout(self, w, h)
            labelEntry:SetSize(math.max(130, w - 526), 28)
            swatch:SetPos(w - 304, 30)
            hexEntry:SetPos(w - 266, 30)
            save:SetPos(w - 158, 30)
            save:SetSize(64, 28)
        end
    end

    swatch.DoClick = function()
        local picker = vgui.Create("DFrame")
        picker:SetSize(360, 300)
        picker:Center()
        picker:SetTitle("")
        picker:ShowCloseButton(true)
        picker:MakePopup()
        picker.Paint = function(_, w, h)
            draw.RoundedBox(Radius("MD"), 0, 0, w, h, CardColor(255))
            Text(groupEntry:GetValue() .. " rank color", Font("Header", "DermaDefaultBold"), 16, 12, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local mixer = vgui.Create("DColorMixer", picker)
        mixer:SetPos(16, 48)
        mixer:SetSize(328, 190)
        mixer:SetPalette(false)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetColor(HexToColor(hexEntry:GetValue(), currentColor))
        mixer.ValueChanged = function(_, col)
            hexEntry:SetText(ColorToHex(col))
        end

        local done = vgui.Create("DButton", picker)
        StyleButton(done)
        done:SetPos(232, 252)
        done:SetSize(112, 30)
        done.Paint = function(self, w, h)
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), self:IsHovered() and 92 or 52))
            Text("Done", Font("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        done.DoClick = function() picker:Remove() end
    end

    local remove
    if onRemove then
        remove = vgui.Create("DButton", panel)
        StyleButton(remove)
        remove.Hover = 0
        remove.Paint = function(self, w, h)
            self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
            if self.Hover > 0.01 then draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Color(232, 84, 84), 28 + self.Hover * 42)) end
            Text("x", Font("Body", "DermaDefaultBold"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        remove.DoClick = onRemove
        local oldLayout = panel.PerformLayout
        panel.PerformLayout = function(self, w, h)
            oldLayout(self, w, h)
            remove:SetPos(w - 46, 30)
            remove:SetSize(28, 28)
        end
    end

    return {Name = labelEntry, Hex = hexEntry, Group = groupEntry, OriginalGroup = group}
end

local function ClearBody(body)
    for _, child in ipairs(body:GetChildren()) do
        child:Remove()
    end
end

RefreshBodyTall = function(body)
    if not IsValid(body) then return end

    local maxBottom = 0
    for _, child in ipairs(body:GetChildren()) do
        if IsValid(child) and child:IsVisible() then
            local _, y = child:GetPos()
            maxBottom = math.max(maxBottom, y + child:GetTall())
        end
    end

    body:SetTall(math.max(maxBottom + 16, 64))
    if body.InvalidateParent then body:InvalidateParent(true) end
end

local function ApplyConfigSearch(body)
    local needle = string.lower(string.Trim(tostring(configSearchText or "")))
    if needle == "" then return end

    for _, child in ipairs(body:GetChildren()) do
        if IsValid(child) and child.DHUDSearchText then
            child:SetVisible(string.find(child.DHUDSearchText, needle, 1, true) ~= nil)
        end
    end
end

local function BuildOverview(body)
    local cfg = DHUD.Config
    cfg.Language = cfg.Language or "en"
    cfg.Interface = cfg.Interface or {}
    cfg.Scoreboard = cfg.Scoreboard or {}
    cfg.Connection = cfg.Connection or {}
    cfg.DarkRPMenus = cfg.DarkRPMenus or {}
    local languageChoices = {}
    if DHUD.Language and istable(DHUD.Language.Available) then
        for _, data in ipairs(DHUD.Language.Available) do
            languageChoices[#languageChoices + 1] = {
                Label = tostring(data.Name or data.Code or "English"),
                Value = tostring(data.Code or "en")
            }
        end
    else
        languageChoices = {
            {Label = "English", Value = "en"}
        }
    end
    AddSection(body, "Language & Localization", "Choose the language used by built-in HUD and menu labels.")
    local language = AddCombo(body, (DHUD.T and DHUD.T("config.language", "Language") or "Language"), languageChoices, cfg.Language)
    language.DHUDSearchText = "language locale translation"

    AddSection(body, "Interface Sounds", "Hover sound behavior for interactive HUD controls.")
    local hoverSounds = AddCheck(body, "Enable hover sounds", cfg.Interface.HoverSounds ~= false)
    local hoverPreset = AddCombo(body, "Hover sound preset", {
        {Label = "Rollover", Value = "rollover"},
        {Label = "Soft click", Value = "soft_click"},
        {Label = "Blip", Value = "blip"},
        {Label = "Tick", Value = "tick"}
    }, cfg.Interface.HoverSoundChoice or "rollover")

    AddSection(body, "System Overview", "Core HUD behavior and quick workspace actions.")
    local style = AddCombo(body, "Active HUD layout", {
        {Label = "Bar HUD", Value = "bar"},
        {Label = "Card HUD", Value = "card"}
    }, cfg.HUDStyle or "bar")
    local clock = AddCombo(body, "Clock source", {
        {Label = "Real world time", Value = "realtime"},
        {Label = "Atmos / in-game time", Value = "atmos"}
    }, cfg.Clock and cfg.Clock.Mode or "realtime")
    local adminSystem = AddCombo(body, "Admin command system", {
        {Label = "Auto detect", Value = "auto"},
        {Label = "ULX", Value = "ulx"},
        {Label = "SAM", Value = "sam"},
        {Label = "FAdmin", Value = "fadmin"},
        {Label = "ServerGuard / Custom", Value = "custom"}
    }, cfg.Scoreboard.AdminSystem or "auto")
    AddSection(body, "Animation Menu", "DarkRP gesture/action menu override.")
    local darkrpMenus = cfg.DarkRPMenus
    local animationMenuEnabled = AddCheck(body, "Enable animation menu override", darkrpMenus.AnimationMenu ~= false)
    local animationTitle = AddEntry(body, "Animation menu title", darkrpMenus.AnimationTitle or "Actions Menu")
    local animationSubtitle = AddEntry(body, "Animation menu subtitle", darkrpMenus.AnimationSubtitle or "Choose a gesture")
    local animationWidth = AddSlider(body, "Animation menu width", darkrpMenus.AnimationWidth or 278, 240, 420, 0)
    local animationRows = AddSlider(body, "Animation row height", darkrpMenus.AnimationRowHeight or 36, 30, 56, 0)
    local animationX = AddSlider(body, "Animation menu horizontal position", darkrpMenus.AnimationXPercent or 0.61, 0.05, 0.9, 2)
    AddSection(body, "Connection Overlay", "Fullscreen crash / reconnect panel behavior.")
    local connection = cfg.Connection
    local connectionEnabled = AddCheck(body, "Enable lost connection overlay", connection.Enabled ~= false)
    local connectionTimeout = AddSlider(body, "Lost connection timeout", connection.Timeout or 6, 2, 20, 1)
    local connectionRetry = AddCheck(body, "Auto retry connection", connection.AutoRetry ~= false)
    local connectionRetryDelay = AddSlider(body, "Auto retry delay", connection.RetryDelay or 30, 5, 120, 0)
    local connectionBlur = AddCheck(body, "Use background blur", connection.Blur ~= false)
    local connectionDisconnect = AddCheck(body, "Show disconnect button", connection.ShowDisconnect ~= false)

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)

    AddMenuButton(buttons, "Apply", function()
        cfg.Language = language.SelectedData or language:GetValue() or "en"
        cfg.HUDStyle = (style.SelectedData or style:GetValue()) == "card" and "card" or "bar"
        cfg.Clock = cfg.Clock or {}
        cfg.Clock.Mode = (clock.SelectedData or clock:GetValue()) == "atmos" and "atmos" or "realtime"
        cfg.Interface.HoverSounds = hoverSounds:GetChecked()
        cfg.Interface.HoverSoundChoice = hoverPreset.SelectedData or hoverPreset:GetValue() or "rollover"
        local hoverSoundPaths = {
            rollover = "ui/buttonrollover.wav",
            soft_click = "ui/buttonclick.wav",
            blip = "buttons/blip1.wav",
            tick = "buttons/lightswitch2.wav"
        }
        cfg.Interface.HoverSound = hoverSoundPaths[cfg.Interface.HoverSoundChoice] or hoverSoundPaths.rollover
        cfg.Scoreboard.AdminSystem = adminSystem.SelectedData or adminSystem:GetValue()
        darkrpMenus.AnimationMenu = animationMenuEnabled:GetChecked()
        darkrpMenus.AnimationTitle = animationTitle:GetValue()
        darkrpMenus.AnimationSubtitle = animationSubtitle:GetValue()
        darkrpMenus.AnimationWidth = math.Round(animationWidth:GetValue())
        darkrpMenus.AnimationRowHeight = math.Round(animationRows:GetValue())
        darkrpMenus.AnimationXPercent = tonumber(animationX:GetValue()) or 0.61
        connection.Enabled = connectionEnabled:GetChecked()
        connection.Timeout = tonumber(connectionTimeout:GetValue()) or 6
        connection.AutoRetry = connectionRetry:GetChecked()
        connection.RetryDelay = math.Round(connectionRetryDelay:GetValue())
        connection.Blur = connectionBlur:GetChecked()
        connection.ShowDisconnect = connectionDisconnect:GetChecked()
        SaveConfig()
    end)
    AddMenuButton(buttons, "Placement", function()
        if DHUD.Placement and DHUD.Placement.Open then
            DHUD.Placement.Open()
        end
    end)
end

local function BuildTheme(body)
    DHUD.Config.Colors = DHUD.Config.Colors or {}

    AddSection(body, "HUD Theme", "Sync with Dubz Framework or use a script-specific framework preset.")

    local function AddThemeChoice(label, id, accent, isSync)
        local btn = vgui.Create("DButton", body)
        StyleButton(btn)
        btn:Dock(TOP)
        btn:SetTall(44)
        btn:DockMargin(0, 0, 0, isSync and 14 or 8)
        btn.Hover = 0
        btn.Paint = function(self, w, h)
            self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
            local selected = isSync and DHUD.Config.ThemeSource == "framework" or (DHUD.Config.ThemeSource == "preset" and DHUD.Config.FrameworkTheme == id)
            local col = accent or Primary()

            draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
            if selected or self.Hover > 0.01 then
                draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(col, selected and 44 or (16 + self.Hover * 26)))
            end

            draw.RoundedBox(Radius("XS"), 14, 10, 24, 24, col)
            Text(label, Font("Small", "DermaDefault"), 52, h * 0.5 - 1, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            Text(selected and "Active" or "Apply", Font("Small", "DermaDefault"), w - 18, h * 0.5 - 1, selected and col or Muted(), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            if ApplyFrameworkThemeToDHUD(isSync and "framework" or id, true) then
                BuildBody(body)
            end
        end
    end

    AddThemeChoice("Sync With Dubz Framework", "framework", DubzLib and DubzLib.Color and DubzLib.Color("Primary") or Primary(), true)

    local presets = DubzLib and DubzLib.GetThemePresetList and DubzLib.GetThemePresetList() or {}
    for _, preset in ipairs(presets) do
        AddThemeChoice(preset.Name or preset.ID, preset.ID, preset.Accent or Primary(), false)
    end
end

local function BuildHUD(body)
    local bar = DHUD.Config.Bar or {}
    local layout = bar.Layout or {}
    local section = bar.Section or {}
    local card = DHUD.Config.Card or {}
    local cardProps = card.Props or {}
    local currentStyle = string.lower(tostring(DHUD.Config.HUDStyle or "bar")) == "card" and "card" or "bar"

    AddSection(body, "HUD Layout", "Switch between bar and card HUDs without losing saved settings.")
    local style = AddCombo(body, "HUD style", {
        {Label = "Bar HUD", Value = "bar"},
        {Label = "Card HUD", Value = "card"}
    }, currentStyle)
    style.OnSelect = function(_, _, _, value)
        style.SelectedData = value
        DHUD.Config.HUDStyle = value == "card" and "card" or "bar"
        SaveConfig()
        BuildBody(body)
    end

    local height
    local edge
    local startY
    local gap
    local pad
    local accentLineEnabled
    local animateNumbers = AddCheck(body, "Animate changing numbers", bar.AnimateNumbers ~= false)
    local barPropsEnabled
    bar.LeftEntries = istable(bar.LeftEntries) and bar.LeftEntries or {"identity", "health", "armor", "salary", "wallet", "props"}
    bar.RightEntries = istable(bar.RightEntries) and bar.RightEntries or {"clock", "arrested", "wanted", "gunlicense"}
    local names = {
        identity = "Player",
        health = "Health",
        armor = "Armor",
        oxygen = "Oxygen",
        hunger = "Hunger",
        salary = "Salary",
        wallet = "Cash",
        props = "Props",
        clock = "Clock",
        arrested = "Arrested",
        wanted = "Wanted",
        gunlicense = "License"
    }
    local barLeftKeys = {"identity", "health", "armor", "oxygen", "hunger", "salary", "wallet", "props"}
    local barRightKeys = {"clock", "arrested", "wanted", "gunlicense"}
    local cardKeys = {"health", "armor", "hunger", "oxygen", "money", "props"}
    names.money = "Wallet / Salary"
    if currentStyle == "bar" then
        AddSection(body, "Bar HUD", "Track placement, entry spacing, and left/right draw order.")
        bar.BottomAccentLine = istable(bar.BottomAccentLine) and bar.BottomAccentLine or {}
        height = AddSlider(body, "Bar height", layout.Height or 42, 34, 64, 0)
        edge = AddCombo(body, "Bar screen edge", {
            {Label = "Top", Value = "top"},
            {Label = "Bottom", Value = "bottom"}
        }, layout.Edge or "top")
        startY = AddSlider(body, "Top offset", layout.StartY or 6, 0, 40, 0)
        gap = AddSlider(body, "Track gap", layout.Gap or 8, 2, 18, 0)
        pad = AddSlider(body, "Entry horizontal padding", section.PadX or 12, 6, 22, 0)
        accentLineEnabled = AddCheck(body, "Show bottom accent line", bar.BottomAccentLine.Enabled == true)
        AddManagedOrderEditor(body, "Left bar draw order", bar.LeftEntries, names, barLeftKeys, false)
        AddManagedOrderEditor(body, "Right bar draw order", bar.RightEntries, names, barRightKeys, false)
        local propEntry = bar.Entries and bar.Entries.props or {}
        barPropsEnabled = AddCheck(body, "Show prop counter", propEntry.Enabled ~= false)
    end

    local cardX
    local cardBottom
    local cardWidth
    local cardMoney
    local cardPropsEnabled
    if currentStyle == "card" then
        AddSection(body, "Card HUD", "Card anchor, width, and visible compact entries.")
        card.Order = istable(card.Order) and card.Order or {"health", "armor", "hunger", "oxygen", "money", "props"}
        cardX = AddSlider(body, "Card X position", card.X or 18, 0, 420, 0)
        cardBottom = AddSlider(body, "Card bottom offset", card.BottomY or 30, 0, 280, 0)
        cardWidth = AddSlider(body, "Card width", card.Width or 300, 220, 420, 0)
        cardMoney = AddCheck(body, "Show wallet card", card.ShowMoney ~= false)
        cardPropsEnabled = AddCheck(body, "Show prop counter", cardProps.Enabled ~= false)
        AddManagedOrderEditor(body, "Card HUD draw order", card.Order, names, cardKeys, true)
    end

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save HUD", function()
        DHUD.Config.HUDStyle = (style.SelectedData or style:GetValue()) == "card" and "card" or "bar"
        DHUD.Config.Bar = bar
        DHUD.Config.Card = card
        bar.Layout = layout
        bar.Section = section
        card.Props = cardProps
        if height then
            bar.Entries = bar.Entries or {}
            bar.Entries.props = bar.Entries.props or {Type = "props", Label = "Props", Icon = "misc/handyman", Accent = "props"}
            layout.Height = math.Round(height:GetValue())
            layout.Edge = edge.SelectedData or edge:GetValue()
            layout.StartY = math.Round(startY:GetValue())
            layout.Gap = math.Round(gap:GetValue())
            section.PadX = math.Round(pad:GetValue())
            bar.Entries.props.Enabled = barPropsEnabled:GetChecked()
            bar.BottomAccentLine.Enabled = accentLineEnabled:GetChecked()
        end
        bar.AnimateNumbers = animateNumbers:GetChecked()
        if cardX then
            card.X = math.Round(cardX:GetValue())
            card.BottomY = math.Round(cardBottom:GetValue())
            card.Width = math.Round(cardWidth:GetValue())
            card.ShowMoney = cardMoney:GetChecked()
            cardProps.Enabled = cardPropsEnabled:GetChecked()
        end
        SaveConfig()
    end)
    AddMenuButton(buttons, "Placement", function()
        if DHUD.Placement and DHUD.Placement.Open then DHUD.Placement.Open() end
    end)
end

local function BuildScoreboard(body)
    DHUD.Config.Scoreboard = DHUD.Config.Scoreboard or {}
    local cfg = DHUD.Scoreboard and DHUD.Scoreboard.GetConfig and DHUD.Scoreboard.GetConfig() or DHUD.Config.Scoreboard
    DHUD.Config.Scoreboard = cfg

    AddSection(body, "Header", "Server title, subtitle, icon, and scoreboard size.")
    local title = AddEntry(body, "Header title", cfg.HeaderTitle or "")
    local subtitle = AddEntry(body, "Header subtitle", cfg.HeaderSubtitle or "")
    local showHeaderIcon = AddCheck(body, "Show header icon/image", cfg.ShowHeaderIcon ~= false)
    local icon = AddEntry(body, "Header icon path", cfg.HeaderIcon or "misc/groups")
    local image = AddEntry(body, "Header Imgur URL/key", cfg.HeaderIconURL or "")
    local iconScale = AddSlider(body, "Header icon scale", cfg.HeaderIconScale or 1, 0.5, 1.8, 2)
    iconScale.OnValueChanged = function(_, value)
        cfg.HeaderIconScale = math.Clamp(tonumber(value) or cfg.HeaderIconScale or 1, 0.5, 1.8)
        if DHUD.Scoreboard and DHUD.Scoreboard.PreviewExternalConfig then
            DHUD.Scoreboard.PreviewExternalConfig(cfg)
        end
    end
    local width = AddSlider(body, "Scoreboard width", cfg.Width or 960, 820, 1120, 0)
    width.OnValueChanged = function(_, value)
        cfg.Width = math.Round(tonumber(value) or cfg.Width or 960)
        if DHUD.Scoreboard and DHUD.Scoreboard.PreviewExternalConfig then
            DHUD.Scoreboard.PreviewExternalConfig(cfg)
        end
    end
    local rows = AddSlider(body, "Player row gap", cfg.RowGap or 3, 0, 10, 0)
    local search = AddCheck(body, "Show search", cfg.ShowSearch ~= false)
    local money = AddCheck(body, "Show money column", cfg.ShowMoney ~= false)
    local rep = AddCheck(body, "Enable rep buttons", cfg.RepEnabled ~= false)
    AddSection(body, "Columns", "Drag sliders while previewing to line up player information.")
    cfg.Columns = istable(cfg.Columns) and cfg.Columns or {Jobs = 0.45, Staff = 0.58, Cash = 0.74, Ping = 0.9}
    cfg.ColumnOrder = istable(cfg.ColumnOrder) and cfg.ColumnOrder or {"Jobs", "Staff", "Cash", "Ping"}
    local columnSliders = {}
    for _, key in ipairs({"Jobs", "Staff", "Cash", "Ping"}) do
        columnSliders[key] = AddSlider(body, key .. " column X", cfg.Columns[key] or 0.5, 0.18, 0.94, 2)
        columnSliders[key].OnValueChanged = function(_, value)
            cfg.Columns[key] = math.Clamp(tonumber(value) or cfg.Columns[key] or 0.5, 0.05, 0.98)
            if DHUD.Scoreboard and DHUD.Scoreboard.PreviewExternalConfig then
                DHUD.Scoreboard.PreviewExternalConfig(cfg)
            end
        end
    end
    local adminSystem = {
        SelectedData = cfg.AdminSystem or "auto",
        GetValue = function() return cfg.AdminSystem or "auto" end
    }
    local actionIDs = {}
    for _, action in ipairs(cfg.DrawerActions or {}) do
        if istable(action) then
            actionIDs[#actionIDs + 1] = action.ID or action.Label or ""
        elseif action ~= nil then
            actionIDs[#actionIDs + 1] = tostring(action)
        end
    end
    local drawerActions = AddDrawerCommandEditor(body, "Drawer command buttons", actionIDs, function(csv)
        cfg.AdminSystem = adminSystem.SelectedData or adminSystem:GetValue()
        cfg.DrawerActions = DrawerActionsFromCSV(csv, cfg.AdminSystem)
        cfg.DrawerActionOrder = CSVToList(csv)
        if DHUD.Scoreboard and DHUD.Scoreboard.PreviewExternalConfig then
            DHUD.Scoreboard.PreviewExternalConfig(cfg)
        end
    end)

    AddSection(body, "Rank Tags", "Override display labels and colors for usergroups.")
    cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or {}
    cfg.DisabledRankDisplay = istable(cfg.DisabledRankDisplay) and cfg.DisabledRankDisplay or {}
    local rankDefaults = {
        superadmin = {Name = "Owner", Color = Color(232, 91, 91)},
        admin = {Name = "Admin", Color = Color(232, 176, 77)},
        moderator = {Name = "Moderator", Color = Color(122, 166, 255)},
        mod = {Name = "Moderator", Color = Color(122, 166, 255)},
        vip = {Name = "VIP", Color = Color(232, 176, 77)},
        user = {Name = "User", Color = Color(160, 160, 160)}
    }
    local rankRows = {}
    local rankGroups = {"superadmin", "admin", "moderator", "mod", "vip", "user"}
    for group in next, (cfg.RankDisplay or {}) do
        if not ListHasValue(rankGroups, group) then rankGroups[#rankGroups + 1] = group end
    end
    table.sort(rankGroups, function(a, b)
        local order = {superadmin = 1, admin = 2, moderator = 3, mod = 4, vip = 5, user = 6}
        return (order[a] or 99) == (order[b] or 99) and tostring(a) < tostring(b) or (order[a] or 99) < (order[b] or 99)
    end)
    for _, group in ipairs(rankGroups) do
        if cfg.DisabledRankDisplay[group] then continue end
        local data = cfg.RankDisplay[group] or {}
        local fallback = rankDefaults[group] or {Name = group, Color = color_white}
        rankRows[group] = AddRankTagRow(body, group, data, fallback, function()
            ConfirmAction("Remove Rank Mapping", "Remove the rank mapping for " .. tostring(group) .. "?", function()
                cfg.RankDisplay[group] = nil
                cfg.DisabledRankDisplay[group] = true
                SaveScoreboardConfig(cfg)
                BuildBody(body)
            end)
        end, function(newGroup, label, hex, oldGroup)
            newGroup = string.lower(string.Trim(tostring(newGroup or "")))
            if newGroup == "" then return end
            cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or {}
            cfg.DisabledRankDisplay = istable(cfg.DisabledRankDisplay) and cfg.DisabledRankDisplay or {}
            if oldGroup and oldGroup ~= newGroup then
                cfg.RankDisplay[oldGroup] = nil
                cfg.DisabledRankDisplay[oldGroup] = true
            end
            cfg.RankDisplay[newGroup] = {
                Name = string.Trim(tostring(label or "")) ~= "" and label or newGroup,
                Color = HexToColor(hex, fallback.Color)
            }
            cfg.DisabledRankDisplay[newGroup] = nil
            SaveScoreboardConfig(cfg)
            BuildBody(body)
        end)
    end
    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save Board", function()
        cfg.HeaderTitle = title:GetValue()
        cfg.HeaderSubtitle = subtitle:GetValue()
        cfg.ShowHeaderIcon = showHeaderIcon:GetChecked()
        cfg.HeaderIcon = icon:GetValue()
        cfg.HeaderIconURL = image:GetValue()
        cfg.HeaderIconScale = tonumber(iconScale:GetValue()) or 1
        cfg.Width = math.Round(width:GetValue())
        cfg.RowGap = math.Round(rows:GetValue())
        cfg.ShowSearch = search:GetChecked()
        cfg.ShowMoney = money:GetChecked()
        cfg.RepEnabled = rep:GetChecked()
        cfg.Columns = cfg.Columns or {}
        for key, slider in next, (columnSliders) do
            cfg.Columns[key] = math.Clamp(tonumber(slider:GetValue()) or cfg.Columns[key] or 0.5, 0.05, 0.98)
        end
        cfg.AdminSystem = adminSystem.SelectedData or adminSystem:GetValue()
        cfg.DrawerActions = DrawerActionsFromCSV(drawerActions.GetCSV(), cfg.AdminSystem)
        cfg.DrawerActionOrder = CSVToList(drawerActions.GetCSV())
        cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or {}
        local nextRanks = {}
        for group, row in next, (rankRows) do
            if cfg.DisabledRankDisplay and cfg.DisabledRankDisplay[group] then continue end
            local newGroup = string.lower(string.Trim(tostring(row.Group:GetValue() or group)))
            if newGroup == "" then newGroup = group end
            local fallback = rankDefaults[group] or {Name = group, Color = color_white}
            nextRanks[newGroup] = {
                Name = row.Name:GetValue(),
                Color = HexToColor(row.Hex:GetValue(), fallback.Color)
            }
        end
        cfg.RankDisplay = nextRanks
        SaveScoreboardConfig(cfg)
    end)
    AddMenuButton(buttons, "+ Rank", function()
        local key = "new_rank"
        local index = 1
        while cfg.RankDisplay[key] ~= nil do
            index = index + 1
            key = "new_rank_" .. string.format("%d", index)
        end

        cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or {}
        cfg.RankDisplay[key] = {
            Name = "New Rank",
            Color = Color(160, 160, 160)
        }
        cfg.DisabledRankDisplay[key] = nil
        SaveScoreboardConfig(cfg)
        BuildBody(body)
    end)
    AddMenuButton(buttons, "Preview", function()
        if DHUD.Scoreboard and DHUD.Scoreboard.GetFrame and IsValid(DHUD.Scoreboard.GetFrame()) and DHUD.Scoreboard.GetFrame().DHUDPreview then
            if DHUD.Scoreboard.Close then DHUD.Scoreboard.Close() end
            if DHUD.ConfigMenu and DHUD.ConfigMenu.CenterExisting then DHUD.ConfigMenu.CenterExisting() end
        elseif DHUD.Scoreboard and DHUD.Scoreboard.OpenPreviewLeft then
            DHUD.Scoreboard.OpenPreviewLeft()
            if DHUD.ConfigMenu and DHUD.ConfigMenu.DockRight then
                DHUD.ConfigMenu.DockRight()
            end
        elseif DHUD.Scoreboard and DHUD.Scoreboard.Open then
            DHUD.Scoreboard.Open()
        end
    end)
end

local function BuildMOTD(body)
    DHUD.Config.MOTD = DHUD.Config.MOTD or {}
    local cfg = DHUD.Config.MOTD
    local reward = cfg.DailyReward or {}

    AddSection(body, "MOTD Basics", "Window text, launch behavior, and public links.")
    local enabled = AddCheck(body, "Enable MOTD", cfg.Enabled ~= false)
    local join = AddCheck(body, "Show on join", cfg.ShowOnJoin ~= false)
    local showHeaderIcon = AddCheck(body, "Show header icon/image", cfg.ShowHeaderIcon ~= false)
    local title = AddEntry(body, "Title", cfg.Title or "")
    local subtitle = AddEntry(body, "Subtitle", cfg.Subtitle or "")
    local updates = AddMulti(body, "Server updates", table.concat(cfg.ServerUpdates or {}, "\n"), 76)
    local rules = AddMulti(body, "Rules", table.concat(cfg.Body or {}, "\n"), 120)
    AddSection(body, "Daily Reward Panel", "Controls the visible claim card players see on the MOTD.")
    local rewardEnabled = AddCheck(body, "Enable daily reward panel", reward.Enabled ~= false)
    local rewardTitle = AddEntry(body, "Reward title", reward.Title or "Daily Reward")
    local rewardAmount = AddEntry(body, "Reward amount", reward.Amount or "$5,000")
    local rewardButton = AddEntry(body, "Reward button", reward.ButtonText or "Claim")
    cfg.Rewards = istable(cfg.Rewards) and cfg.Rewards or {}
    AddSection(body, "Reward Entry Builder", "Add cash, points, weapon, or entity rewards to the claim table.")
    AddLabel(body, "Configured reward entries: " .. string.format("%d", #cfg.Rewards))
    for index, rewardRow in ipairs(cfg.Rewards) do
        if istable(rewardRow) then
            local row = vgui.Create("DPanel", body)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 8)
            row:SetTall(42)
            row:SetPaintBackground(false)
            row.DHUDSearchText = "motd reward daily calendar day " .. string.format("%d", tonumber(rewardRow.Day) or index)
            row.Paint = function(_, w, h)
                draw.RoundedBox(Radius("SM"), 0, 0, w, h, FieldColor(255))
                draw.RoundedBox(Radius("SM"), 0, 0, 4, h, WithAlpha(Primary(), 160))
                local titleText = "Day " .. string.format("%d", tonumber(rewardRow.Day) or index) .. " - " .. tostring(rewardRow.Name or rewardRow.Type or "Reward")
                local rewardAmount = tonumber(rewardRow.Amount or rewardRow.Value)
                local rewardDetail = rewardAmount and string.format("%d", rewardAmount) or tostring(rewardRow.Weapon or rewardRow.Entity or "")
                local detailText = tostring(rewardRow.Type or "cash") .. " / " .. rewardDetail
                Text(titleText, Font("Small", "DermaDefault"), 14, 8, Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                Text(detailText, Font("Small", "DermaDefault"), 14, 24, Muted(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local remove = vgui.Create("DButton", row)
            StyleButton(remove)
            remove.Paint = function(self, w, h)
                draw.RoundedBox(Radius("SM"), 0, 0, w, h, CardColor(255))
                if self:IsHovered() then draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Color(232, 84, 84), 46)) end
                Text("x", Font("Body", "DermaDefaultBold"), w * 0.5, h * 0.5 - 1, Foreground(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            row.PerformLayout = function(_, w)
                remove:SetPos(w - 36, 7)
                remove:SetSize(28, 28)
            end
            remove.DoClick = function()
                ConfirmAction("Remove Daily Reward", "Remove the reward for day " .. string.format("%d", tonumber(rewardRow.Day) or index) .. "?", function()
                    table.remove(cfg.Rewards, index)
                    SyncMOTDConfig(cfg)
                    BuildBody(body)
                end)
            end
        end
    end
    local rewardDay = AddSlider(body, "Reward day number", 1, 1, 31, 0)
    local rewardType = AddCombo(body, "Reward type", {
        {Label = "Cash", Value = "cash"},
        {Label = "Pointshop points", Value = "points"},
        {Label = "Credit support", Value = "credits"},
        {Label = "Weapon", Value = "weapon"},
        {Label = "Entity", Value = "entity"}
    }, "cash")
    local rewardName = AddEntry(body, "Reward display name", "Daily Cash")
    local rewardValue = AddEntry(body, "Cash / points / credits amount", "5000")
    local rewardWeapon = AddCombo(body, "Weapon class reward", WeaponChoices(), "")
    local rewardEntity = AddCombo(body, "Entity class reward", EntityChoices(), "")
    AddSection(body, "Footer Buttons", "Enable links and set button labels / URLs.")
    cfg.Buttons = istable(cfg.Buttons) and cfg.Buttons or {
        {Enabled = true, Label = "Discord", URL = ""},
        {Enabled = true, Label = "Website", URL = ""},
        {Enabled = true, Label = "Shop", URL = ""},
        {Enabled = true, Label = "Rules", URL = ""},
        {Enabled = true, Label = "Close", Action = "close"}
    }
    local motdButtons = {}
    for index, data in ipairs(cfg.Buttons) do
        local enabledButton = AddCheck(body, "Enable MOTD button " .. index, data.Enabled ~= false)
        local labelButton = AddEntry(body, "Button " .. index .. " label", data.Label or "")
        local urlButton = AddEntry(body, "Button " .. index .. " URL", data.URL or "")
        motdButtons[index] = {Enabled = enabledButton, Label = labelButton, URL = urlButton, Action = data.Action}
    end

    local function CaptureMOTD()
        cfg.Enabled = enabled:GetChecked()
        cfg.ShowOnJoin = join:GetChecked()
        cfg.ShowHeaderIcon = showHeaderIcon:GetChecked()
        cfg.Title = title:GetValue()
        cfg.Subtitle = subtitle:GetValue()
        cfg.ServerUpdates = LinesFromText(updates:GetValue())
        cfg.Body = LinesFromText(rules:GetValue())
        cfg.DailyReward = reward
        reward.Enabled = rewardEnabled:GetChecked()
        reward.Title = rewardTitle:GetValue()
        reward.Amount = rewardAmount:GetValue()
        reward.ButtonText = rewardButton:GetValue()
        cfg.Buttons = cfg.Buttons or {}
        for index, row in ipairs(motdButtons) do
            cfg.Buttons[index] = cfg.Buttons[index] or {}
            cfg.Buttons[index].Enabled = row.Enabled:GetChecked()
            cfg.Buttons[index].Label = row.Label:GetValue()
            cfg.Buttons[index].URL = row.URL:GetValue()
            cfg.Buttons[index].Action = row.Action
        end

        return cfg
    end

    local function PushMOTDPreview()
        if not (DHUD.MOTD and DHUD.MOTD.GetFrame and DHUD.MOTD.PreviewExternalConfig) then return end

        local preview = DHUD.MOTD.GetFrame()
        if not (IsValid(preview) and preview.DHUDPreview) then return end

        DHUD.MOTD.PreviewExternalConfig(CaptureMOTD())
    end

    local function Watch(control)
        if not IsValid(control) then return end

        local old = control.OnChange
        control.OnChange = function(self, ...)
            if old then old(self, ...) end
            PushMOTDPreview()
        end

        local oldValue = control.OnValueChanged
        control.OnValueChanged = function(self, ...)
            if oldValue then oldValue(self, ...) end
            PushMOTDPreview()
        end
    end

    for _, control in ipairs({
        enabled, join, showHeaderIcon, title, subtitle, updates, rules,
        rewardEnabled, rewardTitle, rewardAmount, rewardButton
    }) do
        Watch(control)
    end

    for _, row in ipairs(motdButtons) do
        Watch(row.Enabled)
        Watch(row.Label)
        Watch(row.URL)
    end

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Preview", function()
        if DHUD.MOTD and DHUD.MOTD.GetFrame and IsValid(DHUD.MOTD.GetFrame()) and DHUD.MOTD.GetFrame().DHUDPreview then
            if DHUD.MOTD.Close then DHUD.MOTD.Close() end
            if DHUD.ConfigMenu and DHUD.ConfigMenu.CenterExisting then DHUD.ConfigMenu.CenterExisting() end
            return
        end

        if DHUD.MOTD and DHUD.MOTD.PreviewExternalConfig then
            DHUD.MOTD.PreviewExternalConfig(CaptureMOTD())
        end

        if DHUD.MOTD and DHUD.MOTD.OpenPreviewLeft then
            DHUD.MOTD.OpenPreviewLeft()
            if DHUD.ConfigMenu and DHUD.ConfigMenu.DockRight then
                DHUD.ConfigMenu.DockRight()
            end
        elseif DHUD.MOTD and DHUD.MOTD.Open then
            DHUD.MOTD.Open()
        end
    end)
    AddMenuButton(buttons, "Save MOTD", function()
        SyncMOTDConfig(CaptureMOTD())
    end)
    AddMenuButton(buttons, "Add Reward", function()
        cfg.Rewards = istable(cfg.Rewards) and cfg.Rewards or {}
        local day = math.Round(rewardDay:GetValue())
        for index = #cfg.Rewards, 1, -1 do
            if tonumber(cfg.Rewards[index].Day or 0) == day then
                table.remove(cfg.Rewards, index)
            end
        end
        cfg.Rewards[#cfg.Rewards + 1] = {
            Day = day,
            Type = rewardType.SelectedData or rewardType:GetValue(),
            Name = rewardName:GetValue(),
            Amount = tonumber(rewardValue:GetValue()) or rewardValue:GetValue(),
            Weapon = rewardWeapon.SelectedData or rewardWeapon:GetValue(),
            Entity = rewardEntity.SelectedData or rewardEntity:GetValue()
        }
        SyncMOTDConfig(cfg)
        BuildBody(body)
    end)
end

local function BuildFeeds(body)
    DHUD.Config.Notifications = DHUD.Config.Notifications or {}
    DHUD.Config.DeathNotice = DHUD.Config.DeathNotice or {}
    DHUD.Config.Voice = DHUD.Config.Voice or {}
    DHUD.Config.Connection = DHUD.Config.Connection or {}
    DHUD.Config.Vote = DHUD.Config.Vote or {}
    DHUD.Config.DarkRPMenus = DHUD.Config.DarkRPMenus or {}

    local notify = DHUD.Config.Notifications
    local death = DHUD.Config.DeathNotice
    local voice = DHUD.Config.Voice
    local vote = DHUD.Config.Vote
    local darkrpMenus = DHUD.Config.DarkRPMenus

    AddSection(body, "Notification Feed", "Screen-side toast feed and popup stacking.")
    local notifyEnabled = AddCheck(body, "Enable notification override", notify.Enabled ~= false)
    local notifyPickup = AddCheck(body, "Use notification feed for item pickups", notify.PickupOverride ~= false)
    local notifyMax = AddSlider(body, "Notification max visible", notify.MaxVisible or 5, 1, 8, 0)
    local notifyRight = AddSlider(body, "Notification right padding", notify.RightPadding or 24, 0, 420, 0)
    local notifyBottom = AddSlider(body, "Notification bottom offset", notify.BottomOffset or 245, 0, 520, 0)
    AddSection(body, "Death Feed", "Kill feed queue placement and density.")
    local deathEnabled = AddCheck(body, "Enable kill feed override", death.Enabled ~= false)
    local deathMax = AddSlider(body, "Death feed max visible", death.MaxVisible or 3, 1, 6, 0)
    local deathRight = AddSlider(body, "Death feed right padding", death.Right or 24, 0, 420, 0)
    local deathTop = AddSlider(body, "Death feed top offset", death.Top or 170, 0, 520, 0)
    AddSection(body, "Voice Feed", "Right-side voice popup feed and overhead speaker icon.")
    local voiceEnabled = AddCheck(body, "Enable voice feed", voice.Enabled ~= false)
    local voiceOverhead = AddCheck(body, "Enable overhead speaker", voice.Overhead ~= false)
    local voiceMax = AddSlider(body, "Voice max visible", voice.MaxVisible or 4, 1, 6, 0)
    local voiceRight = AddSlider(body, "Voice feed right padding", voice.Right or 24, 0, 420, 0)
    local voiceTop = AddSlider(body, "Voice feed top offset", voice.Top or math.floor(ScrH() * 0.5), 0, 720, 0)
    AddSection(body, "DarkRP Popups", "Vote popup and DarkRP derma menu overrides.")
    local voteEnabled = AddCheck(body, "Enable vote UI override", vote.Enabled ~= false)
    local darkrpMenusEnabled = AddCheck(body, "Enable DarkRP menu skin override", darkrpMenus.Enabled ~= false)

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save Feeds", function()
        notify.Enabled = notifyEnabled:GetChecked()
        notify.PickupOverride = notifyPickup:GetChecked()
        notify.MaxVisible = math.Round(notifyMax:GetValue())
        notify.RightPadding = math.Round(notifyRight:GetValue())
        notify.BottomOffset = math.Round(notifyBottom:GetValue())
        death.Enabled = deathEnabled:GetChecked()
        death.MaxVisible = math.Round(deathMax:GetValue())
        death.Right = math.Round(deathRight:GetValue())
        death.Top = math.Round(deathTop:GetValue())
        voice.Enabled = voiceEnabled:GetChecked()
        voice.Overhead = voiceOverhead:GetChecked()
        voice.MaxVisible = math.Round(voiceMax:GetValue())
        voice.Right = math.Round(voiceRight:GetValue())
        voice.Top = math.Round(voiceTop:GetValue())
        vote.Enabled = voteEnabled:GetChecked()
        darkrpMenus.Enabled = darkrpMenusEnabled:GetChecked()
        SaveConfig()
    end)
    AddMenuButton(buttons, "Placement", function()
        if DHUD.Placement and DHUD.Placement.Open then DHUD.Placement.Open() end
    end)
end

local function BuildDeathScreen(body)
    DHUD.Config.DeathScreen = DHUD.Config.DeathScreen or {}
    local cfg = DHUD.Config.DeathScreen

    AddSection(body, "Death Screen", "Built-in respawn overlay configuration.")
    local enabled = AddCheck(body, "Enable death screen", cfg.Enabled ~= false)
    local title = AddEntry(body, "Title", cfg.Title or "You Died")
    local subtitle = AddEntry(body, "Subtitle", cfg.Subtitle or "")
    local hint = AddEntry(body, "Hint text", cfg.Hint or "Press {key} to respawn")
    local key = AddCombo(body, "Respawn key", {
        {Label = "Any key", Value = "any"},
        {Label = "Space", Value = "space"},
        {Label = "R", Value = "r"},
        {Label = "E", Value = "e"},
        {Label = "Enter", Value = "enter"},
        {Label = "Mouse 1", Value = "mouse1"}
    }, cfg.RespawnKey or "any")
    local width = AddSlider(body, "Panel width", cfg.Width or 520, 360, 760, 0)
    local height = AddSlider(body, "Panel height", cfg.Height or 178, 130, 260, 0)
    local dim = AddSlider(body, "Screen dim amount", cfg.DimAlpha or 175, 80, 235, 0)
    local blur = AddCheck(body, "Use background blur", cfg.Blur ~= false)

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save Death", function()
        cfg.SupportEnabled = true
        cfg.Enabled = enabled:GetChecked()
        cfg.Title = title:GetValue()
        cfg.Subtitle = subtitle:GetValue()
        cfg.Hint = hint:GetValue()
        cfg.RespawnKey = key.SelectedData or key:GetValue()
        cfg.Width = math.Round(width:GetValue())
        cfg.Height = math.Round(height:GetValue())
        cfg.DimAlpha = math.Round(dim:GetValue())
        cfg.Blur = blur:GetChecked()
        SaveConfig()
    end)
end

local function BuildLeaderboards(body)
    DHUD.Config.Leaderboards = DHUD.Config.Leaderboards or {}
    local cfg = DHUD.Config.Leaderboards

    AddSection(body, "Leaderboard Menu", "Choose which scoreboard leaderboard lists are available.")
    local enabled = AddCheck(body, "Enable leaderboard menu", cfg.Enabled ~= false)
    local storageMode = AddCombo(body, "Storage mode", {
        {Label = "File based data", Value = "file"},
        {Label = "SQLite database", Value = "sqlite"},
        {Label = "MySQL bridge settings", Value = "mysql"}
    }, cfg.StorageMode or "file")
    local refresh = AddSlider(body, "Auto refresh seconds", cfg.RefreshInterval or 30, 10, 300, 0)
    local top = AddSlider(body, "Top result count", cfg.TopResults or 10, 1, 25, 0)
    local overall = AddCheck(body, "Show overall playtime", cfg.OverallTime ~= false)
    local session = AddCheck(body, "Show session playtime", cfg.SessionTime ~= false)
    local money = AddCheck(body, "Show money leaderboard", cfg.Money ~= false)
    local kills = AddCheck(body, "Show kills leaderboard", cfg.Kills == true)
    local deaths = AddCheck(body, "Show deaths leaderboard", cfg.Deaths == true)
    local points = AddCheck(body, "Show pointshop leaderboard", cfg.Points == true)
    local credits = AddCheck(body, "Show credit leaderboard", cfg.Credits == true)
    cfg.SQL = istable(cfg.SQL) and cfg.SQL or {}
    AddSection(body, "Database Settings", "Used when SQLite or MySQL mode is selected. File mode is the default.")
    local sqlType = AddCombo(body, "SQL type", {
        {Label = "SQLite", Value = "sqlite"},
        {Label = "MySQL", Value = "mysql"}
    }, cfg.SQL.Type or "sqlite")
    local sqlHost = AddEntry(body, "MySQL host", cfg.SQL.Host or "")
    local sqlDb = AddEntry(body, "Database name", cfg.SQL.Database or "")
    local sqlUser = AddEntry(body, "Database user", cfg.SQL.Username or "")
    local sqlPass = AddEntry(body, "Database password", cfg.SQL.Password or "")
    local sqlPort = AddEntry(body, "Database port", cfg.SQL.Port or 3306)

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save Boards", function()
        cfg.Enabled = enabled:GetChecked()
        cfg.StorageMode = storageMode.SelectedData or storageMode:GetValue()
        cfg.RefreshInterval = math.Round(refresh:GetValue())
        cfg.TopResults = math.Round(top:GetValue())
        cfg.OverallTime = overall:GetChecked()
        cfg.SessionTime = session:GetChecked()
        cfg.Money = money:GetChecked()
        cfg.Kills = kills:GetChecked()
        cfg.Deaths = deaths:GetChecked()
        cfg.Points = points:GetChecked()
        cfg.Credits = credits:GetChecked()
        cfg.SQL = {
            Type = sqlType.SelectedData or sqlType:GetValue(),
            Host = sqlHost:GetValue(),
            Database = sqlDb:GetValue(),
            Username = sqlUser:GetValue(),
            Password = sqlPass:GetValue(),
            Port = tonumber(sqlPort:GetValue()) or 3306
        }
        if DHUD.Scoreboard and DHUD.Scoreboard.GetConfig and DHUD.Scoreboard.ApplyExternalConfig then
            local score = DHUD.Scoreboard.GetConfig()
            score.Leaderboards = table.Copy(cfg)
            DHUD.Scoreboard.ApplyExternalConfig(score)
        end
        SaveConfig()

        if DHUD.Scoreboard and DHUD.Scoreboard.GetFrame and IsValid(DHUD.Scoreboard.GetFrame()) and DHUD.Scoreboard.SetView and DHUD.Scoreboard.GetView then
            if DHUD.Scoreboard.GetView() == "leaderboard" and cfg.Enabled == false then
                DHUD.Scoreboard.SetView("players")
            else
                DHUD.Scoreboard.SetView(DHUD.Scoreboard.GetView() or "players")
            end
        end
    end)
end

local function BuildSupport(body)
    DHUD.Config.Credits = DHUD.Config.Credits or {}
    DHUD.Config.Inventory = DHUD.Config.Inventory or {}

    AddSection(body, "Optional Addons", "Enable integrations only when the matching addon is installed.")
    AddLabel(body, "Credit system detected: " .. (CreditDetected() and "Yes" or "No"))
    AddLabel(body, "Inventory system detected: " .. (InventoryDetected() and "Yes" or "No"))
    local credits = AddCheck(body, "Enable credit system support", DHUD.Config.Credits.Enabled == true)
    local inventory = AddCheck(body, "Enable inventory system support", DHUD.Config.Inventory.Enabled == true)

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save Support", function()
        DHUD.Config.Credits.Enabled = credits:GetChecked() and CreditDetected()
        DHUD.Config.Inventory.Enabled = inventory:GetChecked() and InventoryDetected()

        if DHUD.Scoreboard and DHUD.Scoreboard.GetConfig and DHUD.Scoreboard.ApplyExternalConfig then
            local score = DHUD.Scoreboard.GetConfig()
            score.CreditsEnabled = DHUD.Config.Credits.Enabled
            score.ShowShop = DHUD.Config.Credits.Enabled
            DHUD.Scoreboard.ApplyExternalConfig(score)
        end

        SaveConfig()
    end)
end

local function BuildCredits(body)
    DHUD.Config.Credits = DHUD.Config.Credits or {}
    local supportEnabled = DHUD.Config.Credits.Enabled == true and CreditDetected()

    AddSection(body, "Credit Shop Bridge", "Standalone credit shop product metadata and display options.")
    if not supportEnabled then
        AddLabel(body, "Credit system support is disabled or the addon was not detected.")
        AddLabel(body, "Configure a supported currency provider, then enable support in Supported Scripts.")
        return
    end

    local score = DHUD.Scoreboard and DHUD.Scoreboard.GetConfig and DHUD.Scoreboard.GetConfig() or {}
    score.ShopListings = istable(score.ShopListings) and score.ShopListings or {}
    local title = AddEntry(body, "Shop title", score.ShopTitle or "Credit Shop")
    local subtitle = AddEntry(body, "Shop subtitle", score.ShopSubtitle or "")
    local currency = AddEntry(body, "Currency name", score.ShopCurrencyName or "Credits")
    local grid = AddSlider(body, "Shop grid columns", score.ShopGridColumns or 2, 1, 4, 0)

    AddLabel(body, "Product listings: " .. string.format("%d", #score.ShopListings))
    local productName = AddEntry(body, "New product name", "New Product")
    local productPrice = AddEntry(body, "New product price", "100")
    local productType = AddCombo(body, "Product type", {
        {Label = "Profile cosmetic", Value = "profile"},
        {Label = "Weapon", Value = "weapon"},
        {Label = "Entity", Value = "entity"},
        {Label = "Cash amount", Value = "cash"},
        {Label = "Pointshop points", Value = "points"},
        {Label = "Pointshop item", Value = "pointshop_item"}
    }, "profile")
    local productClass = AddEntry(body, "Weapon / entity / item class", "")
    local productImage = AddEntry(body, "Preview Imgur URL/key", "")

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Save Shop", function()
        score.ShopTitle = title:GetValue()
        score.ShopSubtitle = subtitle:GetValue()
        score.ShopCurrencyName = currency:GetValue()
        score.ShopGridColumns = math.Round(grid:GetValue())
        score.CreditsEnabled = true
        if score.ShowShop == nil then score.ShowShop = true end
        if DHUD.Scoreboard and DHUD.Scoreboard.ApplyExternalConfig then
            DHUD.Scoreboard.ApplyExternalConfig(score)
        end
        SaveConfig()
    end)
    AddMenuButton(buttons, "Add Product", function()
        score.ShopListings[#score.ShopListings + 1] = {
            ID = "listing_" .. string.format("%.3f", CurTime()):gsub("%.", "_"),
            Title = productName:GetValue(),
            Price = (currency:GetValue() or "Credits") .. " " .. productPrice:GetValue(),
            PriceAmount = tonumber(productPrice:GetValue()) or 0,
            Currency = currency:GetValue(),
            ItemType = productType.SelectedData or productType:GetValue(),
            Class = productClass:GetValue(),
            ImageURL = productImage:GetValue(),
            Public = true
        }
        if DHUD.Scoreboard and DHUD.Scoreboard.ApplyExternalConfig then
            DHUD.Scoreboard.ApplyExternalConfig(score)
        end
        SaveConfig()
        BuildBody(body)
    end)
end

local function BuildWeaponSelector(body)
    DHUD.Config.Systems = DHUD.Config.Systems or {}
    DHUD.Config.WeaponSelector = DHUD.Config.WeaponSelector or {}
    local cfg = DHUD.Config.WeaponSelector

    AddSection(body, "Weapon Selector", "Top-screen reskin of the default Garry's Mod weapon selector.")
    local enabled = AddCheck(body, "Enable weapon selector", cfg.Enabled ~= false and DHUD.Config.Systems.WeaponSelector ~= false)
    local showTime = AddSlider(body, "Visible time after selection", cfg.ShowTime or 1.25, 0.5, 3, 2)
    local topPadding = AddSlider(body, "Top padding", cfg.TopPadding or 44, 0, 180, 0)
    local centerOffset = AddSlider(body, "Center offset", cfg.CenterOffsetX or 0, -360, 360, 0)
    local slotWidth = AddSlider(body, "Slot width", cfg.SlotWidth or 176, 130, 260, 0)
    local rowHeight = AddSlider(body, "Row height", cfg.RowHeight or 30, 24, 44, 0)
    local showNumbers = AddCheck(body, "Show slot numbers", cfg.ShowSlotNumbers ~= false)

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)
    AddMenuButton(buttons, "Preview Selector", function()
        cfg.Enabled = enabled:GetChecked()
        cfg.ShowTime = tonumber(showTime:GetValue()) or 1.25
        cfg.TopPadding = math.Round(topPadding:GetValue())
        cfg.CenterOffsetX = math.Round(centerOffset:GetValue())
        cfg.SlotWidth = math.Round(slotWidth:GetValue())
        cfg.RowHeight = math.Round(rowHeight:GetValue())
        cfg.ShowSlotNumbers = showNumbers:GetChecked()
        cfg.Position = "top"
        DHUD.Config.Systems.WeaponSelector = cfg.Enabled
        if DHUD.WeaponSelector and DHUD.WeaponSelector.OpenPreview then
            DHUD.WeaponSelector.OpenPreview(8)
        end
    end)
    AddMenuButton(buttons, "Save Selector", function()
        cfg.Enabled = enabled:GetChecked()
        cfg.ShowTime = tonumber(showTime:GetValue()) or 1.25
        cfg.TopPadding = math.Round(topPadding:GetValue())
        cfg.CenterOffsetX = math.Round(centerOffset:GetValue())
        cfg.SlotWidth = math.Round(slotWidth:GetValue())
        cfg.RowHeight = math.Round(rowHeight:GetValue())
        cfg.ShowSlotNumbers = showNumbers:GetChecked()
        cfg.Position = "top"
        DHUD.Config.Systems.WeaponSelector = cfg.Enabled
        SaveConfig()
    end)
end

local builders = {
    overview = BuildOverview,
    theme = BuildTheme,
    hud = BuildHUD,
    weaponselector = BuildWeaponSelector,
    scoreboard = BuildScoreboard,
    leaderboards = BuildLeaderboards,
    motd = BuildMOTD,
    feeds = BuildFeeds,
    support = BuildSupport,
    deathscreen = BuildDeathScreen,
    credits = BuildCredits
}

BuildBody = function(body)
    ClearBody(body)
    body:SetTall(64)
    local builder = builders[activeTab] or BuildOverview
    builder(body)
    ApplyConfigSearch(body)
    timer.Simple(0, function()
        RefreshBodyTall(body)
    end)
end

function DHUD.ConfigMenu.Build(parent)
    if not IsValid(parent) then return end
    if not IsAdmin() then return end

    RequestConfig()
    if DHUD.Scoreboard and DHUD.Scoreboard.RequestData then
        DHUD.Scoreboard.RequestData(true)
    end
    configSearchText = ""

    for _, child in ipairs(parent:GetChildren()) do
        if IsValid(child) then child:Remove() end
    end

    local root = vgui.Create("DPanel", parent)
    root:Dock(TOP)
    root:SetTall(math.max(520, ScrH() - 220))
    root:SetPaintBackground(false)

    local nav = vgui.Create("DScrollPanel", root)
    nav:SetPos(0, 0)
    nav:SetSize(176, root:GetTall())
    nav:SetPaintBackground(false)
    nav.Paint = function() end
    CloseCombosOnScroll(nav)

    local navBar = nav:GetVBar()
    if IsValid(navBar) then
        navBar:SetWide(5)
        navBar.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, Color(0, 0, 0, 55)) end
        navBar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, WithAlpha(Primary(), 150)) end
        navBar.btnUp.Paint = function() end
        navBar.btnDown.Paint = function() end
    end

    local navContent = vgui.Create("DPanel", nav)
    navContent:Dock(TOP)
    navContent:SetWide(176)
    navContent:SetPaintBackground(false)
    nav:AddItem(navContent)

    local bodyWrap = vgui.Create("DScrollPanel", root)
    bodyWrap.DHUDNoDarkRPSkin = true
    bodyWrap:SetPos(192, 0)
    bodyWrap:SetSize(math.max(parent:GetWide() - 192, 520), root:GetTall())
    bodyWrap:SetPaintBackground(false)
    bodyWrap.Paint = function() end
    CloseCombosOnScroll(bodyWrap)

    local bar = bodyWrap:GetVBar()
    if IsValid(bar) then
        bar:SetWide(6)
        bar.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, Color(0, 0, 0, 70)) end
        bar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, WithAlpha(Primary(), 160)) end
        bar.btnUp.Paint = function() end
        bar.btnDown.Paint = function() end
    end

    local body = vgui.Create("DPanel", bodyWrap)
    body:Dock(TOP)
    body:SetTall(1280)
    body:SetPaintBackground(false)

    root.PerformLayout = function(self, w, h)
        if IsValid(nav) then nav:SetSize(176, h) end
        if IsValid(navContent) then navContent:SetWide(176) end
        if IsValid(bodyWrap) then
            bodyWrap:SetPos(192, 0)
            bodyWrap:SetSize(math.max(w - 192, 520), h)
        end
    end

    local y = 0
    for _, tab in ipairs(tabs) do
        local tabID = tab.ID
        local visibleTab = (tabID ~= "credits" or CreditDetected())
        if visibleTab then
            if tabID == "support" then y = y + 10 end
            if tabID == "credits" then y = y + 4 end

            local btn = vgui.Create("DButton", navContent)
            StyleButton(btn)
            btn:SetPos(0, y)
            btn:SetSize(176, 36)
            btn.Hover = 0
            btn.Paint = function(self, bw, bh)
                self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
                local active = activeTab == tabID
                local col = active and Primary() or Muted()
                draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, CardColor(255))
                if active or self.Hover > 0.01 then
                    draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, WithAlpha(col, active and 48 or (18 + self.Hover * 26)))
                end
                DrawIcon(tab.Icon or "navigation/settings", 12, bh * 0.5 - 8, 16, active and col or Muted())
                Text(tab.Label, Font("Small", "DermaDefault"), 38, bh * 0.5 - 1, active and col or Foreground(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function()
                activeTab = tabID
                BuildBody(body)
            end
            y = y + 42
        end
    end

    navContent:SetTall(math.max(y, nav:GetTall()))
    BuildBody(body)
end

function DHUD.ConfigMenu.Open()
    if not IsAdmin() then
        if DHUD.Notify and DHUD.Notify.Add then
            DHUD.Notify.Add("Only admins can open Dubz Config.", "warning", 3)
        end
        return
    end

    RequestConfig()
    if DHUD.Scoreboard and DHUD.Scoreboard.RequestData then
        DHUD.Scoreboard.RequestData(true)
    end
    configSearchText = ""

    if IsValid(frame) then frame:Remove() end

    local w = math.min(ScrW() - 80, 980)
    local h = math.min(ScrH() - 80, 700)
    frame = vgui.Create("DFrame")
    frame.DHUDNoDarkRPSkin = true
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    if frame.SetSizable then frame:SetSizable(true) end
    if frame.SetMinWidth then frame:SetMinWidth(820) end
    if frame.SetMinHeight then frame:SetMinHeight(600) end
    frame:MakePopup()
    frame:SetAlpha(255)
    frame.Progress = 0
    frame.TargetAlpha = 255
    if DHUD.TrackPanel then DHUD.TrackPanel(frame) end

    local baseX, baseY = frame:GetPos()
    local body
    frame.OnRemove = function()
        if DHUD.Scoreboard and DHUD.Scoreboard.CenterExisting then
            DHUD.Scoreboard.CenterExisting()
        end
    end
    frame.Paint = function(self, pw, ph)
        local alpha = 255
        draw.RoundedBox(Radius("MD"), 3, 4, pw - 3, ph - 4, Color(0, 0, 0, 60 * (alpha / 255)))
        draw.RoundedBox(Radius("MD"), 0, 0, pw, ph, WithAlpha(Primary(), alpha))
        draw.RoundedBox(Radius("MD"), 6, 0, pw - 6, ph, ShellColor(255))
        draw.RoundedBox(Radius("MD"), 22, 18, pw - 44, 64, CardColor(alpha))
        DrawIcon("darkrp/health_cross", 42, 36, 22, WithAlpha(Primary(), alpha))
        Text("Dubz HUD Config", Font("Header", "DermaDefaultBold"), 78, 32, WithAlpha(Foreground(), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text("HUD, scoreboard, MOTD, feeds, and player interface settings.", Font("Small", "DermaDefault"), 78, 58, WithAlpha(Muted(), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local close = AddHeaderIconButton(frame, "navigation/close", function()
        frame.TargetAlpha = 0
        frame:SetMouseInputEnabled(false)
        frame:SetKeyboardInputEnabled(false)
    end, "Close", Color(232, 84, 84))
    close:SetPos(w - 58, 35)

    local nav = vgui.Create("DScrollPanel", frame)
    nav:SetPos(22, 98)
    nav:SetSize(176, h - 120)
    nav:SetPaintBackground(false)
    nav.Paint = function() end
    CloseCombosOnScroll(nav)
    local navBar = nav:GetVBar()
    if IsValid(navBar) then
        navBar:SetWide(5)
        navBar.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, Color(0, 0, 0, 55)) end
        navBar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, WithAlpha(Primary(), 150)) end
        navBar.btnUp.Paint = function() end
        navBar.btnDown.Paint = function() end
    end

    local navContent = vgui.Create("DPanel", nav)
    navContent:Dock(TOP)
    navContent:SetWide(176)
    navContent:SetPaintBackground(false)
    nav:AddItem(navContent)

    local bodyWrap = vgui.Create("DScrollPanel", frame)
    bodyWrap.DHUDNoDarkRPSkin = true
    bodyWrap:SetPos(214, 98)
    bodyWrap:SetSize(w - 236, h - 120)
    bodyWrap:SetPaintBackground(false)
    bodyWrap.Paint = function() end
    CloseCombosOnScroll(bodyWrap)
    local bar = bodyWrap:GetVBar()
    if IsValid(bar) then
        bar:SetWide(6)
        bar.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, Color(0, 0, 0, 70)) end
        bar.btnGrip.Paint = function(_, bw, bh) draw.RoundedBox(3, 1, 0, bw - 2, bh, WithAlpha(Primary(), 160)) end
        bar.btnUp.Paint = function() end
        bar.btnDown.Paint = function() end
    end

    body = vgui.Create("DPanel", bodyWrap)
    body:Dock(TOP)
    body:SetTall(1280)
    body:SetPaintBackground(false)
    frame.PerformLayout = function(self, pw, ph)
        if IsValid(close) then close:SetPos(pw - 58, 35) end
        if IsValid(nav) then
            nav:SetPos(22, 98)
            nav:SetSize(176, ph - 120)
        end
        if IsValid(navContent) then
            navContent:SetWide(176)
        end
        if IsValid(bodyWrap) then
            bodyWrap:SetPos(214, 98)
            bodyWrap:SetSize(pw - 236, ph - 120)
        end
    end

    local y = 0
    for _, tab in ipairs(tabs) do
        local tabID = tab.ID
        local visibleTab = (tabID ~= "credits" or CreditDetected())
        if visibleTab then
            if tabID == "support" then y = y + 10 end
            if tabID == "credits" then y = y + 4 end
            local btn = vgui.Create("DButton", navContent)
            StyleButton(btn)
            btn:SetPos(0, y)
            btn:SetSize(176, 36)
            btn.Hover = 0
            btn.Paint = function(self, bw, bh)
                self.Hover = Lerp(math.Clamp(FrameTime() * 16, 0, 1), self.Hover or 0, self:IsHovered() and 1 or 0)
                local active = activeTab == tabID
                local col = active and Primary() or Muted()
                draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, CardColor(frame:GetAlpha()))
                if active or self.Hover > 0.01 then
                    draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, WithAlpha(col, active and 48 or (18 + self.Hover * 26)))
                end
                DrawIcon(tab.Icon or "navigation/settings", 12, bh * 0.5 - 8, 16, WithAlpha(active and col or Muted(), frame:GetAlpha()))
                Text(tab.Label, Font("Small", "DermaDefault"), 38, bh * 0.5 - 1, WithAlpha(active and col or Foreground(), frame:GetAlpha()), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function()
                activeTab = tabID
                BuildBody(body)
            end
            y = y + 42
        end
    end
    navContent:SetTall(math.max(y, nav:GetTall()))

    BuildBody(body)

    frame.Think = function(self)
        self.Progress = Lerp(math.Clamp(FrameTime() * 13, 0, 1), self.Progress or 0, self.TargetAlpha == 0 and 0 or 1)
        self:SetAlpha(255)
        local targetX = self.DHUDBaseX or baseX
        local targetY = self.DHUDBaseY or baseY
        self:SetPos(targetX + (1 - self.Progress) * 22, targetY)
        if self.TargetAlpha == 0 and self.Progress <= 0.02 then
            self:Remove()
        end
    end
end

function DHUD.ConfigMenu.DockRight()
    if not IsValid(frame) then return end

    local _, h = frame:GetSize()
    local gap = 12
    local edge = 28
    local dockW = math.floor((ScrW() - edge * 2 - gap) * 0.5)
    frame:SetSize(dockW, h)
    frame:SetPos(edge + dockW + gap, math.max(28, (ScrH() - h) * 0.5))
    frame.DHUDBaseX, frame.DHUDBaseY = frame:GetPos()
end

function DHUD.ConfigMenu.HideInstant()
    if IsValid(frame) then
        frame:Remove()
    end
end

function DHUD.ConfigMenu.CenterExisting()
    if not IsValid(frame) then return end

    frame:Center()
    frame.DHUDBaseX, frame.DHUDBaseY = frame:GetPos()
end

if concommand.Remove then
    concommand.Remove("dubzconfig")
    concommand.Remove("dhud_config")
end

concommand.Add("dhud_config", function()
    DHUD.ConfigMenu.Open()
end)

concommand.Add("dubzhud", function()
    DHUD.ConfigMenu.Open()
end)

local function ConfigChatCommandHook(ply, text)
    if ply ~= LocalPlayer() then return end
    text = string.lower(string.Trim(tostring(text or "")))
    if text == "!dubzhud" or text == "/dubzhud" or text == "!dhudconfig" or text == "/dhudconfig" then
        DHUD.ConfigMenu.Open()
        return true
    end
end

local function RegisterDHUDConfigPage()
    if DubzLib and DubzLib.RegisterConfigPage then
        DubzLib.RegisterConfigPage("dhud", {
            Name = "Dubz HUD",
            Description = "Open the full HUD, scoreboard, MOTD, feeds, and theme config suite.",
            Icon = "darkrp/health_cross",
            Order = 10,
            Version = DHUD.Version or "dev",
            Build = function(parent)
                if DHUD and DHUD.ConfigMenu and DHUD.ConfigMenu.Build then
                    DHUD.ConfigMenu.Build(parent)
                end
            end,
            Open = function()
                if DHUD and DHUD.ConfigMenu and DHUD.ConfigMenu.Open then
                    DHUD.ConfigMenu.Open()
                end
            end
        })
    end
end

RegisterDHUDConfigPage()
timer.Simple(0, RegisterDHUDConfigPage)
timer.Simple(2, RegisterDHUDConfigPage)
timer.Simple(6, RegisterDHUDConfigPage)

hook.Add("DubzLib.ThemeChanged", "DHUD.FrameworkThemeSource", function()
    if DHUD.Config and DHUD.Config.ThemeSource == "framework" then
        ApplyFrameworkThemeToDHUD(nil, true)
    end
end)

net.Receive("DHUD.Config.Data", function()
    local ok, incoming = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    DHUD.Config = MergeConfig(DHUD.Config or {}, ok and incoming or {})
    DHUD.ConfigLoaded = true
    if DHUD.Config.ThemeSource == "framework" then
        ApplyFrameworkThemeToDHUD("framework", false)
    end
    hook.Run("DHUD.ConfigLoaded")
end)

net.Receive("DHUD.Config.Notice", function()
    local msg = net.ReadString()
    local kind = net.ReadString()
    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add(msg, kind ~= "" and kind or "hint", 3)
    end
end)

local function RequestConfigHook()
    timer.Simple(1, RequestConfig)
end

hook.Add("OnPlayerChat", "DHUD.Config.ChatCommand", ConfigChatCommandHook)
hook.Add("InitPostEntity", "DHUD.Config.Request", RequestConfigHook)
