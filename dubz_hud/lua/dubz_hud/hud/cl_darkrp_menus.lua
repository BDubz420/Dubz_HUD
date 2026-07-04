local DHUD = DHUD
DHUD.DarkRPMenus = DHUD.DarkRPMenus or {}

local nextScan = 0

local function Cfg()
    return DHUD.Config and DHUD.Config.DarkRPMenus or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function LibColor(name, fallback)
    if DubzLib and DubzLib.Color then
        return DubzLib.Color(name)
    end

    return fallback
end

local function Accent()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.Agenda or colors.Clock or Color(184, 116, 255)
end

local function PanelClass(pnl)
    if not IsValid(pnl) or not pnl.GetName then return "" end
    return tostring(pnl:GetName() or "")
end

local function PanelText(pnl)
    if not IsValid(pnl) then return "" end

    if pnl.GetTitle then
        local ok, title = pcall(function() return pnl:GetTitle() end)
        if ok and title and title ~= "" then return tostring(title) end
    end

    if not IsValid(pnl) then return "" end

    if pnl.GetText then
        local ok, text = pcall(function() return pnl:GetText() end)
        if ok and text and text ~= "" then return tostring(text) end
    end

    return ""
end

local function MatchesKeywords(text)
    text = string.lower(tostring(text or ""))
    if text == "" then return false end

    for _, keyword in ipairs(Cfg().Keywords or {}) do
        if string.find(text, string.lower(keyword), 1, true) then
            return true
        end
    end

    return false
end

local blacklist = {
    "spawn",
    "spawnmenu",
    "context",
    "properties",
    "fadmin",
    "toolmenu",
    "gmod_tool",
    "permaprop",
    "perma prop",
    "perma-prop",
    "permaprops",
    "configuration",
    "config",
    "settings",
    "tool gun",
    "duplicator",
    "advdupe"
}

local function IsDHUDPanel(pnl, depth)
    if not IsValid(pnl) or depth > 8 then return false end
    if pnl.DHUDNoDarkRPSkin or pnl.DHUDContent or pnl.DHUDMenuIgnore then return true end

    local parent = pnl.GetParent and pnl:GetParent()
    if IsValid(parent) then
        return IsDHUDPanel(parent, depth + 1)
    end

    return false
end

local function IsBlacklistedPanel(pnl, depth)
    if not IsValid(pnl) or depth > 3 then return false end

    local class = string.lower(PanelClass(pnl))
    local text = string.lower(PanelText(pnl))
    for _, word in ipairs(blacklist) do
        if string.find(class, word, 1, true) or string.find(text, word, 1, true) then
            return true
        end
    end

    for _, child in ipairs(pnl:GetChildren() or {}) do
        if IsValid(child) and IsBlacklistedPanel(child, depth + 1) then return true end
    end

    return false
end

local function HasMatchingContent(pnl, depth)
    if not IsValid(pnl) or depth > 4 then return false end
    if MatchesKeywords(PanelText(pnl)) then return true end

    for _, child in ipairs(pnl:GetChildren() or {}) do
        if IsValid(child) and HasMatchingContent(child, depth + 1) then
            return true
        end
    end

    return false
end

local function IsMenuRoot(pnl)
    if IsDHUDPanel(pnl, 0) then return false end
    if IsBlacklistedPanel(pnl, 0) then return false end

    local class = PanelClass(pnl)
    if class == "DFrame" then return HasMatchingContent(pnl, 0) end
    if class == "DPanel" or class == "EditablePanel" then
        return HasMatchingContent(pnl, 0)
    end

    return false
end

local function PaintShell(w, h, title)
    local cfg = Cfg()
    local accentW = cfg.AccentWidth or 5
    local accent = Accent()
    local radius = DubzLib and DubzLib.Radius and DubzLib.Radius("MD") or 6
    local bg = LibColor("Secondary", Color(32, 32, 34))

    draw.RoundedBox(radius, 0, 0, w, h, accent)
    draw.RoundedBox(radius, accentW, 0, w - accentW, h, WithAlpha(bg, cfg.InnerAlpha or 255))
    if title and title ~= "" then
        draw.RoundedBox(radius, accentW, 0, w - accentW, math.min(34, h), WithAlpha(LibColor("Panel", Color(22, 22, 24)), 245))
        draw.SimpleText(DHUD.L and DHUD.L(title) or title, DubzLib and DubzLib.Font and DubzLib.Font("Header") or "DermaDefaultBold", accentW + 12, 17, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function PaintButton(self, w, h)
    local accent = Accent()
    local bg = LibColor("Panel", Color(24, 24, 26))
    local muted = LibColor("Muted", Color(180, 180, 185))
    local selected = self.GetSelected and self:GetSelected()
    local hot = self:IsHovered() or self.Depressed or selected

    draw.RoundedBox(DubzLib and DubzLib.Radius and DubzLib.Radius("SM") or 4, 0, 0, w, h, WithAlpha(hot and accent or bg, hot and 42 or 230))
    draw.RoundedBox(0, 0, h - 1, w, 1, WithAlpha(hot and accent or LibColor("BorderSoft", Color(80, 80, 86)), hot and 190 or 120))
    local menuText = self.DHUDMenuText or PanelText(self)
    draw.SimpleText(DHUD.L and DHUD.L(menuText) or menuText, DubzLib and DubzLib.Font and DubzLib.Font("Body") or "DermaDefault", 10, h * 0.5, hot and accent or muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function SkinButton(pnl)
    if pnl.DHUDMenuSkinned then return end
    pnl.DHUDMenuSkinned = true
    pnl.DHUDMenuText = PanelText(pnl)
    if pnl.SetTall then pnl:SetTall(math.max(pnl:GetTall(), 30)) end
    if pnl.SetText then pnl:SetText("") end
    if pnl.SetTextColor then pnl:SetTextColor(Color(0, 0, 0, 0)) end
    pnl.Paint = PaintButton
end

local function SkinCloseButton(pnl)
    if pnl.DHUDMenuSkinned then return end
    pnl.DHUDMenuSkinned = true
    if pnl.SetText then pnl:SetText("") end
    pnl.Paint = function(self, w, h)
        local hot = self:IsHovered()
        draw.RoundedBox(DubzLib and DubzLib.Radius and DubzLib.Radius("SM") or 4, 2, 2, w - 4, h - 4, WithAlpha(hot and Color(232, 84, 84) or LibColor("Panel", Color(30, 30, 32)), hot and 70 or 160))
        draw.SimpleText("x", "DermaDefaultBold", w * 0.5, h * 0.5 - 1, hot and Color(232, 84, 84) or LibColor("Muted", Color(190, 190, 195)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function SkinTextEntry(pnl)
    if pnl.DHUDMenuSkinned then return end
    pnl.DHUDMenuSkinned = true
    pnl.Paint = function(self, w, h)
        draw.RoundedBox(DubzLib and DubzLib.Radius and DubzLib.Radius("SM") or 4, 0, 0, w, h, LibColor("Panel", Color(24, 24, 26)))
        draw.RoundedBox(0, 0, h - 1, w, 1, WithAlpha(Accent(), self:HasFocus() and 210 or 110))
        self:DrawTextEntryText(LibColor("Foreground", color_white), Accent(), LibColor("Foreground", color_white))
    end
end

local function SkinComboBox(pnl)
    if pnl.DHUDMenuSkinned then return end
    pnl.DHUDMenuSkinned = true
    if pnl.SetTextColor then pnl:SetTextColor(LibColor("Foreground", color_white)) end
    pnl.Paint = function(self, w, h)
        local hot = self:IsHovered()
        draw.RoundedBox(DubzLib and DubzLib.Radius and DubzLib.Radius("SM") or 4, 0, 0, w, h, WithAlpha(hot and Accent() or LibColor("Panel", Color(24, 24, 26)), hot and 38 or 230))
        draw.RoundedBox(0, 0, h - 1, w, 1, WithAlpha(Accent(), hot and 190 or 110))
    end
end

local function SkinScroll(pnl)
    if pnl.DHUDMenuScrollSkinned then return end
    pnl.DHUDMenuScrollSkinned = true

    local bar = pnl:GetVBar()
    if not IsValid(bar) then return end

    bar.Paint = function(_, w, h)
        draw.RoundedBox(4, w - 4, 0, 4, h, WithAlpha(LibColor("BorderSoft", Color(80, 80, 86)), 70))
    end

    if IsValid(bar.btnGrip) then
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(4, w - 5, 0, 5, h, WithAlpha(Accent(), 190))
        end
    end

    if IsValid(bar.btnUp) then bar.btnUp.Paint = function() end end
    if IsValid(bar.btnDown) then bar.btnDown.Paint = function() end end
end

local function SkinPanel(pnl, isRoot)
    if not IsValid(pnl) then return end

    local class = PanelClass(pnl)

    if class == "DFrame" and isRoot and not pnl.DHUDMenuSkinned then
        pnl.DHUDMenuSkinned = true
        pnl.DHUDMenuTitle = PanelText(pnl)
        pnl:SetTitle("")
        pnl.Paint = function(self, w, h)
            PaintShell(w, h, self.DHUDMenuTitle)
        end
    elseif class == "DMenu" and isRoot and not pnl.DHUDMenuSkinned then
        pnl.DHUDMenuSkinned = true
        pnl:SetMinimumWidth(math.max(Cfg().WidthMin or 220, pnl:GetWide()))
        pnl.Paint = function(self, w, h)
            PaintShell(w, h)
        end
    elseif class == "DButton" or class == "DMenuOption" then
        if pnl:GetText() == "X" or pnl:GetText() == "x" then
            SkinCloseButton(pnl)
        else
            SkinButton(pnl)
        end
    elseif class == "DTextEntry" then
        SkinTextEntry(pnl)
    elseif class == "DComboBox" then
        SkinComboBox(pnl)
    elseif class == "DLabel" then
        if pnl.SetTextColor then pnl:SetTextColor(LibColor("Muted", Color(180, 180, 185))) end
    elseif class == "DCheckBoxLabel" then
        if pnl.SetTextColor then pnl:SetTextColor(LibColor("Muted", Color(180, 180, 185))) end
    elseif class == "DScrollPanel" then
        SkinScroll(pnl)
    elseif class == "DPanel" and pnl.DHUDMenuPanel ~= true then
        pnl.DHUDMenuPanel = true
        pnl.Paint = function() end
    end
end

local function SkinTree(pnl, isRoot, depth)
    if not IsValid(pnl) or depth > 8 then return end
    if IsDHUDPanel(pnl, 0) then return end
    if IsBlacklistedPanel(pnl, 0) then return end

    SkinPanel(pnl, isRoot)

    for _, child in ipairs(pnl:GetChildren() or {}) do
        if IsValid(child) then SkinTree(child, false, depth + 1) end
    end
end

local function ScanPanel(pnl, depth)
    if not IsValid(pnl) or depth > 3 then return end
    if IsDHUDPanel(pnl, 0) then return end
    if IsBlacklistedPanel(pnl, 0) then return end

    if IsMenuRoot(pnl) then
        SkinTree(pnl, true, 0)
        return
    end

    for _, child in ipairs(pnl:GetChildren() or {}) do
        if IsValid(child) then ScanPanel(child, depth + 1) end
    end
end

hook.Add("Think", "DHUD.SkinDarkRPMenus", function()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DarkRPMenus == false or cfg.Enabled == false or not vgui or not IsValid(vgui.GetWorldPanel()) then return end

    local now = CurTime()
    if now < nextScan then return end
    nextScan = now + (cfg.ScanInterval or 0.25)

    for _, child in ipairs(vgui.GetWorldPanel():GetChildren() or {}) do
        if IsValid(child) then ScanPanel(child, 0) end
    end
end)
