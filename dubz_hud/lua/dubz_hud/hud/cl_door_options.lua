local DHUD = DHUD
DHUD.DoorOptions = DHUD.DoorOptions or {}

local activeFrame
local popupFrames = {}
local Notify

local function Cfg()
    return DHUD.Config and DHUD.Config.DoorOptions or {}
end

local function AnimSpeed(cfg)
    cfg = cfg or Cfg()
    return cfg.AnimSpeed or 13
end

local function HoverSpeed(cfg)
    cfg = cfg or Cfg()
    return cfg.HoverSpeed or cfg.AnimHoverSpeed or 16
end

local function AnimSlide(cfg)
    cfg = cfg or Cfg()
    return cfg.Slide or 22
end

local function EaseValue(value, target, speed)
    return Lerp(math.Clamp(FrameTime() * (tonumber(speed) or 13), 0, 1), value or 0, target or 0)
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function Accent()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.DoorAccent or colors.Agenda or colors.Clock or Color(184, 116, 255)
end

local function ButtonBaseColor(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local col = colors.DoorBackground or colors.Background2 or Color(32, 33, 38)
    return Color(col.r or 32, col.g or 33, col.b or 38, math.min(alpha or 255, 245))
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
        local ok, result = pcall(function() return ent:isDoor() end)
        allowedClass = ok and result == true
    end

    return allowedClass == true
end

local function IsNonOwnable(ent)
    return ent.getKeysNonOwnable and ent:getKeysNonOwnable() == true
end

local function Owner(ent)
    if not ent.getDoorOwner then return nil end

    local owner = ent:getDoorOwner()
    if IsValid(owner) and owner:IsPlayer() then return owner end
end

local function OwnerName(ent)
    local owner = Owner(ent)
    return IsValid(owner) and owner:Nick() or nil
end

local function IsOwned(ent)
    return ent.isKeysOwned and ent:isKeysOwned()
end

local function DoorGroup(ent)
    return ent.getKeysDoorGroup and ent:getKeysDoorGroup() or nil
end

local function HasDoorTeams(ent)
    local teams = ent.getKeysDoorTeams and ent:getKeysDoorTeams() or nil
    return teams and not table.IsEmpty(teams)
end

local function IsOwnedByLocal(ent)
    local ply = LocalPlayer()
    if Owner(ent) == ply then return true end
    if ent.isKeysOwnedBy then return ent:isKeysOwnedBy(ply) == true end

    return false
end

local function CoOwners(ent)
    local out = {}
    local raw = ent.getKeysCoOwners and ent:getKeysCoOwners() or {}
    local owner = Owner(ent)

    local function HasCoOwnerKey(ply)
        if raw[ply] then return true end
        if raw[ply:UserID()] or raw[string.format("%d", ply:UserID() or 0)] then return true end
        if raw[ply:SteamID()] then return true end
        if ply.SteamID64 and raw[ply:SteamID64()] then return true end
        if ply.UniqueID and raw[ply:UniqueID()] then return true end

        return false
    end

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= owner and (HasCoOwnerKey(ply) or (ent.isKeysOwnedBy and ent:isKeysOwnedBy(ply) == true)) then
            out[#out + 1] = ply
        end
    end

    table.sort(out, function(a, b) return a:Nick():lower() < b:Nick():lower() end)
    return out
end

local function PotentialOwners(ent)
    local out = {}
    local owner = Owner(ent)
    local existing = {}

    for _, ply in ipairs(CoOwners(ent)) do
        existing[ply] = true
    end

    for _, ply in ipairs(player.GetAll()) do
        if ply ~= LocalPlayer() and ply ~= owner and not existing[ply] then
            out[#out + 1] = ply
        end
    end

    table.sort(out, function(a, b) return a:Nick():lower() < b:Nick():lower() end)
    return out
end

local function SayCommand(text)
    text = string.Trim(tostring(text or ""))
    if text == "" then return end
    RunConsoleCommand("say", text)
end

local function SetDoorTitle(ent, title, useAdminSetter)
    title = string.Trim(tostring(title or ""))
    if title == "" then return end
    if not IsDoor(ent) then
        Notify("You must be looking at a door or vehicle.", "warning")
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(ent:GetPos()) > 40000 then
        Notify("Move closer to set the door title.", "warning")
        return
    end

    title = string.sub(title, 1, 80)

    if useAdminSetter then
        net.Start("DHUD.SetDoorTitle")
            net.WriteEntity(ent)
            net.WriteString(title)
        net.SendToServer()
        return
    end

    SayCommand("/title " .. title)
end

Notify = function(text, kind)
    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add(text, kind or "hint", 4)
    elseif DarkRP and DarkRP.notify then
        DarkRP.notify(LocalPlayer(), 0, 4, text)
    else
        chat.AddText(Color(184, 116, 255), "[Door] ", color_white, text)
    end
end

local function RemovePanel(pnl)
    if IsValid(pnl) then
        pnl:SetVisible(false)
        pnl:Remove()
    end
end

local function Close()
    for i = #popupFrames, 1, -1 do
        RemovePanel(popupFrames[i])
    end

    popupFrames = {}

    local frame = activeFrame
    activeFrame = nil

    if IsValid(frame) then
        frame.TargetAlpha = 0
        frame.TargetSlide = 1
    end
end

local function TrackPopup(frame)
    popupFrames[#popupFrames + 1] = frame
    frame.OnRemove = function(self)
        for i = #popupFrames, 1, -1 do
            if popupFrames[i] == self then
                table.remove(popupFrames, i)
            end
        end
    end

    if IsValid(activeFrame) then
        frame:SetParent(activeFrame)
    end

    if DHUD.TrackPanel then DHUD.TrackPanel(frame) end
end

local function AddCloseButton(parent, callback)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetTextColor(Color(0, 0, 0, 0))
    btn:SetDrawBackground(false)
    if btn.SetDrawBorder then btn:SetDrawBorder(false) end
    btn:SetSize(24, 24)
    btn:SetPos(parent:GetWide() - 32, 8)
    btn.Paint = function(self, w, h)
        local alpha = parent.GetAlpha and parent:GetAlpha() or 255
        local bg = self:IsHovered() and Color(232, 84, 84, math.min(alpha, 220)) or ButtonBaseColor(math.min(alpha, 190))
        draw.RoundedBox(DubzLib.Radius("SM"), 0, 0, w, h, bg)
        DubzLib.Draw.Text("x", DubzLib.Font("Body"), w * 0.5, h * 0.5 - 1, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = callback or Close

    return btn
end

local function PaintShell(w, h, title, subtitle, alpha)
    local cfg = Cfg()
    local accent = Accent()
    local accentW = cfg.AccentWidth or 5
    local radius = DubzLib.Radius("MD")

    draw.RoundedBox(radius, 0, 0, w, h, WithAlpha(accent, alpha))
    DubzLib.Draw.Panel(accentW, -1, w - accentW + 1, h + 2, {
        Radius = "MD",
        Color = WithAlpha(DubzLib.Color("Secondary"), math.min(alpha, cfg.InnerAlpha or 255)),
        Border = WithAlpha(DubzLib.Color("BorderSoft"), alpha),
        Shadow = false
    })

    DubzLib.Draw.Text(DHUD.L and DHUD.L(title) or title, DubzLib.Font("Header"), accentW + 12, 10, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DubzLib.Draw.Text(DHUD.L and DHUD.L(subtitle) or subtitle, DubzLib.Font("Small"), accentW + 12, 35, WithAlpha(DubzLib.Color("Muted"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function AddButton(parent, text, icon, accent, callback)
    local cfg = Cfg()
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetTextColor(Color(0, 0, 0, 0))
    btn:SetDrawBackground(false)
    if btn.SetDrawBorder then btn:SetDrawBorder(false) end
    btn:SetTall(cfg.ButtonHeight or 32)
    btn:Dock(TOP)
    btn:DockMargin(cfg.Pad or 12, 0, cfg.Pad or 12, cfg.ButtonGap or 7)
    btn.Hover = 0

    btn.Paint = function(self, w, h)
        self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, HoverSpeed(cfg))
        local alpha = parent:GetAlpha()
        local base = ButtonBaseColor(alpha)

        draw.RoundedBox(DubzLib.Radius("SM"), 0, 0, w, h, base)
        if self.Hover > 0.01 then
            draw.RoundedBox(DubzLib.Radius("SM"), 0, 0, w, h, WithAlpha(accent, 28 + self.Hover * 46))
        end
        draw.RoundedBox(0, 0, h - 1, w, 1, WithAlpha(accent, 110 + self.Hover * 80))

        if DHUD.Status and DHUD.Status.DrawIcon then
            DHUD.Status.DrawIcon(icon or "misc/check", 9, h * 0.5 - 8, 16, WithAlpha(accent, alpha))
        end

        DubzLib.Draw.Text(DHUD.L and DHUD.L(text) or text, DubzLib.Font("Body"), 34, h * 0.5, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    btn.DoClick = callback
    return btn
end

local function StyleScroll(scroll)
    local bar = scroll:GetVBar()
    if not IsValid(bar) then return end

    bar:SetWide(6)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, w - 2, h, Color(0, 0, 0, 70))
    end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, w - 2, h, Color(184, 116, 255, 150))
    end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
end

local function DoorGroups()
    local groups = {}

    if DarkRP and DarkRP.getDoorGroups then
        for _, name in ipairs(DarkRP.getDoorGroups() or {}) do
            groups[#groups + 1] = tostring(name)
        end
    elseif RPExtraTeamDoors then
        for name in next, (RPExtraTeamDoors) do
            groups[#groups + 1] = tostring(name)
        end
    end

    table.sort(groups, function(a, b) return a:lower() < b:lower() end)
    return groups
end

local function DoorTeamSet(ent)
    return ent.getKeysDoorTeams and ent:getKeysDoorTeams() or {}
end

local function SortedTeams()
    local teams = {}

    for id, data in next, (RPExtraTeams or {}) do
        teams[#teams + 1] = {
            Id = id,
            Name = tostring(data.name or ("Job " .. tostring(id)))
        }
    end

    table.sort(teams, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return teams
end

local function DoorTeams(ent, wantedAdded)
    local current = DoorTeamSet(ent)
    local out = {}

    for _, teamData in ipairs(SortedTeams()) do
        local added = current and current[teamData.Id] == true
        if added == wantedAdded then
            out[#out + 1] = teamData
        end
    end

    return out
end

local function RunDoorGroupCommand(groupName)
    groupName = string.Trim(tostring(groupName or ""))

    if groupName == "" then
        SayCommand("/togglegroupownable")
    else
        SayCommand("/togglegroupownable " .. groupName)
    end
end

local function OpenChoicePopup(title, subtitle, options, emptyText, onSelect)
    if #options <= 0 then
        Notify(emptyText or "No options available.", "warning")
        return
    end

    local cfg = Cfg()
    local frame = vgui.Create("DFrame")
    frame:SetSize(340, math.min(118 + #options * ((cfg.ButtonHeight or 32) + 4), 430))
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    TrackPopup(frame)

    frame.Paint = function(_, w, h)
        PaintShell(w, h, title, subtitle or "Choose an option", 255)
    end

    AddCloseButton(frame, function()
        frame:Close()
    end)

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(0, 62)
    scroll:SetSize(frame:GetWide(), frame:GetTall() - 70)
    StyleScroll(scroll)

    for _, option in ipairs(options) do
        AddButton(scroll, option.Text, option.Icon, option.Accent or Accent(), function()
            onSelect(option)
            frame:Close()
        end)
    end
end

local function OpenTextPopup(title, onSubmit)
    local frame = vgui.Create("DFrame")
    frame:SetSize(300, 128)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    TrackPopup(frame)

    frame.Paint = function(_, w, h)
        PaintShell(w, h, title, "Enter a new value", 255)
    end

    AddCloseButton(frame, function()
        frame:Close()
    end)

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(17, 60)
    entry:SetSize(266, 26)
    entry:SetText("")

    local confirm = vgui.Create("DButton", frame)
    confirm:SetPos(17, 94)
    confirm:SetSize(266, 22)
    confirm:SetText("")
    confirm:SetTextColor(Color(0, 0, 0, 0))
    confirm:SetDrawBackground(false)
    if confirm.SetDrawBorder then confirm:SetDrawBorder(false) end
    confirm.Paint = function(self, w, h)
        draw.RoundedBox(DubzLib.Radius("SM"), 0, 0, w, h, ButtonBaseColor(255))
        draw.RoundedBox(DubzLib.Radius("SM"), 0, 0, w, h, WithAlpha(Accent(), self:IsHovered() and 76 or 42))
        DubzLib.Draw.Text(DHUD.L and DHUD.L("Confirm") or "Confirm", DubzLib.Font("Small"), w * 0.5, h * 0.5, Accent(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    confirm.DoClick = function()
        local value = string.Trim(entry:GetText() or "")
        if value == "" then
            Notify("Text cannot be empty.", "warning")
            return
        end

        onSubmit(value)
        frame:Close()
    end
end

local function OpenPlayerPopup(title, players, onSelect)
    if #players <= 0 then
        Notify("No nearby player options available.", "warning")
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(300, math.min(120 + #players * 34, 300))
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    TrackPopup(frame)

    frame.Paint = function(_, w, h)
        PaintShell(w, h, title, "Choose a player", 255)
    end

    AddCloseButton(frame, function()
        frame:Close()
    end)

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(0, 62)
    scroll:SetSize(frame:GetWide(), frame:GetTall() - 70)
    StyleScroll(scroll)

    for _, ply in ipairs(players) do
        AddButton(scroll, ply:Nick(), "players/person", Accent(), function()
            if IsValid(ply) then onSelect(ply) end
            frame:Close()
        end)
    end
end

local function Open(ent)
    local cfg = Cfg()
    if cfg.Enabled == false then return end
    if not IsDoor(ent) then return end

    Close()

    local ply = LocalPlayer()
    local blocked = IsNonOwnable(ent)
    local ownerName = OwnerName(ent)
    local isOwner = IsOwnedByLocal(ent)
    local isAdmin = IsValid(ply) and ply:IsAdmin()
    local isOwned = IsOwned(ent)
    local hasGroupOrTeams = DoorGroup(ent) ~= nil or HasDoorTeams(ent)
    local adminCanTitle = isAdmin and (blocked or hasGroupOrTeams)
    local accent = Accent()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local actions = {}

    if not blocked and not isOwned and not hasGroupOrTeams then
        actions[#actions + 1] = {
            Text = "Buy Door",
            Icon = "economy/house",
            Accent = colors.Cash or accent,
            Click = function()
                SayCommand("/toggleown")
                Close()
            end
        }
    end

    if isOwner then
        actions[#actions + 1] = {
            Text = "Sell Door",
            Icon = "economy/sell",
            Accent = colors.Warning or accent,
            Click = function()
                SayCommand("/toggleown")
                Close()
            end
        }
    end

    if isOwner or adminCanTitle then
        actions[#actions + 1] = {
            Text = "Set Title",
            Icon = "communication/forum",
            Accent = accent,
            Click = function()
                local titleDist = isAdmin and 40000 or 12100
                if LocalPlayer():GetPos():DistToSqr(ent:GetPos()) >= titleDist then
                    Notify("Move closer to set the door title.", "warning")
                    return
                end

                Close()
                OpenTextPopup("Set Door Title", function(value)
                    SetDoorTitle(ent, value, isAdmin)
                end)
            end
        }
    end

    if isOwner then
        actions[#actions + 1] = {
            Text = "Add Co-owner",
            Icon = "players/groups",
            Accent = colors.Clock or accent,
            Click = function()
                local options = {}

                for _, target in ipairs(PotentialOwners(ent)) do
                    options[#options + 1] = {
                        Text = target:Nick(),
                        Icon = "players/person",
                        Accent = colors.Clock or accent,
                        Value = target
                    }
                end

                Close()
                if #options <= 0 then
                    Notify("No online players are available to add.", "warning")
                    return
                end

                OpenChoicePopup("Add Co-owner", "Players online and not added to this door", options, "No online players are available.", function(option)
                    if IsValid(option.Value) then
                        SayCommand("/addowner " .. option.Value:Nick())
                    end
                end)
            end
        }

        actions[#actions + 1] = {
            Text = "Remove Co-owner",
            Icon = "actions/delete",
            Accent = colors.Warning or accent,
            Click = function()
                local options = {}

                for _, target in ipairs(CoOwners(ent)) do
                    options[#options + 1] = {
                        Text = target:Nick(),
                        Icon = "players/person",
                        Accent = colors.Warning or accent,
                        Value = target
                    }
                end

                Close()
                OpenChoicePopup("Remove Co-owner", "Players added to this door", options, "No co-owners are added to this door.", function(option)
                    if IsValid(option.Value) then
                        SayCommand("/removeowner " .. option.Value:Nick())
                    end
                end)
            end
        }
    end

    if isAdmin then
        actions[#actions + 1] = {
            Text = "Set Door Group",
            Icon = "misc/door",
            Accent = colors.Clock or accent,
            Click = function()
                local options = {
                    {
                        Text = "Clear Door Group",
                        Icon = "actions/cancel",
                        Accent = colors.Warning or accent,
                        Value = ""
                    }
                }

                for _, groupName in ipairs(DoorGroups()) do
                    options[#options + 1] = {
                        Text = groupName,
                        Icon = "darkrp/apartment",
                        Accent = accent,
                        Value = groupName
                    }
                end

                Close()
                OpenChoicePopup("Set Door Group", "Choose a door group", options, "No door groups are configured.", function(option)
                    RunDoorGroupCommand(option.Value)
                end)
            end
        }

        actions[#actions + 1] = {
            Text = "Add Job Access",
            Icon = "actions/add",
            Accent = colors.Cash or accent,
            Click = function()
                local options = {}

                for _, teamData in ipairs(DoorTeams(ent, false)) do
                    options[#options + 1] = {
                        Text = teamData.Name,
                        Icon = "darkrp/work",
                        Accent = colors.Cash or accent,
                        Value = teamData.Id
                    }
                end

                Close()
                OpenChoicePopup("Add Job Access", "Jobs not added to this door", options, "Every job is already added to this door.", function(option)
                    SayCommand("/toggleteamownable " .. tostring(option.Value))
                end)
            end
        }

        actions[#actions + 1] = {
            Text = "Remove Job Access",
            Icon = "actions/delete",
            Accent = colors.Warning or accent,
            Click = function()
                local options = {}

                for _, teamData in ipairs(DoorTeams(ent, true)) do
                    options[#options + 1] = {
                        Text = teamData.Name,
                        Icon = "darkrp/work",
                        Accent = colors.Warning or accent,
                        Value = teamData.Id
                    }
                end

                Close()
                OpenChoicePopup("Remove Job Access", "Jobs currently added to this door", options, "No jobs are added to this door.", function(option)
                    SayCommand("/toggleteamownable " .. tostring(option.Value))
                end)
            end
        }

        actions[#actions + 1] = {
            Text = blocked and "Enable Ownership" or "Disable Ownership",
            Icon = "admin/security",
            Accent = colors.Wanted or accent,
            Click = function()
                SayCommand("/toggleownable")
                Close()
            end
        }
    end

    if #actions <= 0 then
        Notify("No door options available.", "warning")
        return
    end

    local w = cfg.Width or 286
    local h = 66 + #actions * ((cfg.ButtonHeight or 32) + (cfg.ButtonGap or 7)) + (cfg.Pad or 12)
    local frame = vgui.Create("DFrame")
    activeFrame = frame
    if DHUD.TrackPanel then DHUD.TrackPanel(frame) end

    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame:SetAlpha(0)
    frame.Progress = 0
    frame.TargetAlpha = 255
    frame.TargetSlide = 0
    frame.OnRemove = function(self)
        if activeFrame == self then
            activeFrame = nil
        end
    end

    local baseX, baseY = frame:GetPos()
    frame.Think = function(self)
        self.Progress = EaseValue(self.Progress, self.TargetAlpha == 0 and 0 or 1, AnimSpeed(cfg))
        local alpha = math.floor(255 * self.Progress)
        self:SetAlpha(alpha)
        self:SetPos(baseX + (1 - self.Progress) * AnimSlide(cfg), baseY)
        if self.TargetAlpha == 0 and self.Progress <= 0.02 then
            RemovePanel(self)
        end
    end

    frame.Paint = function(self, pw, ph)
        PaintShell(pw, ph, "Door Options", ownerName and ("Owner: " .. ownerName) or "Unowned", self:GetAlpha())
    end

    AddCloseButton(frame, Close)

    local container = vgui.Create("DPanel", frame)
    container:SetPaintBackground(false)
    container:SetPos(0, 60)
    container:SetSize(w, h - 60)
    container.GetAlpha = function() return frame:GetAlpha() end

    for _, action in ipairs(actions) do
        AddButton(container, action.Text, action.Icon, action.Accent, action.Click)
    end
end

local function TraceDoor()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local dist = 220
    local startPos = ply:EyePos()
    local tr = util.TraceLine({
        start = startPos,
        endpos = startPos + ply:EyeAngles():Forward() * dist,
        filter = ply,
        mask = MASK_SOLID
    })

    if not tr or not tr.Hit then return nil end
    if not IsDoor(tr.Entity) then return nil end
    if startPos:DistToSqr(tr.HitPos or tr.Entity:GetPos()) > dist * dist then return nil end

    return tr.Entity
end

local function TryOpen()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.DoorOptions == false or Cfg().Enabled == false then return false end

    if IsValid(activeFrame) then
        Close()
        return true
    end

    local ent = TraceDoor()
    if not IsValid(ent) then return false end

    Open(ent)
    return true
end

local function HoldingKeys()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    local weapon = ply:GetActiveWeapon()
    return IsValid(weapon) and string.lower(tostring(weapon:GetClass() or "")) == "keys"
end

hook.Add("ShowTeam", "DHUD.OpenDoorOptions", function()
    if TryOpen() then return true end
end)

hook.Add("PlayerBindPress", "DHUD.OpenDoorOptionsReloadBind", function(_, bind, pressed)
    if not pressed then return end
    bind = string.lower(tostring(bind or ""))

    if bind == "+reload" and HoldingKeys() and TryOpen() then
        return true
    end
end)

hook.Add("KeyPress", "DHUD.OpenDoorOptionsReloadKey", function(ply, key)
    if ply ~= LocalPlayer() or key ~= IN_RELOAD then return end
    if not HoldingKeys() then return end
    TryOpen()
end)

hook.Add("Think", "DHUD.CloseDoorOptionsEscape", function()
    local down = input.IsKeyDown(KEY_ESCAPE)
    if down and not DHUD.DoorOptions.EscapeWasDown and IsValid(activeFrame) then
        Close()
    end

    DHUD.DoorOptions.EscapeWasDown = down
end)

hook.Add("PlayerDeath", "DHUD.CloseDoorOptionsOnDeath", function(ply)
    if ply == LocalPlayer() then Close() end
end)

hook.Add("OnContextMenuOpen", "DHUD.CloseDoorOptionsOnContext", Close)
