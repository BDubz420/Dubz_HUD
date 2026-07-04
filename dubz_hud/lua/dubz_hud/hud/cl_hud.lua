local DHUD = DHUD
DHUD.Preview = DHUD.Preview or {}
DHUD.Preview.Features = DHUD.Preview.Features or {}

function DHUD.IsPreviewActive()
    return (DHUD.Preview.EndTime or 0) > CurTime()
end

function DHUD.IsPreviewFeature(name)
    if DHUD.IsPreviewActive() then return true end

    name = tostring(name or "")
    return (DHUD.Preview.Features[name] or 0) > CurTime()
end

local function SetPreviewFeature(name, duration)
    DHUD.Preview.Features[tostring(name or "")] = CurTime() + (duration or 12)
end

local function SystemEnabled(name)
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    return systems[name] ~= false
end

hook.Add("HUDPaint", "DHUD.Paint", function()

    local ply = LocalPlayer()

    if not IsValid(ply) then return end
    if not DHUD.Config then return end
    if not DubzLib or not DubzLib.Draw then return end

    local style = DHUD.Config.HUDStyle or "card"

    if SystemEnabled("HUD") and style == "card" then

        if DHUD.DrawCardHUD then
            DHUD.DrawCardHUD()
        end
    elseif SystemEnabled("HUD") and style == "bar" then

        if DHUD.DrawBarHUD then
            DHUD.DrawBarHUD()
        end
    end

    if SystemEnabled("Overhead") and DHUD.DrawOverheadHUD then
        DHUD.DrawOverheadHUD()
    end

    if SystemEnabled("Doors") and DHUD.DrawDoorHUD then
        DHUD.DrawDoorHUD()
    end

    if SystemEnabled("Ammo") and DHUD.DrawAmmoHUD then
        DHUD.DrawAmmoHUD()
    end

    if SystemEnabled("Notifications") and DHUD.DrawNotifications then
        DHUD.DrawNotifications()
    end

    if SystemEnabled("Status") and DHUD.DrawStatusAnnouncements then
        DHUD.DrawStatusAnnouncements()
    end

    if SystemEnabled("Status") and DHUD.DrawAgendaCard then
        DHUD.DrawAgendaCard()
    end

    if SystemEnabled("Laws") and DHUD.DrawLawsPanel then
        DHUD.DrawLawsPanel()
    end
end)

function DHUD.InstallDefaultHudSuppressor()
    if DubzLib and DubzLib.EnableDarkRPHUD then
        DubzLib.EnableDarkRPHUD()
    else
        hook.Remove("HUDShouldDraw", "DubzLib.DisableDarkRPHUD")
    end

    hook.Add("HUDShouldDraw", "DHUD.HideDefaultDarkRPHUD", function(name)
        local blocked = {
            DarkRP_HUD = true,
            DarkRP_LocalPlayerHUD = true,
            DarkRP_Hungermod = true,
            DarkRP_Agenda = true,
            DarkRP_LockdownHUD = true,
            DarkRP_ArrestedHUD = true,
            DarkRP_EntityDisplay = true
        }

        if blocked[name] and SystemEnabled("HUD") then return false end
    end)
end

hook.Add("InitPostEntity", "DHUD.Setup", DHUD.InstallDefaultHudSuppressor)
DHUD.InstallDefaultHudSuppressor()

local function AddPreviewNotification(delay, text, kind, life)
    timer.Simple(delay, function()
        if DHUD.Notify and DHUD.Notify.Add then
            DHUD.Notify.Add(text, kind, life or 8)
        end
    end)
end

function DHUD.RunNotificationTests()
    AddPreviewNotification(0, "Short hint", NOTIFY_HINT, 8)
    AddPreviewNotification(0.12, "This notification expands to fit the filled text.", "success", 8)
    AddPreviewNotification(0.24, "Warning: stacked notification preview with a longer line of text", "warning", 8)
    AddPreviewNotification(0.36, "Unable to complete that action because the preview is intentionally noisy", NOTIFY_ERROR, 8)
    AddPreviewNotification(0.48, "Cleanup complete", NOTIFY_CLEANUP, 8)
    AddPreviewNotification(0.60, "Undo action is available", NOTIFY_UNDO, 8)

    if DHUD.Notify and DHUD.Notify.AddProgress then
        DHUD.Notify.AddProgress("dhud_preview_progress", "Progress notification preview")

        timer.Simple(8, function()
            if DHUD.Notify and DHUD.Notify.Kill then
                DHUD.Notify.Kill("dhud_preview_progress")
            end
        end)
    end

    print("[DHUD] Notification test started.")
end

function DHUD.RunVoteTests()
    if not DubzLib or not DubzLib.Vote then
        print("[DHUD] DubzLib.Vote is missing; skipping vote preview.")
        return
    end

    DHUD.Preview.VoteMaxVisible = 5
    DHUD.Preview.VoteMaxVisibleUntil = CurTime() + 22

    for i = 1, 5 do
        DubzLib.Vote.Remove("dhud_preview_vote_" .. i)
    end

    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local tests = {
        {
            Title = "Start a lockdown vote?",
            Subtitle = "Regular vote preview.",
            YesText = "Approve",
            NoText = "Deny",
            Icon = "communication/forum",
            Accent = colors.Cash
        },
        {
            Title = "Join the lottery?",
            Subtitle = "Ticket price: $500",
            YesText = "Enter",
            NoText = "Skip",
            Icon = "economy/diamond",
            Accent = colors.Gold
        },
        {
            Title = "Change the map after this round?",
            Subtitle = "Queued vote preview.",
            YesText = "Change",
            NoText = "Stay",
            Icon = "navigation/settings",
            Accent = colors.Clock
        },
        {
            Title = "City lottery is open!",
            Subtitle = "Ticket price: $1,000",
            YesText = "Buy In",
            NoText = "Pass",
            Icon = "economy/diamond",
            Accent = colors.Gold
        },
        {
            Title = "Start emergency broadcast?",
            Subtitle = "Stacking behavior preview.",
            YesText = "Start",
            NoText = "No",
            Icon = "communication/notifications_active",
            Accent = colors.Health
        }
    }

    for i, vote in ipairs(tests) do
        local idx = i
        local voteData = table.Copy(vote)

        timer.Simple((i - 1) * 0.12, function()
            if not DubzLib or not DubzLib.Vote then return end

            voteData.ID = "dhud_preview_vote_" .. idx
            voteData.Duration = 20
            DubzLib.Vote.Create(voteData)
        end)
    end

    print("[DHUD] Vote stack test started.")
end

function DHUD.RunAmmoTest()
    SetPreviewFeature("ammo", 14)
    print("[DHUD] Ammo preview forced on for 14 seconds.")
end

function DHUD.RunClockTest(mode)
    mode = string.lower(tostring(mode or ""))

    if mode ~= "realtime" and mode ~= "atmos" then
        print("[DHUD] Clock mode must be realtime or atmos.")
        return
    end

    DHUD.Config.Clock = DHUD.Config.Clock or {}
    DHUD.Config.Clock.Mode = mode

    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add("Clock mode: " .. mode, "hint", 4)
    end

    print("[DHUD] Clock mode set to " .. mode .. ".")
end

function DHUD.RunOverheadTest()
    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add("Overhead test: nameplates now require line of sight. Wanted players show Wanted!", "hint", 6)
    end

    print("[DHUD] Overhead UI test note: check another player from behind a wall, then with line of sight. Wanted players show Wanted!.")
end

function DHUD.RunStatusTest()
    SetPreviewFeature("status", 18)
    print("[DHUD] Status preview forced on for 18 seconds.")
end

function DHUD.RunPreviewTest()
    DHUD.Preview.EndTime = CurTime() + 22
    DHUD.Preview.Features = {}
    SetPreviewFeature("ammo", 22)
    DHUD.RunStatusTest()
    DHUD.RunNotificationTests()
    DHUD.RunVoteTests()
    hook.Run("AddDeathNotice", "Preview Killer", TEAM_UNASSIGNED, "weapon_preview", "Preview Victim", TEAM_UNASSIGNED)

    if DHUD.WeaponSelector and DHUD.WeaponSelector.OpenPreview then
        DHUD.WeaponSelector.OpenPreview(22)
    end

    if DHUD.Laws then
        DHUD.Laws.Open = true
    end

    if DHUD.MOTD and DHUD.MOTD.Open then
        timer.Simple(0.35, function()
            if DHUD.MOTD and DHUD.MOTD.Open then DHUD.MOTD.Open() end
        end)
    end

    print("[DHUD] Preview test started. Showing the selected HUD style plus votes, notifications, death feed, laws, MOTD, weapon selector, status, and ammo.")
end
