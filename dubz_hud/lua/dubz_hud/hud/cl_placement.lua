local DHUD = DHUD
DHUD.Placement = DHUD.Placement or {}

local frame
local groups = {}
local trashPanel

local elementDefs = {
    {ID = "notifications", Label = "Notifications", System = "Notifications", Icon = "communication/notifications"},
    {ID = "death", Label = "Death Feed", System = "DeathNotice", Icon = "players/skull"},
    {ID = "voice", Label = "Voice HUD", System = "Voice", Icon = "communication/chat"},
    {ID = "vote", Label = "Vote UI", System = "Vote", Icon = "communication/forum"},
    {ID = "laws", Label = "Laws", System = "Laws", Icon = "admin/gavel"},
    {ID = "status", Label = "Wanted / Lockdown", System = "Status", Icon = "admin/warning"},
    {ID = "agenda", Label = "Agenda", System = "Status", Icon = "darkrp/agenda"},
    {ID = "card", Label = "Card HUD", System = "HUD", Icon = "players/person"},
    {ID = "bar", Label = "Bar HUD", System = "HUD", Icon = "navigation/menu"},
    {ID = "ammo", Label = "Ammo HUD", System = "Ammo", Icon = "admin/security"},
    {ID = "connection", Label = "Lost Connection", System = "Connection", Icon = "communication/no_connection"},
    {ID = "deathscreen", Label = "Death Screen", System = "DeathScreen", Icon = "players/skull"},
    {ID = "weaponselector", Label = "Weapon Selector", System = "WeaponSelector", Icon = "admin/security"},
    {ID = "vehicle", Label = "Vehicle HUD", System = "Vehicle", Icon = "misc/directions_run"}
}

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha)
end

local function Primary()
    return DHUD.Config and DHUD.Config.Colors and (DHUD.Config.Colors.Agenda or DHUD.Config.Colors.Clock) or Color(184, 116, 255)
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then return DubzLib.Radius(name) end
    return name == "MD" and 8 or 5
end

local function Font(name)
    if DubzLib and DubzLib.Font then return DubzLib.Font(name) end
    return "DermaDefault"
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

local function SaveConfig()
    if not net then return end

    net.Start("DHUD.Config.Save")
    net.WriteString(util.TableToJSON(DHUD.Config or {}) or "{}")
    net.SendToServer()
end

local function StyleButton(btn)
    btn:SetText("")
    btn:SetDrawBackground(false)
    btn:SetTextColor(Color(0, 0, 0, 0))
end

local function SnapValue(value, candidates)
    local snapDist = 9
    for _, candidate in ipairs(candidates or {}) do
        if math.abs(value - candidate) <= snapDist then
            return candidate
        end
    end
    return value
end

local function EdgeCandidates(ignore)
    local lefts, rights = {0, 10, 20, 24, 32, ScrW() * 0.5}, {ScrW(), ScrW() - 10, ScrW() - 20, ScrW() - 24, ScrW() - 32, ScrW() * 0.5}
    for _, pnl in ipairs(groups) do
        if IsValid(pnl) and pnl ~= ignore then
            local x, _ = pnl:GetPos()
            local w = pnl:GetWide()
            lefts[#lefts + 1] = x
            rights[#rights + 1] = ScrW() - x - w
        end
    end
    return lefts, rights
end

local function VerticalCandidates(ignore)
    local tops, bottoms = {0, 10, 20, 24, 32, ScrH() * 0.5}, {ScrH(), ScrH() - 10, ScrH() - 20, ScrH() - 24, ScrH() - 32, ScrH() * 0.5}
    for _, pnl in ipairs(groups) do
        if IsValid(pnl) and pnl ~= ignore then
            local _, y = pnl:GetPos()
            local h = pnl:GetTall()
            tops[#tops + 1] = y
            bottoms[#bottoms + 1] = ScrH() - y - h
        end
    end
    return tops, bottoms
end

local function StorePosition(id, x, y, w)
    DHUD.Config = DHUD.Config or {}

    if id == "notifications" then
        DHUD.Config.Notifications = DHUD.Config.Notifications or {}
        DHUD.Config.Notifications.RightPadding = math.max(0, math.Round(ScrW() - x - w))
        DHUD.Config.Notifications.BottomOffset = math.max(0, math.Round(ScrH() - y))
    elseif id == "death" then
        DHUD.Config.DeathNotice = DHUD.Config.DeathNotice or {}
        DHUD.Config.DeathNotice.Right = math.max(0, math.Round(ScrW() - x - w))
        DHUD.Config.DeathNotice.Top = math.max(0, math.Round(y))
    elseif id == "voice" then
        DHUD.Config.Voice = DHUD.Config.Voice or {}
        DHUD.Config.Voice.Right = math.max(0, math.Round(ScrW() - x - w))
        DHUD.Config.Voice.Top = math.max(0, math.Round(y))
    elseif id == "vote" then
        DHUD.Config.Vote = DHUD.Config.Vote or {}
        DHUD.Config.Vote.LeftPadding = math.max(0, math.Round(x))
        DHUD.Config.Vote.Y = math.max(0, math.Round(y))
    elseif id == "laws" then
        DHUD.Config.Laws = DHUD.Config.Laws or {}
        local rightPad = math.max(0, math.Round(ScrW() - x - w))
        local leftPad = math.max(0, math.Round(x))
        DHUD.Config.Laws.TopRight = rightPad <= leftPad
        DHUD.Config.Laws.X = DHUD.Config.Laws.TopRight and rightPad or leftPad
        DHUD.Config.Laws.Y = math.max(0, math.Round(y))
    elseif id == "status" then
        DHUD.Config.Status = DHUD.Config.Status or {}
        DHUD.Config.Status.AnnouncementY = math.max(0, math.Round(y))
    elseif id == "agenda" then
        DHUD.Config.Status = DHUD.Config.Status or {}
        DHUD.Config.Status.AgendaCard = DHUD.Config.Status.AgendaCard or {}
        DHUD.Config.Status.AgendaCard.X = math.max(0, math.Round(x))
        DHUD.Config.Status.AgendaCard.Y = math.max(0, math.Round(y))
    elseif id == "bar" then
        DHUD.Config.Bar = DHUD.Config.Bar or {}
        DHUD.Config.Bar.Layout = DHUD.Config.Bar.Layout or {}
        local layout = DHUD.Config.Bar.Layout
        layout.Edge = y > ScrH() * 0.5 and "bottom" or "top"
        layout.StartY = layout.Edge == "bottom" and math.max(0, math.Round(y - (ScrH() - (layout.Height or 42)))) or math.max(0, math.Round(y))
    elseif id == "card" then
        DHUD.Config.Card = DHUD.Config.Card or {}
        DHUD.Config.Card.X = math.max(0, math.Round(x))
        DHUD.Config.Card.BottomY = math.max(0, math.Round(ScrH() - y - 210))
    elseif id == "ammo" then
        DHUD.Config.Ammo = DHUD.Config.Ammo or {}
        DHUD.Config.Ammo.RightPadding = math.max(0, math.Round(ScrW() - x - w))
        DHUD.Config.Ammo.BottomPadding = math.max(0, math.Round(ScrH() - y - 52))
    elseif id == "connection" then
        DHUD.Config.Connection = DHUD.Config.Connection or {}
        DHUD.Config.Connection.XPercent = math.Clamp((x + w * 0.5) / ScrW(), 0.05, 0.95)
        DHUD.Config.Connection.YPercent = math.Clamp((y + 99) / ScrH(), 0.05, 0.95)
    elseif id == "deathscreen" then
        DHUD.Config.DeathScreen = DHUD.Config.DeathScreen or {}
        DHUD.Config.DeathScreen.XPercent = math.Clamp((x + w * 0.5) / ScrW(), 0.05, 0.95)
        DHUD.Config.DeathScreen.YPercent = math.Clamp((y + 50) / ScrH(), 0.05, 0.95)
    elseif id == "weaponselector" then
        DHUD.Config.WeaponSelector = DHUD.Config.WeaponSelector or {}
        DHUD.Config.WeaponSelector.TopPadding = math.max(0, math.Round(y))
        DHUD.Config.WeaponSelector.CenterOffsetX = math.Round((x + w * 0.5) - ScrW() * 0.5)
    elseif id == "vehicle" then
        DHUD.Config.Vehicle = DHUD.Config.Vehicle or {}
        DHUD.Config.Vehicle.RightPadding = math.max(0, math.Round(ScrW() - x - w))
        DHUD.Config.Vehicle.BottomPadding = math.max(0, math.Round(ScrH() - y - (DHUD.Config.Vehicle.Height or 132)))
    end
end

local function SystemFor(id)
    for _, def in ipairs(elementDefs) do
        if def.ID == id then return def.System end
    end
end

local function DisableElement(id)
    local system = SystemFor(id)
    if not system then return end
    DHUD.Config.Systems = DHUD.Config.Systems or {}
    DHUD.Config.Systems[system] = false
end

local function EnableElement(id)
    local system = SystemFor(id)
    if not system then return end
    DHUD.Config.Systems = DHUD.Config.Systems or {}
    DHUD.Config.Systems[system] = true
end

local function TrashContains(x, y)
    if not IsValid(trashPanel) then return false end
    local tx, ty = trashPanel:LocalToScreen(0, 0)
    return x >= tx and y >= ty and x <= tx + trashPanel:GetWide() and y <= ty + trashPanel:GetTall()
end

local function ResetDefaults()
    DHUD.Config = DHUD.Config or {}
    DHUD.Config.Notifications = DHUD.Config.Notifications or {}
    DHUD.Config.DeathNotice = DHUD.Config.DeathNotice or {}
    DHUD.Config.Voice = DHUD.Config.Voice or {}
    DHUD.Config.Vote = DHUD.Config.Vote or {}
    DHUD.Config.Laws = DHUD.Config.Laws or {}
    DHUD.Config.Bar = DHUD.Config.Bar or {}
    DHUD.Config.Bar.Layout = DHUD.Config.Bar.Layout or {}
    DHUD.Config.Card = DHUD.Config.Card or {}
    DHUD.Config.Ammo = DHUD.Config.Ammo or {}
    DHUD.Config.Status = DHUD.Config.Status or {}
    DHUD.Config.Status.AgendaCard = DHUD.Config.Status.AgendaCard or {}
    DHUD.Config.Connection = DHUD.Config.Connection or {}
    DHUD.Config.DeathScreen = DHUD.Config.DeathScreen or {}
    DHUD.Config.WeaponSelector = DHUD.Config.WeaponSelector or {}
    DHUD.Config.Vehicle = DHUD.Config.Vehicle or {}
    DHUD.Config.Systems = DHUD.Config.Systems or {}

    DHUD.Config.Notifications.RightPadding = 24
    DHUD.Config.Notifications.BottomOffset = 245
    DHUD.Config.DeathNotice.Right = 24
    DHUD.Config.DeathNotice.Top = 170
    DHUD.Config.Voice.Right = 24
    DHUD.Config.Voice.Top = math.floor(ScrH() * 0.5)
    DHUD.Config.Vote.LeftPadding = 24
    DHUD.Config.Vote.Y = 132
    DHUD.Config.Laws.X = 20
    DHUD.Config.Laws.Y = 54
    DHUD.Config.Laws.TopRight = true
    DHUD.Config.Bar.Layout.Edge = "top"
    DHUD.Config.Bar.Layout.StartY = 6
    DHUD.Config.Card.X = 20
    DHUD.Config.Card.BottomY = 30
    DHUD.Config.Ammo.RightPadding = 24
    DHUD.Config.Ammo.BottomPadding = 28
    DHUD.Config.Status.AnnouncementY = 82
    DHUD.Config.Status.AgendaCard.X = 20
    DHUD.Config.Status.AgendaCard.Y = 54
    DHUD.Config.Connection.XPercent = 0.5
    DHUD.Config.Connection.YPercent = 0.5
    DHUD.Config.DeathScreen.XPercent = 0.5
    DHUD.Config.DeathScreen.YPercent = 0.44
    DHUD.Config.WeaponSelector.TopPadding = 44
    DHUD.Config.WeaponSelector.CenterOffsetX = 0
    DHUD.Config.Vehicle.RightPadding = 24
    DHUD.Config.Vehicle.BottomPadding = 92
    for _, def in ipairs(elementDefs) do
        if def.System then DHUD.Config.Systems[def.System] = true end
    end
end

local function PaintCard(title, subtitle, icon, accent)
    return function(self, w, h)
        local alpha = self:GetAlpha()
        draw.RoundedBox(Radius("MD"), 1, 3, w - 1, h - 2, Color(0, 0, 0, 48 * (alpha / 255)))
        draw.RoundedBox(Radius("MD"), 0, 0, w, h, WithAlpha(accent, alpha))
        draw.RoundedBox(Radius("MD"), 5, -1, w - 4, h + 2, Color(27, 28, 33, alpha))
        draw.RoundedBox(Radius("SM"), 14, h * 0.5 - 13, 26, 26, WithAlpha(accent, 42 * (alpha / 255)))
        DrawIcon(icon, 19, h * 0.5 - 8, 16, WithAlpha(accent, alpha))
        Text(title, Font("Body"), 52, h * 0.5 - 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text(subtitle, Font("Small"), 52, h * 0.5 + 4, Color(170, 171, 178), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

local function AddStackCard(parent, y, h, title, subtitle, icon, accent)
    local card = vgui.Create("DPanel", parent)
    card:SetPos(0, y)
    card:SetSize(parent:GetWide(), h)
    card:SetMouseInputEnabled(false)
    card.Paint = PaintCard(title, subtitle, icon, accent)
    return card
end

local function CreateGroup(parent, id, x, y, w, rows, rowH, gap, accent)
    local group = vgui.Create("DPanel", parent)
    group:SetPos(x, y)
    group:SetSize(w, (#rows * rowH) + (math.max(#rows - 1, 0) * gap))
    group:SetPaintBackground(false)
    group:SetMouseInputEnabled(true)
    group.ID = id
    group.Accent = accent
    groups[#groups + 1] = group

    local cy = 0
    for _, row in ipairs(rows) do
        AddStackCard(group, cy, rowH, row[1], row[2], row[3], accent)
        cy = cy + rowH + gap
    end

    group.OnMousePressed = function(self)
        local mx, my = gui.MousePos()
        local px, py = self:GetPos()
        self.Dragging = {mx - px, my - py}
        self:MouseCapture(true)
    end

    group.OnMouseReleased = function(self)
        self.Dragging = nil
        self:MouseCapture(false)
        local px, py = self:GetPos()
        local mx, my = gui.MousePos()
        if TrashContains(mx, my) then
            DisableElement(self.ID)
            SaveConfig()
            self:Remove()
            return
        end
        StorePosition(self.ID, px, py, self:GetWide())
    end

    group.Think = function(self)
        if not self.Dragging then return end

        local mx, my = gui.MousePos()
        local nx = math.Clamp(mx - self.Dragging[1], 0, ScrW() - self:GetWide())
        local ny = math.Clamp(my - self.Dragging[2], 0, ScrH() - self:GetTall())
        local lefts, rights = EdgeCandidates(self)
        local rightPad = SnapValue(ScrW() - nx - self:GetWide(), rights)
        nx = ScrW() - self:GetWide() - rightPad
        nx = SnapValue(nx, lefts)
        local centerX = SnapValue(nx + self:GetWide() * 0.5, {ScrW() * 0.5})
        if centerX == ScrW() * 0.5 then nx = centerX - self:GetWide() * 0.5 end

        local tops, bottoms = VerticalCandidates(self)
        local bottomPad = SnapValue(ScrH() - ny - self:GetTall(), bottoms)
        ny = ScrH() - self:GetTall() - bottomPad
        ny = SnapValue(ny, tops)
        local centerY = SnapValue(ny + self:GetTall() * 0.5, {ScrH() * 0.5})
        if centerY == ScrH() * 0.5 then ny = centerY - self:GetTall() * 0.5 end

        self:SetPos(math.Clamp(nx, 0, ScrW() - self:GetWide()), math.Clamp(ny, 0, ScrH() - self:GetTall()))
    end

    return group
end

function DHUD.Placement.Open()
    if DHUD.ConfigMenu and DHUD.ConfigMenu.HideInstant then
        DHUD.ConfigMenu.HideInstant()
    end

    if IsValid(frame) then frame:Remove() end
    groups = {}

    frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame:SetAlpha(255)
    if DHUD.TrackPanel then DHUD.TrackPanel(frame) end

    frame.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 96))
        surface.SetDrawColor(255, 255, 255, 28)
        surface.DrawLine(w * 0.5, 0, w * 0.5, h)
        surface.DrawLine(0, h * 0.5, w, h * 0.5)
        Text("Placement Mode", Font("Header"), 24, 22, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        Text("Drag a stack to move it. Drop it on Trash to hide it, or restore it from the element list.", Font("Small"), 24, 52, Color(190, 190, 196), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local notify = DHUD.Config and DHUD.Config.Notifications or {}
    local death = DHUD.Config and DHUD.Config.DeathNotice or {}
    local voice = DHUD.Config and DHUD.Config.Voice or {}
    local vote = DHUD.Config and DHUD.Config.Vote or {}
    local laws = DHUD.Config and DHUD.Config.Laws or {}
    local bar = DHUD.Config and DHUD.Config.Bar or {}
    local barLayout = bar.Layout or {}
    local card = DHUD.Config and DHUD.Config.Card or {}
    local ammo = DHUD.Config and DHUD.Config.Ammo or {}
    local status = DHUD.Config and DHUD.Config.Status or {}
    local agenda = status.AgendaCard or {}
    local connection = DHUD.Config and DHUD.Config.Connection or {}
    local deathScreen = DHUD.Config and DHUD.Config.DeathScreen or {}
    local vehicle = DHUD.Config and DHUD.Config.Vehicle or {}
    local weaponSelector = DHUD.Config and DHUD.Config.WeaponSelector or {}
    local systems = DHUD.Config and DHUD.Config.Systems or {}

    local notifyW, notifyH, notifyGap = 320, notify.Height or 44, notify.Gap or 8
    local deathW, deathH, deathGap = death.Width or 330, death.Height or 34, death.Gap or 7
    local voiceW, voiceH, voiceGap = voice.Width or 318, voice.Height or 46, voice.Gap or 7
    local voteW, voteH, voteGap = vote.Width or 292, vote.Height or 78, vote.Gap or 10
    local lawW = laws.Width or 360

    local notifyRows = {}
    for i = 1, notify.MaxVisible or 4 do
        notifyRows[#notifyRows + 1] = {"Notification " .. i, i == 1 and "Example server popup" or "Queued notification", "misc/lightbulb"}
    end
    local deathRows = {}
    for i = 1, death.MaxVisible or 3 do
        deathRows[#deathRows + 1] = {"Player" .. i .. " killed Player" .. (i + 1), "Death feed queue item", "players/skull"}
    end
    local voiceRows = {}
    for i = 1, voice.MaxVisible or 4 do
        voiceRows[#voiceRows + 1] = {"Talking Player " .. i, "Citizen", "communication/chat"}
    end
    local voteRows = {}
    for i = 1, vote.MaxVisible or 3 do
        voteRows[#voteRows + 1] = {"Vote Popup " .. i, "Yes / No action panel", "communication/forum"}
    end

    if systems.Notifications ~= false then CreateGroup(frame, "notifications", ScrW() - notifyW - (notify.RightPadding or 24), ScrH() - (notify.BottomOffset or 245), notifyW, notifyRows, notifyH, notifyGap, Primary()) end
    if systems.DeathNotice ~= false then CreateGroup(frame, "death", ScrW() - deathW - (death.Right or 24), death.Top or 170, deathW, deathRows, deathH, deathGap, Color(232, 84, 84)) end
    if systems.Voice ~= false then CreateGroup(frame, "voice", ScrW() - voiceW - (voice.Right or 24), voice.Top or math.floor(ScrH() * 0.5), voiceW, voiceRows, voiceH, voiceGap, Color(91, 159, 232)) end
    if systems.Vote ~= false then CreateGroup(frame, "vote", vote.LeftPadding or 24, vote.Y or 132, voteW, voteRows, voteH, voteGap, Color(221, 177, 74)) end
    local lawsX = laws.TopRight ~= false and (ScrW() - lawW - (laws.X or 20)) or (laws.X or 20)
    if systems.Laws ~= false then CreateGroup(frame, "laws", lawsX, laws.Y or 54, lawW, {{"Laws of the Land", "Open/collapsed laws anchor", "admin/gavel"}}, 64, 0, Color(221, 177, 74)) end
    if systems.Status ~= false then CreateGroup(frame, "status", math.floor(ScrW() * 0.5) - 170, status.AnnouncementY or 82, 340, {
        {"Wanted", "Status announcement line", "admin/warning"},
        {"Arrested", "Status announcement line", "darkrp/local_police"},
        {"Lockdown", "Status announcement line", "admin/gavel"}
    }, 30, 6, Color(232, 84, 84)) end
    if systems.Status ~= false then CreateGroup(frame, "agenda", agenda.X or 20, agenda.Y or 54, agenda.Width or 360, {{"Agenda", "DarkRP agenda panel anchor", "communication/forum"}}, agenda.MinHeight or 64, 0, Primary()) end
    if string.lower(tostring(DHUD.Config and DHUD.Config.HUDStyle or "bar")) == "card" then
        local cardH = math.max(card.BaseHeight or 92, 210)
        if systems.HUD ~= false then CreateGroup(frame, "card", card.X or 20, ScrH() - cardH - (card.BottomY or 30), card.Width or 324, {{"Card HUD", "Drag the player card HUD anchor", "players/person"}}, cardH, 0, Primary()) end
    else
        local barY = string.lower(tostring(barLayout.Edge or "top")) == "bottom" and (ScrH() - (barLayout.Height or 42) + (barLayout.StartY or 0)) or (barLayout.StartY or 6)
        if systems.HUD ~= false then CreateGroup(frame, "bar", 24, barY, math.min(560, ScrW() - 48), {{"Bar HUD Track", "Drag to top or bottom edge", "navigation/menu"}}, barLayout.Height or 42, 0, Primary()) end
    end
    if systems.Ammo ~= false then CreateGroup(frame, "ammo", ScrW() - (ammo.Width or 178) - (ammo.RightPadding or 24), ScrH() - (ammo.Height or 52) - (ammo.BottomPadding or 28), ammo.Width or 178, {{"Ammo HUD", "Drag the ammo panel anchor", "admin/security"}}, ammo.Height or 52, 0, Color(221, 177, 74)) end
    if systems.Connection ~= false then CreateGroup(frame, "connection", ScrW() * (connection.XPercent or 0.5) - 210, ScrH() * (connection.YPercent or 0.5) - 99, connection.WindowWidth or 420, {{"Connection Interrupted", "Lost connection screen anchor", "communication/no_connection"}}, 72, 0, Color(238, 146, 80)) end
    if systems.DeathScreen ~= false then CreateGroup(frame, "deathscreen", ScrW() * (deathScreen.XPercent or 0.5) - 190, ScrH() * (deathScreen.YPercent or 0.44) - 50, 380, {{"You Died", "Death screen text anchor", "players/skull"}}, 72, 0, Color(232, 84, 84)) end
    if systems.WeaponSelector ~= false then CreateGroup(frame, "weaponselector", math.floor(ScrW() * 0.5 - 210 + (weaponSelector.CenterOffsetX or 0)), weaponSelector.TopPadding or 44, 420, {{"Weapon Selector", "Top default-style selector anchor", "admin/security"}}, 64, 0, Primary()) end
    if systems.Vehicle ~= false then CreateGroup(frame, "vehicle", ScrW() - (vehicle.Width or 320) - (vehicle.RightPadding or 24), ScrH() - (vehicle.Height or 132) - (vehicle.BottomPadding or 92), vehicle.Width or 320, {{"Vehicle HUD", "Speedometer anchor", "misc/directions_run"}}, vehicle.Height or 132, 0, Primary()) end

    local palette = vgui.Create("DPanel", frame)
    palette:SetPos(24, 86)
    palette:SetSize(210, math.min(520, ScrH() - 190))
    palette.Paint = function(_, w, h)
        draw.RoundedBox(Radius("MD"), 0, 0, w, h, Color(20, 20, 24, 220))
        Text("Elements", Font("Header"), 14, 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    local py = 46
    for _, def in ipairs(elementDefs) do
        local btn = vgui.Create("DButton", palette)
        StyleButton(btn)
        btn:SetPos(10, py)
        btn:SetSize(190, 28)
        btn.Paint = function(self, w, h)
            local enabled = systems[def.System] ~= false
            draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(enabled and Primary() or Color(232, 84, 84), self:IsHovered() and 76 or 34))
            DrawIcon(def.Icon, 8, 6, 16, color_white)
            Text(def.Label, Font("Small"), 30, h * 0.5 - 1, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            EnableElement(def.ID)
            SaveConfig()
            if IsValid(frame) then frame:Remove() end
            DHUD.Placement.Open()
        end
        py = py + 32
    end

    trashPanel = vgui.Create("DPanel", frame)
    trashPanel:SetPos(24, ScrH() - 84)
    trashPanel:SetSize(210, 52)
    trashPanel.Paint = function(_, w, h)
        draw.RoundedBox(Radius("MD"), 0, 0, w, h, Color(232, 84, 84, 72))
        DrawIcon("actions/delete", 16, 16, 20, Color(255, 210, 210))
        Text("Trash / Hide Element", Font("Body"), 48, h * 0.5 - 1, Color(255, 230, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local save = vgui.Create("DButton", frame)
    StyleButton(save)
    save:SetPos(ScrW() - 264, 24)
    save:SetSize(112, 32)
    save.Paint = function(self, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Primary(), self:IsHovered() and 96 or 62))
        Text("Save", Font("Small"), w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    save.DoClick = SaveConfig

    local reset = vgui.Create("DButton", frame)
    StyleButton(reset)
    reset:SetPos(ScrW() - 388, 24)
    reset:SetSize(112, 32)
    reset.Paint = function(self, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Color(238, 146, 80), self:IsHovered() and 96 or 54))
        Text("Reset", Font("Small"), w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    reset.DoClick = function()
        ResetDefaults()
        if IsValid(frame) then
            frame:Remove()
        end
        DHUD.Placement.Open()
    end

    local close = vgui.Create("DButton", frame)
    StyleButton(close)
    close:SetPos(ScrW() - 140, 24)
    close:SetSize(112, 32)
    close.Paint = function(self, w, h)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, WithAlpha(Color(232, 84, 84), self:IsHovered() and 96 or 48))
        Text("Close", Font("Small"), w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function()
        if IsValid(frame) then frame:Remove() end
    end
end
