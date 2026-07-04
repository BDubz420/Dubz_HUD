local DHUD = DHUD
DHUD.Scoreboard = DHUD.Scoreboard or {}

util.AddNetworkString("DHUD.Scoreboard.RequestData")
util.AddNetworkString("DHUD.Scoreboard.Data")
util.AddNetworkString("DHUD.Scoreboard.SaveConfig")
util.AddNetworkString("DHUD.Scoreboard.ResetConfig")
util.AddNetworkString("DHUD.Scoreboard.VoteRep")
util.AddNetworkString("DHUD.Scoreboard.Rep")
util.AddNetworkString("DHUD.Scoreboard.Notice")
util.AddNetworkString("DHUD.Scoreboard.BuyListing")
util.AddNetworkString("DHUD.Scoreboard.Leaderboards")
util.AddNetworkString("Dubz_UpdatePlaytime")

local configPath = "dhud/scoreboard_config.txt"
local repPath = "dhud/scoreboard_rep.txt"
local playtimePath = "dhud/playtime_data.txt"
local leaderboardPath = "dhud/leaderboard_data.txt"
local MAX_CONFIG_BITS = 768 * 1024
local REQUEST_COOLDOWN = 1
local SAVE_COOLDOWN = 2
local ACTION_COOLDOWN = 0.75
local LEADERBOARD_SAVE_COOLDOWN = 60
local defaultScoreConfig = {
    ShowHeaderIcon = true,
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
    ShopTitle = "Credit Shop",
    ShopSubtitle = "Server items, perks, and profile extras.",
    CreditsEnabled = false,
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
    ShopListings = {
        {ID = "default_carbon_card", Title = "Carbon Card", Price = "$15,000", PriceAmount = 15000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = true},
        {ID = "default_neon_frame", Title = "Neon Frame", Price = "$25,000", PriceAmount = 25000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = true},
        {ID = "default_city_cover", Title = "City Cover", Price = "$35,000", PriceAmount = 35000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = true},
        {ID = "default_founder_plate", Title = "Founder Plate", Price = "$50,000", PriceAmount = 50000, Currency = "Credits", ImageURL = "", Model = "", Class = "", ItemType = "profile", Public = false}
    },
    RankDisplay = {},
    DisabledRankDisplay = {}
}

local scoreboardConfig = table.Copy(defaultScoreConfig)
local repVotes = {}
local repScores = {}
local playtimes = {}
local leaderboardData = {}
local PlaytimeSeconds
local nextLeaderboardSave = 0

local function IsScoreboardAdmin(ply)
    return not IsValid(ply) or ply:IsAdmin() or ply:IsSuperAdmin()
end

local function RateLimited(ply, key, cooldown)
    if not IsValid(ply) then return false end

    local field = "DHUD_Scoreboard_" .. key
    local nextAllowed = tonumber(ply[field] or 0) or 0
    if CurTime() < nextAllowed then return true end

    ply[field] = CurTime() + cooldown
    return false
end

local function PlayerKey(ply)
    if not IsValid(ply) then return nil end

    local steam64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    if steam64 ~= "" and steam64 ~= "0" then return "sid64:" .. steam64 end

    local steamID = ply.SteamID and tostring(ply:SteamID() or "") or ""
    if steamID ~= "" then return "sid:" .. steamID end

    local name = ply.Nick and tostring(ply:Nick() or "") or tostring(ply)
    local userID = ply.UserID and string.format("%d", ply:UserID() or 0) or "0"
    local entIndex = ply.EntIndex and string.format("%d", ply:EntIndex() or 0) or "0"

    return "ply:" .. steamID .. ":" .. name .. ":" .. userID .. ":" .. entIndex
end

local function VoterKey(ply)
    if not IsValid(ply) then return nil end

    local steam64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    if steam64 ~= "" and steam64 ~= "0" then return "sid64:" .. steam64 end

    local steamID = ply.SteamID and tostring(ply:SteamID() or "") or ""
    if steamID ~= "" then return "sid:" .. steamID end

    return PlayerKey(ply)
end

local function RebuildRepScores()
    repScores = {}

    for targetKey, voters in next, (repVotes or {}) do
        if istable(voters) then
            local total = 0
            for _, amount in next, (voters) do
                amount = tonumber(amount or 0) or 0
                if amount > 0 then
                    total = total + 1
                elseif amount < 0 then
                    total = total - 1
                end
            end

            repScores[targetKey] = math.Clamp(total, -9999, 9999)
        end
    end
end

local function ReadJSON(path, fallback)
    if not file.Exists(path, "DATA") then return fallback end

    local raw = file.Read(path, "DATA")
    local ok, decoded = pcall(function()
        return util.JSONToTable(raw or "")
    end)

    if ok and istable(decoded) then return decoded end

    return fallback
end

local function SaveConfig()
    file.CreateDir("dhud")
    file.Write(configPath, util.TableToJSON(scoreboardConfig or {}, true))
end

local function SaveRep()
    file.CreateDir("dhud")
    file.Write(repPath, util.TableToJSON({
        Votes = repVotes or {},
        Scores = repScores or {}
    }, true))
end

local function SavePlaytimes()
    file.CreateDir("dhud")
    local snapshot = table.Copy(playtimes or {})

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply.SteamID64 then
            local sid64 = tostring(ply:SteamID64() or "")
            if sid64 ~= "" and sid64 ~= "0" then
                snapshot[sid64] = PlaytimeSeconds(ply)
            end
        end
    end

    file.Write(playtimePath, util.TableToJSON(snapshot, true))
end

local function SaveLeaderboards()
    local leaderCfg = scoreboardConfig.Leaderboards or {}
    if string.lower(tostring(leaderCfg.StorageMode or "file")) == "sqlite" and sql then
        sql.Query("CREATE TABLE IF NOT EXISTS dhud_leaderboards (steam64 TEXT PRIMARY KEY, data TEXT)")
        for steam64, row in next, (leaderboardData or {}) do
            sql.Query("REPLACE INTO dhud_leaderboards (steam64, data) VALUES (" .. sql.SQLStr(tostring(steam64)) .. ", " .. sql.SQLStr(util.TableToJSON(row or {})) .. ")")
        end
        return
    end

    file.CreateDir("dhud")
    file.Write(leaderboardPath, util.TableToJSON(leaderboardData or {}, true))
end

local function SaveLeaderboardsThrottled(force)
    if not force and CurTime() < nextLeaderboardSave then return end

    nextLeaderboardSave = CurTime() + LEADERBOARD_SAVE_COOLDOWN
    SaveLeaderboards()
end

local function LoadData()
    scoreboardConfig = table.Copy(defaultScoreConfig)
    local savedConfig = ReadJSON(configPath, {}) or {}
    for key, value in next, (savedConfig) do
        scoreboardConfig[key] = value
    end

    local repData = ReadJSON(repPath, {}) or {}
    repVotes = istable(repData.Votes) and repData.Votes or {}
    RebuildRepScores()
    if istable(repData.Scores) then
        for key, value in next, (repData.Scores) do
            if repScores[key] == nil then
                repScores[key] = math.Clamp(tonumber(value) or 0, -9999, 9999)
            end
        end
    end

    playtimes = ReadJSON(playtimePath, {}) or {}
    local leaderCfg = scoreboardConfig.Leaderboards or {}
    if string.lower(tostring(leaderCfg.StorageMode or "file")) == "sqlite" and sql then
        leaderboardData = {}
        sql.Query("CREATE TABLE IF NOT EXISTS dhud_leaderboards (steam64 TEXT PRIMARY KEY, data TEXT)")
        local rows = sql.Query("SELECT steam64, data FROM dhud_leaderboards") or {}
        for _, sqlRow in ipairs(rows) do
            local ok, decoded = pcall(function() return util.JSONToTable(sqlRow.data or "") end)
            if ok and istable(decoded) then
                leaderboardData[tostring(sqlRow.steam64 or decoded.SteamID64 or "")] = decoded
            end
        end
    else
        leaderboardData = ReadJSON(leaderboardPath, {}) or {}
    end
end

PlaytimeSeconds = function(ply)
    if not IsValid(ply) then return 0 end

    local sid64 = ply.SteamID64 and tostring(ply:SteamID64() or "") or ""
    if sid64 == "" or sid64 == "0" then return 0 end

    local base = tonumber(playtimes[sid64] or 0) or 0
    local join = tonumber(ply.Dubz_JoinTime or CurTime()) or CurTime()
    local tracked = math.max(base + CurTime() - join, 0)
    local utime = 0

    if ply.GetUTimeTotalTime then
        utime = tonumber(ply:GetUTimeTotalTime() or 0) or 0
    end

    return math.max(tracked, utime, 0)
end

local function BroadcastPlaytimes(ply)
    local out = {}

    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) and target.SteamID64 then
            local sid64 = tostring(target:SteamID64() or "")
            if sid64 ~= "" and sid64 ~= "0" then
                out[sid64] = PlaytimeSeconds(target)
            end
        end
    end

    net.Start("Dubz_UpdatePlaytime")
    net.WriteString(util.TableToJSON(out) or "{}")

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

local function UpdateLeaderboardPlayer(ply)
    if not IsValid(ply) or not ply.SteamID64 then return end

    local sid64 = tostring(ply:SteamID64() or "")
    if sid64 == "" or sid64 == "0" then return end

    leaderboardData[sid64] = leaderboardData[sid64] or {}
    local row = leaderboardData[sid64]
    row.SteamID64 = sid64
    row.Name = ply.Nick and tostring(ply:Nick() or "Player") or "Player"
    row.Money = ply.getDarkRPVar and tonumber(ply:getDarkRPVar("money") or row.Money or 0) or tonumber(row.Money or 0) or 0
    row.Kills = ply.Frags and tonumber(ply:Frags() or 0) or tonumber(row.Kills or 0) or 0
    row.Deaths = ply.Deaths and tonumber(ply:Deaths() or 0) or tonumber(row.Deaths or 0) or 0
    row.Playtime = PlaytimeSeconds(ply)
    local session = math.max(CurTime() - (tonumber(ply.Dubz_JoinTime or CurTime()) or CurTime()), 0)
    row.SessionTime = math.max(tonumber(row.SessionTime or 0) or 0, session)
    row.Updated = os.time()
end

local function RefreshLeaderboards()
    for _, ply in ipairs(player.GetAll()) do
        UpdateLeaderboardPlayer(ply)
    end

    SaveLeaderboardsThrottled(false)
end

local function LeaderboardLimit()
    local leaderCfg = scoreboardConfig.Leaderboards or {}
    return math.Clamp(math.floor(tonumber(leaderCfg.TopResults) or 10), 1, 50)
end

local function CopyLeaderboardRow(row)
    row = istable(row) and row or {}

    return {
        SteamID64 = tostring(row.SteamID64 or ""),
        Name = string.sub(tostring(row.Name or "Player"), 1, 64),
        Money = tonumber(row.Money or 0) or 0,
        Kills = tonumber(row.Kills or 0) or 0,
        Deaths = tonumber(row.Deaths or 0) or 0,
        Playtime = tonumber(row.Playtime or 0) or 0,
        SessionTime = tonumber(row.SessionTime or 0) or 0,
        Updated = tonumber(row.Updated or 0) or 0
    }
end

local function AddTopLeaderboardRows(snapshot, field, limit)
    local rows = {}

    for steam64, row in next, (leaderboardData or {}) do
        if istable(row) then
            local raw = tonumber(row[field] or 0) or 0
            if raw > 0 then
                rows[#rows + 1] = {
                    SteamID64 = tostring(row.SteamID64 or steam64 or ""),
                    Raw = raw,
                    Row = row
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        if a.Raw == b.Raw then
            return string.lower(tostring(a.Row.Name or "")) < string.lower(tostring(b.Row.Name or ""))
        end

        return a.Raw > b.Raw
    end)

    for i = 1, math.min(#rows, limit) do
        local key = rows[i].SteamID64
        if key ~= "" then
            snapshot[key] = CopyLeaderboardRow(rows[i].Row)
            snapshot[key].SteamID64 = key
        end
    end
end

local function BuildLeaderboardSnapshot()
    local leaderCfg = scoreboardConfig.Leaderboards or {}
    local limit = LeaderboardLimit()
    local snapshot = {}

    if leaderCfg.Money ~= false then AddTopLeaderboardRows(snapshot, "Money", limit) end
    if leaderCfg.Kills ~= false then AddTopLeaderboardRows(snapshot, "Kills", limit) end
    if leaderCfg.Deaths ~= false then AddTopLeaderboardRows(snapshot, "Deaths", limit) end
    if leaderCfg.OverallTime ~= false then AddTopLeaderboardRows(snapshot, "Playtime", limit) end
    if leaderCfg.SessionTime == true then AddTopLeaderboardRows(snapshot, "SessionTime", limit) end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply.SteamID64 then
            local sid64 = tostring(ply:SteamID64() or "")
            if sid64 ~= "" and sid64 ~= "0" and leaderboardData[sid64] then
                snapshot[sid64] = CopyLeaderboardRow(leaderboardData[sid64])
                snapshot[sid64].SteamID64 = sid64
            end
        end
    end

    return snapshot
end

local function BroadcastLeaderboards(ply)
    RefreshLeaderboards()

    net.Start("DHUD.Scoreboard.Leaderboards")
    net.WriteString(util.TableToJSON(BuildLeaderboardSnapshot()) or "{}")

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

local function SendData(ply)
    net.Start("DHUD.Scoreboard.Data")
    net.WriteString(util.TableToJSON(scoreboardConfig or {}) or "{}")
    net.WriteString(util.TableToJSON(repScores or {}) or "{}")

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

local function BroadcastRep()
    net.Start("DHUD.Scoreboard.Rep")
    net.WriteString(util.TableToJSON(repScores or {}) or "{}")
    net.Broadcast()
end

local function Notice(ply, message, kind)
    if not IsValid(ply) then return end

    net.Start("DHUD.Scoreboard.Notice")
    net.WriteString(tostring(message or ""))
    net.WriteString(tostring(kind or "hint"))
    net.Send(ply)
end

local function FindListing(id)
    id = tostring(id or "")
    if id == "" then return nil end

    for _, listing in ipairs(scoreboardConfig.ShopListings or {}) do
        if istable(listing) and tostring(listing.ID or "") == id then
            return listing
        end
    end
end

local function ChargePlayer(ply, listing)
    local amount = tonumber(listing.PriceAmount or 0) or 0
    if amount <= 0 then return true end

    local mode = string.lower(tostring(scoreboardConfig.ShopCurrencyMode or "darkrp"))
    if mode == "none" then return true end

    if mode == "darkrp" then
        if ply.canAfford and not ply:canAfford(amount) then
            return false, "You cannot afford this listing."
        end

        if ply.addMoney then
            ply:addMoney(-amount)
            return true
        end

        return false, "DarkRP money is not available."
    end

    return false, "Custom currency bridge is saved, but not connected yet."
end

local function GiveListing(ply, listing)
    local itemType = string.lower(tostring(listing.ItemType or "profile"))
    local class = string.Trim(tostring(listing.Class or ""))

    if itemType == "weapon" and class ~= "" then
        ply:Give(class)
        return true, "Purchased " .. tostring(listing.Title or class) .. "."
    end

    if itemType == "entity" and class ~= "" then
        local ent = ents.Create(class)
        if not IsValid(ent) then
            return false, "That entity could not be created."
        end

        local pos = ply:GetPos() + ply:GetForward() * 56 + Vector(0, 0, 24)
        ent:SetPos(pos)
        ent:Spawn()
        return true, "Purchased " .. tostring(listing.Title or class) .. "."
    end

    return true, "Purchased " .. tostring(listing.Title or "listing") .. "."
end

local function RefundPlayer(ply, listing)
    local amount = tonumber(listing.PriceAmount or 0) or 0
    if amount <= 0 then return end

    if string.lower(tostring(scoreboardConfig.ShopCurrencyMode or "darkrp")) == "darkrp" and ply.addMoney then
        ply:addMoney(amount)
    end
end

LoadData()

net.Receive("DHUD.Scoreboard.RequestData", function(_, ply)
    if RateLimited(ply, "RequestData", REQUEST_COOLDOWN) then return end

    SendData(ply)
    BroadcastPlaytimes(ply)
    BroadcastLeaderboards(ply)
end)

net.Receive("DHUD.Scoreboard.SaveConfig", function(length, ply)
    if not IsScoreboardAdmin(ply) then return end
    if length > MAX_CONFIG_BITS then
        Notice(ply, "Scoreboard config payload is too large.", "warning")
        return
    end
    if RateLimited(ply, "SaveConfig", SAVE_COOLDOWN) then return end

    local ok, incoming = pcall(function()
        return util.JSONToTable(net.ReadString() or "")
    end)
    if not ok then return end
    if not istable(incoming) then return end

    scoreboardConfig = incoming
    SaveConfig()
    SendData()
    BroadcastLeaderboards()
end)

net.Receive("DHUD.Scoreboard.ResetConfig", function(_, ply)
    if not IsScoreboardAdmin(ply) then return end
    if RateLimited(ply, "ResetConfig", SAVE_COOLDOWN) then return end

    scoreboardConfig = table.Copy(defaultScoreConfig)
    if file.Exists(configPath, "DATA") then
        file.Delete(configPath)
    end

    SendData()
    BroadcastLeaderboards()
end)

net.Receive("DHUD.Scoreboard.VoteRep", function(_, ply)
    if not IsValid(ply) then return end
    if RateLimited(ply, "VoteRep", ACTION_COOLDOWN) then return end

    local target = net.ReadEntity()
    local amount = net.ReadInt(3)
    if not IsValid(target) or not target:IsPlayer() then return end
    if target == ply then
        Notice(ply, "You cannot rep yourself.", "warning")
        return
    end

    amount = amount > 0 and 1 or -1

    local targetKey = PlayerKey(target)
    local voterKey = VoterKey(ply)
    if not targetKey or not voterKey then return end

    repVotes[targetKey] = istable(repVotes[targetKey]) and repVotes[targetKey] or {}
    if repVotes[targetKey][voterKey] ~= nil then
        Notice(ply, "You already voted on " .. target:Nick() .. "'s rep.", "warning")
        return
    end

    repVotes[targetKey][voterKey] = amount
    RebuildRepScores()
    SaveRep()
    BroadcastRep()

    Notice(ply, (amount > 0 and "+Rep added for " or "-Rep added for ") .. target:Nick() .. ".", "hint")
    Notice(target, ply:Nick() .. (amount > 0 and " gave you +Rep." or " gave you -Rep."), amount > 0 and "success" or "warning")
end)

net.Receive("DHUD.Scoreboard.BuyListing", function(_, ply)
    if not IsValid(ply) then return end
    if RateLimited(ply, "BuyListing", ACTION_COOLDOWN) then return end

    if scoreboardConfig.CreditsEnabled == false then
        Notice(ply, "The credit shop is disabled.", "warning")
        return
    end

    local listing = FindListing(net.ReadString())
    if not listing or listing.Public == false then
        Notice(ply, "That shop listing is not available.", "warning")
        return
    end

    local charged, chargeMessage = ChargePlayer(ply, listing)
    if not charged then
        Notice(ply, chargeMessage or "Purchase failed.", "warning")
        return
    end

    local given, giveMessage = GiveListing(ply, listing)
    if not given then
        RefundPlayer(ply, listing)
    end

    Notice(ply, giveMessage or (given and "Purchase complete." or "Purchase failed."), given and "hint" or "warning")
end)

hook.Add("PlayerInitialSpawn", "DHUD.Scoreboard.PlaytimeInit", function(ply)
    ply.Dubz_JoinTime = CurTime()
    timer.Simple(3, function()
        if IsValid(ply) then
            UpdateLeaderboardPlayer(ply)
            BroadcastPlaytimes(ply)
            BroadcastLeaderboards()
        end
    end)
end)

hook.Add("PlayerDisconnected", "DHUD.Scoreboard.PlaytimeSave", function(ply)
    if not ply or not ply.SteamID64 then return end

    local sid64 = tostring(ply:SteamID64() or "")
    if sid64 == "" or sid64 == "0" then return end

    local base = tonumber(playtimes[sid64] or 0) or 0
    local join = tonumber(ply.Dubz_JoinTime or CurTime()) or CurTime()
    UpdateLeaderboardPlayer(ply)
    playtimes[sid64] = math.max(base + CurTime() - join, 0)
    SavePlaytimes()
    SaveLeaderboards()
    timer.Simple(0, BroadcastLeaderboards)
end)

hook.Add("ShutDown", "DHUD.Scoreboard.PlaytimeShutdownSave", function()
    RefreshLeaderboards()
    SavePlaytimes()
    SaveLeaderboards()
end)

timer.Create("DHUD.Scoreboard.PlaytimeAutosave", 300, 0, function()
    RefreshLeaderboards()
    SavePlaytimes()
    SaveLeaderboardsThrottled(true)
end)
timer.Create("DHUD.Scoreboard.PlaytimeBroadcast", 30, 0, function()
    BroadcastPlaytimes()
end)

local nextLeaderboardBroadcast = 0
timer.Create("DHUD.Scoreboard.LeaderboardBroadcast", 5, 0, function()
    local leaderCfg = scoreboardConfig.Leaderboards or {}
    local interval = math.max(tonumber(leaderCfg.RefreshInterval) or 30, 10)
    if CurTime() < nextLeaderboardBroadcast then return end

    nextLeaderboardBroadcast = CurTime() + interval
    BroadcastLeaderboards()
end)
