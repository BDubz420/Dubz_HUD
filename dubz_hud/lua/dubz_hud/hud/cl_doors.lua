local DHUD = DHUD
DHUD.Doors = DHUD.Doors or {}

local changeDoorAccess = false

local function Cfg()
    return DHUD.Config and DHUD.Config.Door or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then
        return DubzLib.Radius(name)
    end

    return name == "MD" and 8 or 5
end

local function LibColor(name, fallback)
    if DubzLib and DubzLib.Color then
        return DubzLib.Color(name)
    end

    return fallback
end

local function LibFont(name, fallback)
    if DubzLib and DubzLib.Font then
        return DubzLib.Font(name)
    end

    return fallback
end

local function AccentFor(ent, blocked, owned)
    local colors = DHUD.Config and DHUD.Config.Colors or {}

    if blocked then return colors.Warning or Color(238, 146, 80) end
    if owned then return colors.License or colors.Cash or Color(91, 201, 121) end

    return colors.Wanted or colors.Health or Color(232, 84, 84)
end

local function AddLine(lines, text, colorName)
    if not text or text == "" then return end
    lines[#lines + 1] = {Text = tostring(text), ColorName = colorName}
end

local function AddDoorHint(lines, owned)
    AddLine(lines, owned and "Press F2 or R for door options" or "Press F2 or R to own this door", "hint")
end

local function LocalIsAdmin()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:IsAdmin()
end

local function HoldingKeys()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    local weapon = ply:GetActiveWeapon()
    return IsValid(weapon) and string.lower(tostring(weapon:GetClass() or "")) == "keys"
end

local function CanShowDoorHover()
    local cfg = Cfg()
    return cfg.RequireKeysForHover ~= true or HoldingKeys()
end

local function DoorTitle(ent)
    local title

    if ent.getKeysTitle then
        local ok, result = pcall(function()
            return ent:getKeysTitle()
        end)

        if ok then title = result end
    end

    title = string.Trim(tostring(title or ""))

    return title ~= "" and title or nil
end

local function Phrase(name, ...)
    if DarkRP and DarkRP.getPhrase then
        return DarkRP.getPhrase(name, ...)
    end

    return name
end

local function IsDoor(ent)
    if not IsValid(ent) then return false end
    if ent:IsWorld() then return false end

    if ent:IsVehicle() then return true end

    local class = string.lower(ent:GetClass() or "")
    local allowedClass = class == "prop_door_rotating"
        or class == "func_door"
        or class == "func_door_rotating"

    if not allowedClass and ent.isDoor and not string.StartWith(class, "prop_") then
        local ok, result = pcall(function()
            return ent:isDoor()
        end)

        allowedClass = ok and result == true
    end

    return allowedClass == true
end

local function BuildDoorLines(ent)
    local blocked = ent.getKeysNonOwnable and ent:getKeysNonOwnable()
    if blocked then
        local lines = {}
        local title = DoorTitle(ent)

        if not title then return {}, true, false end

        AddLine(lines, "Private Property", "title")
        AddLine(lines, title, "main")
        if LocalIsAdmin() then AddDoorHint(lines, true) end

        return lines, false, true
    end

    local doorTeams = ent.getKeysDoorTeams and ent:getKeysDoorTeams()
    local doorGroup = ent.getKeysDoorGroup and ent:getKeysDoorGroup()
    local coOwners = ent.getKeysCoOwners and ent:getKeysCoOwners() or {}
    local playerOwned = (ent.isKeysOwned and ent:isKeysOwned()) or table.GetFirstValue(coOwners or {}) ~= nil
    local owned = playerOwned or doorGroup or doorTeams
    local lines = {}

    if playerOwned then
        AddLine(lines, "Private Property", "title")

        local title = DoorTitle(ent)
        if title then
            AddLine(lines, title, "main")
        end

        if ent.isKeysOwned and ent:isKeysOwned() then
            local owner = ent.getDoorOwner and ent:getDoorOwner()
            if IsValid(owner) then AddLine(lines, "Owned by " .. owner:Nick(), "main") end
        end

        for k in next, (coOwners or {}) do
            local ply = Player(k)
            if IsValid(ply) and ply:IsPlayer() then
                AddLine(lines, "Co-owner: " .. ply:Nick(), "muted")
            end
        end

        local allowed = ent.getKeysAllowedToOwn and ent:getKeysAllowedToOwn()
        if allowed and (not fn or not fn.Null or not fn.Null(allowed)) then
            for k in next, (allowed) do
                local ply = Player(k)
                if IsValid(ply) and ply:IsPlayer() then
                    AddLine(lines, "Allowed: " .. ply:Nick(), "muted")
                end
            end
        end
        AddDoorHint(lines, true)
    elseif doorGroup then
        AddLine(lines, "Private Property", "title")
        local title = DoorTitle(ent)
        if title then
            AddLine(lines, title, "main")
        end
        AddLine(lines, doorGroup, "main")
        if LocalIsAdmin() then AddDoorHint(lines, true) end
    elseif doorTeams then
        AddLine(lines, "Private Property", "title")
        local title = DoorTitle(ent)
        if title then
            AddLine(lines, title, "main")
        end
        for k, v in next, (doorTeams) do
            if v and RPExtraTeams and RPExtraTeams[k] then
                AddLine(lines, RPExtraTeams[k].name, "main")
            end
        end
        if LocalIsAdmin() then AddDoorHint(lines, true) end
    else
        AddLine(lines, "Unowned", "title")
        local title = DoorTitle(ent)
        if title then
            AddLine(lines, title, "main")
        end
        AddDoorHint(lines, false)
    end

    if ent:IsVehicle() then
        local driver = ent:GetDriver()
        if IsValid(driver) and driver:IsPlayer() then
            AddLine(lines, Phrase("driver", driver:Nick()), "muted")
        end
    end

    if #lines <= 0 then
        AddLine(lines, Phrase("keys_unowned"), "unowned")
    end

    return lines, blocked, owned
end

local function DrawLayeredCard(x, y, w, h, accent, cfg)
    local radius = Radius("MD")
    local accentW = cfg.AccentWidth or 5
    local bg = cfg.Background or LibColor("Secondary", Color(28, 28, 30))

    draw.RoundedBox(radius, x, y, w, h, accent)

    if DubzLib and DubzLib.Draw and DubzLib.Draw.Panel then
        DubzLib.Draw.Panel(x + accentW, y - 1, w - accentW + 1, h + 2, {
            Radius = "MD",
            Color = WithAlpha(bg, cfg.InnerAlpha or 255),
            Border = cfg.Border or LibColor("BorderSoft", Color(75, 75, 82)),
            Shadow = false
        })
    else
        draw.RoundedBox(radius, x + accentW, y, w - accentW, h, WithAlpha(bg, cfg.InnerAlpha or 255))
        surface.SetDrawColor(WithAlpha(LibColor("BorderSoft", Color(75, 75, 82)), 170))
        surface.DrawOutlinedRect(x + accentW, y, w - accentW, h)
    end
end

local function LineColor(line, accent)
    local colors = DHUD.Config and DHUD.Config.Colors or {}

    if line.ColorName == "title" then return LibColor("Foreground", color_white) end
    if line.ColorName == "muted" then return LibColor("Muted", Color(180, 180, 185)) end
    if line.ColorName == "hint" then return LibColor("Muted", Color(180, 180, 185)) end
    if line.ColorName == "warning" then return colors.Warning or accent end
    if line.ColorName == "unowned" then return colors.Wanted or accent end

    return accent
end

local function LineFont(line, cfg)
    if line.ColorName == "title" then return LibFont(cfg.TitleFont or "Header", "DermaDefaultBold") end
    if line.ColorName == "hint" then return LibFont(cfg.HintFont or "Small", "DermaDefault") end

    return LibFont(cfg.DetailFont or "Body", "DermaDefault")
end

local function LineHeight(line)
    if line.ColorName == "title" then return 22 end
    if line.ColorName == "hint" then return 16 end

    return 18
end

local function DrawText(text, font, x, y, col, ax, ay)
    text = DHUD.L and DHUD.L(text) or tostring(text or "")
    if DubzLib and DubzLib.Draw and DubzLib.Draw.Text then
        DubzLib.Draw.Text(text, font, x, y, col, ax, ay)
    else
        draw.SimpleText(text, font, x, y, col, ax, ay)
    end
end

local function DrawShadowText(text, font, x, y, col, ax, ay)
    DrawText(text, font, x + 1, y + 1, Color(0, 0, 0, 185), ax, ay)
    DrawText(text, font, x, y, col, ax, ay)
end

local function DrawDoorPanel(ent)
    local cfg = Cfg()
    if cfg.Enabled == false or not CanShowDoorHover() or not IsValid(ent) then return false end

    local lines, blocked, owned = BuildDoorLines(ent)
    if blocked then return true end

    local maxLines = cfg.MaxLines or 8
    local drawLines = {}

    for i = 1, math.min(#lines, maxLines) do
        drawLines[#drawLines + 1] = lines[i]
    end

    local w = cfg.Width or 300
    local h = 0
    for _, line in ipairs(drawLines) do
        h = h + LineHeight(line)
    end

    local x = ScrW() * 0.5
    local y = ScrH() * 0.5 + (cfg.YOffset or 36)
    local accent = AccentFor(ent, blocked, owned)

    local icon = (cfg.Icons and (owned and cfg.Icons.Owned or cfg.Icons.Unowned)) or "economy/house"
    if ent:IsVehicle() then icon = cfg.Icons and cfg.Icons.Vehicle or icon end

    local textW = w
    local cursorY = y - h * 0.5

    for i, line in ipairs(drawLines) do
        local text = tostring(line.Text or "")
        local font = LineFont(line, cfg)
        local lineH = LineHeight(line)
        surface.SetFont(font)

        if surface.GetTextSize(text) > textW then
            text = string.sub(text, 1, 34) .. "..."
        end

        if i == 1 and DHUD.Status and DHUD.Status.DrawIcon then
            local tw = surface.GetTextSize(text)
            local iconSize = 18
            local gap = 8
            local totalW = iconSize + gap + tw
            local iconX = x - totalW * 0.5
            local iconY = cursorY + lineH * 0.5 - iconSize * 0.5

            DHUD.Status.DrawIcon(icon, iconX, iconY, iconSize, accent)
            DrawShadowText(text, font, iconX + iconSize + gap, cursorY, LineColor(line, accent), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        else
            DrawShadowText(text, font, x, cursorY, LineColor(line, accent), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        cursorY = cursorY + lineH
    end

    return true
end

local function TraceDoor()
    if not CanShowDoorHover() then return nil end

    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local cfg = Cfg()
    local dist = cfg.DrawDistance or 250
    local startPos = ply:EyePos()
    local tr = util.TraceLine({
        start = startPos,
        endpos = startPos + ply:EyeAngles():Forward() * dist,
        filter = ply,
        mask = MASK_SOLID
    })

    if not tr or not tr.Hit then return nil end

    local ent = tr.Entity
    if not IsDoor(ent) then return nil end

    local hitPos = tr.HitPos or ent:GetPos()
    if startPos:DistToSqr(hitPos) > dist * dist then return nil end

    return ent
end

function DHUD.UpdateDoorTarget(force)
    local now = CurTime()
    if not force and (DHUD.Doors.NextScan or 0) > now then return end

    DHUD.Doors.NextScan = now + 0.04
    DHUD.Doors.CurrentEntity = TraceDoor()
    DHUD.Doors.LastSeen = IsValid(DHUD.Doors.CurrentEntity) and now or 0
end

local function LoadDoorPrivilegesHook()
    if CAMI and CAMI.PlayerHasAccess then
        local function updatePrivs()
            CAMI.PlayerHasAccess(LocalPlayer(), "DarkRP_ChangeDoorSettings", function(hasAccess)
                changeDoorAccess = hasAccess == true
            end)
        end

        updatePrivs()
        timer.Create("DHUD.DoorPrivilegeChecker", 1, 0, updatePrivs)
    end
end

local function DrawDoorDataHook(ent)
    local drawn = DrawDoorPanel(ent)
    if drawn then
        DHUD.Doors.LastDrawFrame = FrameNumber()
    end

    return drawn
end

DHUD.DrawDoorHUD = function()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Doors == false or Cfg().Enabled == false then return end

    local frame = FrameNumber()
    if DHUD.Doors.LastDrawFrame == frame then return end

    DHUD.UpdateDoorTarget()

    local ent = DHUD.Doors.CurrentEntity
    if not IsValid(ent) then return end

    DHUD.Doors.LastDrawFrame = frame
    DrawDoorPanel(ent)
end

local function ScanDoorTargetHook()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Doors == false or Cfg().Enabled == false then
        DHUD.Doors.CurrentEntity = nil
    else
        DHUD.UpdateDoorTarget()
    end
end

local function DrawDoorDataFallbackHook()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Doors ~= false and Cfg().Enabled ~= false and DHUD.DrawDoorHUD then
        DHUD.DrawDoorHUD()
    end
end

hook.Add("InitPostEntity", "DHUD.LoadDoorPrivileges", LoadDoorPrivilegesHook)
hook.Add("HUDDrawDoorData", "DHUD.DrawDoorData", DrawDoorDataHook)
hook.Add("Think", "DHUD.ScanDoorTarget", ScanDoorTargetHook)
hook.Add("HUDPaint", "DHUD.DrawDoorDataFallback", DrawDoorDataFallbackHook)
