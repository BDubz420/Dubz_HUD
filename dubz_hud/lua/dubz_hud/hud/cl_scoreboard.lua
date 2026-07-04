local DHUD = DHUD
DHUD.Scoreboard = DHUD.Scoreboard or {}

local frame
local currentView = "players"
local expandedPlayers = {}
local headerIconURL
local headerIconMaterial
local headerIconLoading = false
local playerActionStates = {}
local playerRep = {}
local searchText = ""
local remoteImageMaterials = {}
local remoteImageLoading = {}
local serverScoreConfig
local previewScoreConfig
local scoreboardDataRequested = false
local RebuildCurrentView
local openingPreview = false
local searchFocusedUntil = 0
local sortKey = "name"
local sortAscending = true
local playtimeBySteam64 = {}
local persistentLeaderboardData = {}
local settingsTab = "basic"
local nextLeaderboardRefresh = 0
local leaderboardRefreshInterval = 15
local MAX_REMOTE_IMAGE_BYTES = 2 * 1024 * 1024

local defaultDrawerActions = {
    {ID = "copy", Label = "Copy ID", Icon = "communication/link", Type = "copy", Admin = false, Enabled = true},
    {ID = "profile", Label = "Profile", Icon = "players/person", Type = "profile", Admin = false, Enabled = true},
    {ID = "mute", Label = "Mute", ToggleLabel = "Unmute", Icon = "actions/muted", ToggleIcon = "actions/unmuted", Type = "mute", Admin = false, Enabled = true},
    {ID = "goto", Label = "Go To", Icon = "misc/directions_run", Type = "command", Command = "ulx goto \"%steamid%\"", Admin = true, Enabled = true},
    {ID = "freeze", Label = "Freeze", ToggleLabel = "Unfreeze", Icon = "admin/freeze", Type = "command", Command = "ulx freeze \"%steamid%\"", Toggle = true, ToggleCommand = "ulx unfreeze \"%steamid%\"", Admin = true, Enabled = true},
    {ID = "jail", Label = "Jail", ToggleLabel = "Unjail", Icon = "admin/security", Type = "command", Command = "ulx jail \"%steamid%\"", Toggle = true, ToggleCommand = "ulx unjail \"%steamid%\"", Admin = true, Enabled = true},
    {ID = "spectate", Label = "Spectate", Icon = "players/person", Type = "command", Command = "ulx spectate \"%steamid%\"", Admin = true, Enabled = true},
    {ID = "kick", Label = "Kick", Icon = "admin/kick", Type = "command", Command = "ulx kick \"%steamid%\" \"Kicked from scoreboard\"", Admin = true, Enabled = true},
    {ID = "ban", Label = "Ban", Icon = "admin/gavel", Type = "command", Command = "ulx ban \"%steamid%\" 60 \"Banned from scoreboard\"", Admin = true, Enabled = true}
}

local defaultDrawerActionOrder = {
    "copy",
    "profile",
    "mute",
    "goto",
    "freeze",
    "jail",
    "spectate",
    "kick",
    "ban"
}

local defaultScoreConfig = {
    Enabled = true,
    HeaderTitle = "",
    HeaderSubtitle = "Clean player overview",
    ShowHeaderIcon = true,
    HeaderIcon = "misc/groups",
    HeaderIconURL = "",
    HeaderIconScale = 1,
    Width = 960,
    Height = 650,
    AccentWidth = 6,
    HeaderHeight = 72,
    RowHeight = 42,
    RowGap = 3,
    ShowMoney = true,
    ShowShop = false,
    CreditsEnabled = false,
    ShowSearch = true,
    RepEnabled = true,
    PlayerCardShadow = true,
    PlayerCardRadius = nil,
    ShopTitle = "Credit Shop",
    ShopSubtitle = "Server items, perks, and profile extras.",
    ShopCurrencyName = "Credits",
    ShopCurrencyMode = "darkrp",
    ShopCurrencyGet = "",
    ShopCurrencyTake = "",
    ShopGridColumns = 2,
    MOTD = {
        Enabled = true,
        ShowOnJoin = true,
        Width = 960,
        Height = 650,
        Shadow = true,
        ShadowAlpha = 92,
        Title = "Welcome to the Server",
        ShowHeaderIcon = true,
        Icon = "communication/notifications",
        Subtitle = "Read the rules, respect the RP, and have a good time.",
        Body = {
            "Respect staff and other players.",
            "Stay in character during RP situations.",
            "Do not RDM, prop abuse, or exploit.",
            "Use the scoreboard for quick player actions and server info."
        },
        ServerUpdates = {
            "New HUD systems are being tested.",
            "Use F1 for laws and TAB for the scoreboard."
        },
        Buttons = {
            {Enabled = true, Label = "Discord", URL = ""},
            {Enabled = true, Label = "Website", URL = ""},
            {Enabled = true, Label = "Shop", URL = ""},
            {Enabled = true, Label = "Rules", URL = ""},
            {Enabled = true, Label = "Close", Action = "close"}
        }
    },
    Leaderboards = {
        Enabled = true,
        StorageMode = "file",
        RefreshInterval = 30,
        TopResults = 10,
        OverallTime = true,
        SessionTime = false,
        Money = true,
        Kills = true,
        Deaths = true,
        Points = false,
        Credits = false,
        SQL = {
            Type = "sqlite",
            Host = "",
            Database = "",
            Username = "",
            Password = "",
            Port = 3306
        }
    },
    Columns = {
        Jobs = 0.52,
        Staff = 0.70,
        Cash = 0.86,
        Ping = 0.94
    },
    ColumnOrder = {
        "Jobs",
        "Staff",
        "Cash",
        "Ping"
    },
    DrawerActions = defaultDrawerActions,
    DrawerActionOrder = defaultDrawerActionOrder,
    RankDisplay = {
        user = {Name = "User", Color = {r = 180, g = 180, b = 185}},
        vip = {Name = "VIP", Color = {r = 221, g = 177, b = 74}},
        trialmod = {Name = "Trial Mod", Color = {r = 91, g = 159, b = 232}},
        trialadmin = {Name = "Trial Admin", Color = {r = 122, g = 166, b = 255}},
        admin = {Name = "Admin", Color = {r = 238, g = 146, b = 80}},
        headadmin = {Name = "Head Admin", Color = {r = 232, g = 176, b = 77}},
        owner = {Name = "Owner", Color = {r = 232, g = 84, b = 84}}
    },
    DisabledRankDisplay = {},
    Animation = {
        Speed = 13,
        HoverSpeed = 16,
        ExpandSpeed = 18,
        Slide = 22
    },
    ShopListings = {
        {ID = "default_carbon_card", Title = "Carbon Card", Price = "$15,000", PriceAmount = 15000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = true},
        {ID = "default_neon_frame", Title = "Neon Frame", Price = "$25,000", PriceAmount = 25000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = true},
        {ID = "default_city_cover", Title = "City Cover", Price = "$35,000", PriceAmount = 35000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = true},
        {ID = "default_founder_plate", Title = "Founder Plate", Price = "$50,000", PriceAmount = 50000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = false}
    }
}

local columnDefaults = {
    Jobs = 0.52,
    Staff = 0.70,
    Cash = 0.86,
    Ping = 0.94
}

local function NormalizeDrawerActions(cfg)
    cfg.DrawerActions = istable(cfg.DrawerActions) and cfg.DrawerActions or table.Copy(defaultDrawerActions)
    cfg.DrawerActionOrder = istable(cfg.DrawerActionOrder) and cfg.DrawerActionOrder or table.Copy(defaultDrawerActionOrder)
    cfg.ShopListings = istable(cfg.ShopListings) and cfg.ShopListings or table.Copy(defaultScoreConfig.ShopListings or {})
    cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or table.Copy(defaultScoreConfig.RankDisplay or {})
    cfg.MOTD = istable(cfg.MOTD) and cfg.MOTD or table.Copy(defaultScoreConfig.MOTD or {})

    local defaultsByID = {}
    for _, action in ipairs(defaultDrawerActions) do
        if istable(action) and action.ID then defaultsByID[tostring(action.ID)] = action end
    end

    local byID = {}
    for _, action in ipairs(cfg.DrawerActions) do
        if istable(action) and action.ID then
            local fallback = defaultsByID[tostring(action.ID)] or {}
            byID[tostring(action.ID)] = true
            if action.Enabled == nil then action.Enabled = true end
            if action.Admin == nil then action.Admin = fallback.Admin == true end
            action.Type = action.Type or fallback.Type or (action.Command and "command" or tostring(action.ID))
            action.Icon = action.Icon or fallback.Icon or "misc/bolt"
            action.ToggleIcon = action.ToggleIcon or fallback.ToggleIcon
            action.Label = action.Label or fallback.Label or tostring(action.ID)
            action.ToggleLabel = action.ToggleLabel or fallback.ToggleLabel
            action.Toggle = action.Toggle or fallback.Toggle
            action.ToggleCommand = action.ToggleCommand or fallback.ToggleCommand
        end
    end

    for _, action in ipairs(defaultDrawerActions) do
        if not byID[action.ID] then
            cfg.DrawerActions[#cfg.DrawerActions + 1] = table.Copy(action)
        end
    end

    if #cfg.DrawerActionOrder == 0 then
        cfg.DrawerActionOrder = table.Copy(defaultDrawerActionOrder)
    end

    local ordered = {}
    for _, id in ipairs(cfg.DrawerActionOrder or {}) do
        ordered[tostring(id)] = true
    end

    for _, id in ipairs(defaultDrawerActionOrder) do
        if not ordered[tostring(id)] then
            cfg.DrawerActionOrder[#cfg.DrawerActionOrder + 1] = id
            ordered[tostring(id)] = true
        end
    end

    for _, listing in ipairs(cfg.ShopListings) do
        if istable(listing) then
            listing.Title = listing.Title or "Profile Photo"
            listing.ID = listing.ID or ("listing_" .. util.CRC((listing.Title or "") .. (listing.Class or "") .. (listing.ImageURL or "")))
            listing.Price = listing.Price or "$0"
            listing.PriceAmount = tonumber(listing.PriceAmount) or tonumber(string.match(tostring(listing.Price or ""), "%d+")) or 0
            listing.Currency = listing.Currency or cfg.ShopCurrencyName or "Credits"
            listing.ImageURL = listing.ImageURL or ""
            listing.Model = listing.Model or ""
            listing.Class = listing.Class or ""
            listing.ItemType = listing.ItemType or "profile"
            if listing.Public == nil then listing.Public = true end
        end
    end

    for key, data in next, (defaultScoreConfig.RankDisplay or {}) do
        cfg.RankDisplay[key] = istable(cfg.RankDisplay[key]) and cfg.RankDisplay[key] or table.Copy(data)
        cfg.RankDisplay[key].Name = cfg.RankDisplay[key].Name or data.Name or key
        cfg.RankDisplay[key].Color = istable(cfg.RankDisplay[key].Color) and cfg.RankDisplay[key].Color or table.Copy(data.Color)
    end

    if istable(defaultScoreConfig.MOTD) then
        for key, value in next, (defaultScoreConfig.MOTD) do
            if cfg.MOTD[key] == nil then
                cfg.MOTD[key] = istable(value) and table.Copy(value) or value
            end
        end
        cfg.MOTD.Buttons = istable(cfg.MOTD.Buttons) and cfg.MOTD.Buttons or table.Copy(defaultScoreConfig.MOTD.Buttons or {})
    end
end

local function ScoreCfg()
    DHUD.Config = DHUD.Config or {}
    DHUD.Config.Scoreboard = DHUD.Config.Scoreboard or {}

    local cfg = DHUD.Config.Scoreboard
    for key, value in next, (defaultScoreConfig) do
        if istable(value) then
            cfg[key] = cfg[key] or table.Copy(value)
        elseif cfg[key] == nil then
            cfg[key] = value
        end
    end

    cfg.Columns = cfg.Columns or table.Copy(columnDefaults)
    for key, value in next, (columnDefaults) do
        if cfg.Columns[key] == nil then cfg.Columns[key] = value end
    end
    NormalizeDrawerActions(cfg)

    if istable(serverScoreConfig) then
        for key in next, (defaultScoreConfig) do
            if serverScoreConfig[key] ~= nil then
                cfg[key] = istable(serverScoreConfig[key]) and table.Copy(serverScoreConfig[key]) or serverScoreConfig[key]
            end
        end

        cfg.Columns = cfg.Columns or table.Copy(columnDefaults)
        for key, value in next, (columnDefaults) do
            if cfg.Columns[key] == nil then cfg.Columns[key] = value end
        end
    end

    if istable(previewScoreConfig) then
        for key, value in next, (previewScoreConfig) do
            cfg[key] = istable(value) and table.Copy(value) or value
        end
    end

    NormalizeDrawerActions(cfg)

    if (not istable(serverScoreConfig) or serverScoreConfig.CreditsEnabled == nil)
        and DHUD.Config and DHUD.Config.Credits and DHUD.Config.Credits.Enabled ~= nil then
        cfg.CreditsEnabled = DHUD.Config.Credits.Enabled == true
    end

    if DHUD.Config then
        DHUD.Config.MOTD = table.Copy(cfg.MOTD or defaultScoreConfig.MOTD or {})
    end

    return cfg
end

local function SaveScoreCfg()
    local cfg = ScoreCfg()
    local out = {}

    for key in next, (defaultScoreConfig) do
        out[key] = cfg[key]
    end

    serverScoreConfig = table.Copy(out)

    if net then
        net.Start("DHUD.Scoreboard.SaveConfig")
        net.WriteString(util.TableToJSON(out) or "{}")
        net.SendToServer()
    end
end

function DHUD.Scoreboard.GetConfig()
    return table.Copy(ScoreCfg())
end

function DHUD.Scoreboard.ApplyExternalConfig(overrides)
    local cfg = ScoreCfg()
    previewScoreConfig = nil

    if istable(overrides) then
        for key, value in next, (overrides) do
            cfg[key] = istable(value) and table.Copy(value) or value
        end
    end

    DHUD.Config = DHUD.Config or {}
    DHUD.Config.Scoreboard = table.Copy(cfg)
    serverScoreConfig = table.Copy(cfg)
    SaveScoreCfg()

    if RebuildCurrentView then
        RebuildCurrentView()
    end
end

function DHUD.Scoreboard.PreviewExternalConfig(overrides)
    previewScoreConfig = istable(overrides) and table.Copy(overrides) or nil

    if IsValid(frame) and frame.DHUDPreview then
        local cfg = ScoreCfg()
        local edge = 28
        local gap = 12
        local maxPreviewW = math.floor((ScrW() - edge * 2 - gap) * 0.5)
        local targetW = math.min(maxPreviewW, math.max(tonumber(cfg.Width or defaultScoreConfig.Width) or defaultScoreConfig.Width, 720))
        local _, frameH = frame:GetSize()
        frame:SetSize(targetW, frameH)
        frame:SetPos(edge, math.max(28, (ScrH() - frameH) * 0.5))
        frame.DHUDBaseX, frame.DHUDBaseY = frame:GetPos()
    end

    if RebuildCurrentView then
        RebuildCurrentView()
    end
end

local function ResetScoreCfg()
    local cfg = ScoreCfg()

    for key, value in next, (defaultScoreConfig) do
        cfg[key] = istable(value) and table.Copy(value) or value
    end

    headerIconURL = nil
    headerIconMaterial = nil
    serverScoreConfig = nil

    if net then
        net.Start("DHUD.Scoreboard.ResetConfig")
        net.SendToServer()
    end
end

local function AnimProfile()
    local cfg = DHUD.Config and DHUD.Config.Scoreboard or {}
    local anim = istable(cfg.Animation) and cfg.Animation or defaultScoreConfig.Animation

    return {
        Speed = tonumber(anim.Speed) or defaultScoreConfig.Animation.Speed,
        HoverSpeed = tonumber(anim.HoverSpeed) or defaultScoreConfig.Animation.HoverSpeed,
        ExpandSpeed = tonumber(anim.ExpandSpeed) or defaultScoreConfig.Animation.ExpandSpeed,
        Slide = tonumber(anim.Slide) or defaultScoreConfig.Animation.Slide
    }
end

local function EaseValue(value, target, speed)
    return Lerp(math.Clamp(FrameTime() * (tonumber(speed) or defaultScoreConfig.Animation.HoverSpeed), 0, 1), value or 0, target or 0)
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

local function LibFont(name, fallback)
    if DubzLib and DubzLib.Font then
        return DubzLib.Font(name)
    end

    return fallback
end

local function Radius(name)
    if DubzLib and DubzLib.Radius then
        return DubzLib.Radius(name)
    end

    return name == "MD" and 8 or 5
end

local function CardRadius()
    local cfg = DHUD.Config and DHUD.Config.Scoreboard or {}
    if isnumber(cfg.PlayerCardRadius) then
        return math.max(math.Round(cfg.PlayerCardRadius), 0)
    end

    return Radius("MD")
end

local function DrawText(text, font, x, y, col, ax, ay)
    text = DHUD.L and DHUD.L(text) or tostring(text or "")
    if DubzLib and DubzLib.Draw and DubzLib.Draw.Text then
        DubzLib.Draw.Text(text, font, x, y, col, ax, ay)
    else
        draw.SimpleText(text, font, x, y, col, ax, ay)
    end
end

local function DrawIcon(path, x, y, size, col)
    if DHUD.Status and DHUD.Status.DrawIcon then
        DHUD.Status.DrawIcon(path, x, y, size, col)
    elseif DHUD.Icon and DHUD.Icon.Draw then
        DHUD.Icon.Draw(path, x, y, size, col)
    end
end

local function NormalizeImageURL(url)
    url = string.Trim(tostring(url or ""))
    if url == "" then return "" end

    if string.match(url, "^[%w]+$") then
        return "https://i.imgur.com/" .. url .. ".png"
    end

    local cleanURL = string.match(url, "^[^%?]+") or url
    local id = string.match(cleanURL, "^https://imgur%.com/([%w]+)$")
    if id then
        return "https://i.imgur.com/" .. id .. ".png"
    end

    if string.match(cleanURL, "^https://i%.imgur%.com/[%w]+%.png$") then
        return cleanURL
    end

    return ""
end

local function HeaderIconFileName(url)
    local cleanURL = string.match(url, "^[^%?]+") or url
    local imgurID = string.match(cleanURL, "i%.imgur%.com/([%w]+)%.")
        or string.match(cleanURL, "imgur%.com/([%w]+)$")

    if imgurID and imgurID ~= "" then
        return "imgur_" .. imgurID
    end

    return "url_" .. util.CRC(url)
end

local function HeaderIconMaterial()
    local cfg = ScoreCfg()
    local url = NormalizeImageURL(cfg.HeaderIconURL)
    if url == "" then return nil end
    if headerIconURL == url and headerIconMaterial then return headerIconMaterial end
    if headerIconLoading and headerIconURL == url then return nil end

    headerIconURL = url
    headerIconMaterial = nil
    headerIconLoading = true

    local fileName = HeaderIconFileName(url)
    local dataPath = "dhud/scoreboard_images/" .. fileName .. ".png"
    local materialPath = "data/" .. dataPath

    file.CreateDir("dhud")
    file.CreateDir("dhud/scoreboard_images")

    if file.Exists(dataPath, "DATA") then
        headerIconLoading = false
        headerIconMaterial = Material(materialPath, "noclamp smooth")
        return headerIconMaterial
    end

    http.Fetch(url, function(body)
        headerIconLoading = false
        if not body or body == "" or #body > MAX_REMOTE_IMAGE_BYTES then return end

        file.Write(dataPath, body)
        headerIconMaterial = Material(materialPath, "noclamp smooth")
    end, function()
        headerIconLoading = false
    end)

    return nil
end

local function RemoteImageMaterial(url)
    url = NormalizeImageURL(url)
    if url == "" then return nil end
    if remoteImageMaterials[url] then return remoteImageMaterials[url] end
    if remoteImageLoading[url] then return nil end

    local fileName = HeaderIconFileName(url)
    local dataPath = "dhud/scoreboard_images/" .. fileName .. ".png"
    local materialPath = "data/" .. dataPath

    file.CreateDir("dhud")
    file.CreateDir("dhud/scoreboard_images")

    if file.Exists(dataPath, "DATA") then
        remoteImageMaterials[url] = Material(materialPath, "noclamp smooth")
        return remoteImageMaterials[url]
    end

    remoteImageLoading[url] = true
    http.Fetch(url, function(body)
        remoteImageLoading[url] = nil
        if not body or body == "" or #body > MAX_REMOTE_IMAGE_BYTES then return end

        file.Write(dataPath, body)
        remoteImageMaterials[url] = Material(materialPath, "noclamp smooth")
    end, function()
        remoteImageLoading[url] = nil
    end)

    return nil
end

local function DrawHeaderIcon(path, x, y, size, col)
    local mat = HeaderIconMaterial()
    if mat and not mat:IsError() then
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(x, y, size, size)
        return
    end

    DrawIcon(path, x, y, size, col)
end

local function Accent()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.Agenda or colors.Clock or Color(184, 116, 255)
end

local function Primary()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.ScoreboardAccent or LibColor("Primary", colors.Health or Accent())
end

local function Secondary()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.ScoreboardBackground or colors.Background or LibColor("Secondary", Color(24, 25, 30))
end

local function ButtonBase(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local col = colors.ScoreboardPanel or Secondary()
    return Color(math.max(col.r - 8, 0), math.max(col.g - 8, 0), math.max(col.b - 8, 0), math.min(alpha or 255, 255))
end

local function CardBase(alpha)
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local col = colors.ScoreboardPanel or Secondary()
    return Color(math.max(col.r - 3, 0), math.max(col.g - 3, 0), math.max(col.b - 3, 0), math.min(alpha or 255, 255))
end

local function CashColor()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    return colors.Cash or Color(91, 201, 121)
end

local function CreditsSupported()
    return DubzCreditSystem ~= nil or (DHUD.Support and DHUD.Support.CreditsDetected == true)
end

local function CreditsEnabled(cfg)
    local hudEnabled = DHUD.Config and DHUD.Config.Credits and DHUD.Config.Credits.Enabled == true
    return hudEnabled and CreditsSupported() and cfg and cfg.CreditsEnabled ~= false
end

local function Shadow(alpha)
    return Color(0, 0, 0, math.min(alpha or 255, 255))
end

local function StyleButton(btn)
    btn:SetText("")
    btn:SetTextColor(Color(0, 0, 0, 0))
    btn:SetDrawBackground(false)
    if btn.SetDrawBorder then btn:SetDrawBorder(false) end
end

local function HandleHoverSound(panel)
    if DubzLib and DubzLib.UI and DubzLib.UI.HandleHoverSound then
        DubzLib.UI.HandleHoverSound(panel)
    end
end

local function SafeNick(ply)
    return IsValid(ply) and ply.Nick and tostring(ply:Nick() or "") or ""
end

local function SafeSteamID(ply)
    return IsValid(ply) and ply.SteamID and tostring(ply:SteamID() or "") or ""
end

local function SafePing(ply)
    return IsValid(ply) and ply.Ping and (tonumber(ply:Ping() or 0) or 0) or 0
end

local function TeamName(ply)
    if IsValid(ply) and DarkRP and ply.getDarkRPVar then
        local job = ply:getDarkRPVar("job")
        if job and job ~= "" then return tostring(job) end
    end

    if IsValid(ply) and ply.Team then
        return team.GetName(ply:Team()) or ""
    end

    return ""
end

local function TeamColor(ply)
    if IsValid(ply) then
        local col = team.GetColor(ply:Team())
        if col then return col end
    end

    return Primary()
end

local function RankName(ply)
    local group = IsValid(ply) and ply.GetUserGroup and ply:GetUserGroup() or "user"
    if not group or group == "" then group = "user" end

    return group
end

local rankColors = {
    superadmin = Color(232, 84, 84),
    admin = Color(238, 146, 80),
    moderator = Color(91, 159, 232),
    mod = Color(91, 159, 232),
    vip = Color(221, 177, 74),
    user = Color(180, 180, 185)
}

local HexToColor

local function TableColor(data, fallback)
    if isstring(data) then
        return HexToColor(data, fallback)
    end

    if istable(data) then
        return Color(tonumber(data.r) or fallback.r, tonumber(data.g) or fallback.g, tonumber(data.b) or fallback.b, tonumber(data.a) or 255)
    end

    return fallback
end

local function ColorToHex(col)
    if isstring(col) then return col end
    col = col or color_white
    return string.format("#%02X%02X%02X", math.Clamp(col.r or 255, 0, 255), math.Clamp(col.g or 255, 0, 255), math.Clamp(col.b or 255, 0, 255))
end

HexToColor = function(hex, fallback)
    fallback = fallback or color_white
    hex = string.Trim(tostring(hex or ""))
    hex = string.gsub(hex, "#", "")

    if #hex == 3 then
        hex = string.sub(hex, 1, 1) .. string.sub(hex, 1, 1)
            .. string.sub(hex, 2, 2) .. string.sub(hex, 2, 2)
            .. string.sub(hex, 3, 3) .. string.sub(hex, 3, 3)
    end

    if not string.match(hex, "^[%x][%x][%x][%x][%x][%x]$") then
        return fallback
    end

    return Color(
        tonumber(string.sub(hex, 1, 2), 16) or fallback.r,
        tonumber(string.sub(hex, 3, 4), 16) or fallback.g,
        tonumber(string.sub(hex, 5, 6), 16) or fallback.b,
        255
    )
end

local function RankDisplay(rank)
    local cfg = ScoreCfg()
    local key = string.lower(tostring(rank or "user"))
    local data = cfg.RankDisplay and cfg.RankDisplay[key] or nil

    if istable(data) then
        local label = tostring(data.Name or rank or "user")
        if key == "user" and string.find(string.lower(label), "admin", 1, true) then
            return "User", rankColors.user
        end

        return label, TableColor(data.Color, rankColors[key] or Accent())
    end

    return tostring(rank or "user"), rankColors[key] or Accent()
end

local function RankColor(rank)
    local _, col = RankDisplay(rank)
    return col
end

local function PingColor(ping)
    ping = tonumber(ping or 0) or 0
    if ping <= 70 then return Color(91, 201, 121) end
    if ping <= 140 then return Color(221, 177, 74) end

    return Color(232, 84, 84)
end

local function PlayerMoney(ply)
    if IsValid(ply) and DarkRP and ply.getDarkRPVar then
        local money = ply:getDarkRPVar("money")
        if money and DarkRP.formatMoney then return DarkRP.formatMoney(money) end
    end

    return nil
end

local function PlayerMoneyValue(ply)
    if IsValid(ply) and DarkRP and ply.getDarkRPVar then
        return tonumber(ply:getDarkRPVar("money") or 0) or 0
    end

    return 0
end

local function PlayerPlaytimeSeconds(ply)
    if not IsValid(ply) then return 0 end

    local steam64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    local saved = steam64 ~= "" and steam64 ~= "0" and (tonumber(playtimeBySteam64[steam64] or 0) or 0) or 0

    local utime = 0
    if ply.GetUTimeTotalTime then
        utime = tonumber(ply:GetUTimeTotalTime() or 0) or 0
    end

    return math.max(saved, utime, 0)
end

local function PlayerSessionSeconds(ply)
    if not IsValid(ply) then return 0 end
    if ply.TimeConnected then
        local ok, value = pcall(function() return ply:TimeConnected() end)
        if ok and tonumber(value) then return math.max(tonumber(value) or 0, 0) end
    end
    return 0
end

local function PlayerPointValue(ply)
    if not IsValid(ply) then return 0 end
    return tonumber(ply.DHUDScoreboardPoints or 0) or 0
end

local function PlayerCreditValue(ply)
    if not IsValid(ply) then return 0 end
    return tonumber(ply.DHUDScoreboardCredits or 0) or 0
end

local function PlayerFragValue(ply)
    if IsValid(ply) and ply.Frags then return math.max(tonumber(ply:Frags() or 0) or 0, 0) end
    return 0
end

local function PlayerDeathValue(ply)
    if IsValid(ply) and ply.Deaths then return math.max(tonumber(ply:Deaths() or 0) or 0, 0) end
    return 0
end

local function FormatDuration(seconds)
    seconds = math.max(tonumber(seconds or 0) or 0, 0)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if hours > 0 then
        return hours .. "h " .. minutes .. "m"
    end

    return minutes .. "m"
end

local function PlayerCount()
    local count = #player.GetAll()
    local maxPlayers = game.MaxPlayers and game.MaxPlayers() or nil

    if maxPlayers and maxPlayers > 0 then
        return count .. "/" .. maxPlayers
    end

    return string.format("%d", count)
end

local function MapName()
    if game and game.GetMap then
        return game.GetMap()
    end

    return "unknown"
end

local function PingVisual(ping)
    ping = tonumber(ping or 0) or 0

    if ping <= 60 then return "misc/signal_cellular_4", Color(91, 201, 121) end
    if ping <= 100 then return "misc/signal_cellular_3", Color(91, 201, 121) end
    if ping <= 150 then return "misc/signal_cellular_2", Color(221, 177, 74) end
    if ping <= 220 then return "misc/signal_cellular_1", Color(238, 146, 80) end

    return "misc/signal_cellular_0", Color(232, 84, 84)
end

local function FitText(text, font, maxWidth)
    text = tostring(text or "")
    if not maxWidth or maxWidth <= 0 then return text end

    surface.SetFont(font)
    local width = surface.GetTextSize(text)
    if width <= maxWidth then return text end

    local suffix = "..."
    local lo, hi = 0, #text
    while lo < hi do
        local mid = math.ceil((lo + hi) * 0.5)
        local candidate = string.sub(text, 1, mid) .. suffix
        local candidateWidth = surface.GetTextSize(candidate)

        if candidateWidth <= maxWidth then
            lo = mid
        else
            hi = mid - 1
        end
    end

    return string.sub(text, 1, lo) .. suffix
end

local DrawChip

local function PaintShell(panel, w, h)
    local accent = Primary()
    local bg = Secondary()
    local cfg = ScoreCfg()
    local accentW = (cfg.AccentWidth or 6)
    local topX, topY = 18, 14
    local topW, topH = w - 36, cfg.HeaderHeight or 72
    local baseHeader = ButtonBase(255)
    local headerCol = Color(math.min((baseHeader.r or 32) + 4, 255), math.min((baseHeader.g or 32) + 4, 255), math.min((baseHeader.b or 38) + 5, 255), 255)
    local showHeaderIcon = cfg.ShowHeaderIcon ~= false
    local iconSize = 52
    local iconX = topX + 16
    local iconY = topY + (topH - iconSize) * 0.5
    local titleX = showHeaderIcon and (iconX + iconSize + 14) or (topX + 18)
    local rightX = topX + topW - 16
    local onlineW = 116
    surface.SetFont(LibFont("Small", "DermaDefault"))
    local mapValueW = surface.GetTextSize(MapName())
    local mapLabelW = surface.GetTextSize("Map")
    local mapW = math.Clamp(30 + mapLabelW + 10 + mapValueW + 12, 156, 212)
    local onlineX = rightX - onlineW
    local mapX = onlineX - 6 - mapW
    local statY = topY + topH - 29
    local titleMaxW = math.max(mapX - titleX - 12, 180)

    draw.RoundedBox(Radius("MD"), 3, 4, w - 3, h - 4, Shadow(58))
    draw.RoundedBox(Radius("MD"), 0, 0, w - 1, h, WithAlpha(accent, 255))
    draw.RoundedBox(Radius("MD"), accentW, 0, w - accentW, h, WithAlpha(bg, 255))
    draw.RoundedBox(Radius("MD"), topX + 2, topY + 3, topW - 2, topH - 1, Shadow(54))
    draw.RoundedBox(Radius("MD"), topX, topY, topW, topH, headerCol)

    local serverName = cfg.HeaderTitle ~= "" and cfg.HeaderTitle or (GetHostName and GetHostName() or "Dubz Server")
    local subtitle = tostring(cfg.HeaderSubtitle or "")

    if showHeaderIcon then
        local imageScale = math.Clamp(tonumber(cfg.HeaderIconScale) or 1, 0.5, 1.8)
        local imageSize = (iconSize - 14) * imageScale

        draw.RoundedBox(CardRadius(), iconX, iconY, iconSize, iconSize, ButtonBase(255))
        DrawHeaderIcon(cfg.HeaderIcon or "misc/groups", iconX + iconSize * 0.5 - imageSize * 0.5, iconY + iconSize * 0.5 - imageSize * 0.5, imageSize, LibColor("Muted", Color(170, 171, 178)))
    end

    DrawText(FitText(serverName, LibFont("Header", "DermaDefaultBold"), titleMaxW), LibFont("Header", "DermaDefaultBold"), titleX, topY + 18, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    if subtitle ~= "" then
        DrawText(FitText(subtitle, LibFont("Small", "DermaDefault"), titleMaxW), LibFont("Small", "DermaDefault"), titleX, topY + 44, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    DrawChip(mapX, statY, mapW, "Map", MapName(), "misc/map")
    DrawChip(onlineX, statY, onlineW, "Players", PlayerCount(), "players/groups")
end

DrawChip = function(x, y, w, label, value, icon)
    local muted = LibColor("Muted", Color(170, 171, 178))
    local accent = Primary()

    draw.RoundedBox(CardRadius(), x, y + 2, w, 24, Shadow(26))
    draw.RoundedBox(CardRadius(), x, y, w, 24, ButtonBase(255))
    draw.RoundedBox(Radius("SM"), x + 7, y + 5, 16, 14, WithAlpha(accent, 26))
    DrawIcon(icon, x + 9, y + 6, 12, accent)
    surface.SetFont(LibFont("Small", "DermaDefault"))
    local labelW = surface.GetTextSize(tostring(label or ""))
    local valueX = x + 30 + labelW + 10
    DrawText(label, LibFont("Small", "DermaDefault"), x + 30, y + 5, muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    DrawText(FitText(value, LibFont("Small", "DermaDefault"), math.max(w - (valueX - x) - 10, 38)), LibFont("Small", "DermaDefault"), valueX, y + 5, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function StyleScroll(scroll)
    local bar = scroll:GetVBar()
    if not IsValid(bar) then return end

    bar:SetWide(6)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, w - 2, h, Color(0, 0, 0, 70))
    end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(3, 1, 0, w - 2, h, WithAlpha(LibColor("Muted", Color(170, 171, 178)), 160))
    end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
end

local function AddIconButton(parent, icon, callback, tooltip, hoverColor)
    local btn = vgui.Create("DButton", parent)
    StyleButton(btn)
    btn:SetSize(28, 28)
    btn.Hover = 0
    if tooltip and btn.SetTooltip then btn:SetTooltip(tooltip) end
    btn.Paint = function(self, w, h)
        HandleHoverSound(self)
        self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
        local muted = LibColor("Muted", Color(170, 171, 178))
        local hot = hoverColor or muted

        draw.RoundedBox(Radius("SM"), 0, 1, w, h - 1, Shadow(24))
        draw.RoundedBox(Radius("SM"), 0, 0, w, h - 1, ButtonBase(255))
        if self.Hover > 0.01 then
            draw.RoundedBox(Radius("SM"), 0, 0, w, h - 1, WithAlpha(hot, 20 + self.Hover * 42))
        end

        DrawIcon(icon, 6, 6, 16, self.Hover > 0.05 and hot or muted)
    end
    btn.DoClick = callback

    return btn
end

local function CopySteamID(ply)
    if not IsValid(ply) then return end

    SetClipboardText(ply:SteamID())
    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add("Copied " .. ply:Nick() .. "'s SteamID.", "hint", 3)
    else
        chat.AddText(Primary(), "[DHUD] ", color_white, "Copied SteamID.")
    end
end

local function ProfileURL(ply)
    if not IsValid(ply) then return end

    local steam64 = ply.SteamID64 and ply:SteamID64() or nil
    if not steam64 or steam64 == "" then return end

    gui.OpenURL("https://steamcommunity.com/profiles/" .. steam64)
end

local function PlayerDrawerKey(ply)
    if not IsValid(ply) then return end

    local steam64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    if steam64 ~= "" and steam64 ~= "0" then return "sid64:" .. steam64 end

    local steamID = ply.SteamID and tostring(ply:SteamID() or "") or ""
    local name = ply.Nick and tostring(ply:Nick() or "") or tostring(ply)
    local userID = ply.UserID and string.format("%d", ply:UserID() or 0) or "0"
    local entIndex = ply.EntIndex and string.format("%d", ply:EntIndex() or 0) or "0"

    return "ply:" .. steamID .. ":" .. name .. ":" .. userID .. ":" .. entIndex
end

local function PlayerRepValue(ply)
    local key = PlayerDrawerKey(ply)
    if not key then return 0 end

    return tonumber(playerRep[key] or 0) or 0
end

local function AddPlayerRep(ply, amount)
    if not IsValid(ply) or not net then return end

    net.Start("DHUD.Scoreboard.VoteRep")
    net.WriteEntity(ply)
    net.WriteInt(amount > 0 and 1 or -1, 3)
    net.SendToServer()
end

local function DrawerActionStateKey(ply, action)
    return tostring(PlayerDrawerKey(ply) or "invalid") .. ":" .. tostring(action and action.ID or "")
end

local function ReplaceActionTokens(command, ply)
    if not IsValid(ply) then return tostring(command or "") end

    local steamID = ply.SteamID and tostring(ply:SteamID() or "") or ""
    local steam64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    local nick = ply.Nick and tostring(ply:Nick() or "") or ""

    command = tostring(command or "")
    command = string.Replace(command, "%steamid64%", steam64)
    command = string.Replace(command, "%steam64%", steam64)
    command = string.Replace(command, "%steamid%", steamID)
    command = string.Replace(command, "%name%", nick)
    command = string.Replace(command, "%nick%", nick)

    return command
end

local function DrawerActionLabel(action, ply)
    if not action then return "" end

    local stateKey = DrawerActionStateKey(ply, action)
    if action.Type == "mute" and ((IsValid(ply) and ply.IsMuted and ply:IsMuted()) or playerActionStates[stateKey] == true) then
        return action.ToggleLabel or "Unmute"
    end

    if action.Toggle then
        if playerActionStates[stateKey] then
            return action.ToggleLabel or ("Un" .. tostring(action.Label or action.ID or "Toggle"))
        end
    end

    return action.Label or action.ID or "Action"
end

local function RunDrawerAction(action, ply)
    if not action or not IsValid(ply) then return end

    local actionType = tostring(action.Type or "")
    if actionType == "copy" or action.ID == "copy" then
        CopySteamID(ply)
        return
    end

    if actionType == "profile" or action.ID == "profile" then
        ProfileURL(ply)
        return
    end

    if actionType == "mute" or action.ID == "mute" then
        if ply.SetMuted and ply.IsMuted then
            local muted = ply:IsMuted()
            ply:SetMuted(not muted)
            playerActionStates[DrawerActionStateKey(ply, action)] = not muted or nil
        end
        return
    end

    local stateKey = DrawerActionStateKey(ply, action)
    local toggled = action.Toggle and playerActionStates[stateKey] == true
    local command = toggled and (action.ToggleCommand or action.Command) or action.Command
    command = ReplaceActionTokens(command, ply)
    if command == "" then return end

    LocalPlayer():ConCommand(command)

    if action.Toggle then
        playerActionStates[stateKey] = not toggled or nil
    end
end

local function OrderedDrawerActions()
    local cfg = ScoreCfg()
    local actions = {}
    local lookup = {}

    for _, action in ipairs(cfg.DrawerActions or defaultDrawerActions) do
        if istable(action) and action.ID then
            lookup[tostring(action.ID)] = action
        end
    end

    for _, id in ipairs(cfg.DrawerActionOrder or defaultDrawerActionOrder) do
        local action = lookup[tostring(id)]
        if action and action.Enabled ~= false then
            actions[#actions + 1] = action
        end
    end

    return actions
end

local function AddActionButton(parent, action, ply, accent)
    local btn = vgui.Create("DButton", parent)
    StyleButton(btn)
    btn:SetSize(90, 31)
    btn.Hover = 0
    btn.Paint = function(self, w, h)
        HandleHoverSound(self)
        self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
        local text = DrawerActionLabel(action, ply)
        local stateKey = DrawerActionStateKey(ply, action)
        local isMutedAction = action.Type == "mute" or action.ID == "mute"
        local isToggled = (action.Toggle and playerActionStates[stateKey] == true) or (isMutedAction and ((IsValid(ply) and ply.IsMuted and ply:IsMuted()) or playerActionStates[stateKey] == true))
        local icon = isToggled and (action.ToggleIcon or action.Icon) or (action.Icon or "misc/bolt")
        local hot = isToggled and ((DHUD.Config and DHUD.Config.Colors and DHUD.Config.Colors.Warning) or Color(238, 146, 80)) or accent

        draw.RoundedBox(CardRadius(), 0, 0, w, h, ButtonBase(255))
        draw.RoundedBox(Radius("SM"), 7, h * 0.5 - 10, 20, 20, WithAlpha(hot, 32 + self.Hover * 32))
        if self.Hover > 0.01 then
            draw.RoundedBox(CardRadius(), 0, 0, w, h, WithAlpha(hot, 18 + self.Hover * 26))
        end

        DrawIcon(icon, 9, h * 0.5 - 8, 16, hot)
        DrawText(FitText(text, LibFont("Small", "DermaDefault"), w - 36), LibFont("Small", "DermaDefault"), 34, h * 0.5 - 1, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        RunDrawerAction(action, ply)
    end

    return btn
end

local function AddRepButton(parent, ply, amount, text, accent)
    local btn = vgui.Create("DButton", parent)
    StyleButton(btn)
    btn:SetSize(42, 31)
    btn.Hover = 0
    btn.Paint = function(self, w, h)
        HandleHoverSound(self)
        self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
        local hot = amount > 0 and Color(91, 201, 121) or Color(232, 84, 84)

        draw.RoundedBox(CardRadius(), 0, 0, w, h, ButtonBase(255))
        if self.Hover > 0.01 then
            draw.RoundedBox(CardRadius(), 0, 0, w, h, WithAlpha(hot, 22 + self.Hover * 34))
        end

        DrawText(text, LibFont("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, amount > 0 and hot or WithAlpha(hot, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        AddPlayerRep(ply, amount)
    end

    return btn
end

local function AddRepIndicator(parent, ply)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(58, 31)
    panel.Paint = function(_, w, h)
        local rep = PlayerRepValue(ply)
        local col = rep >= 0 and Color(91, 201, 121) or Color(232, 84, 84)

        draw.RoundedBox(CardRadius(), 0, 0, w, h, ButtonBase(255))
        DrawText((rep >= 0 and "+" or "") .. rep .. " Rep", LibFont("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    return panel
end

local function AddPlaytimeIndicator(parent, ply)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(88, 31)
    panel.Paint = function(_, w, h)
        local valid = IsValid(ply)
        local text = valid and FormatDuration(PlayerPlaytimeSeconds(ply)) or "--"
        local col = valid and Primary() or LibColor("Muted", Color(166, 167, 174))

        draw.RoundedBox(CardRadius(), 0, 0, w, h, ButtonBase(255))
        DrawIcon("misc/clock", 8, h * 0.5 - 7, 14, col)
        DrawText(text, LibFont("Small", "DermaDefault"), w - 8, h * 0.5 - 1, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    return panel
end

local function AddPlayerRow(parent, ply)
    local cfg = ScoreCfg()
    local rowH = cfg.RowHeight or 42
    local rowGap = cfg.RowGap or 3
    local plyKey = PlayerDrawerKey(ply) or tostring(ply)

    local wrap = vgui.Create("DPanel", parent)
    wrap:Dock(TOP)
    wrap:DockMargin(0, 0, 0, rowGap)
    wrap:SetTall(expandedPlayers[plyKey] and (rowH + 42) or rowH)
    wrap.TargetTall = expandedPlayers[plyKey] and (rowH + 42) or rowH
    wrap.Expanded = expandedPlayers[plyKey] == true
    local actions
    wrap.Paint = function() end
    wrap.Think = function(self)
        if self.Expanded and IsValid(actions) then
            self.TargetTall = rowH + (actions.TargetTall or actions:GetTall()) + 6
        end

        local tall = EaseValue(self:GetTall(), self.TargetTall or rowH, AnimProfile().ExpandSpeed)
        self:SetTall(math.Round(tall))
        if IsValid(actions) then
            actions:SetVisible(self:GetTall() > 48)
        end
    end

    local row = vgui.Create("DButton", wrap)
    StyleButton(row)
    row:Dock(TOP)
    row:SetTall(rowH)
    row.Hover = 0
    local avatar = vgui.Create("AvatarImage", row)
    avatar:SetSize(29, 29)
    avatar:SetPos(9, 6)
    avatar:SetMouseInputEnabled(false)
    if IsValid(ply) then
        avatar:SetPlayer(ply, 32)
    end

    row.Paint = function(self, w, h)
        HandleHoverSound(self)
        self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)

        local valid = IsValid(ply)
        local accent = valid and TeamColor(ply) or LibColor("Muted", Color(166, 167, 174))
        local rank = RankName(ply)
        local rankDisplay, rankColor = RankDisplay(rank)
        local ping = SafePing(ply)
        local alpha = self:GetAlpha()

        local columns = ScoreCfg().Columns or columnDefaults
        local jobCenter = w * math.Clamp(tonumber(columns.Jobs) or columnDefaults.Jobs, 0.25, 0.9)
        local staffCenter = w * math.Clamp(tonumber(columns.Staff) or columnDefaults.Staff, 0.25, 0.9)
        local moneyX = w * math.Clamp(tonumber(columns.Cash) or columnDefaults.Cash, 0.25, 0.92)
        local pingX = w * math.Clamp(tonumber(columns.Ping) or columnDefaults.Ping, 0.3, 0.96)
        local signalIcon, signalColor = PingVisual(ping + ((math.sin(CurTime() * 2.4) + 1) * 4))

        if cfg.PlayerCardShadow ~= false then
            draw.RoundedBox(CardRadius(), 1, 2, w - 2, h - 1, Shadow(46))
        end
        draw.RoundedBox(CardRadius(), 0, 0, w, h - 2, CardBase(alpha))
        if self.Hover > 0.01 then
            draw.RoundedBox(CardRadius(), 0, 0, w, h - 2, WithAlpha(accent, 14 + self.Hover * 26))
        end
        draw.RoundedBox(Radius("SM"), 9, 6, 29, 29, WithAlpha(rankColor, 38))
        if not valid then
            DrawIcon("players/person", 15, 12, 17, LibColor("Muted", Color(166, 167, 174)))
        end

        local nameFont = LibFont("Body", "DermaDefault")
        local smallFont = LibFont("Small", "DermaDefault")
        local name = SafeNick(ply)
        local steamId = SafeSteamID(ply)
        local showSteam = LocalPlayer():IsAdmin()

        DrawText(FitText(name, nameFont, math.max(jobCenter - 92, 120)), nameFont, 48, showSteam and 7 or 13, valid and LibColor("Foreground", color_white) or LibColor("Muted", Color(166, 167, 174)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if showSteam then
            DrawText(FitText(steamId, smallFont, math.max(jobCenter - 92, 120)), smallFont, 48, 24, LibColor("Muted", Color(166, 167, 174)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local job = TeamName(ply)
        surface.SetFont(smallFont)
        local jobTextW = surface.GetTextSize(job)
        local jobPillW = math.Clamp(jobTextW + 18, 84, 178)
        local jobPillH = 20
        draw.RoundedBox(CardRadius(), jobCenter - jobPillW * 0.5, h * 0.5 - jobPillH * 0.5 - 1, jobPillW, jobPillH, WithAlpha(accent, 34))
        DrawText(FitText(job, smallFont, jobPillW - 14), smallFont, jobCenter, h * 0.5 - 1, WithAlpha(accent, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        DrawText(FitText(rankDisplay, smallFont, 112), smallFont, staffCenter, h * 0.5 - 1, rankColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local cfg = ScoreCfg()
        local money = cfg.ShowMoney ~= false and PlayerMoney(ply) or nil
        if money then
            DrawText(FitText(money, smallFont, 82), smallFont, moneyX, h * 0.5 - 1, CashColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        DrawIcon(signalIcon, pingX, 13, 15, signalColor)
        DrawText(string.format("%d", ping), smallFont, pingX + 22, h * 0.5 - 1, signalColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    row.DoClick = function()
        wrap.Expanded = not wrap.Expanded
        expandedPlayers[plyKey] = wrap.Expanded or nil
        wrap.TargetTall = wrap.Expanded and (rowH + (actions.TargetTall or actions:GetTall()) + 6) or rowH
    end
    row.PerformLayout = function()
        if IsValid(avatar) then
            avatar:SetPos(9, 6)
            avatar:SetSize(29, 29)
            avatar:SetVisible(IsValid(ply))
        end
    end

    actions = vgui.Create("DPanel", wrap)
    actions:Dock(TOP)
    actions:SetTall(31)
    actions:DockMargin(8, 3, 8, 0)
    actions:SetVisible(false)
    actions.Paint = function(_, w, h)
        draw.RoundedBox(CardRadius(), 0, 0, w, h, WithAlpha(Secondary(), 255))
    end
    actions.PerformLayout = function(self, w)
        if w <= 0 then return end

        local x, y = 0, 0
        local gap = 6
        local rowTall = 31

        for _, child in ipairs(self:GetChildren()) do
            if IsValid(child) then
                local cw = child:GetWide()
                if x > 0 and x + cw > w then
                    x = 0
                    y = y + rowTall + gap
                end

                child:SetPos(x, y)
                child:SetTall(rowTall)
                x = x + cw + gap
            end
        end

        self.TargetTall = y + rowTall
        self:SetTall(self.TargetTall)
    end

    local teamCol = TeamColor(ply)
    for _, action in ipairs(OrderedDrawerActions()) do
        if IsValid(ply) and (action.Admin ~= true or LocalPlayer():IsAdmin()) then
            AddActionButton(actions, action, ply, teamCol)
        end
    end

    AddPlaytimeIndicator(actions, ply)

    if IsValid(ply) and ScoreCfg().RepEnabled ~= false and ply ~= LocalPlayer() then
        AddRepButton(actions, ply, -1, "-Rep", teamCol)
        AddRepButton(actions, ply, 1, "+Rep", teamCol)
        AddRepIndicator(actions, ply)
    end
end

local function RebuildPlayers(scroll)
    scroll:Clear()

    local filter = string.lower(string.Trim(tostring(searchText or "")))
    local players = player.GetAll()
    table.sort(players, function(a, b)
        local av
        local bv

        if sortKey == "job" then
            av = string.lower(TeamName(a))
            bv = string.lower(TeamName(b))
        elseif sortKey == "money" then
            av = PlayerMoneyValue(a)
            bv = PlayerMoneyValue(b)
        elseif sortKey == "ping" then
            av = SafePing(a)
            bv = SafePing(b)
        else
            av = string.lower(SafeNick(a))
            bv = string.lower(SafeNick(b))
        end

        if av == bv then
            return string.lower(SafeNick(a)) < string.lower(SafeNick(b))
        end

        if sortAscending then
            return av < bv
        end

        return av > bv
    end)

    for _, ply in ipairs(players) do
        local haystack = string.lower(SafeNick(ply) .. " " .. TeamName(ply) .. " " .. RankName(ply) .. " " .. SafeSteamID(ply))
        if filter == "" or string.find(haystack, filter, 1, true) then
            AddPlayerRow(scroll, ply)
        end
    end
end

local function ToggleSort(key)
    if sortKey == key then
        sortAscending = not sortAscending
    else
        sortKey = key
        sortAscending = true
        if key == "money" or key == "ping" then
            sortAscending = false
        end
    end

    if IsValid(frame) then
        for _, child in ipairs(frame:GetChildren()) do
            if child.DHUDPlayerScroll then
                RebuildPlayers(child)
                break
            end
        end
    end
end

local function StyleTextEntry(entry)
    entry:SetFont(LibFont("Small", "DermaDefault"))
    entry:SetTextColor(LibColor("Foreground", color_white))
    entry:SetCursorColor(Primary())
    entry:SetHighlightColor(WithAlpha(Primary(), 90))
    entry.Paint = function(self, w, h)
        local focused = self:HasFocus()
        local bg = self.DHUDSearchEntry and Color(44, 45, 52, 255) or ButtonBase(255)
        draw.RoundedBox(Radius("SM"), 0, 0, w, h, bg)
        if self.DHUDSearchEntry and string.Trim(self:GetValue() or "") == "" then
            DrawIcon("navigation/search", 8, h * 0.5 - 7, 14, WithAlpha(LibColor("Muted", Color(170, 171, 178)), 210))
            DrawText("Search players", LibFont("Small", "DermaDefault"), 28, h * 0.5 - 1, WithAlpha(LibColor("Muted", Color(170, 171, 178)), 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        if focused then
            surface.SetDrawColor(WithAlpha(Primary(), 150))
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        self:DrawTextEntryText(LibColor("Foreground", color_white), Primary(), LibColor("Foreground", color_white))
    end
end

local function AddFormLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:Dock(TOP)
    label:DockMargin(0, 0, 0, 4)
    label:SetTall(14)
    label:SetText(DHUD.L and DHUD.L(text) or tostring(text or ""))
    label:SetFont(LibFont("Small", "DermaDefault"))
    label:SetTextColor(LibColor("Muted", Color(170, 171, 178)))

    return label
end

local function AddFormEntry(parent, label, value)
    AddFormLabel(parent, label)

    local entry = vgui.Create("DTextEntry", parent)
    entry:Dock(TOP)
    entry:DockMargin(0, 0, 0, 10)
    entry:SetTall(28)
    entry:SetText(tostring(value or ""))
    StyleTextEntry(entry)

    return entry
end

local function AddFormCheck(parent, label, value)
    local check = vgui.Create("DCheckBoxLabel", parent)
    check:Dock(TOP)
    check:DockMargin(0, 0, 0, 10)
    check:SetTall(20)
    check:SetText(DHUD.L and DHUD.L(label) or tostring(label or ""))
    check:SetFont(LibFont("Small", "DermaDefault"))
    check:SetTextColor(LibColor("Foreground", color_white))
    check:SetValue(value and 1 or 0)

    return check
end

local function AddFormMultiEntry(parent, label, value, height)
    AddFormLabel(parent, label)

    local entry = vgui.Create("DTextEntry", parent)
    entry:Dock(TOP)
    entry:DockMargin(0, 0, 0, 10)
    entry:SetTall(height or 54)
    if entry.SetMultiline then entry:SetMultiline(true) end
    entry:SetText(tostring(value or ""))
    StyleTextEntry(entry)

    return entry
end

local function AddMenuButton(parent, text, accent, callback)
    local btn = vgui.Create("DButton", parent)
    StyleButton(btn)
    btn:Dock(LEFT)
    btn:DockMargin(0, 0, 8, 0)
    btn:SetWide(96)
    btn.Hover = 0
    btn.Paint = function(self, w, h)
        HandleHoverSound(self)
        self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
        draw.RoundedBox(CardRadius(), 0, 0, w, h, ButtonBase(255))
        if self.Hover > 0.01 then
            draw.RoundedBox(CardRadius(), 0, 0, w, h, WithAlpha(accent, 24 + self.Hover * 36))
        end

        DrawText(text, LibFont("Small", "DermaDefault"), w * 0.5, h * 0.5 - 1, LibColor("Foreground", color_white), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = callback

    return btn
end

local function DrawerActionOrderText(cfg)
    return table.concat(cfg.DrawerActionOrder or defaultDrawerActionOrder, ",")
end

local function ParseDrawerActionOrder(text)
    local order = {}
    local seen = {}

    for token in string.gmatch(tostring(text or ""), "([^,%s]+)") do
        token = string.Trim(token)
        if token ~= "" and not seen[token] then
            order[#order + 1] = token
            seen[token] = true
        end
    end

    return order
end

local function AddCustomDrawerAction(cfg, label, icon, command, adminOnly, toggle, toggleLabel, toggleCommand)
    label = string.Trim(tostring(label or ""))
    command = string.Trim(tostring(command or ""))
    if label == "" or command == "" then return end

    local id = "custom_" .. util.CRC(label .. command)
    local action = {
        ID = id,
        Label = label,
        Icon = string.Trim(tostring(icon or "")) ~= "" and string.Trim(tostring(icon or "")) or "misc/bolt",
        Type = "command",
        Command = command,
        Admin = adminOnly == true,
        Enabled = true
    }

    if toggle then
        action.Toggle = true
        action.ToggleLabel = string.Trim(tostring(toggleLabel or "")) ~= "" and string.Trim(tostring(toggleLabel or "")) or ("Un" .. label)
        action.ToggleCommand = string.Trim(tostring(toggleCommand or ""))
    end

    cfg.DrawerActions = istable(cfg.DrawerActions) and cfg.DrawerActions or table.Copy(defaultDrawerActions)

    local replaced = false
    for index, existing in ipairs(cfg.DrawerActions) do
        if istable(existing) and existing.ID == id then
            cfg.DrawerActions[index] = action
            replaced = true
            break
        end
    end

    if not replaced then
        cfg.DrawerActions[#cfg.DrawerActions + 1] = action
    end

    cfg.DrawerActionOrder = istable(cfg.DrawerActionOrder) and cfg.DrawerActionOrder or table.Copy(defaultDrawerActionOrder)
    local actionOrderHasID = false
    for _, actionID in ipairs(cfg.DrawerActionOrder) do
        if actionID == id then
            actionOrderHasID = true
            break
        end
    end

    if not actionOrderHasID then
        cfg.DrawerActionOrder[#cfg.DrawerActionOrder + 1] = id
    end
end

local function SaveShopListing(cfg, index, title, price, imageURL, public, itemType, className, modelPath, currency)
    title = string.Trim(tostring(title or ""))
    if title == "" then return end

    cfg.ShopListings = istable(cfg.ShopListings) and cfg.ShopListings or {}
    local priceAmount = tonumber(price) or tonumber(string.match(tostring(price or ""), "%d+")) or 0
    local listing = {
        ID = index > 0 and cfg.ShopListings[index] and cfg.ShopListings[index].ID or ("listing_" .. util.CRC(title .. tostring(className or "") .. tostring(imageURL or "") .. CurTime())),
        Title = title,
        Price = string.Trim(tostring(price or "")) ~= "" and string.Trim(tostring(price or "")) or "$0",
        PriceAmount = priceAmount,
        Currency = string.Trim(tostring(currency or "")) ~= "" and string.Trim(tostring(currency or "")) or (cfg.ShopCurrencyName or "Credits"),
        ImageURL = string.Trim(tostring(imageURL or "")),
        ItemType = string.Trim(tostring(itemType or "")) ~= "" and string.Trim(tostring(itemType or "")) or "profile",
        Class = string.Trim(tostring(className or "")),
        Model = string.Trim(tostring(modelPath or "")),
        Public = public == true
    }

    index = tonumber(index or 0) or 0
    if index > 0 and cfg.ShopListings[index] then
        cfg.ShopListings[index] = listing
    else
        cfg.ShopListings[#cfg.ShopListings + 1] = listing
    end
end

local function AddListingToolButton(parent, icon, callback, tooltip, hoverColor)
    local btn = AddIconButton(parent, icon, callback, tooltip, hoverColor)
    btn:SetParent(parent)
    return btn
end

local function AvailableShopClasses()
    local items = {}

    if weapons and weapons.GetList then
        for _, data in ipairs(weapons.GetList() or {}) do
            local class = data.ClassName or data.Classname or data.Class
            if class and class ~= "" then
                items[#items + 1] = {
                    Type = "weapon",
                    Class = class,
                    Name = data.PrintName or class,
                    Model = data.WorldModel or data.ViewModel or ""
                }
            end
        end
    end

    if scripted_ents and scripted_ents.GetList then
        for class, data in next, (scripted_ents.GetList() or {}) do
            local tableData = istable(data) and (data.t or data) or {}
            if class and class ~= "" then
                items[#items + 1] = {
                    Type = "entity",
                    Class = class,
                    Name = tableData.PrintName or tableData.Name or class,
                    Model = tableData.Model or ""
                }
            end
        end
    end

    table.sort(items, function(a, b)
        return string.lower(a.Name or a.Class or "") < string.lower(b.Name or b.Class or "")
    end)

    return items
end

local function AddTrackSlider(parent, label, value, minValue, maxValue, onChanged)
    AddFormLabel(parent, label)

    local slider = vgui.Create("DPanel", parent)
    slider:Dock(TOP)
    slider:DockMargin(0, 0, 0, 10)
    slider:SetTall(28)
    slider.Value = math.Clamp(tonumber(value) or minValue, minValue, maxValue)
    slider.Dragging = false

    slider.Paint = function(self, w, h)
        local accent = Primary()
        local t = math.TimeFraction(minValue, maxValue, self.Value)
        local knobX = math.Clamp(t * (w - 18), 0, w - 18) + 9

        draw.RoundedBox(Radius("SM"), 0, 7, w, 14, ButtonBase(255))
        draw.RoundedBox(Radius("SM"), 0, 7, knobX, 14, WithAlpha(accent, 62))
        draw.RoundedBox(Radius("SM"), knobX - 7, 4, 14, 20, WithAlpha(accent, 230))
        DrawText(string.format("%.2f", self.Value), LibFont("Small", "DermaDefault"), w - 8, h * 0.5, LibColor("Foreground", color_white), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    slider.OnMousePressed = function(self)
        self.Dragging = true
        self:MouseCapture(true)
    end
    slider.OnMouseReleased = function(self)
        self.Dragging = false
        self:MouseCapture(false)
    end
    slider.Think = function(self)
        if not self.Dragging then return end

        local x = self:CursorPos()
        local t = math.Clamp(x / math.max(self:GetWide(), 1), 0, 1)
        local newValue = minValue + (maxValue - minValue) * t

        self.Value = onChanged(newValue) or newValue
    end

    return slider
end

local function ClearScoreboardBody()
    if not IsValid(frame) then return end

    for _, child in ipairs(frame:GetChildren()) do
        if child.DHUDContent then
            child:Remove()
        end
    end
end

local function SetScoreboardView(view)
    if view == "shop" then
        if DubzCreditSystem and DubzCreditSystem.OpenMenu then
            DubzCreditSystem.OpenMenu()
        elseif DHUD.Notify and DHUD.Notify.Add then
            DHUD.Notify.Add("Credit shop addon is not installed yet.", "hint", 3)
        end
        return
    end

    currentView = view or "players"
    if RebuildCurrentView then RebuildCurrentView() end
end

function DHUD.Scoreboard.SetView(view)
    SetScoreboardView(view)
end

function DHUD.Scoreboard.GetView()
    return currentView
end

local function RequestScoreboardData(force)
    if scoreboardDataRequested and not force then return end
    if not net then return end

    scoreboardDataRequested = true
    net.Start("DHUD.Scoreboard.RequestData")
    net.SendToServer()
end

function DHUD.Scoreboard.RequestData(force)
    RequestScoreboardData(force)
end

net.Receive("DHUD.Scoreboard.Data", function()
    local okCfg, cfg = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    local okRep, rep = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    serverScoreConfig = okCfg and istable(cfg) and cfg or {}
    playerRep = okRep and istable(rep) and rep or {}
    headerIconURL = nil
    headerIconMaterial = nil

    if RebuildCurrentView then
        RebuildCurrentView()
    end
end)

net.Receive("DHUD.Scoreboard.Rep", function()
    local ok, rep = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    playerRep = ok and istable(rep) and rep or {}

    if RebuildCurrentView then
        RebuildCurrentView()
    end
end)

net.Receive("Dubz_UpdatePlaytime", function()
    local ok, data = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    playtimeBySteam64 = ok and istable(data) and data or {}

    if currentView == "leaderboard" and RebuildCurrentView then
        RebuildCurrentView()
    end
end)

net.Receive("DHUD.Scoreboard.Leaderboards", function()
    local ok, data = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    persistentLeaderboardData = ok and istable(data) and data or {}
    if RebuildCurrentView and currentView == "leaderboard" then
        RebuildCurrentView()
    end
end)

net.Receive("DHUD.Scoreboard.Notice", function()
    local message = net.ReadString()
    local kind = net.ReadString()

    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add(message, kind ~= "" and kind or "hint", 3)
    else
        chat.AddText(Primary(), "[DHUD] ", color_white, message)
    end
end)

local function BuyShopListing(item)
    if not item or not net then return end

    net.Start("DHUD.Scoreboard.BuyListing")
    net.WriteString(tostring(item.ID or ""))
    net.SendToServer()
end

local function BuildPlayersView(w, h, cfg)
    local listY = 118

    if cfg.ShowSearch ~= false then
        local search = vgui.Create("DTextEntry", frame)
        search.DHUDContent = true
        search.DHUDSearchEntry = true
        local searchWide = 172
        local buttonsLeft = IsValid(frame) and frame.DHUDHeaderButtonsLeft or (w - 54)
        local searchRight = buttonsLeft - 8
        local searchX = searchRight - searchWide
        if searchX < 190 then
            searchWide = math.max(116, searchRight - 190)
            searchX = searchRight - searchWide
        end
        search:SetPos(math.max(24, searchX), 23)
        search:SetSize(searchWide, 26)
        search:SetText(searchText or "")
        search:SetKeyboardInputEnabled(true)
        search:SetMouseInputEnabled(true)
        StyleTextEntry(search)
        search.OnMousePressed = function(self)
            searchFocusedUntil = CurTime() + 8
            if IsValid(frame) then frame.DHUDTypingSearch = true end
            if IsValid(frame) then frame:SetKeyboardInputEnabled(true) end
            self:RequestFocus()
        end
        search.OnGetFocus = function()
            searchFocusedUntil = CurTime() + 8
            if IsValid(frame) then
                frame.DHUDTypingSearch = true
                frame:SetKeyboardInputEnabled(true)
            end
        end
        search.OnLoseFocus = function()
            searchFocusedUntil = CurTime() + 1
            if IsValid(frame) then frame.DHUDTypingSearch = false end
            if IsValid(frame) then frame:SetKeyboardInputEnabled(true) end
        end
        search.OnValueChange = function(_, value)
            searchText = tostring(value or "")
            searchFocusedUntil = CurTime() + 8
            for _, child in ipairs(frame:GetChildren()) do
                if child.DHUDPlayerScroll then
                    RebuildPlayers(child)
                    break
                end
            end
        end
        search.OnKeyCodeTyped = function(self, code)
            if code == KEY_ENTER then
                searchText = tostring(self:GetValue() or "")
                for _, child in ipairs(frame:GetChildren()) do
                    if child.DHUDPlayerScroll then
                        RebuildPlayers(child)
                        break
                    end
                end
                self:KillFocus()
                searchFocusedUntil = CurTime() + 0.35
                if IsValid(frame) then frame.DHUDTypingSearch = false end
                return true
            end

            if code == KEY_ESCAPE then
                self:KillFocus()
                searchFocusedUntil = CurTime() + 0.35
                if IsValid(frame) then frame.DHUDTypingSearch = false end
                return true
            end
        end
    end

    local header = vgui.Create("DPanel", frame)
    header.DHUDContent = true
    header:SetPos(22, listY - 30)
    header:SetSize(w - 44, 28)
    header:SetPaintBackground(false)
    header.Paint = function(_, hw, hh)
        local muted = LibColor("Muted", Color(180, 180, 185))
        local columns = ScoreCfg().Columns or columnDefaults
        local y = hh * 0.5
        local sortIcon = sortAscending and "actions/arrow_drop_up" or "actions/arrow_drop_down"

        local function DrawHeader(label, key, x, align)
            local active = sortKey == key
            local col = active and Primary() or muted
            DrawText(label, LibFont("Small", "DermaDefault"), x, y, col, align, TEXT_ALIGN_CENTER)
            if active then
                local iconX = align == TEXT_ALIGN_LEFT and (x + 44) or (x + 27)
                DrawIcon(sortIcon, iconX, y - 10, 20, col)
            end
        end

        DrawHeader("Player", "name", 0, TEXT_ALIGN_LEFT)
        DrawHeader("Jobs", "job", hw * (columns.Jobs or columnDefaults.Jobs), TEXT_ALIGN_CENTER)
        DrawText("Staff", LibFont("Small", "DermaDefault"), hw * (columns.Staff or columnDefaults.Staff), y, muted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if cfg.ShowMoney ~= false then
            DrawHeader("Cash", "money", hw * (columns.Cash or columnDefaults.Cash), TEXT_ALIGN_CENTER)
        end
        DrawHeader("Ping", "ping", hw * (columns.Ping or columnDefaults.Ping), TEXT_ALIGN_LEFT)
    end
    header.OnMousePressed = function(self)
        local x = self:CursorPos()
        local hw = self:GetWide()
        local columns = ScoreCfg().Columns or columnDefaults
        local jobX = hw * (columns.Jobs or columnDefaults.Jobs)
        local cashX = hw * (columns.Cash or columnDefaults.Cash)
        local pingX = hw * (columns.Ping or columnDefaults.Ping)

        if x < math.max(jobX - 80, 160) then
            ToggleSort("name")
        elseif x < (jobX + cashX) * 0.5 then
            ToggleSort("job")
        elseif x < (cashX + pingX) * 0.5 then
            ToggleSort("money")
        else
            ToggleSort("ping")
        end
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll.DHUDContent = true
    scroll.DHUDPlayerScroll = true
    scroll:SetPos(22, listY)
    scroll:SetSize(w - 44, h - listY - 20)
    StyleScroll(scroll)
    RebuildPlayers(scroll)
end

local function ClampColumn(cfg, key, value)
    local columns = cfg.Columns or columnDefaults
    local order = cfg.ColumnOrder or defaultScoreConfig.ColumnOrder
    local index = table.KeyFromValue(order, key) or 1
    local minGap = 0.08
    local minValue = 0.24
    local maxValue = 0.96

    if order[index - 1] and columns[order[index - 1]] then
        minValue = math.max(minValue, columns[order[index - 1]] + minGap)
    end

    if order[index + 1] and columns[order[index + 1]] then
        maxValue = math.min(maxValue, columns[order[index + 1]] - minGap)
    end

    return math.Clamp(value, minValue, maxValue)
end

local function BuildSettingsView(w, h, cfg)
    local intro = vgui.Create("DPanel", frame)
    intro.DHUDContent = true
    intro:SetPos(24, 98)
    intro:SetSize(w - 48, 48)
    intro.Paint = function(_, pw, ph)
        draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
        DrawText("Scoreboard Customization", LibFont("Header", "DermaDefaultBold"), 50, 8, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawText("Use tabs to tune one section at a time.", LibFont("Small", "DermaDefault"), 50, 31, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    local settingsBack = AddIconButton(intro, "actions/back", function()
        SetScoreboardView("players")
    end, "Back")
    settingsBack:SetPos(12, 10)

    local tabBar = vgui.Create("DPanel", frame)
    tabBar.DHUDContent = true
    tabBar:SetPos(24, 154)
    tabBar:SetSize(w - 48, 34)
    tabBar:SetPaintBackground(false)

    local tabs = {
        {ID = "basic", Label = "Basic"},
        {ID = "layout", Label = "Layout"},
        {ID = "ranks", Label = "Ranks"},
        {ID = "drawer", Label = "Drawer"},
        {ID = "motd", Label = "MOTD"}
    }
    if settingsTab == "shop" then
        settingsTab = "basic"
    end

    local tabX = 0
    for _, tab in ipairs(tabs) do
        local tabID = tab.ID
        local tabLabel = tab.Label
        local btn = vgui.Create("DButton", tabBar)
        StyleButton(btn)
        btn:SetPos(tabX, 0)
        btn:SetSize((tabID == "shop" or tabID == "motd") and 118 or 86, 30)
        btn.Hover = 0
        btn.Paint = function(self, bw, bh)
            HandleHoverSound(self)
            self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
            local active = settingsTab == tabID
            local accent = active and Primary() or LibColor("Muted", Color(170, 171, 178))

            draw.RoundedBox(CardRadius(), 0, 0, bw, bh, ButtonBase(255))
            if active or self.Hover > 0.01 then
                draw.RoundedBox(CardRadius(), 0, 0, bw, bh, WithAlpha(accent, active and 48 or (18 + self.Hover * 28)))
            end

            DrawText(tabLabel, LibFont("Small", "DermaDefault"), bw * 0.5, bh * 0.5 - 1, active and accent or LibColor("Foreground", color_white), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            settingsTab = tabID
            SetScoreboardView("settings")
        end
        tabX = tabX + btn:GetWide() + 8
    end

    local body = vgui.Create("DScrollPanel", frame)
    body.DHUDContent = true
    body:SetPos(24, 198)
    body:SetSize(w - 48, h - 218)
    StyleScroll(body)

    local form = vgui.Create("DPanel", body)
    form:Dock(TOP)
    form:SetPaintBackground(false)

    local function SaveAndStay()
        NormalizeDrawerActions(cfg)
        SaveScoreCfg()
        SetScoreboardView("settings")
    end

    if settingsTab == "basic" then
        form:SetTall(560)
        local titleEntry = AddFormEntry(form, "Header title", cfg.HeaderTitle or "")
        local subtitleEntry = AddFormEntry(form, "Header subtitle", cfg.HeaderSubtitle or "")
        local iconEntry = AddFormEntry(form, "Local icon path", cfg.HeaderIcon or "misc/groups")
        local urlEntry = AddFormEntry(form, "Imgur image URL or key / ID", cfg.HeaderIconURL or "")
        local widthEntry = AddFormEntry(form, "Scoreboard width", cfg.Width or defaultScoreConfig.Width)
        local creditsCheck = AddFormCheck(form, "Enable credit/shop system", cfg.CreditsEnabled ~= false)
        local shopCheck = AddFormCheck(form, "Show shop button for players", cfg.ShowShop ~= false)
        local searchCheck = AddFormCheck(form, "Show player search bar", cfg.ShowSearch ~= false)
        local moneyCheck = AddFormCheck(form, "Show money column", cfg.ShowMoney ~= false)
        local repCheck = AddFormCheck(form, "Enable player rep buttons", cfg.RepEnabled ~= false)

        AddTrackSlider(form, "Header image scale", cfg.HeaderIconScale or 1, 0.5, 1.8, function(value)
            cfg.HeaderIconScale = value
            return value
        end)

        local buttons = vgui.Create("DPanel", form)
        buttons:Dock(TOP)
        buttons:SetTall(32)
        buttons:SetPaintBackground(false)

        AddMenuButton(buttons, "Save Basic", Primary(), function()
            cfg.HeaderTitle = titleEntry:GetValue()
            cfg.HeaderSubtitle = subtitleEntry:GetValue()
            cfg.HeaderIcon = iconEntry:GetValue()
            cfg.HeaderIconURL = urlEntry:GetValue()
            cfg.Width = math.Clamp(tonumber(widthEntry:GetValue()) or cfg.Width or defaultScoreConfig.Width, 720, 1120)
            cfg.CreditsEnabled = creditsCheck:GetChecked()
            DHUD.Config.Credits = DHUD.Config.Credits or {}
            DHUD.Config.Credits.Enabled = cfg.CreditsEnabled
            cfg.ShowShop = shopCheck:GetChecked()
            cfg.ShowSearch = searchCheck:GetChecked()
            cfg.ShowMoney = moneyCheck:GetChecked()
            cfg.RepEnabled = repCheck:GetChecked()
            headerIconURL = nil
            headerIconMaterial = nil
            SaveAndStay()
        end)

        AddMenuButton(buttons, "Reset All", (DHUD.Config and DHUD.Config.Colors and DHUD.Config.Colors.Warning) or Color(238, 146, 80), function()
            ResetScoreCfg()
            SetScoreboardView("settings")
        end)
        return
    end

    if settingsTab == "layout" then
        form:SetTall(500)
        local rowGapEntry = AddFormEntry(form, "Player row gap", cfg.RowGap or defaultScoreConfig.RowGap)
        local shadowCheck = AddFormCheck(form, "Player card shadow", cfg.PlayerCardShadow ~= false)
        local columns = cfg.Columns or columnDefaults

        for _, key in ipairs(cfg.ColumnOrder or defaultScoreConfig.ColumnOrder) do
            AddTrackSlider(form, key .. " column", columns[key] or columnDefaults[key], 0.24, 0.96, function(value)
                local nextValue = ClampColumn(cfg, key, value)
                columns[key] = nextValue
                return nextValue
            end)
        end

        AddFormLabel(form, "Column draw order")
        local orderEntry = AddFormEntry(form, "Left to right: Jobs,Staff,Cash,Ping", table.concat(cfg.ColumnOrder or defaultScoreConfig.ColumnOrder, ","))

        local buttons = vgui.Create("DPanel", form)
        buttons:Dock(TOP)
        buttons:SetTall(32)
        buttons:SetPaintBackground(false)

        AddMenuButton(buttons, "Save Layout", Primary(), function()
            cfg.RowGap = math.Clamp(tonumber(rowGapEntry:GetValue()) or cfg.RowGap or defaultScoreConfig.RowGap, 0, 10)
            cfg.PlayerCardShadow = shadowCheck:GetChecked()

            local newOrder = {}
            for token in string.gmatch(orderEntry:GetValue() or "", "([^,%s]+)") do
                if columnDefaults[token] then newOrder[#newOrder + 1] = token end
            end
            if #newOrder > 0 then cfg.ColumnOrder = newOrder end
            SaveAndStay()
        end)
        return
    end

    if settingsTab == "ranks" then
        form:SetTall(980)
        AddFormLabel(form, "Rank display overrides")
        local rankEntries = {}
        local rankDefaults = {
            user = {Label = "User", Hex = "#A0A0A0"},
            vip = {Label = "VIP", Hex = "#E8B04D"},
            trialmod = {Label = "Trial Mod", Hex = "#7AA6FF"},
            trialadmin = {Label = "Trial Admin", Hex = "#7AA6FF"},
            admin = {Label = "Admin", Hex = "#E8B04D"},
            headadmin = {Label = "Head Admin", Hex = "#E8B04D"},
            owner = {Label = "Owner", Hex = "#E85B5B"}
        }

        for _, group in ipairs({"user", "vip", "trialmod", "trialadmin", "admin", "headadmin", "owner"}) do
            local data = cfg.RankDisplay and cfg.RankDisplay[group] or {}
            local fallback = HexToColor(rankDefaults[group].Hex, rankColors[group] or Accent())
            local col = TableColor(data.Color, fallback)

            local card = vgui.Create("DPanel", form)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, 10)
            card:SetTall(142)
            card.Paint = function(_, pw, ph)
                draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
                DrawText(group, LibFont("Small", "DermaDefault"), 12, 9, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local nameEntry = vgui.Create("DTextEntry", card)
            nameEntry:SetPos(12, 28)
            nameEntry:SetSize(190, 28)
            nameEntry:SetText(data.Name or rankDefaults[group].Label)
            StyleTextEntry(nameEntry)

            local hexEntry = vgui.Create("DTextEntry", card)
            hexEntry:SetPos(212, 28)
            hexEntry:SetSize(92, 28)
            hexEntry:SetText(ColorToHex(col))
            StyleTextEntry(hexEntry)

            local preview = vgui.Create("DPanel", card)
            preview:SetPos(314, 28)
            preview:SetSize(118, 28)
            preview.Paint = function(_, pw, ph)
                local previewCol = HexToColor(hexEntry:GetValue(), col)
                draw.RoundedBox(Radius("SM"), 0, 0, pw, ph, ButtonBase(255))
                DrawText(FitText(nameEntry:GetValue(), LibFont("Small", "DermaDefault"), pw - 12), LibFont("Small", "DermaDefault"), pw * 0.5, ph * 0.5 - 1, previewCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            local mixer = vgui.Create("DColorMixer", card)
            mixer:SetPos(12, 62)
            mixer:SetSize(420, 70)
            mixer:SetPalette(false)
            mixer:SetAlphaBar(false)
            mixer:SetWangs(true)
            mixer:SetColor(col)
            mixer.ValueChanged = function(_, newColor)
                hexEntry:SetText(ColorToHex(newColor))
            end

            hexEntry.OnEnter = function()
                mixer:SetColor(HexToColor(hexEntry:GetValue(), col))
            end
            hexEntry.OnLoseFocus = function()
                mixer:SetColor(HexToColor(hexEntry:GetValue(), col))
                hexEntry:SetText(ColorToHex(HexToColor(hexEntry:GetValue(), col)))
            end

            rankEntries[group] = {Name = nameEntry, Hex = hexEntry, Mixer = mixer}
        end

        local buttons = vgui.Create("DPanel", form)
        buttons:Dock(TOP)
        buttons:SetTall(32)
        buttons:SetPaintBackground(false)

        AddMenuButton(buttons, "Save Ranks", Primary(), function()
            cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or {}
            for group, entries in next, (rankEntries) do
                local selected = HexToColor(entries.Hex:GetValue(), entries.Mixer:GetColor())
                cfg.RankDisplay[group] = {
                    Name = entries.Name:GetValue(),
                    Color = {r = selected.r, g = selected.g, b = selected.b}
                }
            end
            SaveAndStay()
        end)
        return
    end

    if settingsTab == "drawer" then
        form:SetTall(500)
        local drawerOrderEntry = AddFormMultiEntry(form, "Drawer button IDs shown left to right. Remove an ID to hide it.", DrawerActionOrderText(cfg), 48)
        AddFormLabel(form, "Built-in IDs: copy, profile, mute, goto, freeze, jail, kick, ban")
        local customLabelEntry = AddFormEntry(form, "Add custom drawer button label", "")
        local customIconEntry = AddFormEntry(form, "Custom icon path", "misc/bolt")
        local customCommandEntry = AddFormEntry(form, "Custom command. Tokens: %steamid%, %steamid64%, %nick%", "")
        local customAdminCheck = AddFormCheck(form, "Custom button is admin only", true)
        local customToggleCheck = AddFormCheck(form, "Custom button is a toggle", false)
        local customToggleLabelEntry = AddFormEntry(form, "Toggle-on label, like Unfreeze or Unjail", "")
        local customToggleCommandEntry = AddFormEntry(form, "Toggle-on command", "")

        local buttons = vgui.Create("DPanel", form)
        buttons:Dock(TOP)
        buttons:SetTall(32)
        buttons:SetPaintBackground(false)

        AddMenuButton(buttons, "Save Drawer", Primary(), function()
            local actionOrder = ParseDrawerActionOrder(drawerOrderEntry:GetValue())
            if #actionOrder > 0 then cfg.DrawerActionOrder = actionOrder end
            AddCustomDrawerAction(
                cfg,
                customLabelEntry:GetValue(),
                customIconEntry:GetValue(),
                customCommandEntry:GetValue(),
                customAdminCheck:GetChecked(),
                customToggleCheck:GetChecked(),
                customToggleLabelEntry:GetValue(),
                customToggleCommandEntry:GetValue()
            )
            SaveAndStay()
        end)
        return
    end

    if settingsTab == "motd" then
        form:SetTall(940)
        local motd = istable(cfg.MOTD) and cfg.MOTD or table.Copy(defaultScoreConfig.MOTD or {})
        local buttons = istable(motd.Buttons) and motd.Buttons or {}

        local enabledCheck = AddFormCheck(form, "Enable MOTD", motd.Enabled ~= false)
        local joinCheck = AddFormCheck(form, "Show MOTD on join", motd.ShowOnJoin ~= false)
        local titleEntry = AddFormEntry(form, "MOTD title", motd.Title or "")
        local iconEntry = AddFormEntry(form, "MOTD image/icon path", motd.Icon or "communication/notifications")
        local subtitleEntry = AddFormEntry(form, "MOTD subtitle", motd.Subtitle or "")
        local updatesEntry = AddFormMultiEntry(form, "Server updates, one line per row", table.concat(motd.ServerUpdates or {}, "\n"), 78)
        local bodyEntry = AddFormMultiEntry(form, "Rules, one line per row", table.concat(motd.Body or {}, "\n"), 120)

        AddFormLabel(form, "Bottom buttons")
        local buttonEntries = {}
        for index = 1, 5 do
            local data = buttons[index] or {}
            local card = vgui.Create("DPanel", form)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, 10)
            card:SetTall(92)
            card.Paint = function(_, pw, ph)
                draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
                DrawText("Button " .. index, LibFont("Small", "DermaDefault"), 12, 8, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local enabled = vgui.Create("DCheckBoxLabel", card)
            enabled:SetPos(12, 30)
            enabled:SetText("Enabled")
            enabled:SetFont(LibFont("Small", "DermaDefault"))
            enabled:SetTextColor(LibColor("Foreground", color_white))
            enabled:SetValue(data.Enabled ~= false and 1 or 0)

            local label = vgui.Create("DTextEntry", card)
            label:SetPos(105, 28)
            label:SetSize(130, 28)
            label:SetText(data.Label or (index == 5 and "Close" or ""))
            StyleTextEntry(label)

            local url = vgui.Create("DTextEntry", card)
            url:SetPos(245, 28)
            url:SetSize(300, 28)
            url:SetText(data.URL or "")
            StyleTextEntry(url)

            local action = vgui.Create("DTextEntry", card)
            action:SetPos(555, 28)
            action:SetSize(86, 28)
            action:SetText(data.Action or (index == 5 and "close" or "url"))
            StyleTextEntry(action)

            buttonEntries[index] = {Enabled = enabled, Label = label, URL = url, Action = action}
        end

        local save = vgui.Create("DPanel", form)
        save:Dock(TOP)
        save:SetTall(32)
        save:SetPaintBackground(false)

        local function LinesFromText(text)
            local out = {}
            for line in string.gmatch(tostring(text or ""), "([^\n]+)") do
                line = string.Trim(line)
                if line ~= "" then out[#out + 1] = line end
            end
            return out
        end

        AddMenuButton(save, "Save MOTD", Primary(), function()
            cfg.MOTD = {
                Enabled = enabledCheck:GetChecked(),
                ShowOnJoin = joinCheck:GetChecked(),
                Width = 820,
                Height = 540,
                Shadow = motd.Shadow ~= false,
                ShadowAlpha = tonumber(motd.ShadowAlpha) or 92,
                Title = titleEntry:GetValue(),
                Icon = iconEntry:GetValue(),
                Subtitle = subtitleEntry:GetValue(),
                Body = LinesFromText(bodyEntry:GetValue()),
                ServerUpdates = LinesFromText(updatesEntry:GetValue()),
                Buttons = {}
            }

            for index, entry in ipairs(buttonEntries) do
                cfg.MOTD.Buttons[index] = {
                    Enabled = entry.Enabled:GetChecked(),
                    Label = entry.Label:GetValue(),
                    URL = entry.URL:GetValue(),
                    Action = entry.Action:GetValue()
                }
            end

            DHUD.Config.MOTD = table.Copy(cfg.MOTD)
            SaveAndStay()
        end)

        AddMenuButton(save, "Preview", Primary(), function()
            DHUD.Config.MOTD = table.Copy(cfg.MOTD)
            if DHUD.MOTD and DHUD.MOTD.Open then
                DHUD.MOTD.Open()
            end
        end)
        return
    end

    form:SetTall(1380)
    local shopTitleEntry = AddFormEntry(form, "Shop header title", cfg.ShopTitle or "Credit Shop")
    local shopSubtitleEntry = AddFormEntry(form, "Shop header subtitle", cfg.ShopSubtitle or "")
    local shopCurrencyNameEntry = AddFormEntry(form, "Currency display name", cfg.ShopCurrencyName or "Credits")
    local shopCurrencyModeEntry = AddFormEntry(form, "Currency mode: darkrp, custom, none", cfg.ShopCurrencyMode or "darkrp")
    local shopCurrencyGetEntry = AddFormEntry(form, "Custom currency balance function / path", cfg.ShopCurrencyGet or "")
    local shopCurrencyTakeEntry = AddFormEntry(form, "Custom currency take function / path", cfg.ShopCurrencyTake or "")

    AddTrackSlider(form, "Shop grid columns", cfg.ShopGridColumns or 2, 1, 4, function(value)
        cfg.ShopGridColumns = math.Round(value)
        return cfg.ShopGridColumns
    end)

    AddFormLabel(form, "Credit shop listing")
    local listingTitleEntry = AddFormEntry(form, "Listing name", "")
    local listingPriceEntry = AddFormEntry(form, "Listing price", "$0")
    local listingCurrencyEntry = AddFormEntry(form, "Listing currency name", cfg.ShopCurrencyName or "Credits")
    local listingImageEntry = AddFormEntry(form, "Listing Imgur image URL or key", "")
    local listingTypeEntry = AddFormEntry(form, "Listing type: profile, weapon, entity, model", "profile")
    local listingClassEntry = AddFormEntry(form, "Weapon/entity class", "")
    local listingModelEntry = AddFormEntry(form, "Preview model path", "")
    local listingPublicCheck = AddFormCheck(form, "Listing is public", true)

    local classSearchEntry = AddFormEntry(form, "Search available weapon/entity classes", "")
    local classList = vgui.Create("DPanel", form)
    classList:Dock(TOP)
    classList:DockMargin(0, 0, 0, 10)
    classList:SetTall(150)
    classList:SetPaintBackground(false)

    local function RebuildClassList(_, value)
        if value ~= nil and IsValid(classSearchEntry) and classSearchEntry:GetValue() ~= tostring(value or "") then
            classSearchEntry:SetText(tostring(value or ""))
        end

        for _, child in ipairs(classList:GetChildren()) do
            child:Remove()
        end

        local filter = string.lower(string.Trim(classSearchEntry:GetValue() or ""))
        local count = 0
        for _, item in ipairs(AvailableShopClasses()) do
            local haystack = string.lower((item.Name or "") .. " " .. (item.Class or "") .. " " .. (item.Type or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                local btn = vgui.Create("DButton", classList)
                StyleButton(btn)
                btn:Dock(TOP)
                btn:DockMargin(0, 0, 0, 4)
                btn:SetTall(24)
                btn.Hover = 0
                btn.Paint = function(self, bw, bh)
                    HandleHoverSound(self)
                    self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
                    draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, ButtonBase(255))
                    if self.Hover > 0.01 then
                        draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, WithAlpha(Primary(), 18 + self.Hover * 28))
                    end
                    DrawText(FitText((item.Type or "item") .. " - " .. (item.Name or item.Class), LibFont("Small", "DermaDefault"), bw - 170), LibFont("Small", "DermaDefault"), 8, bh * 0.5, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    DrawText(FitText(item.Class or "", LibFont("Small", "DermaDefault"), 150), LibFont("Small", "DermaDefault"), bw - 8, bh * 0.5, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                btn.DoClick = function()
                    listingTypeEntry:SetText(item.Type or "entity")
                    listingClassEntry:SetText(item.Class or "")
                    listingModelEntry:SetText(item.Model or "")
                    if listingTitleEntry:GetValue() == "" then
                        listingTitleEntry:SetText(item.Name or item.Class or "")
                    end
                end

                count = count + 1
                if count >= 5 then break end
            end
        end
    end
    classSearchEntry.OnValueChange = RebuildClassList
    RebuildClassList()

    local listingsPanel = vgui.Create("DPanel", form)
    listingsPanel:Dock(TOP)
    listingsPanel:DockMargin(0, 0, 0, 12)
    listingsPanel:SetTall(math.max(60, #(cfg.ShopListings or {}) * 58))
    listingsPanel:SetPaintBackground(false)

    for index, listing in ipairs(cfg.ShopListings or {}) do
        local card = vgui.Create("DPanel", listingsPanel)
        card:Dock(TOP)
        card:DockMargin(0, 0, 0, 8)
        card:SetTall(50)
        card.Paint = function(_, pw, ph)
            local status = listing.Public ~= false and "Public" or "Hidden"
            local statusCol = listing.Public ~= false and Color(91, 201, 121) or Color(238, 146, 80)

            draw.RoundedBox(CardRadius(), 1, 2, pw - 2, ph - 2, Shadow(34))
            draw.RoundedBox(CardRadius(), 0, 0, pw, ph - 2, CardBase(255))
            DrawText(FitText(listing.Title or "Profile Photo", LibFont("Body", "DermaDefaultBold"), pw - 220), LibFont("Body", "DermaDefaultBold"), 14, 8, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawText((listing.Price or "$0") .. "  -  " .. status, LibFont("Small", "DermaDefault"), 14, 29, statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local edit = AddListingToolButton(card, "actions/edit_square", function()
            form.EditListingIndex = index
            listingTitleEntry:SetText(listing.Title or "")
            listingPriceEntry:SetText(listing.Price or "$0")
            listingCurrencyEntry:SetText(listing.Currency or cfg.ShopCurrencyName or "Credits")
            listingImageEntry:SetText(listing.ImageURL or "")
            listingTypeEntry:SetText(listing.ItemType or "profile")
            listingClassEntry:SetText(listing.Class or "")
            listingModelEntry:SetText(listing.Model or "")
            listingPublicCheck:SetValue(listing.Public ~= false and 1 or 0)
        end, "Edit")

        local toggle = AddListingToolButton(card, listing.Public ~= false and "actions/cancel" or "actions/check", function()
            listing.Public = not (listing.Public ~= false)
            SaveAndStay()
        end, listing.Public ~= false and "Hide" or "Publish", listing.Public ~= false and Color(238, 146, 80) or Color(91, 201, 121))

        local delete = AddListingToolButton(card, "actions/delete", function()
            table.remove(cfg.ShopListings, index)
            SaveAndStay()
        end, "Delete", Color(232, 84, 84))

        card.PerformLayout = function(_, pw)
            delete:SetPos(pw - 38, 10)
            toggle:SetPos(pw - 70, 10)
            edit:SetPos(pw - 102, 10)
        end
    end

    local buttons = vgui.Create("DPanel", form)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)

    AddMenuButton(buttons, "Create Listing", Primary(), function()
        SaveShopListing(
            cfg,
            form.EditListingIndex,
            listingTitleEntry:GetValue(),
            listingPriceEntry:GetValue(),
            listingImageEntry:GetValue(),
            listingPublicCheck:GetChecked(),
            listingTypeEntry:GetValue(),
            listingClassEntry:GetValue(),
            listingModelEntry:GetValue(),
            listingCurrencyEntry:GetValue()
        )

        form.EditListingIndex = nil
        SaveAndStay()
    end)

    AddMenuButton(buttons, "Save Shop", Primary(), function()
        cfg.ShopTitle = shopTitleEntry:GetValue()
        cfg.ShopSubtitle = shopSubtitleEntry:GetValue()
        cfg.ShopCurrencyName = shopCurrencyNameEntry:GetValue()
        cfg.ShopCurrencyMode = shopCurrencyModeEntry:GetValue()
        cfg.ShopCurrencyGet = shopCurrencyGetEntry:GetValue()
        cfg.ShopCurrencyTake = shopCurrencyTakeEntry:GetValue()
        cfg.ShopGridColumns = math.Clamp(math.Round(tonumber(cfg.ShopGridColumns or 2) or 2), 1, 4)
        SaveAndStay()
    end)
end

local function BuildSettingsViewLegacy(w, h, cfg)
    local intro = vgui.Create("DPanel", frame)
    intro.DHUDContent = true
    intro:SetPos(24, 98)
    intro:SetSize(w - 48, 48)
    intro.Paint = function(_, pw, ph)
        draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
        DrawText("Scoreboard Customization", LibFont("Header", "DermaDefaultBold"), 50, 8, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawText("Paste a full Imgur URL or just the image key. The HUD will clean it up.", LibFont("Small", "DermaDefault"), 50, 31, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    local settingsBack = AddIconButton(intro, "actions/back", function()
        SetScoreboardView("players")
    end, "Back")
    settingsBack:SetPos(12, 10)

    local body = vgui.Create("DScrollPanel", frame)
    body.DHUDContent = true
    body:SetPos(24, 158)
    body:SetSize(w - 48, h - 178)
    StyleScroll(body)

    local form = vgui.Create("DPanel", body)
    form:Dock(TOP)
    form:SetTall(2450)
    form:SetPaintBackground(false)

    local titleEntry = AddFormEntry(form, "Header title", cfg.HeaderTitle or "")
    local subtitleEntry = AddFormEntry(form, "Header subtitle", cfg.HeaderSubtitle or "")
    local iconEntry = AddFormEntry(form, "Local icon path", cfg.HeaderIcon or "misc/groups")
    local urlEntry = AddFormEntry(form, "Imgur image URL or key / ID", cfg.HeaderIconURL or "")
    local widthEntry = AddFormEntry(form, "Width", cfg.Width or defaultScoreConfig.Width)
    local rowGapEntry = AddFormEntry(form, "Player row gap", cfg.RowGap or defaultScoreConfig.RowGap)
    local moneyCheck = AddFormCheck(form, "Show money column", cfg.ShowMoney ~= false)
    local shopCheck = AddFormCheck(form, "Show shop button for players", cfg.ShowShop ~= false)
    local searchCheck = AddFormCheck(form, "Show player search bar", cfg.ShowSearch ~= false)
    local repCheck = AddFormCheck(form, "Enable player rep buttons", cfg.RepEnabled ~= false)
    local shadowCheck = AddFormCheck(form, "Player card shadow", cfg.PlayerCardShadow ~= false)
    local shopTitleEntry = AddFormEntry(form, "Shop header title", cfg.ShopTitle or "Credit Shop")
    local shopSubtitleEntry = AddFormEntry(form, "Shop header subtitle", cfg.ShopSubtitle or "")
    local shopCurrencyNameEntry = AddFormEntry(form, "Currency display name", cfg.ShopCurrencyName or "Credits")
    local shopCurrencyModeEntry = AddFormEntry(form, "Currency mode: darkrp, custom, none", cfg.ShopCurrencyMode or "darkrp")
    local shopCurrencyGetEntry = AddFormEntry(form, "Custom currency balance function / path", cfg.ShopCurrencyGet or "")
    local shopCurrencyTakeEntry = AddFormEntry(form, "Custom currency take function / path", cfg.ShopCurrencyTake or "")

    AddTrackSlider(form, "Header image scale", cfg.HeaderIconScale or 1, 0.5, 1.8, function(value)
        cfg.HeaderIconScale = value
        return value
    end)

    local columns = cfg.Columns or columnDefaults
    for _, key in ipairs(cfg.ColumnOrder or defaultScoreConfig.ColumnOrder) do
        AddTrackSlider(form, key .. " column", columns[key] or columnDefaults[key], 0.24, 0.96, function(value)
            local nextValue = ClampColumn(cfg, key, value)
            columns[key] = nextValue
            return nextValue
        end)
    end

    AddFormLabel(form, "Column draw order")
    local orderEntry = AddFormEntry(form, "Left to right: Jobs,Staff,Cash,Ping", table.concat(cfg.ColumnOrder or defaultScoreConfig.ColumnOrder, ","))
    local drawerOrderEntry = AddFormMultiEntry(form, "Drawer button IDs shown left to right. Remove an ID to hide it.", DrawerActionOrderText(cfg), 48)
    AddFormLabel(form, "Built-in IDs: copy, profile, goto, freeze, jail, kick, ban")
    local customLabelEntry = AddFormEntry(form, "Add custom drawer button label", "")
    local customIconEntry = AddFormEntry(form, "Custom icon path", "misc/bolt")
    local customCommandEntry = AddFormEntry(form, "Custom command. Tokens: %steamid%, %steamid64%, %nick%", "")
    local customAdminCheck = AddFormCheck(form, "Custom button is admin only", true)
    local customToggleCheck = AddFormCheck(form, "Custom button is a toggle", false)
    local customToggleLabelEntry = AddFormEntry(form, "Toggle-on label, like Unfreeze or Unjail", "")
    local customToggleCommandEntry = AddFormEntry(form, "Toggle-on command", "")

    AddFormLabel(form, "Rank display overrides")
    local rankEntries = {}
    local rankDefaults = {
        user = {Label = "User", Hex = "#A0A0A0"},
        vip = {Label = "VIP", Hex = "#E8B04D"},
        trialmod = {Label = "Trial Mod", Hex = "#7AA6FF"},
        trialadmin = {Label = "Trial Admin", Hex = "#7AA6FF"},
        admin = {Label = "Admin", Hex = "#E8B04D"},
        headadmin = {Label = "Head Admin", Hex = "#E8B04D"},
        owner = {Label = "Owner", Hex = "#E85B5B"}
    }

    for _, group in ipairs({"user", "vip", "trialmod", "trialadmin", "admin", "headadmin", "owner"}) do
        local data = cfg.RankDisplay and cfg.RankDisplay[group] or {}
        local fallback = HexToColor(rankDefaults[group].Hex, rankColors[group] or Accent())
        local col = TableColor(data.Color, fallback)

        local card = vgui.Create("DPanel", form)
        card:Dock(TOP)
        card:DockMargin(0, 0, 0, 10)
        card:SetTall(142)
        card.Paint = function(_, pw, ph)
            draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
            DrawText(group, LibFont("Small", "DermaDefault"), 12, 9, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local nameEntry = vgui.Create("DTextEntry", card)
        nameEntry:SetPos(12, 28)
        nameEntry:SetSize(190, 28)
        nameEntry:SetText(data.Name or rankDefaults[group].Label)
        StyleTextEntry(nameEntry)

        local hexEntry = vgui.Create("DTextEntry", card)
        hexEntry:SetPos(212, 28)
        hexEntry:SetSize(92, 28)
        hexEntry:SetText(ColorToHex(col))
        StyleTextEntry(hexEntry)

        local preview = vgui.Create("DPanel", card)
        preview:SetPos(314, 28)
        preview:SetSize(118, 28)
        preview.Paint = function(_, pw, ph)
            local previewCol = HexToColor(hexEntry:GetValue(), col)
            draw.RoundedBox(Radius("SM"), 0, 0, pw, ph, ButtonBase(255))
            DrawText(FitText(nameEntry:GetValue(), LibFont("Small", "DermaDefault"), pw - 12), LibFont("Small", "DermaDefault"), pw * 0.5, ph * 0.5 - 1, previewCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local mixer = vgui.Create("DColorMixer", card)
        mixer:SetPos(12, 62)
        mixer:SetSize(420, 70)
        mixer:SetPalette(false)
        mixer:SetAlphaBar(false)
        mixer:SetWangs(true)
        mixer:SetColor(col)
        mixer.ValueChanged = function(_, newColor)
            hexEntry:SetText(ColorToHex(newColor))
        end

        hexEntry.OnEnter = function()
            mixer:SetColor(HexToColor(hexEntry:GetValue(), col))
        end
        hexEntry.OnLoseFocus = function()
            mixer:SetColor(HexToColor(hexEntry:GetValue(), col))
            hexEntry:SetText(ColorToHex(HexToColor(hexEntry:GetValue(), col)))
        end

        rankEntries[group] = {
            Name = nameEntry,
            Hex = hexEntry,
            Mixer = mixer
        }
    end

    AddFormLabel(form, "Credit shop listing")
    local listingTitleEntry = AddFormEntry(form, "Listing name", "")
    local listingPriceEntry = AddFormEntry(form, "Listing price", "$0")
    local listingCurrencyEntry = AddFormEntry(form, "Listing currency name", cfg.ShopCurrencyName or "Credits")
    local listingImageEntry = AddFormEntry(form, "Listing Imgur image URL or key", "")
    local listingTypeEntry = AddFormEntry(form, "Listing type: profile, weapon, entity, model", "profile")
    local listingClassEntry = AddFormEntry(form, "Weapon/entity class", "")
    local listingModelEntry = AddFormEntry(form, "Preview model path", "")
    local listingPublicCheck = AddFormCheck(form, "Listing is public", true)

    local classSearchEntry = AddFormEntry(form, "Search available weapon/entity classes", "")
    local classList = vgui.Create("DPanel", form)
    classList:Dock(TOP)
    classList:DockMargin(0, 0, 0, 10)
    classList:SetTall(150)
    classList:SetPaintBackground(false)

    local function RebuildClassList(_, value)
        if value ~= nil and IsValid(classSearchEntry) and classSearchEntry:GetValue() ~= tostring(value or "") then
            classSearchEntry:SetText(tostring(value or ""))
        end

        for _, child in ipairs(classList:GetChildren()) do
            child:Remove()
        end

        local filter = string.lower(string.Trim(classSearchEntry:GetValue() or ""))
        local count = 0
        for _, item in ipairs(AvailableShopClasses()) do
            local haystack = string.lower((item.Name or "") .. " " .. (item.Class or "") .. " " .. (item.Type or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                local btn = vgui.Create("DButton", classList)
                StyleButton(btn)
                btn:Dock(TOP)
                btn:DockMargin(0, 0, 0, 4)
                btn:SetTall(24)
                btn.Hover = 0
                btn.Paint = function(self, bw, bh)
                    HandleHoverSound(self)
                    self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
                    draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, ButtonBase(255))
                    if self.Hover > 0.01 then
                        draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, WithAlpha(Primary(), 18 + self.Hover * 28))
                    end
                    DrawText(FitText((item.Type or "item") .. " - " .. (item.Name or item.Class), LibFont("Small", "DermaDefault"), bw - 170), LibFont("Small", "DermaDefault"), 8, bh * 0.5, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    DrawText(FitText(item.Class or "", LibFont("Small", "DermaDefault"), 150), LibFont("Small", "DermaDefault"), bw - 8, bh * 0.5, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                btn.DoClick = function()
                    listingTypeEntry:SetText(item.Type or "entity")
                    listingClassEntry:SetText(item.Class or "")
                    listingModelEntry:SetText(item.Model or "")
                    if listingTitleEntry:GetValue() == "" then
                        listingTitleEntry:SetText(item.Name or item.Class or "")
                    end
                end

                count = count + 1
                if count >= 5 then break end
            end
        end
    end
    classSearchEntry.OnValueChange = RebuildClassList
    RebuildClassList()

    local listingsPanel = vgui.Create("DPanel", body)
    listingsPanel:Dock(TOP)
    listingsPanel:DockMargin(0, 0, 0, 12)
    listingsPanel:SetTall(math.max(60, #(cfg.ShopListings or {}) * 58))
    listingsPanel:SetPaintBackground(false)

    for index, listing in ipairs(cfg.ShopListings or {}) do
        local card = vgui.Create("DPanel", listingsPanel)
        card:Dock(TOP)
        card:DockMargin(0, 0, 0, 8)
        card:SetTall(50)
        card.Paint = function(_, pw, ph)
            local status = listing.Public ~= false and "Public" or "Hidden"
            local statusCol = listing.Public ~= false and Color(91, 201, 121) or Color(238, 146, 80)

            draw.RoundedBox(CardRadius(), 1, 2, pw - 2, ph - 2, Shadow(34))
            draw.RoundedBox(CardRadius(), 0, 0, pw, ph - 2, CardBase(255))
            DrawText(FitText(listing.Title or "Profile Photo", LibFont("Body", "DermaDefaultBold"), pw - 220), LibFont("Body", "DermaDefaultBold"), 14, 8, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawText((listing.Price or "$0") .. "  -  " .. status, LibFont("Small", "DermaDefault"), 14, 29, statusCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local edit = AddListingToolButton(card, "actions/edit_square", function()
            form.EditListingIndex = index
            listingTitleEntry:SetText(listing.Title or "")
            listingPriceEntry:SetText(listing.Price or "$0")
            listingCurrencyEntry:SetText(listing.Currency or cfg.ShopCurrencyName or "Credits")
            listingImageEntry:SetText(listing.ImageURL or "")
            listingTypeEntry:SetText(listing.ItemType or "profile")
            listingClassEntry:SetText(listing.Class or "")
            listingModelEntry:SetText(listing.Model or "")
            listingPublicCheck:SetValue(listing.Public ~= false and 1 or 0)
        end, "Edit")

        local toggle = AddListingToolButton(card, listing.Public ~= false and "actions/cancel" or "actions/check", function()
            listing.Public = not (listing.Public ~= false)
            SaveScoreCfg()
            SetScoreboardView("settings")
        end, listing.Public ~= false and "Hide" or "Publish", listing.Public ~= false and Color(238, 146, 80) or Color(91, 201, 121))

        local delete = AddListingToolButton(card, "actions/delete", function()
            table.remove(cfg.ShopListings, index)
            SaveScoreCfg()
            SetScoreboardView("settings")
        end, "Delete", Color(232, 84, 84))

        card.PerformLayout = function(_, pw)
            delete:SetPos(pw - 38, 10)
            toggle:SetPos(pw - 70, 10)
            edit:SetPos(pw - 102, 10)
        end
    end

    local buttons = vgui.Create("DPanel", body)
    buttons:Dock(TOP)
    buttons:SetTall(32)
    buttons:SetPaintBackground(false)

    AddMenuButton(buttons, "Create Listing", Primary(), function()
        SaveShopListing(
            cfg,
            form.EditListingIndex,
            listingTitleEntry:GetValue(),
            listingPriceEntry:GetValue(),
            listingImageEntry:GetValue(),
            listingPublicCheck:GetChecked(),
            listingTypeEntry:GetValue(),
            listingClassEntry:GetValue(),
            listingModelEntry:GetValue(),
            listingCurrencyEntry:GetValue()
        )

        form.EditListingIndex = nil
        SaveScoreCfg()
        SetScoreboardView("settings")
    end)

    AddMenuButton(buttons, "Save Settings", Primary(), function()
        cfg.HeaderTitle = titleEntry:GetValue()
        cfg.HeaderSubtitle = subtitleEntry:GetValue()
        cfg.HeaderIcon = iconEntry:GetValue()
        cfg.HeaderIconURL = urlEntry:GetValue()
        cfg.Width = math.Clamp(tonumber(widthEntry:GetValue()) or cfg.Width or defaultScoreConfig.Width, 720, 1120)
        cfg.RowGap = math.Clamp(tonumber(rowGapEntry:GetValue()) or cfg.RowGap or defaultScoreConfig.RowGap, 0, 10)
        cfg.ShowMoney = moneyCheck:GetChecked()
        cfg.ShowShop = shopCheck:GetChecked()
        cfg.ShowSearch = searchCheck:GetChecked()
        cfg.RepEnabled = repCheck:GetChecked()
        cfg.PlayerCardShadow = shadowCheck:GetChecked()
        cfg.ShopTitle = shopTitleEntry:GetValue()
        cfg.ShopSubtitle = shopSubtitleEntry:GetValue()
        cfg.ShopCurrencyName = shopCurrencyNameEntry:GetValue()
        cfg.ShopCurrencyMode = shopCurrencyModeEntry:GetValue()
        cfg.ShopCurrencyGet = shopCurrencyGetEntry:GetValue()
        cfg.ShopCurrencyTake = shopCurrencyTakeEntry:GetValue()

        local newOrder = {}
        for token in string.gmatch(orderEntry:GetValue() or "", "([^,%s]+)") do
            if columnDefaults[token] then newOrder[#newOrder + 1] = token end
        end
        if #newOrder > 0 then cfg.ColumnOrder = newOrder end

        local actionOrder = ParseDrawerActionOrder(drawerOrderEntry:GetValue())
        if #actionOrder > 0 then cfg.DrawerActionOrder = actionOrder end

        AddCustomDrawerAction(
            cfg,
            customLabelEntry:GetValue(),
            customIconEntry:GetValue(),
            customCommandEntry:GetValue(),
            customAdminCheck:GetChecked(),
            customToggleCheck:GetChecked(),
            customToggleLabelEntry:GetValue(),
            customToggleCommandEntry:GetValue()
        )
        cfg.RankDisplay = istable(cfg.RankDisplay) and cfg.RankDisplay or {}
        for group, entries in next, (rankEntries) do
            local selected = HexToColor(entries.Hex:GetValue(), entries.Mixer:GetColor())
            cfg.RankDisplay[group] = {
                Name = entries.Name:GetValue(),
                Color = {
                    r = selected.r,
                    g = selected.g,
                    b = selected.b
                }
            }
        end
        NormalizeDrawerActions(cfg)

        headerIconURL = nil
        headerIconMaterial = nil
        SaveScoreCfg()
        SetScoreboardView("players")
    end)

    AddMenuButton(buttons, "Reset", (DHUD.Config and DHUD.Config.Colors and DHUD.Config.Colors.Warning) or Color(238, 146, 80), function()
        ResetScoreCfg()
        SetScoreboardView("settings")
    end)

end

local function BuildShopView(w, h, cfg)
    local intro = vgui.Create("DPanel", frame)
    intro.DHUDContent = true
    intro:SetPos(24, 98)
    intro:SetSize(w - 48, 52)
    intro.Paint = function(_, pw, ph)
        draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
        DrawText(cfg.ShopTitle or "Credit Shop", LibFont("Header", "DermaDefaultBold"), 50, 9, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawText(cfg.ShopSubtitle or "Server items, perks, and profile extras.", LibFont("Small", "DermaDefault"), 50, 33, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    local shopBack = AddIconButton(intro, "actions/back", function()
        SetScoreboardView("players")
    end, "Back")
    shopBack:SetPos(12, 12)

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll.DHUDContent = true
    scroll:SetPos(24, 162)
    scroll:SetSize(w - 48, h - 182)
    StyleScroll(scroll)

    local listings = {}
    if not CreditsEnabled(cfg) then
        local disabled = vgui.Create("DPanel", frame)
        disabled.DHUDContent = true
        disabled:SetPos(24, 162)
        disabled:SetSize(w - 48, 78)
        disabled.Paint = function(_, pw, ph)
            draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
            DrawText("Credit shop is disabled.", LibFont("Body", "DermaDefaultBold"), 14, 14, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawText("Admins can re-enable it from Scoreboard Customization > Basic.", LibFont("Small", "DermaDefault"), 14, 39, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        return
    end

    for _, listing in ipairs(cfg.ShopListings or {}) do
        if listing.Public ~= false or LocalPlayer():IsAdmin() then
            listings[#listings + 1] = listing
        end
    end

    if #listings == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:Dock(TOP)
        empty:SetTall(78)
        empty.Paint = function(_, pw, ph)
            draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
            DrawText("No profile shop listings yet.", LibFont("Body", "DermaDefaultBold"), 14, 14, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawText("Admins can create listings from scoreboard customization.", LibFont("Small", "DermaDefault"), 14, 39, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        return
    end

    local grid = vgui.Create("DIconLayout", scroll)
    grid:Dock(TOP)
    grid:SetSpaceX(8)
    grid:SetSpaceY(8)
    local columns = math.Clamp(math.Round(tonumber(cfg.ShopGridColumns or 2) or 2), 1, 4)
    local cardW = math.floor((w - 48 - ((columns - 1) * 8)) / columns)
    grid:SetTall(math.ceil(#listings / columns) * 118)

    for _, item in ipairs(listings) do
        local card = grid:Add("DButton")
        StyleButton(card)
        card:SetSize(cardW, 110)
        card.Hover = 0
        card.Paint = function(self, pw, ph)
            HandleHoverSound(self)
            self.Hover = EaseValue(self.Hover, self:IsHovered() and 1 or 0, AnimProfile().HoverSpeed)
            local mat = RemoteImageMaterial(item.ImageURL or "")
            local hidden = item.Public == false

            draw.RoundedBox(CardRadius(), 1, 2, pw - 2, ph - 2, Shadow(44))
            draw.RoundedBox(CardRadius(), 0, 0, pw, ph - 2, CardBase(255))
            if self.Hover > 0.01 then
                draw.RoundedBox(CardRadius(), 0, 0, pw, ph - 2, WithAlpha(Primary(), 18 + self.Hover * 32))
            end

            draw.RoundedBox(CardRadius(), 12, 12, 70, 70, ButtonBase(255))
            if mat and not mat:IsError() then
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(12, 12, 70, 70)
            else
                DrawIcon("economy/diamond", 36, 36, 22, Primary())
            end

            DrawText(FitText(item.Title or "Profile Photo", LibFont("Body", "DermaDefaultBold"), pw - 110), LibFont("Body", "DermaDefaultBold"), 94, 14, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local price = item.Price or string.format("%d", tonumber(item.PriceAmount) or 0)
            local currency = item.Currency or cfg.ShopCurrencyName or "Credits"
            local class = tostring(item.Class or "")
            DrawText(price .. " " .. currency, LibFont("Small", "DermaDefault"), 94, 39, Primary(), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            DrawText(FitText((item.ItemType or "item") .. (class ~= "" and (" - " .. class) or ""), LibFont("Small", "DermaDefault"), pw - 112), LibFont("Small", "DermaDefault"), 94, 58, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            if hidden then
                DrawText("Hidden", LibFont("Small", "DermaDefault"), 94, 76, Color(238, 146, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            draw.RoundedBox(Radius("SM"), pw - 84, ph - 32, 70, 22, ButtonBase(255))
            DrawText("Buy", LibFont("Small", "DermaDefault"), pw - 49, ph - 21, Primary(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        card.DoClick = function()
            BuyShopListing(item)
        end
    end
end

local function LeaderboardEntries(players, valueFunc, formatFunc, limit)
    local entries = {}
    local seen = {}

    for _, ply in ipairs(players or {}) do
        if IsValid(ply) then
            local sid64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
            local sid = ply.SteamID and tostring(ply:SteamID() or "") or ""
            local key = sid64 ~= "" and sid64 ~= "0" and ("sid64:" .. sid64) or sid ~= "" and ("sid:" .. sid) or ("ent:" .. string.format("%d", ply:EntIndex() or 0))

            if seen[key] then continue end
            seen[key] = true

            local raw = tonumber(valueFunc(ply) or 0) or 0
            entries[#entries + 1] = {
                Player = ply,
                Raw = raw,
                Value = formatFunc and formatFunc(raw, ply) or string.format("%d", math.floor(raw))
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.Raw == b.Raw then
            return string.lower(SafeNick(a.Player)) < string.lower(SafeNick(b.Player))
        end
        return a.Raw > b.Raw
    end)

    local max = math.max(1, math.floor(tonumber(limit) or 10))
    while #entries > max do
        table.remove(entries)
    end

    return entries
end

local function StoredLeaderboardEntries(field, formatFunc, limit)
    local entries = {}
    local seen = {}

    for steam64, row in next, (persistentLeaderboardData or {}) do
        if istable(row) then
            local key = tostring(row.SteamID64 or steam64 or "")
            if key == "" or seen[key] then continue end
            seen[key] = true

            local raw = tonumber(row[field] or 0) or 0
            entries[#entries + 1] = {
                SteamID64 = key,
                Raw = raw,
                Value = formatFunc and formatFunc(raw, row) or string.format("%d", math.floor(raw)),
                Name = tostring(row.Name or "Player")
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.Raw == b.Raw then
            return string.lower(a.Name or "") < string.lower(b.Name or "")
        end
        return a.Raw > b.Raw
    end)

    local max = math.max(1, math.floor(tonumber(limit) or 10))
    while #entries > max do
        table.remove(entries)
    end

    return entries
end

local function DrawLeaderboardCard(parent, x, y, w, h, title, icon, entries, accent)
    local card = vgui.Create("DPanel", parent)
    card.DHUDContent = true
    card:SetPos(x, y)
    card:SetSize(w, h)
    card.Paint = function(_, pw, ph)
        draw.RoundedBox(CardRadius(), 1, 3, pw - 2, ph - 2, Shadow(48))
        draw.RoundedBox(CardRadius(), 0, 0, pw, ph - 2, CardBase(255))
        draw.RoundedBox(CardRadius(), 14, 14, 40, 40, WithAlpha(accent, 34))
        DrawIcon(icon, 24, 24, 20, accent)

        DrawText(title, LibFont("Header", "DermaDefaultBold"), 66, 13, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawText(string.format("%d ranked players", #entries), LibFont("Small", "DermaDefault"), 66, 38, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local rowY = 68
        local rowH = 25
        local medalColors = {
            Color(221, 177, 74),
            Color(178, 184, 194),
            Color(190, 122, 74)
        }

        if #entries == 0 then
            DrawText("No data yet", LibFont("Small", "DermaDefault"), pw * 0.5, rowY + 18, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        for index, entry in ipairs(entries) do
            local y = rowY + (index - 1) * rowH
            if y + rowH > ph - 10 then break end

            local rankCol = medalColors[index] or LibColor("Muted", Color(170, 171, 178))
            local rowCol = index <= 3 and WithAlpha(rankCol, 22) or ButtonBase(220)
            local ply = entry.Player
            local name = IsValid(ply) and SafeNick(ply) or tostring(entry.Name or "Player")
            draw.RoundedBox(Radius("SM"), 12, y, pw - 24, rowH - 3, rowCol)
            DrawText("#" .. index, LibFont("Small", "DermaDefaultBold"), 24, y + rowH * 0.5 - 2, rankCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            DrawText(FitText(name, LibFont("Small", "DermaDefault"), pw - 166), LibFont("Small", "DermaDefault"), 58, y + rowH * 0.5 - 2, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            DrawText(tostring(entry.Value or ""), LibFont("Small", "DermaDefaultBold"), pw - 18, y + rowH * 0.5 - 2, index <= 3 and rankCol or accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    return card
end

local function BuildLeaderboardView(w, h, cfg)
    local scoreCfg = ScoreCfg()
    local leaderCfg = scoreCfg.Leaderboards or (DHUD.Config and DHUD.Config.Leaderboards) or {}
    if leaderCfg.Enabled == false then
        SetScoreboardView("players")
        return
    end

    local intro = vgui.Create("DPanel", frame)
    intro.DHUDContent = true
    intro:SetPos(24, 98)
    intro:SetSize(w - 48, 52)
    intro.Paint = function(_, pw, ph)
        draw.RoundedBox(CardRadius(), 0, 0, pw, ph, CardBase(255))
        DrawText("Leaderboards", LibFont("Header", "DermaDefaultBold"), 50, 9, LibColor("Foreground", color_white), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawText("Top saved all-time players by enabled leaderboard categories.", LibFont("Small", "DermaDefault"), 50, 33, LibColor("Muted", Color(170, 171, 178)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        DrawText("Refresh in " .. math.ceil(math.max((nextLeaderboardRefresh or CurTime()) - CurTime(), 0)) .. "s", LibFont("Small", "DermaDefault"), pw - 14, ph * 0.5, Primary(), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    local back = AddIconButton(intro, "actions/back", function()
        SetScoreboardView("players")
    end, "Back")
    back:SetPos(12, 12)

    local players = player.GetAll()
    local cards = {}
    local limit = math.Clamp(math.Round(tonumber(leaderCfg.TopResults) or 10), 1, 25)

    if leaderCfg.Money ~= false then
        cards[#cards + 1] = {"Richest Players", "economy/attach_money", StoredLeaderboardEntries("Money", function(value) return DarkRP and DarkRP.formatMoney and DarkRP.formatMoney(value) or string.format("%d", math.floor(value)) end, limit), Primary()}
    end

    if leaderCfg.OverallTime ~= false then
        cards[#cards + 1] = {"Most Playtime", "misc/clock", StoredLeaderboardEntries("Playtime", function(value) return FormatDuration(value) end, limit), Color(91, 159, 232)}
    end

    if leaderCfg.SessionTime == true then
        cards[#cards + 1] = {"Longest Session", "misc/clock", StoredLeaderboardEntries("SessionTime", function(value) return FormatDuration(value) end, limit), Color(221, 177, 74)}
    end

    if leaderCfg.Points == true then
        cards[#cards + 1] = {"Most Points", "economy/diamond", LeaderboardEntries(players, PlayerPointValue, function(value) return string.format("%d", math.floor(value)) end, limit), Color(122, 166, 255)}
    end

    if leaderCfg.Kills == true then
        cards[#cards + 1] = {"Most Kills", "players/skull", StoredLeaderboardEntries("Kills", function(value) return string.format("%d", math.floor(value)) end, limit), Color(232, 84, 84)}
    end

    if leaderCfg.Deaths == true then
        cards[#cards + 1] = {"Most Deaths", "admin/warning", StoredLeaderboardEntries("Deaths", function(value) return string.format("%d", math.floor(value)) end, limit), Color(238, 146, 80)}
    end

    if leaderCfg.Credits == true then
        cards[#cards + 1] = {"Most Credits", "economy/payments", LeaderboardEntries(players, PlayerCreditValue, function(value) return string.format("%d", math.floor(value)) end, limit), Color(91, 201, 121)}
    end

    if #cards == 0 then
        cards[1] = {"Leaderboards Disabled", "economy/leaderboard", {}, Primary()}
    end

    local scroller = vgui.Create("DHorizontalScroller", frame)
    scroller.DHUDContent = true
    scroller:SetPos(24, 166)
    scroller:SetSize(w - 48, h - 188)
    scroller:SetOverlap(-10)
    scroller.Paint = function(_, pw, ph)
        draw.RoundedBox(CardRadius(), 0, ph - 10, pw, 6, Color(0, 0, 0, 46))
    end

    local left = IsValid(scroller.btnLeft) and scroller.btnLeft or nil
    local right = IsValid(scroller.btnRight) and scroller.btnRight or nil
    local function styleArrow(btn, dir)
        if not IsValid(btn) then return end
        btn:SetWide(22)
        btn.Paint = function(self, bw, bh)
            local hover = self:IsHovered() and 1 or 0
            draw.RoundedBox(Radius("SM"), 0, 0, bw, bh, WithAlpha(ButtonBase(255), 210))
            DrawText(dir, LibFont("Small", "DermaDefaultBold"), bw * 0.5, bh * 0.5 - 1, WithAlpha(Primary(), 180 + hover * 75), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    styleArrow(left, "<")
    styleArrow(right, ">")

    local cardW = math.max(310, math.min(380, math.floor((w - 76) * 0.38)))
    local cardH = math.max(300, h - 202)
    for index, data in ipairs(cards) do
        local card = DrawLeaderboardCard(scroller, 0, 0, cardW, cardH, data[1], data[2], data[3], data[4])
        card:DockMargin(index == 1 and 0 or 10, 0, 0, 0)
        scroller:AddPanel(card)
    end
end

function DHUD.Scoreboard.Open()
    if IsValid(frame) then frame:Remove() end

    RequestScoreboardData()

    local cfg = ScoreCfg()
    local w = math.min(ScrW() - 110, math.max(tonumber(cfg.Width or 0) or 0, 720))
    local h = math.min(ScrH() - 110, math.max(tonumber(cfg.Height or 0) or 0, 630))

    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    if frame.SetPaintBackground then frame:SetPaintBackground(false) end
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    frame:SetAlpha(0)
    frame.DHUDPreview = openingPreview == true
    openingPreview = false
    frame.Progress = 0
    frame.TargetAlpha = 255
    if DHUD.TrackPanel then DHUD.TrackPanel(frame) end
    local baseX, baseY = frame:GetPos()
    frame.OnRemove = function(self)
        if frame == self then
            frame = nil
            currentView = "players"
            if DHUD.ConfigMenu and DHUD.ConfigMenu.CenterExisting then
                DHUD.ConfigMenu.CenterExisting()
            end
        end
    end

    frame.Paint = function(self, pw, ph)
        PaintShell(self, pw, ph)
    end

    local close = AddIconButton(frame, "navigation/close", function()
        DHUD.Scoreboard.Close()
    end, "Close", (DHUD.Config and DHUD.Config.Colors and DHUD.Config.Colors.Health) or Color(232, 84, 84))

    local settings
    if LocalPlayer():IsAdmin() then
        settings = AddIconButton(frame, "navigation/settings", function()
            if DubzLib and DubzLib.OpenConfigMenu then
                DubzLib.OpenConfigMenu()
            elseif DHUD.ConfigMenu and DHUD.ConfigMenu.Open then
                DHUD.ConfigMenu.Open()
            else
                SetScoreboardView("settings")
            end
        end, "Customize")
    end

    local leaderboard = AddIconButton(frame, "economy/leaderboard", function()
        SetScoreboardView("leaderboard")
    end, "Leaderboards")
    leaderboard:SetVisible(not (DHUD.Config and DHUD.Config.Leaderboards and DHUD.Config.Leaderboards.Enabled == false))

    local shop = AddIconButton(frame, "economy/shopping_bag", function()
        SetScoreboardView("shop")
    end, "Shop")
    shop:SetVisible(CreditsEnabled(cfg) and cfg.ShowShop ~= false)

    local function LayoutHeaderButtons()
        if not IsValid(frame) then return end
        local fw = frame:GetWide()
        local x = fw - 54
        local leftMost = x
        if IsValid(close) then
            close:SetPos(x, 22)
            if close:IsVisible() then leftMost = math.min(leftMost, x) end
            x = x - 32
        end
        if IsValid(settings) then
            settings:SetPos(x, 22)
            if settings:IsVisible() then leftMost = math.min(leftMost, x) end
            x = x - 32
        end
        if IsValid(leaderboard) then
            leaderboard:SetPos(x, 22)
            if leaderboard:IsVisible() then
                leftMost = math.min(leftMost, x)
                x = x - 32
            end
        end
        if IsValid(shop) then
            shop:SetPos(x, 22)
            if shop:IsVisible() then leftMost = math.min(leftMost, x) end
        end
        frame.DHUDHeaderButtonsLeft = leftMost
    end
    LayoutHeaderButtons()

    RebuildCurrentView = function()
        if not IsValid(frame) then return end

        local fw, fh = frame:GetSize()
        local activeCfg = ScoreCfg()
        ClearScoreboardBody()
        frame:SetKeyboardInputEnabled(true)
        if IsValid(shop) then
            shop:SetVisible(CreditsEnabled(activeCfg) and activeCfg.ShowShop ~= false)
        end
        if IsValid(leaderboard) then
            local leaderEnabled = not (DHUD.Config and DHUD.Config.Leaderboards and DHUD.Config.Leaderboards.Enabled == false)
            leaderboard:SetVisible(leaderEnabled)
            if not leaderEnabled and currentView == "leaderboard" then
                currentView = "players"
            end
        end
        LayoutHeaderButtons()

        if currentView == "shop" then
            currentView = "players"
        end

        if currentView == "settings" then
            BuildSettingsView(fw, fh, activeCfg)
        elseif currentView == "leaderboard" then
            BuildLeaderboardView(fw, fh, activeCfg)
        else
            BuildPlayersView(fw, fh, activeCfg)
        end
    end

    RebuildCurrentView()

    frame.Think = function(self)
        local anim = AnimProfile()
        self.Progress = EaseValue(self.Progress, self.TargetAlpha == 0 and 0 or 1, anim.Speed)
        self:SetAlpha(math.Clamp((self.Progress or 0) * 255, 0, 255))
        local targetX = self.DHUDBaseX or baseX
        local targetY = self.DHUDBaseY or baseY
        self:SetPos(targetX + (1 - (self.Progress or 0)) * anim.Slide, targetY)
        if self.TargetAlpha == 0 and (self.Progress or 0) <= 0.02 then
            self:Remove()
            return
        end

        if currentView == "leaderboard" and CurTime() >= (nextLeaderboardRefresh or 0) then
            local leaderCfg = ScoreCfg().Leaderboards or {}
            nextLeaderboardRefresh = CurTime() + math.max(tonumber(leaderCfg.RefreshInterval) or leaderboardRefreshInterval, 10)
            RequestScoreboardData(true)
            if RebuildCurrentView then RebuildCurrentView() end
            return
        end

        local searchFocused = false
        for _, child in ipairs(self:GetChildren()) do
            if IsValid(child) and child.DHUDSearchEntry and child:HasFocus() then
                searchFocused = true
                break
            end
        end
        if self.DHUDTypingSearch or searchFocused or CurTime() < (searchFocusedUntil or 0) then
            self:SetKeyboardInputEnabled(true)
            return
        end

        if currentView ~= "players" or self.DHUDPreview then return end
        if not input.IsKeyDown(KEY_TAB) then
            DHUD.Scoreboard.Close()
        end
    end
end

function DHUD.Scoreboard.GetFrame()
    return frame
end

function DHUD.Scoreboard.CenterExisting()
    if not IsValid(frame) then return end

    frame:Center()
    frame.DHUDBaseX, frame.DHUDBaseY = frame:GetPos()
end

function DHUD.Scoreboard.OpenPreviewLeft()
    openingPreview = true
    DHUD.Scoreboard.Open()
    if IsValid(frame) then frame.DHUDPreview = true end

    timer.Simple(0, function()
        if not IsValid(frame) then return end

        local _, h = frame:GetSize()
        local gap = 12
        local edge = 28
        local maxPreviewW = math.floor((ScrW() - edge * 2 - gap) * 0.5)
        local previewW = math.min(maxPreviewW, math.max(tonumber(ScoreCfg().Width or defaultScoreConfig.Width) or defaultScoreConfig.Width, 720))
        frame.DHUDPreview = true
        frame:SetSize(previewW, h)
        frame:SetPos(edge, math.max(28, (ScrH() - h) * 0.5))
        frame.DHUDBaseX, frame.DHUDBaseY = frame:GetPos()
        if RebuildCurrentView then RebuildCurrentView() end
    end)
end

function DHUD.Scoreboard.Close()
    if IsValid(frame) then
        frame.TargetAlpha = 0
        frame:SetMouseInputEnabled(false)
        frame:SetKeyboardInputEnabled(false)
        return
    end

    frame = nil
    currentView = "players"
end

local function ScoreboardShowHook()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Scoreboard == false or ScoreCfg().Enabled == false then return end

    DHUD.Scoreboard.Open()
    return true
end

local function ScoreboardHideHook()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Scoreboard == false or ScoreCfg().Enabled == false then return end

    if IsValid(frame) and frame.DHUDPreview then return true end
    if IsValid(frame) and (frame.DHUDTypingSearch or CurTime() < (searchFocusedUntil or 0)) then return true end
    if currentView ~= "players" then return true end
    DHUD.Scoreboard.Close()
    return true
end

hook.Add("ScoreboardShow", "DHUD.ScoreboardShow", ScoreboardShowHook)
hook.Add("ScoreboardHide", "DHUD.ScoreboardHide", ScoreboardHideHook)
