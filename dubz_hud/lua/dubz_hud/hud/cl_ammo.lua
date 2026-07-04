local DHUD = DHUD
DHUD.Ammo = DHUD.Ammo or {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Ammo or {}
end

local function Colors()
    return DHUD.Config and DHUD.Config.Colors or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Accent()
    local colors = Colors()
    return colors.AmmoAccent or colors.Ammo or colors.Gold or Color(221, 177, 74)
end

local function TrackValue(key, target, speed)
    if DubzLib.Anim and DubzLib.Anim.Lerp then
        return DubzLib.Anim.Lerp(DHUD.Ammo, key, target, speed or Cfg().LerpSpeed or 16)
    end

    return target
end

local function TextWide(font, text)
    surface.SetFont(font)
    local wide = surface.GetTextSize(tostring(text or ""))
    return wide or 0
end

local function AmmoState(ply)
    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then return false end

    local primaryType = weapon:GetPrimaryAmmoType()
    local secondaryType = weapon:GetSecondaryAmmoType()
    local clip = weapon:Clip1()
    local maxClip = weapon.GetMaxClip1 and weapon:GetMaxClip1() or -1
    local class = weapon.GetClass and weapon:GetClass() or "unknown"
    local reserve = primaryType and primaryType >= 0 and ply:GetAmmoCount(primaryType) or 0
    local secondary = secondaryType and secondaryType >= 0 and ply:GetAmmoCount(secondaryType) or 0
    local hasPrimary = clip >= 0 or reserve > 0
    local hasSecondary = secondary > 0

    if not hasPrimary and not hasSecondary then return false end

    if maxClip <= 0 and istable(weapon.Primary) then
        maxClip = tonumber(weapon.Primary.ClipSize) or maxClip
    end

    DHUD.Ammo.SeenMaxClip = DHUD.Ammo.SeenMaxClip or {}
    if clip and clip > 0 then
        DHUD.Ammo.SeenMaxClip[class] = math.max(DHUD.Ammo.SeenMaxClip[class] or 0, clip)
    end

    if maxClip <= 0 then
        maxClip = DHUD.Ammo.SeenMaxClip[class] or math.max(clip, 0)
    end

    return true, {
        Weapon = weapon,
        Clip = math.max(clip, 0),
        MaxClip = math.max(maxClip or 0, 0),
        Reserve = reserve,
        Secondary = secondary,
        HasClip = clip >= 0,
        HasSecondary = hasSecondary
    }
end

local function DrawLayeredPanel(x, y, w, h, accent, alpha)
    local cfg = Cfg()
    local radius = DubzLib.Radius("MD")
    local accentW = cfg.AccentWidth or 5
    local colors = Colors()
    local bg = cfg.Background or colors.AmmoBackground or colors.HUDBackground or DubzLib.Color("Secondary")
    local border = cfg.Border or DubzLib.Color("BorderSoft")
    local innerAlpha = math.min(alpha, (cfg.InnerAlpha or 255) * (alpha / 255))

    if cfg.Shadow ~= false then
        DubzLib.Draw.Shadow(x, y, w, h, radius, cfg.ShadowAlpha or 80)
    end

    draw.RoundedBox(radius, x, y, w, h, WithAlpha(accent, alpha))
    DubzLib.Draw.Panel(x + accentW, y - 1, w - accentW + 1, h + 2, {
        Radius = "MD",
        Color = WithAlpha(bg, innerAlpha),
        Border = WithAlpha(border, math.min(alpha, 170)),
        Shadow = false
    })
end

local function DrawIconChip(icon, x, y, accent, alpha, size)
    size = size or 28
    draw.RoundedBox(DubzLib.Radius("SM"), x, y, size, size, WithAlpha(accent, 34 * (alpha / 255)))

    if DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(icon, x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
    elseif DubzLib.Icon then
        DubzLib.Icon.Draw(icon, x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
    end
end

local function BulletLayout(totalW, maxClip, gap, minSegmentW)
    totalW = math.floor(totalW)
    maxClip = math.floor(maxClip)
    gap = math.max(math.floor(gap or 1), 0)
    minSegmentW = math.max(math.floor(minSegmentW or 1), 1)

    if maxClip <= 0 then return 0, totalW end

    local available = totalW - gap * (maxClip - 1)
    if available < maxClip * minSegmentW then return 0, totalW end

    local segmentW = math.floor(available / maxClip)
    local usedW = segmentW * maxClip + gap * (maxClip - 1)

    return segmentW, usedW
end

local function DrawBulletBar(x, y, w, state, accent, alpha)
    local cfg = Cfg()
    local maxClip = math.max(tonumber(state.MaxClip) or 0, 0)
    local clip = math.Clamp(tonumber(state.Clip) or 0, 0, math.max(maxClip, 1))
    local barH = cfg.BulletBarHeight or 4
    local gap = cfg.BulletBarGap or 1
    local maxSegments = cfg.MaxBulletSegments or 90

    x = math.floor(x)
    y = math.floor(y)
    w = math.floor(w)

    if not state.HasClip or maxClip <= 0 then
        return
    end

    local fill = TrackValue("clip_bar_fill", clip / math.max(maxClip, 1), cfg.LerpSpeed or 16)
    local segmentW, usedW = BulletLayout(w, maxClip, gap, cfg.MinBulletSegmentWidth or 1)

    if maxClip > maxSegments or segmentW < 1 then
        draw.RoundedBox(DubzLib.Radius("XS"), x, y, w, barH, WithAlpha(DubzLib.Color("Background2"), math.min(alpha, 120)))
        draw.RoundedBox(DubzLib.Radius("XS"), x, y, math.floor(w * fill), barH, WithAlpha(accent, alpha))
        return
    end

    local filledSegments = math.floor(maxClip * fill + 0.0001)
    local emptyCol = WithAlpha(DubzLib.Color("Background2"), math.min(alpha, 125))
    local fillCol = WithAlpha(accent, alpha)

    for i = 1, maxClip do
        local segX = x + (i - 1) * (segmentW + gap)
        local col = i <= filledSegments and fillCol or emptyCol

        draw.RoundedBox(DubzLib.Radius("XS"), segX, y, segmentW, barH, col)
    end

    DHUD.Ammo.LastBulletBarWidth = usedW
end

function DHUD.DrawAmmoHUD()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Ammo == false or cfg.Enabled == false then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local preview = DHUD.IsPreviewFeature and DHUD.IsPreviewFeature("ammo")
    local visible, state = AmmoState(ply)

    if preview then
        visible = true
        state = {
            Clip = 24,
            MaxClip = 30,
            Reserve = 120,
            Secondary = 2,
            HasClip = true,
            HasSecondary = true
        }
    end

    local alphaFrac = TrackValue("visible", visible and 1 or 0, cfg.FadeLerpSpeed or cfg.LerpSpeed or 16)
    if alphaFrac <= 0.01 then return end

    local accent = cfg.Accent or Accent()
    local w = cfg.Width or 178
    if state and state.HasClip == false then
        w = math.min(w, cfg.CliplessWidth or 128)
    end
    local h = cfg.Height or 50
    local right = cfg.RightPadding or 24
    local bottom = cfg.BottomPadding or 28
    local x = TrackValue("x", ScrW() - w - right + (1 - alphaFrac) * 28, cfg.LerpSpeed or 16)
    local y = TrackValue("y", ScrH() - h - bottom, cfg.LerpSpeed or 16)
    local alpha = math.Clamp(alphaFrac * 255, 0, 255)
    local pad = cfg.Pad or 12
    local accentW = cfg.AccentWidth or 5
    local contentX = x + accentW + pad

    state = state or {
        Clip = DHUD.Ammo.LastClip or 0,
        MaxClip = DHUD.Ammo.LastMaxClip or 0,
        Reserve = DHUD.Ammo.LastReserve or 0,
        Secondary = DHUD.Ammo.LastSecondary or 0,
        HasClip = true
    }

    DHUD.Ammo.LastClip = state.Clip
    DHUD.Ammo.LastMaxClip = state.MaxClip
    DHUD.Ammo.LastReserve = state.Reserve
    DHUD.Ammo.LastSecondary = state.Secondary

    DrawLayeredPanel(x, y, w, h, accent, alpha)

    local chipSize = cfg.IconChipSize or 24
    DrawIconChip(cfg.Icon or "admin/security", contentX, y + 9, accent, alpha, chipSize)

    local clipText = state.HasClip and string.format("%d", tonumber(state.Clip) or 0) or string.format("%d", tonumber(state.Reserve) or 0)
    local reserveText = state.HasClip and ("/ " .. string.format("%d", tonumber(state.Reserve) or 0)) or ""
    local secondaryText = state.HasSecondary and ((state.HasClip and " / " or "/ ") .. string.format("%d", tonumber(state.Secondary) or 0)) or ""
    local reserveFullText = reserveText .. secondaryText

    local mainX = x + w - pad
    local reserveFont = DubzLib.Font("Body")
    local clipFont = DubzLib.Font("Header")
    local gap = cfg.SameLineGap or 6

    local reserveWide = TextWide(reserveFont, reserveFullText)
    local clipTargetX = reserveFullText ~= "" and (mainX - reserveWide - gap) or mainX
    local clipX = TrackValue("clip_x", clipTargetX, cfg.LerpSpeed or 16)

    DubzLib.Draw.Text(clipText, clipFont, clipX, y + 6, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    DubzLib.Draw.Text(reserveFullText, reserveFont, mainX, y + 10, WithAlpha(accent, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    DubzLib.Draw.Text(DHUD.L and DHUD.L(cfg.Label or "Ammo") or (cfg.Label or "Ammo"), DubzLib.Font("Body"), contentX + chipSize + 8, y + 16, WithAlpha(DubzLib.Color("Muted"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    if state.HasClip then
        DrawBulletBar(
            x + accentW + pad,
            y + h - (cfg.BulletBarBottom or 5) - (cfg.BulletBarHeight or 4),
            w - accentW - pad * 2,
            state,
            accent,
            alpha
        )
    end
end

hook.Add("HUDShouldDraw", "DHUD.HideDefaultAmmo", function(name)
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Ammo == false or cfg.Enabled == false or cfg.HideDefault == false then return end

    if name == "CHudAmmo" or name == "CHudSecondaryAmmo" then
        return false
    end
end)
