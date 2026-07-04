local DHUD = DHUD
DHUD.Bar = DHUD.Bar or {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Bar or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function FormatMoney(value)
    value = value or 0

    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(value)
    end

    return "$" .. string.Comma(value)
end

local function FormatClockText(timeText)
    timeText = tostring(timeText or "")

    if string.sub(timeText, 1, 1) == "0" then
        timeText = string.sub(timeText, 2)
    end

    return timeText
end

function DHUD.GetClockText()
    local clockCfg = DHUD.Config and DHUD.Config.Clock or {}
    local mode = string.lower(tostring(clockCfg.Mode or "realtime"))

    if mode == "atmos" then
        local globalName = clockCfg.AtmosGlobal or "Atmos_Time"
        local atmosTime = GetGlobalString(globalName, "")

        if atmosTime ~= "" then
            return FormatClockText(atmosTime)
        end

        return clockCfg.AtmosFallback or "0:00 AM"
    end

    return FormatClockText(os.date(clockCfg.RealtimeFormat or "%I:%M %p"))
end

local function TextWide(font, text)
    surface.SetFont(font)
    local wide = surface.GetTextSize(tostring(text or ""))
    return wide or 0
end

local function WithAlpha(col, alpha)
    return Color(col.r, col.g, col.b, alpha)
end

local function Accent(name, ply)
    local colors = Colors()

    if istable(name) and name.r then return name end
    if name == "team" and IsValid(ply) then return team.GetColor(ply:Team()) or DubzLib.Color("Success") end
    if name == "gold" then return colors.Gold or Color(221, 177, 74) end
    if name == "cash" then return colors.Cash or Color(91, 201, 121) end
    if name == "health" then return colors.Health or Color(232, 84, 84) end
    if name == "armor" then return colors.Armor or Color(91, 159, 232) end
    if name == "hunger" then return colors.Hunger or colors.Props or Color(238, 146, 80) end
    if name == "oxygen" then return colors.Oxygen or Color(90, 206, 232) end
    if name == "identity" then return colors.Identity or colors.HUDAccent or Color(184, 116, 255) end
    if name == "job" then return colors.Job or Color(235, 235, 235) end
    if name == "props" then return colors.Props or Color(238, 146, 80) end
    if name == "clock" then return colors.Clock or Color(184, 116, 255) end
    if name == "warning" then return colors.Warning or Color(238, 146, 80) end
    if name == "wanted" then return colors.Wanted or colors.Health or Color(232, 84, 84) end
    if name == "arrested" then return colors.Arrested or colors.Armor or Color(91, 159, 232) end
    if name == "gunlicense" then return colors.License or colors.Cash or Color(91, 201, 121) end

    return DubzLib.Color("Primary")
end

local function GetDarkRPNumber(ply, key)
    if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then
        if key == "money" then return 125000 end
        if key == "salary" then return 850 end
    end

    if DubzLib.Status and DubzLib.Status.GetDarkRPNumber then
        return DubzLib.Status.GetDarkRPNumber(ply, key)
    end

    return 0
end

local function AnimatedNumber(key, target)
    local cfg = Cfg()
    if cfg.AnimateNumbers == false then return target end

    DHUD.Bar.DisplayNumbers = DHUD.Bar.DisplayNumbers or {}
    local current = DHUD.Bar.DisplayNumbers[key]
    target = tonumber(target) or 0

    if current == nil then
        DHUD.Bar.DisplayNumbers[key] = target
        return target
    end

    local speed = (cfg.NumberAnimSpeed or 18) * FrameTime()
    current = Lerp(math.Clamp(speed, 0, 1), current, target)
    if math.abs(current - target) < 0.08 then current = target end
    DHUD.Bar.DisplayNumbers[key] = current
    return current
end

local function GetPropLimit(ply)
    if DubzLib.Status and DubzLib.Status.GetPropLimit then
        return DubzLib.Status.GetPropLimit(ply)
    end

    return "0"
end

local function ResolveText(value, ply, resolved)
    if isfunction(value) then
        return value(ply, resolved)
    end

    return value
end

local function ResolveEntry(key, ply)
    local cfg = Cfg()
    local source = cfg.Entries and cfg.Entries[key]
    if not source then return nil end

    local entry = table.Copy(source)
    entry.Key = key
    entry.Visible = source.Enabled == false and 0 or 1

    if entry.Type == "identity" then
        local teamColor = Accent("team", ply)
        entry.Label = ResolveText(entry.Label, ply, entry) or ply:Nick()
        entry.Value = ResolveText(entry.Value, ply, entry) or team.GetName(ply:Team()) or "Unknown"
        entry.Accent = Accent(entry.Accent or "identity", ply)
        entry.LabelColor = entry.LabelColor or DubzLib.Color("Foreground")
        entry.ValueColor = entry.ValueColor or WithAlpha(Accent("job", ply) or teamColor, 235)
    elseif entry.Type == "health" then
        local health = (DHUD.IsPreviewActive and DHUD.IsPreviewActive()) and 86 or math.max(ply:Health(), 0)
        entry.Value = ResolveText(entry.Value, ply, entry) or (math.Round(AnimatedNumber("health", health)) .. " %")
        entry.Accent = Accent(entry.Accent or "health", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "armor" then
        local enabled, armor, armorCfg
        if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then
            enabled, armor, armorCfg = true, 42, entry
        elseif DubzLib.Status and DubzLib.Status.Armor then
            enabled, armor, armorCfg = DubzLib.Status.Armor(ply, {Armor = entry})
        else
            enabled, armor, armorCfg = true, math.max(ply:Armor(), 0), entry
        end

        entry.Value = ResolveText(entry.Value, ply, entry) or math.Round(AnimatedNumber("armor", armor))
        entry.Visible = enabled and 1 or 0
        entry.Label = entry.Label or armorCfg.Label or "AR"
        entry.Icon = entry.Icon or armorCfg.Icon or "armor"
        entry.Accent = Accent(entry.Accent or "armor", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "oxygen" then
        local enabled, oxygen, oxygenCfg
        if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then
            enabled, oxygen, oxygenCfg = true, 72, entry
        elseif DubzLib.Status and DubzLib.Status.Oxygen then
            enabled, oxygen, oxygenCfg = DubzLib.Status.Oxygen(ply, {Oxygen = entry})
        else
            enabled, oxygen, oxygenCfg = false, 100, entry
        end

        entry.Value = ResolveText(entry.Value, ply, entry) or (math.Round(AnimatedNumber("oxygen", oxygen)) .. "%")
        entry.Visible = enabled and 1 or 0
        entry.Label = entry.Label or oxygenCfg.Label or "O2"
        entry.Icon = entry.Icon or oxygenCfg.Icon or "misc/spo2"
        entry.Accent = Accent(entry.Accent or oxygenCfg.Accent or "oxygen", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "hunger" then
        local enabled, hunger, hungerCfg
        if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then
            enabled, hunger, hungerCfg = true, 64, entry
        elseif DubzLib.Status and DubzLib.Status.Hunger then
            enabled, hunger, hungerCfg = DubzLib.Status.Hunger(ply, {Hunger = entry})
        else
            enabled, hunger, hungerCfg = false, 100, entry
        end

        entry.Value = ResolveText(entry.Value, ply, entry) or (math.Round(AnimatedNumber("hunger", hunger)) .. "%")
        entry.Visible = enabled and 1 or 0
        entry.Label = entry.Label or hungerCfg.Label or "Hunger"
        entry.Icon = entry.Icon or hungerCfg.Icon or "players/hunger"
        entry.Accent = Accent(entry.Accent or hungerCfg.Accent or "hunger", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "props" then
        entry.Value = ResolveText(entry.Value, ply, entry) or GetPropLimit(ply)
        entry.Accent = Accent(entry.Accent or "props", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "salary" then
        entry.Value = ResolveText(entry.Value, ply, entry) or FormatMoney(math.Round(AnimatedNumber("salary", GetDarkRPNumber(ply, "salary"))))
        entry.Accent = Accent(entry.Accent or "cash", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "wallet" then
        entry.Value = ResolveText(entry.Value, ply, entry) or FormatMoney(math.Round(AnimatedNumber("wallet", GetDarkRPNumber(ply, "money"))))
        entry.Accent = Accent(entry.Accent or "gold", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "clock" then
        entry.Label = ResolveText(entry.Label, ply, entry) or ""
        entry.Value = ResolveText(entry.Value, ply, entry) or DHUD.GetClockText()
        entry.Accent = Accent(entry.Accent or "clock", ply)
        entry.ValueColor = entry.ValueColor or DubzLib.Color("Foreground")
    elseif entry.Type == "gunlicense" then
        local enabled = DHUD.Status and DHUD.Status.HasGunLicense and DHUD.Status.HasGunLicense(ply)
        entry.Label = entry.Label or "License"
        entry.Value = ResolveText(entry.Value, ply, entry) or "Yes"
        entry.Visible = enabled and 1 or 0
        entry.Accent = Accent(entry.Accent or "gunlicense", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "wanted" then
        local enabled = DHUD.Status and DHUD.Status.IsWanted and DHUD.Status.IsWanted(ply)
        entry.Label = entry.Label or "Wanted"
        entry.Value = ResolveText(entry.Value, ply, entry) or "Yes"
        entry.Visible = enabled and 1 or 0
        entry.Accent = Accent(entry.Accent or "wanted", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    elseif entry.Type == "arrested" then
        local enabled = DHUD.Status and DHUD.Status.IsArrested and DHUD.Status.IsArrested(ply)
        entry.Label = entry.Label or "Arrested"
        entry.Value = ResolveText(entry.Value, ply, entry) or (DHUD.Status.GetArrestedTimeLeft and DHUD.Status.GetArrestedTimeLeft(ply) and string.FormattedTime(DHUD.Status.GetArrestedTimeLeft(ply), "%02i:%02i") or "Yes")
        entry.Visible = enabled and 1 or 0
        entry.Accent = Accent(entry.Accent or "arrested", ply)
        entry.ValueColor = entry.ValueColor or entry.Accent
    else
        entry.Label = ResolveText(entry.Label, ply, entry) or key
        entry.Value = ResolveText(entry.Value, ply, entry) or ""
        entry.Accent = Accent(entry.Accent, ply)
        entry.ValueColor = entry.ValueColor or DubzLib.Color("Foreground")
    end

    return entry
end

local function MeasureTrackSection(entry)
    local cfg = Cfg()
    local section = cfg.Section or {}
    local font = entry.Font or DubzLib.Font("Body")
    local padX = entry.PadX or section.PadX or 12
    local iconWide = entry.Icon and (entry.IconWide or section.IconWide or 24) or 0
    local label = tostring(entry.Label or "")
    local value = tostring(entry.Value or "")
    local hasValue = value ~= ""
    local gap = hasValue and (entry.TextGap or 8) or 0
    local contentWide = padX * 2 + iconWide + TextWide(font, label) + gap + TextWide(font, value)

    return math.max(entry.MinWide or section.DefaultWide or section.MinWide or 86, contentWide)
end

local function DrawTrackSection(entry, x, y, w, h, ply)
    local cfg = Cfg()
    local section = cfg.Section or {}

    if isfunction(entry.Draw) then
        entry.Draw(entry, x, y, w, h, ply)
        return
    end

    local font = entry.Font or DubzLib.Font("Body")
    local padX = entry.PadX or section.PadX or 12
    local iconSize = entry.IconSize or section.IconSize or 16
    local chipSize = entry.ChipSize or section.ChipSize or 22
    local iconWide = entry.Icon and (entry.IconWide or section.IconWide or 24) or 0
    local label = tostring(entry.Label or "")
    local value = tostring(entry.Value or "")
    local hasValue = value ~= ""
    local gap = hasValue and (entry.TextGap or 8) or 0
    local accent = entry.Accent or DubzLib.Color("Primary")
    local labelWide = TextWide(font, label)

    DubzLib.Draw.Panel(x, y, w, h, {
        Radius = entry.Radius or "MD",
        Color = entry.Background or section.Background or Color(25, 25, 25),
        Border = entry.Border or section.Border or DubzLib.Color("BorderSoft"),
        Shadow = entry.Shadow ~= nil and entry.Shadow or section.Shadow or false
    })

    local cursor = x + padX
    local textY = y + h * 0.5

    if entry.Icon and DubzLib.Icon then
        if entry.DrawChip ~= false then
            draw.RoundedBox(DubzLib.Radius("SM"), cursor - 3, y + h * 0.5 - chipSize * 0.5, chipSize, chipSize, WithAlpha(accent, entry.ChipAlpha or 30))
        end

        DubzLib.Icon.Draw(entry.Icon, cursor, y + h * 0.5 - iconSize * 0.5, iconSize, accent)
        cursor = cursor + iconWide + 2
    end

    if label ~= "" then
        DubzLib.Draw.Text(DHUD.L and DHUD.L(label) or label, font, cursor, textY, entry.LabelColor or DubzLib.Color("Muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        cursor = cursor + labelWide + gap
    end

    if hasValue then
        DubzLib.Draw.Text(value, font, cursor, textY, entry.ValueColor or DubzLib.Color("Foreground"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function TrackValue(key, target)
    local cfg = Cfg()
    local layout = cfg.Layout or {}
    local speed = layout.LerpSpeed or 16

    if DubzLib.Anim and DubzLib.Anim.Lerp then
        return DubzLib.Anim.Lerp(DHUD.Bar, key, target, speed)
    end

    return target
end

local function DrawEntryList(keys, startX, y, h, maxLeft, ply, direction, bounds)
    local cfg = Cfg()
    local layout = cfg.Layout or {}
    local gap = layout.Gap or 8
    local x = startX

    for _, key in ipairs(keys or {}) do
        local entry = ResolveEntry(key, ply)
        if entry then
            local wide = MeasureTrackSection(entry)
            local visible = TrackValue(key .. "_visible", entry.Visible == 0 and 0 or 1)
            local drawWideTarget = wide * visible
            local targetX = x

            if direction == "right" then
                targetX = x - drawWideTarget
                if targetX < maxLeft then break end
            else
                if x + drawWideTarget > maxLeft then break end
            end

            local drawX = TrackValue(key .. "_x", targetX)
            local drawWide = TrackValue(key .. "_w", drawWideTarget)

            if drawWide > 2 then
                render.SetScissorRect(drawX, y, drawX + drawWide, y + h, true)
                DrawTrackSection(entry, drawX, y, drawWide, h, ply)
                render.SetScissorRect(0, 0, 0, 0, false)
            end

            bounds[key] = {x = drawX, y = y, w = drawWide, h = h}

            if direction == "right" then
                x = targetX - gap * visible
            else
                x = x + drawWideTarget + gap * visible
            end
        end
    end
end

local function MeasureEntryList(keys, ply)
    local cfg = Cfg()
    local layout = cfg.Layout or {}
    local gap = layout.Gap or 8
    local total = 0
    local count = 0

    for _, key in ipairs(keys or {}) do
        local entry = ResolveEntry(key, ply)
        if entry then
            local visible = entry.Visible == 0 and 0 or 1
            total = total + MeasureTrackSection(entry) * visible
            count = count + visible
        end
    end

    if count > 1 then
        total = total + gap * (count - 1)
    end

    return total
end

local function DrawRightEntries(ply, rightStart, y, h, minLeft, bounds)
    local cfg = Cfg()
    local layout = cfg.Layout or {}
    local gap = layout.Gap or 8
    local clockEntry = ResolveEntry("clock", ply)
    local x = rightStart

    if clockEntry then
        local clockW = MeasureTrackSection(clockEntry)
        local drawX = TrackValue("clock_x", rightStart - clockW)
        local drawW = TrackValue("clock_w", clockW)

        if drawW > 2 then
            render.SetScissorRect(drawX, y, drawX + drawW, y + h, true)
            DrawTrackSection(clockEntry, drawX, y, drawW, h, ply)
            render.SetScissorRect(0, 0, 0, 0, false)
        end

        bounds.clock = {x = drawX, y = y, w = drawW, h = h}
        x = rightStart - clockW - gap
    end

    for _, key in ipairs(cfg.RightEntries or {}) do
        if key ~= "clock" then
            local entry = ResolveEntry(key, ply)
            if entry then
                local visible = TrackValue(key .. "_visible", entry.Visible == 0 and 0 or 1)
                local wide = MeasureTrackSection(entry)
                local drawWideTarget = wide * visible
                local targetX = x - drawWideTarget
                if targetX < minLeft then break end

                local drawX = TrackValue(key .. "_x", targetX)
                local drawW = TrackValue(key .. "_w", drawWideTarget)

                if drawW > 2 then
                    render.SetScissorRect(drawX, y, drawX + drawW, y + h, true)
                    DrawTrackSection(entry, drawX, y, drawW, h, ply)
                    render.SetScissorRect(0, 0, 0, 0, false)
                end

                bounds[key] = {x = drawX, y = y, w = drawW, h = h}
                x = targetX - gap * visible
            end
        end
    end
end

function DHUD.DrawBarHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local cfg = Cfg()
    if cfg.Enabled == false then return end

    local layout = cfg.Layout or {}
    local section = cfg.Section or {}
    local barH = layout.Height or 42
    local sectionH = section.Height or 30
    local edge = string.lower(tostring(layout.Edge or "top"))
    local y = edge == "bottom" and (ScrH() - barH + (layout.StartY or 6)) or (layout.StartY or 6)
    local leftX = layout.StartX or 10
    local rightPad = layout.RightX or 10
    local bounds = {}

    local barY = edge == "bottom" and (ScrH() - barH) or 0
    draw.RoundedBox(0, 0, barY, ScrW(), barH, DubzLib.Color("Secondary"))

    local line = cfg.BottomAccentLine or {}
    if line.Enabled then
        local col = line.Color or DubzLib.Color("Primary")
        surface.SetDrawColor(WithAlpha(col, line.Alpha or 210))
        local lineY = edge == "bottom" and barY or (barH - (line.Height or 2))
        surface.DrawRect(0, lineY, ScrW(), line.Height or 2)
    end

    local rightStart = ScrW() - rightPad
    local rightWidth = MeasureEntryList(cfg.RightEntries or {}, ply)
    local rightReserve = layout.ReserveRightTrack ~= false and rightStart - rightWidth - (layout.Gap or 8) or rightStart

    DrawRightEntries(ply, rightStart, y, sectionH, leftX, bounds)
    DrawEntryList(cfg.LeftEntries or {}, leftX, y, sectionH, rightReserve, ply, "left", bounds)

    DHUD.Bar.Bounds = bounds
end
