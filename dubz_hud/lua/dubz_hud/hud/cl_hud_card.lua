local DHUD = DHUD
DHUD.Card = DHUD.Card or {}

local function CardCfg()
    return DHUD.Config and DHUD.Config.Card or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function WithAlpha(col, alpha)
    if not col then col = color_white end
    return Color(col.r, col.g, col.b, alpha)
end

local function FormatMoney(value)
    if DubzLib.Status and DubzLib.Status.FormatMoney then
        return DubzLib.Status.FormatMoney(value)
    end

    value = value or 0
    return "$" .. string.Comma(value)
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

    return colors.HUDAccent or colors.Primary or DubzLib.Color("Primary")
end

local function CardBackground()
    local colors = Colors()
    local bg = CardCfg().Background or colors.HUDBackground or colors.Background or DubzLib.Color("Secondary")
    local panel = colors.Background2 or colors.ScoreboardPanel or bg

    if bg.r == panel.r and bg.g == panel.g and bg.b == panel.b then
        return Color(math.max(bg.r - 4, 0), math.max(bg.g - 4, 0), math.max(bg.b - 4, 0), bg.a or 255)
    end

    return bg
end

local function CardPanel()
    local colors = Colors()
    return colors.Background2 or colors.ScoreboardPanel or colors.HUDBackground or colors.Background or DubzLib.Color("Panel")
end

local function CardRadius(defaultKey)
    local cfg = CardCfg()
    if isnumber(cfg.PlayerCardRadius) then
        return math.max(math.Round(cfg.PlayerCardRadius), 0)
    end

    return DubzLib.Radius(defaultKey or "LG")
end

local function TrackValue(key, target, speed)
    if DubzLib.Anim and DubzLib.Anim.Lerp then
        return DubzLib.Anim.Lerp(DHUD.Card, key, target, speed or CardCfg().LerpSpeed or 14)
    end

    return target
end

local function TrackMeterFill(key, target)
    local cfg = CardCfg()
    local speed = cfg.MeterLerpSpeed or cfg.LerpSpeed or 14

    if DubzLib.Anim and DubzLib.Anim.Lerp then
        return DubzLib.Anim.Lerp(DHUD.Card, key, target, speed)
    end

    return target
end

local function GetDarkRPNumber(ply, key)
    if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then
        if key == "money" then return 125000 end
        if key == "salary" then return 850 end
    end

    if ply.getDarkRPVar then
        return ply:getDarkRPVar(key) or 0
    end

    return 0
end

local function NormalizeFeatureConfig(value, default)
    if istable(value) then return value end
    if value == nil then return default or {} end

    return {Enabled = value}
end

local function GetHungerConfig()
    local cfg = CardCfg()
    return NormalizeFeatureConfig(cfg.Hunger, {
        Enabled = "auto",
        Var = "Energy",
        Label = "Hunger",
        Icon = "players/hunger",
        Accent = "hunger"
    })
end

local function GetOxygenConfig()
    local cfg = CardCfg()
    return NormalizeFeatureConfig(cfg.Oxygen, {
        Enabled = "auto",
        Label = "Oxygen",
        Icon = "misc/spo2",
        Accent = "oxygen",
        Max = 100,
        DrainTime = 12,
        RecoverTime = 4
    })
end

local function GetArmorConfig()
    local cfg = CardCfg()
    return NormalizeFeatureConfig(cfg.Armor, {
        Enabled = "auto",
        HideWhenEmpty = true,
        Label = "Armor",
        Icon = "armor",
        Accent = "armor"
    })
end

local function GetPropsConfig()
    local cfg = CardCfg()
    return NormalizeFeatureConfig(cfg.Props, {
        Enabled = true,
        Label = "Props",
        Icon = "misc/handyman",
        Accent = "props",
        Max = 100
    })
end

local function GetDarkRPVar(ply, names)
    if not ply.getDarkRPVar then return nil end

    for _, name in ipairs(names) do
        local value = ply:getDarkRPVar(name)
        if value ~= nil then return value end
    end

    return nil
end

local function HungerState(ply)
    local cfg = GetHungerConfig()
    if cfg.Enabled == false then return false, 100 end
    if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then return true, 64 end

    local value
    if isfunction(cfg.Value) then
        value = cfg.Value(ply)
    else
        value = GetDarkRPVar(ply, {
            cfg.Var or "Energy",
            "Energy",
            "energy",
            "Hunger",
            "hunger"
        })
    end

    local enabled = cfg.Enabled == true
    if cfg.Enabled == "auto" or cfg.Enabled == nil then
        enabled = value ~= nil or (GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.hungermod == true)
    end

    return enabled, math.Clamp(tonumber(value) or tonumber(cfg.FallbackValue) or 100, 0, 100)
end

local function OxygenState(ply)
    local cfg = GetOxygenConfig()
    if cfg.Enabled == false then return false, 100 end
    if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then return true, 72 end

    if DubzLib.Status and DubzLib.Status.Oxygen then
        local enabled, oxygen = DubzLib.Status.Oxygen(ply, {Oxygen = cfg})
        return enabled, oxygen
    end

    return false, cfg.Max or 100
end

local function ArmorState(ply)
    local cfg = GetArmorConfig()
    if cfg.Enabled == false then return false, 0 end
    if DHUD.IsPreviewActive and DHUD.IsPreviewActive() then return true, 42 end

    local armor = math.max(ply:Armor(), 0)
    local enabled = cfg.Enabled == true or armor > 0 or cfg.HideWhenEmpty == false

    if cfg.Enabled == "auto" or cfg.Enabled == nil then
        enabled = armor > 0 or cfg.HideWhenEmpty == false
    end

    return enabled, armor
end

local function DrawLayeredPanel(x, y, w, h, bg, accent, cfg)
    local radius = CardRadius("LG")
    local accentW = cfg.AccentWidth or 7
    local innerAlpha = cfg.InnerAlpha or 255

    if cfg.Shadow ~= false then
        DubzLib.Draw.Shadow(x, y, w, h, radius, 120)
    end

    draw.RoundedBox(radius, x, y, w, h, accent)
    draw.RoundedBox(radius, x + accentW, y - 1, w - accentW + 1, h + 2, WithAlpha(bg, innerAlpha))
end

local function DrawIconChip(icon, x, y, accent, alpha, size)
    size = size or 22
    alpha = alpha or 255

    draw.RoundedBox(DubzLib.Radius("SM"), x, y, size, size, WithAlpha(accent, 30 * (alpha / 255)))

    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(icon, x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
    elseif DubzLib.Icon then
        DubzLib.Icon.Draw(icon, x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
    end
end

local avatarPanel
local avatarPlayer

local function DrawAvatarChip(ply, x, y, accent, size)
    size = size or 32

    if not IsValid(avatarPanel) then
        avatarPanel = vgui.Create("AvatarImage")
        avatarPanel:SetPaintedManually(true)
    end

    if avatarPlayer ~= ply then
        avatarPanel:SetPlayer(ply, 64)
        avatarPlayer = ply
    end

    local radius = math.min(CardRadius("SM"), size * 0.5)
    local maskInset = 2
    local maskSize = size - maskInset * 2
    draw.RoundedBox(radius, x, y, size, size, WithAlpha(accent, 34))
    draw.RoundedBox(radius, x + maskInset, y + maskInset, maskSize, maskSize, CardPanel())

    avatarPanel:SetSize(size, size)
    avatarPanel:SetPos(x, y)

    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilPassOperation(STENCIL_REPLACE)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetBlend(0)
    draw.RoundedBox(math.max(radius - 1, 0), x + maskInset, y + maskInset, maskSize, maskSize, color_white)
    render.SetBlend(1)
    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilPassOperation(STENCIL_KEEP)

    avatarPanel:PaintManual()

    render.SetStencilEnable(false)
end

local function DrawMeter(row, x, y, w)
    local alpha = math.Clamp((row.Anim or 1) * 255, 0, 255)
    if alpha <= 1 then return end

    local accent = row.Accent
    local frac = math.Clamp((row.Value or 0) / math.max(row.Max or 1, 1), 0, 1)
    local fillFrac = TrackMeterFill(row.Key .. "_fill", frac)

    DrawIconChip(row.Icon, x, y - 1, accent, alpha)

    DubzLib.Draw.Text(DHUD.L and DHUD.L(row.Label) or row.Label, DubzLib.Font("Small"), x + 32, y + 9, WithAlpha(DubzLib.Color("Muted"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    DubzLib.Draw.Text(tostring(row.Value or 0), DubzLib.Font("Small"), x + w, y + 9, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    draw.RoundedBox(DubzLib.Radius("XS"), x + 32, y + 21, w - 32, 6, WithAlpha(CardPanel(), alpha))
    draw.RoundedBox(DubzLib.Radius("XS"), x + 32, y + 21, (w - 32) * fillFrac, 6, WithAlpha(accent, alpha))
end

local function DrawMoneyStrip(x, y, w, ply, cfg)
    local wallet = FormatMoney(GetDarkRPNumber(ply, "money"))
    local salary = FormatMoney(GetDarkRPNumber(ply, "salary"))
    local gold = Accent("gold", ply)
    local cash = Accent("cash", ply)

    DrawIconChip("wallet", x, y - 2, gold, 255)
    DubzLib.Draw.Text(DHUD.L and DHUD.L("Wallet") or "Wallet", DubzLib.Font("Small"), x + 32, y + 9, DubzLib.Color("Muted"), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    if cfg.ShowSalaryOnWallet ~= false then
        surface.SetFont(DubzLib.Font("Small"))
        local salaryText = "+ " .. salary
        local salaryWide = surface.GetTextSize(salaryText)

        DubzLib.Draw.Text(salaryText, DubzLib.Font("Small"), x + w, y + 9, cash, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        DubzLib.Draw.Text(wallet, DubzLib.Font("Body"), x + w - salaryWide - 10, y + 9, gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    else
        DubzLib.Draw.Text(wallet, DubzLib.Font("Body"), x + w, y + 9, gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

local function DrawStatusChips(ply, x, y, w, cfg)
    if not DHUD.Status or not DHUD.Status.GetActiveChips then return end

    local chips = DHUD.Status.GetActiveChips(ply)
    if #chips <= 0 then return end

    local size = cfg.StatusChipSize or 22
    local gap = cfg.StatusChipGap or 5
    local startX = x + w - (#chips * size) - math.max(#chips - 1, 0) * gap

    for i, name in ipairs(chips) do
        DHUD.Status.DrawStatusChip(name, startX + (i - 1) * (size + gap), y, size, 255)
    end
end

local function DrawClockChip(x, y, w, cfg)
    if cfg.ClockEnabled == false or not DHUD.GetClockText then return end

    local accent = Accent("clock")
    local text = DHUD.GetClockText()
    local font = DubzLib.Font("Small")
    local size = cfg.ClockChipSize or 22
    local gap = 6

    surface.SetFont(font)
    local textW = surface.GetTextSize(text)
    local chipW = size + gap + textW
    local chipX = x + w - chipW + (cfg.ClockOffsetX or 0)

    draw.RoundedBox(DubzLib.Radius("SM"), chipX, y, size, size, WithAlpha(accent, 34))
    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(cfg.ClockIcon or "communication/notifications", chipX + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, accent)
    end

    DubzLib.Draw.Text(DHUD.L and DHUD.L(text) or text, font, chipX + size + gap, y + size * 0.5, accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function BuildRows(ply)
    local cfg = CardCfg()
    local rows = {}

    table.insert(rows, {
        Key = "health",
        Label = "Health",
        Icon = "health",
        Value = math.max(ply:Health(), 0),
        Max = ply:GetMaxHealth(),
        Accent = Accent("health", ply),
        Visible = 1
    })

    local armorCfg = GetArmorConfig()
    local armorEnabled, armor = ArmorState(ply)
    table.insert(rows, {
        Key = "armor",
        Label = armorCfg.Label or "Armor",
        Icon = armorCfg.Icon or "armor",
        Value = armor,
        Max = armorCfg.Max or 100,
        Accent = Accent(armorCfg.Accent or "armor", ply),
        Visible = armorEnabled and 1 or 0
    })

    local hungerCfg = GetHungerConfig()
    local hungerEnabled, hunger = HungerState(ply)
    table.insert(rows, {
        Key = "hunger",
        Label = hungerCfg.Label or "Hunger",
        Icon = hungerCfg.Icon or "misc/spo2",
        Value = hunger,
        Max = hungerCfg.Max or 100,
        Accent = Accent(hungerCfg.Accent or "hunger", ply),
        Visible = hungerEnabled and 1 or 0
    })

    local oxygenCfg = GetOxygenConfig()
    local oxygenEnabled, oxygen = OxygenState(ply)
    table.insert(rows, {
        Key = "oxygen",
        Label = oxygenCfg.Label or "Oxygen",
        Icon = oxygenCfg.Icon or "misc/spo2",
        Value = oxygen,
        Max = oxygenCfg.Max or 100,
        Accent = Accent(oxygenCfg.Accent or "oxygen", ply),
        Visible = oxygenEnabled and 1 or 0
    })

    local propsCfg = GetPropsConfig()
    if propsCfg.Enabled ~= false then
        local propsText = "0"
        local propsValue = 0
        if DubzLib.Status and DubzLib.Status.GetPropLimit then
            propsText = tostring(DubzLib.Status.GetPropLimit(ply) or "0")
            propsValue = tonumber(string.match(propsText, "^(%d+)")) or 0
        end

        table.insert(rows, {
            Key = "props",
            Label = propsCfg.Label or "Props",
            Icon = propsCfg.Icon or "misc/handyman",
            Value = propsValue,
            Max = propsCfg.Max or 100,
            Accent = Accent(propsCfg.Accent or "props", ply),
            Visible = 1
        })
    end

    if cfg.ShowMoney ~= false then
        table.insert(rows, {
            Key = "money",
            Kind = "money",
            Visible = 1
        })
    end

    local hasCustomOrder = istable(cfg.Order)
    local order = hasCustomOrder and cfg.Order or {"health", "armor", "hunger", "oxygen", "money", "props"}
    local byKey = {}
    for _, row in ipairs(rows) do
        byKey[row.Key] = row
    end

    local sorted = {}
    for _, key in ipairs(order) do
        if byKey[key] then
            sorted[#sorted + 1] = byKey[key]
            byKey[key] = nil
        end
    end

    if not hasCustomOrder then
        for _, row in ipairs(rows) do
            if byKey[row.Key] then
                sorted[#sorted + 1] = row
                byKey[row.Key] = nil
            end
        end
    end

    rows = sorted

    return rows
end

function DHUD.DrawCardHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local cfg = CardCfg()
    if cfg.Enabled == false then return end

    local rows = BuildRows(ply)
    local speed = cfg.LerpSpeed or 14
    local rowH = cfg.RowHeight or 28
    local rowGap = cfg.RowGap or 5
    local moneyH = cfg.MoneyHeight or 22
    local moneyGap = cfg.MoneyGap or 6
    local headerH = cfg.HeaderHeight or 58
    local bottomPad = cfg.BottomPad or 8
    local targetH = headerH + bottomPad
    local visibleRows = 0

    for _, row in ipairs(rows) do
        row.Anim = TrackValue(row.Key .. "_visible", row.Visible, speed)

        if row.Kind == "money" then
            local spacing = visibleRows > 0 and moneyGap or 0
            targetH = targetH + (moneyH + spacing) * row.Anim
        else
            local spacing = visibleRows > 0 and rowGap or 0
            targetH = targetH + (rowH + spacing) * row.Anim
        end

        visibleRows = visibleRows + row.Anim
    end

    local w = cfg.Width or 324
    local h = TrackValue("height", targetH, speed)
    local x = cfg.X or 20
    local y = TrackValue("y", ScrH() - targetH - (cfg.BottomY or 30), speed)
    local pad = cfg.Pad or 16
    local accent = cfg.Accent or Colors().HUDAccent or DubzLib.Color("Primary")
    local bg = CardBackground()
    local identityColor = Accent(cfg.NameColor or "identity", ply)
    local jobColor = Accent(cfg.JobColor or "job", ply)

    DrawLayeredPanel(x, y, w, h, bg, accent, cfg)

    local contentX = x + pad + (cfg.AccentWidth or 7)
    local contentW = w - pad * 2 - (cfg.AccentWidth or 7)

    DrawAvatarChip(ply, contentX, y + 10, identityColor, cfg.AvatarSize or 32)
    DubzLib.Draw.Text(ply:Nick(), DubzLib.Font("Header"), contentX + 42, y + 10, DubzLib.Color("Foreground"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DubzLib.Draw.Text(DHUD.L and DHUD.L(team.GetName(ply:Team()) or "Unknown") or (team.GetName(ply:Team()) or "Unknown"), DubzLib.Font("Small"), contentX + 42, y + 35, jobColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawStatusChips(ply, contentX, y + 13, contentW, cfg)
    DrawClockChip(contentX, y + 36, contentW, cfg)

    local rowY = TrackValue("row_y", y + headerH, speed)
    local drawnRows = 0

    for _, row in ipairs(rows) do
        if row.Kind == "money" then
            if drawnRows > 0 then
                rowY = rowY + moneyGap * row.Anim
            end

            if row.Anim > 0.01 then
                DrawMoneyStrip(contentX, rowY, contentW, ply, cfg)
            end

            rowY = rowY + moneyH * row.Anim
        else
            if drawnRows > 0 then
                rowY = rowY + rowGap * row.Anim
            end

            if row.Anim > 0.01 then
                DrawMeter(row, contentX, rowY, contentW)
            end

            rowY = rowY + rowH * row.Anim
        end

        drawnRows = drawnRows + row.Anim
    end

    DHUD.Card.Bounds = {x = x, y = y, w = w, h = h}
end
