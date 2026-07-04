local DHUD = DHUD
DHUD.WeaponSelector = DHUD.WeaponSelector or {}

surface.CreateFont("DHUD.WeaponSelector.Text", {font = "Roboto", size = 14, weight = 700})
surface.CreateFont("DHUD.WeaponSelector.Small", {font = "Roboto", size = 11, weight = 600})

local state = DHUD.WeaponSelector
state.ShowUntil = state.ShowUntil or 0
state.SelectedIndex = state.SelectedIndex or 1
state.LastWeapons = state.LastWeapons or {}

local function Cfg()
    local cfg = DHUD.Config and DHUD.Config.WeaponSelector or {}
    cfg.Position = "top"
    return cfg
end

local function Enabled()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    return (state.PreviewUntil or 0) > CurTime() or (systems.WeaponSelector ~= false and cfg.Enabled ~= false)
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha or col.a or 255)
end

local function Accent()
    local cfg = Cfg()
    if istable(cfg.Accent) and cfg.Accent.r then return cfg.Accent end
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.HUDAccent or colors.Agenda or (DubzLib and DubzLib.Color and DubzLib.Color("Primary")) or Color(184, 116, 255)
end

local function Radius()
    local cfg = Cfg()
    local value = cfg.Radius or "SM"
    if isnumber(value) then return value end
    return DubzLib and DubzLib.Radius and DubzLib.Radius(value) or 6
end

local function ColorFor(key, fallback)
    if DubzLib and DubzLib.Color then
        return DubzLib.Color(key, fallback)
    end

    return fallback
end

local function ThemeColor(...)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    for _, key in ipairs({...}) do
        local value = colors[key]
        if istable(value) and value.r then return value end
    end
end

local function PanelBackground()
    local cfg = Cfg()
    if istable(cfg.Background) and cfg.Background.r then return cfg.Background end
    return ThemeColor("ScoreboardPanel", "HUDBackground", "Background2") or ColorFor("Secondary", Color(27, 28, 33))
end

local function HeaderBackground()
    local cfg = Cfg()
    if istable(cfg.HeaderBackground) and cfg.HeaderBackground.r then return cfg.HeaderBackground end
    return ThemeColor("ScoreboardHeader", "Background") or PanelBackground()
end

local function ActiveBackground()
    local cfg = Cfg()
    if istable(cfg.ActiveBackground) and cfg.ActiveBackground.r then return cfg.ActiveBackground end
    return ThemeColor("Background2", "ScoreboardHeader", "HUDBackground") or HeaderBackground()
end

local function WeaponName(weapon)
    if not IsValid(weapon) then return "" end

    local printName = weapon.GetPrintName and weapon:GetPrintName() or weapon.PrintName
    if printName and printName ~= "" then return tostring(printName) end

    return weapon.GetClass and weapon:GetClass() or tostring(weapon)
end

local function WeaponSlot(weapon)
    local slot = weapon.GetSlot and weapon:GetSlot() or weapon.Slot or 0
    return math.Clamp(tonumber(slot) or 0, 0, 9)
end

local function WeaponSlotPos(weapon)
    local slotPos = weapon.GetSlotPos and weapon:GetSlotPos() or weapon.SlotPos or 0
    return tonumber(slotPos) or 0
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

local function BuildList()
    local ply = LocalPlayer()
    if not IsValid(ply) then return {} end

    local list = {}
    for _, weapon in ipairs(ply:GetWeapons() or {}) do
        if IsValid(weapon) then
            list[#list + 1] = {
                Weapon = weapon,
                Class = weapon:GetClass(),
                Name = WeaponName(weapon),
                Slot = WeaponSlot(weapon),
                SlotPos = WeaponSlotPos(weapon)
            }
        end
    end

    table.sort(list, function(a, b)
        if a.Slot == b.Slot then
            if a.SlotPos == b.SlotPos then
                return string.lower(a.Name or a.Class or "") < string.lower(b.Name or b.Class or "")
            end

            return a.SlotPos < b.SlotPos
        end

        return a.Slot < b.Slot
    end)

    return list
end

local function ActiveWeaponClass()
    local ply = LocalPlayer()
    if not IsValid(ply) then return "" end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) or not weapon.GetClass then return "" end

    return string.lower(tostring(weapon:GetClass() or ""))
end

local function PhysgunInUse()
    if ActiveWeaponClass() ~= "weapon_physgun" then return false end
    if not input or not input.IsMouseDown then return false end

    return input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT)
end

local function CurrentIndex(list)
    if (state.ShowUntil or 0) >= CurTime() then
        return math.Clamp(tonumber(state.SelectedIndex) or 1, 1, math.max(#list, 1))
    end

    local ply = LocalPlayer()
    local active = IsValid(ply) and IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or ""

    for index, data in ipairs(list or {}) do
        if data.Class == active then return index end
    end

    return math.Clamp(tonumber(state.SelectedIndex) or 1, 1, math.max(#list, 1))
end

local function ExecuteSelect(data)
    local ply = LocalPlayer()
    if not data or not IsValid(ply) or not IsValid(data.Weapon) then return end

    input.SelectWeapon(data.Weapon)
end

local function ShowSelection(list, index)
    local cfg = Cfg()
    state.SelectedIndex = math.Clamp(index or 1, 1, math.max(#list, 1))
    state.LastWeapons = list
    state.ShowUntil = CurTime() + (tonumber(cfg.ShowTime) or 1.25)
end

function DHUD.WeaponSelector.OpenPreview(duration)
    duration = duration or 12
    local list = {
        {Class = "weapon_physgun", Name = "Physics Gun", Slot = 0, SlotPos = 0},
        {Class = "gmod_tool", Name = "Tool Gun", Slot = 0, SlotPos = 1},
        {Class = "weapon_stunstick", Name = "Stun Stick", Slot = 0, SlotPos = 2},
        {Class = "keys", Name = "Keys", Slot = 1, SlotPos = 0},
        {Class = "pocket", Name = "Pocket", Slot = 1, SlotPos = 1},
        {Class = "arrest_baton", Name = "Arrest Baton", Slot = 1, SlotPos = 2},
        {Class = "unarrest_baton", Name = "Unarrest Baton", Slot = 1, SlotPos = 3},
        {Class = "weapon_checker", Name = "Weapon Checker", Slot = 1, SlotPos = 4},
        {Class = "weapon_ak472", Name = "AK-47", Slot = 3, SlotPos = 0},
        {Class = "camera", Name = "Camera", Slot = 5, SlotPos = 0},
        {Class = "admin_keypad_checker", Name = "Admin Keypad Checker", Slot = 5, SlotPos = 1}
    }

    ShowSelection(list, 1)
    state.ShowUntil = CurTime() + duration
    state.PreviewUntil = state.ShowUntil
end

local function ConfirmSelection()
    if (state.ShowUntil or 0) < CurTime() then return false end

    local list = state.LastWeapons
    if not list or #list == 0 then return false end

    local selected = list[math.Clamp(tonumber(state.SelectedIndex) or 1, 1, #list)]
    if IsValid(selected and selected.Weapon) then
        ExecuteSelect(selected)
    end
    state.ShowUntil = 0
    return true
end

local function CloseSelection()
    if (state.ShowUntil or 0) < CurTime() then return false end

    state.ShowUntil = 0
    return true
end

local function Cycle(dir)
    local list = BuildList()
    if #list <= 0 then return end

    local index = CurrentIndex(list) + dir
    if index > #list then index = 1 end
    if index < 1 then index = #list end

    ShowSelection(list, index)
end

local function SelectSlot(slotNumber)
    local list = BuildList()
    if #list <= 0 then return end

    local wantedSlot = math.Clamp((tonumber(slotNumber) or 1) - 1, 0, 9)
    local current = CurrentIndex(list)
    local first
    local nextInSlot

    for index, data in ipairs(list) do
        if data.Slot == wantedSlot then
            first = first or index
            if index > current then
                nextInSlot = index
                break
            end
        end
    end

    local target = nextInSlot or first
    if target then
        ShowSelection(list, target)
    end
end

local function WeaponSelectorBindHook(_, bind, pressed)
    if not pressed or not Enabled() then return end

    bind = string.lower(bind or "")
    if PhysgunInUse() and (bind == "invnext" or bind == "invprev") then
        state.ShowUntil = 0
        state.LastWeapons = {}
        return
    end

    if bind == "invnext" then Cycle(1) return true end
    if bind == "invprev" then Cycle(-1) return true end
    if bind == "+attack" and ConfirmSelection() then return true end
    if bind == "+attack2" and CloseSelection() then return true end

    local slot = string.match(bind, "^slot(%d+)$")
    if slot then
        SelectSlot(slot)
        return true
    end
end

local function HideDefaultWeaponSelectorHook(name)
    if name ~= "CHudWeaponSelection" then return end
    if not Enabled() then return end

    return false
end

hook.Add("PlayerBindPress", "DHUD.WeaponSelector.Binds", WeaponSelectorBindHook)
hook.Add("HUDShouldDraw", "DHUD.WeaponSelector.HideDefault", HideDefaultWeaponSelectorHook)

local function WeaponSelectorPaintHook()
    if not Enabled() then return end
    if (state.ShowUntil or 0) < CurTime() then return end

    local list = state.LastWeapons
    if not list or #list == 0 then list = BuildList() end
    if #list == 0 then return end

    local cfg = Cfg()
    local fadeTime = math.max(tonumber(cfg.FadeTime) or 0.22, 0.01)
    local alphaFrac = math.Clamp(((state.ShowUntil or 0) - CurTime()) / fadeTime, 0, 1)
    local alpha = math.Clamp(alphaFrac * 255, 0, 255)
    local w = tonumber(cfg.Width) or 220
    local slotW = tonumber(cfg.SlotWidth) or 176
    local rowH = tonumber(cfg.RowHeight) or 30
    local gap = tonumber(cfg.RowGap) or 5
    local radius = Radius()
    local accent = Accent()
    local bg = PanelBackground()
    local headerBg = HeaderBackground()
    local activeBg = ActiveBackground()
    local text = cfg.TextColor or ColorFor("Foreground", color_white)
    local muted = cfg.MutedColor or ColorFor("Muted", Color(170, 171, 178))
    local slotCol = cfg.SlotColor or text
    local accentW = math.max(tonumber(cfg.AccentWidth) or 0, 0)
    local headerAccentW = cfg.ShowHeaderAccent == true and accentW or 0
    local rowAccentW = cfg.ShowRowAccent == true and accentW or 0
    local selectedTintAlpha = tonumber(cfg.SelectedTintAlpha) or 18

    if string.lower(tostring(cfg.Position or "top")) == "top" then
        local grouped = {}
        local slots = {}

        for index, data in ipairs(list) do
            local slot = math.Clamp(tonumber(data.Slot) or 0, 0, 9)
            grouped[slot] = grouped[slot] or {}
            data.ListIndex = index
            grouped[slot][#grouped[slot] + 1] = data
        end

        for slot = 0, 9 do
            if grouped[slot] and #grouped[slot] > 0 then
                slots[#slots + 1] = slot
            end
        end

        local slotGap = tonumber(cfg.SlotGap) or 8
        local headerH = tonumber(cfg.HeaderHeight) or 22
        local columnPad = tonumber(cfg.ColumnPadding) or 6
        local maxRows = math.max(math.floor(tonumber(cfg.MaxVisibleRows) or 8), 1)
        local screenPad = 20
        local totalW = #slots * slotW + math.max(#slots - 1, 0) * slotGap
        local availableW = ScrW() - screenPad * 2

        if totalW > availableW and #slots > 0 then
            slotW = math.max(126, math.floor((availableW - math.max(#slots - 1, 0) * slotGap) / #slots))
            totalW = #slots * slotW + math.max(#slots - 1, 0) * slotGap
        end

        local startX = math.floor(ScrW() * 0.5 - totalW * 0.5 + (tonumber(cfg.CenterOffsetX) or 0))
        local topY = tonumber(cfg.TopPadding) or 44
        local panelAlpha = math.min(alpha, (tonumber(cfg.InnerAlpha) or 218) * (alpha / 255))
        local headerAlpha = math.min(alpha, (tonumber(cfg.HeaderAlpha) or 235) * (alpha / 255))

        for slotIndex, slot in ipairs(slots) do
            local x = startX + (slotIndex - 1) * (slotW + slotGap)
            local y = topY
            local items = grouped[slot]
            local visibleRows = math.min(#items, maxRows)
            local panelH = headerH + columnPad * 2 + visibleRows * rowH + math.max(visibleRows - 1, 0) * gap

            if cfg.Shadow == true and DubzLib and DubzLib.Draw and DubzLib.Draw.Shadow then
                DubzLib.Draw.Shadow(x, y, slotW, panelH, radius, 46 * (alpha / 255))
            end

            draw.RoundedBox(radius, x, y, slotW, panelH, WithAlpha(bg, panelAlpha))
            draw.RoundedBoxEx(radius, x, y, slotW, headerH, WithAlpha(headerBg, headerAlpha), true, true, false, false)
            if headerAccentW > 0 then
                draw.RoundedBoxEx(radius, x, y, headerAccentW, headerH, WithAlpha(accent, alpha * 0.45), true, false, false, false)
            end

            local headerText = cfg.ShowSlotNumbers == false and "Weapons" or string.format(tostring(cfg.HeaderText or "Slot %d"), slot + 1)
            draw.SimpleText(headerText, "DHUD.WeaponSelector.Small", x + headerAccentW + 8, y + headerH * 0.5, WithAlpha(slotCol, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if cfg.ShowHeaderCounts == true then
                draw.SimpleText(string.format("%d", #items), "DHUD.WeaponSelector.Small", x + slotW - 10, y + headerH * 0.5, WithAlpha(muted, alpha * 0.8), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            y = y + headerH + columnPad
            for rowIndex, data in ipairs(items) do
                if rowIndex > maxRows then break end
                local active = data.ListIndex == state.SelectedIndex
                local rowAlpha = active and (tonumber(cfg.ActiveAlpha) or 235) or (tonumber(cfg.InactiveAlpha) or 180)
                rowAlpha = math.min(alpha, rowAlpha * (alpha / 255))

                draw.RoundedBox(radius, x + columnPad, y, slotW - columnPad * 2, rowH, WithAlpha(active and activeBg or headerBg, rowAlpha))
                if active then
                    draw.RoundedBox(radius, x + columnPad, y, slotW - columnPad * 2, rowH, WithAlpha(accent, math.min(alpha, selectedTintAlpha * (alpha / 255))))
                end
                if rowAccentW > 0 then
                    draw.RoundedBoxEx(radius, x + columnPad, y, rowAccentW, rowH, WithAlpha(active and color_white or accent, active and alpha * 0.55 or alpha * 0.28), true, false, true, false)
                end

                local numberText = cfg.ShowEntryNumbers == true and string.format("%d", (tonumber(data.SlotPos) or 0) + 1) or ""
                local textX = x + columnPad + rowAccentW + 10
                if numberText ~= "" then
                    draw.SimpleText(numberText, "DHUD.WeaponSelector.Small", textX, y + rowH * 0.5, WithAlpha(active and color_white or slotCol, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    textX = textX + 18
                end
                draw.SimpleText(FitText(data.Name or data.Class or "Weapon", "DHUD.WeaponSelector.Text", x + slotW - columnPad - textX - 8), "DHUD.WeaponSelector.Text", textX, y + rowH * 0.5, WithAlpha(active and text or muted, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                y = y + rowH + gap
            end
        end

        return
    end

    local x = ScrW() - w - (tonumber(cfg.RightPadding) or 28)
    local y = ScrH() * (tonumber(cfg.YPercent) or 0.36)

    for index, data in ipairs(list) do
        local active = index == state.SelectedIndex
        local rowAlpha = active and (tonumber(cfg.ActiveAlpha) or 235) or (tonumber(cfg.InactiveAlpha) or 180)
        rowAlpha = math.min(alpha, rowAlpha * (alpha / 255))

        if cfg.Shadow == true and DubzLib and DubzLib.Draw and DubzLib.Draw.Shadow then
            DubzLib.Draw.Shadow(x, y, w, rowH, radius, 42 * (alpha / 255))
        end

        draw.RoundedBox(radius, x, y, w, rowH, WithAlpha(active and activeBg or bg, rowAlpha))
        if active then
            draw.RoundedBox(radius, x, y, w, rowH, WithAlpha(accent, math.min(alpha, selectedTintAlpha * (alpha / 255))))
        end
        if rowAccentW > 0 then
            draw.RoundedBoxEx(radius, x, y, rowAccentW, rowH, WithAlpha(active and color_white or accent, active and alpha * 0.55 or alpha * 0.28), true, false, true, false)
        end
        draw.SimpleText(FitText(data.Name or data.Class or "Weapon", "DHUD.WeaponSelector.Text", w - rowAccentW - 24), "DHUD.WeaponSelector.Text", x + rowAccentW + 12, y + rowH * 0.5, WithAlpha(active and text or muted, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        y = y + rowH + gap
    end
end

hook.Add("HUDPaint", "DHUD.WeaponSelector.Paint", WeaponSelectorPaintHook)
