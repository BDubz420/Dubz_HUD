local DHUD = DHUD
DHUD.Vote = DHUD.Vote or {}
DHUD.Vote.Panels = DHUD.Vote.Panels or {}
DHUD.Vote.Order = DHUD.Vote.Order or {}
DHUD.Vote.PanelSlot = DHUD.Vote.PanelSlot or {}
DHUD.Vote.OldNetReceivers = DHUD.Vote.OldNetReceivers or {}
DHUD.Vote.NetReceivers = DHUD.Vote.NetReceivers or {}

local iconCache = {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Vote or {}
end

local function WithAlpha(col, alpha)
    col = col or color_white
    return Color(col.r, col.g, col.b, alpha)
end

local function VoteKind(vote)
    local kind = tostring(vote.Type or vote.Kind or vote.VoteType or ""):lower()
    if kind == "lottery" then return "lottery" end
    if kind == "job" or kind == "jobvote" or kind == "team" then return "job" end

    local title = tostring(vote.Title or ""):lower()
    if string.find(title, "lottery", 1, true) then return "lottery" end
    if string.find(title, "job", 1, true)
        or string.find(title, "become", 1, true)
        or string.find(title, "mayor", 1, true)
        or string.find(title, "chief", 1, true)
        or string.find(title, "cp", 1, true) then
        return "job"
    end

    return "default"
end

local function IsLotteryVote(vote)
    return VoteKind(vote) == "lottery"
end

local function IsJobVote(vote)
    return VoteKind(vote) == "job"
end

local function LotteryAccent()
    return (DHUD.Config and DHUD.Config.Colors and DHUD.Config.Colors.Gold) or Color(221, 177, 74)
end

local function Accent(vote)
    if IsLotteryVote(vote) then return LotteryAccent() end
    if vote and istable(vote.Accent) and vote.Accent.r then return vote.Accent end
    return (DHUD.Config and DHUD.Config.Colors and (DHUD.Config.Colors.VoteAccent or DHUD.Config.Colors.Cash)) or Color(91, 201, 121)
end

local function HealthAccent()
    return (DHUD.Config and DHUD.Config.Colors and DHUD.Config.Colors.Health) or Color(232, 84, 84)
end

local function VoteBackground(alpha)
    local cfg = Cfg()
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local bg = cfg.Background or colors.VoteBackground or colors.Background2 or Color(31, 25, 25)

    if not (istable(bg) and bg.r) then
        bg = Color(31, 25, 25)
    end

    return Color(bg.r or 31, bg.g or 25, bg.b or 25, math.Clamp(alpha or 255, 230, 255))
end

local function LocalNotice(text, kind)
    if Cfg().StatusNotifications == false then return end

    if DHUD.Notify and DHUD.Notify.Add then
        DHUD.Notify.Add(text, kind or "hint", 3)
    end
end

local function HandleHoverSound(panel)
    if DubzLib and DubzLib.UI and DubzLib.UI.HandleHoverSound then
        DubzLib.UI.HandleHoverSound(panel)
    end
end

local function ParseQuestionArgs(args)
    local yesText
    local noText
    local yesFn
    local noFn
    local yesCommand
    local noCommand
    local duration

    for _, value in ipairs(args or {}) do
        if isstring(value) then
            local lower = string.lower(value)
            local commandLike = string.find(lower, "darkrp", 1, true) or string.find(lower, "vote", 1, true) or string.find(lower, "answer", 1, true) or string.StartWith(lower, "say ")
            if commandLike and not yesCommand then
                yesCommand = value
            elseif commandLike and not noCommand then
                noCommand = value
            elseif not yesText then
                yesText = value
            elseif not noText then
                noText = value
            end
        elseif isfunction(value) then
            if not yesFn then
                yesFn = value
            elseif not noFn then
                noFn = value
            end
        elseif isnumber(value) and not duration then
            duration = value
        end
    end

    return yesText, noText, yesFn, noFn, duration, yesCommand, noCommand
end

local function RunQuestionAction(fn, command, vote)
    if isfunction(fn) then fn(vote) end
    command = string.Trim(tostring(command or ""))
    if command ~= "" then
        LocalPlayer():ConCommand(command)
    end
end

local function DarkRPQuestionVisuals(question)
    local lower = string.lower(tostring(question or ""))
    local icon = "communication/forum"
    local colors = DHUD.Config and DHUD.Config.Colors or {}
    local accent = colors.Cash or Color(91, 201, 121)

    if string.find(lower, "warrant", 1, true) then
        icon = "admin/gavel"
        accent = HealthAccent()
    elseif string.find(lower, "license", 1, true) then
        icon = "economy/house"
    elseif string.find(lower, "job", 1, true) or string.find(lower, "become", 1, true) then
        icon = "darkrp/work"
        accent = colors.VoteAccent or colors.Cash or Color(91, 201, 121)
    elseif string.find(lower, "lottery", 1, true) then
        icon = "economy/diamond"
        accent = LotteryAccent()
    end

    return icon, accent
end

local function DarkRPQuestionKind(question)
    local lower = string.lower(tostring(question or ""))
    if string.find(lower, "lottery", 1, true) then return "lottery" end
    if string.find(lower, "job", 1, true)
        or string.find(lower, "become", 1, true)
        or string.find(lower, "mayor", 1, true)
        or string.find(lower, "chief", 1, true) then
        return "job"
    end
end

local function DarkRPQuestionSubtitle(question, kind)
    question = tostring(question or "")
    if kind == "lottery" then
        local amount = string.match(question, "[$][%d,%._]+") or string.match(question, "[%d,%._]+%s*money")
        if amount then return "Entry cost: " .. string.format("%d", amount) end
        return "Enter the lottery for a chance to win the pot."
    end

    if kind == "job" then
        return "Approve or deny this job change request."
    end

    return "DarkRP request"
end

local function CleanDarkRPQuestion(question)
    question = tostring(question or "Vote")
    question = string.Replace(question, "\\n", " ")
    question = string.Replace(question, "\n", " ")
    question = string.Trim(question)

    return question ~= "" and question or "Vote"
end

local function CreateDarkRPQuestion(question, id, duration, yesText, noText, yesFn, noFn)
    if not DubzLib or not DubzLib.Vote then return end
    local icon, accent = DarkRPQuestionVisuals(question)
    local questionID = tostring(id or "darkrp_question")
    local kind = DarkRPQuestionKind(question)

    return DubzLib.Vote.Create({
        ID = questionID,
        Title = CleanDarkRPQuestion(question),
        Subtitle = DarkRPQuestionSubtitle(question, kind),
        Type = kind or "darkrp",
        Duration = tonumber(duration) or 20,
        YesText = yesText or (kind == "lottery" and "Enter" or kind == "job" and "Approve" or "Yes"),
        NoText = noText or (kind == "lottery" and "Skip" or kind == "job" and "Deny" or "No"),
        Icon = icon,
        Accent = accent,
        OnYes = function(vote)
            if isfunction(yesFn) then
                yesFn(vote)
            else
                RunConsoleCommand("darkrp", "yes", questionID)
            end
        end,
        OnNo = function(vote)
            if isfunction(noFn) then
                noFn(vote)
            else
                RunConsoleCommand("darkrp", "no", questionID)
            end
        end
    })
end

local function VoteOverrideEnabled()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    return systems.Vote ~= false and Cfg().Enabled ~= false
end

function DHUD.Vote.InstallDarkRPConsoleVoteBridge()
    if DHUD.Vote.ConsoleVoteBridgeInstalled then return end

    DHUD.Vote.ConsoleVoteBridgeInstalled = true

    concommand.Add("rp_vote", function(_, _, args)
        if not DubzLib or not DubzLib.Vote then return end

        local accepted = false
        local value = string.lower(tostring(args and args[1] or ""))
        if value == "1" or value == "yes" or value == "true" then
            accepted = true
        end

        local votes = DubzLib.Vote.GetAll()
        local vote = votes and votes[1]
        if vote and vote.ID then
            DubzLib.Vote.Answer(vote.ID, accepted)
        end
    end)
end

function DHUD.Vote.InstallDarkRPMessageBridge()
    if DHUD.Vote.DarkRPMessageBridgeInstalled then return end
    DHUD.Vote.DarkRPMessageBridgeInstalled = true

    if net and net.Receive then
        local function StoreOldReceiver(name, receiver)
            if not net.Receivers then return end

            local key = string.lower(name)
            local existing = net.Receivers[key]
            if isfunction(existing) and existing ~= receiver and existing ~= DHUD.Vote.NetReceivers[key] then
                DHUD.Vote.OldNetReceivers[key] = existing
            end
        end

        local function PassToOld(name, len, ply)
            local receiver = DHUD.Vote.OldNetReceivers[string.lower(name)]
            if isfunction(receiver) then return receiver(len, ply) end
        end

        local function InstallQuestionReceiver(name, voteType)
            local receiver
            receiver = function(len, ply)
                local systems = DHUD.Config and DHUD.Config.Systems or {}
                if systems.Vote == false or Cfg().Enabled == false then
                    return PassToOld(name, len, ply)
                end

                local ok = pcall(function()
                    local question = net.ReadString()
                    local id = string.format("%d", net.ReadFloat() or 0)
                    local duration = net.ReadFloat()
                    CreateDarkRPQuestion(question, id, duration, nil, nil, nil, nil, voteType)
                end)
                if not ok and DHUD.Notify and DHUD.Notify.Add then
                    DHUD.Notify.Add("DarkRP vote bridge received an unknown question payload.", "warning", 3)
                end
            end

            StoreOldReceiver(name, receiver)
            DHUD.Vote.NetReceivers[string.lower(name)] = receiver
            net.Receive(name, receiver)
        end

        InstallQuestionReceiver("DarkRP_Question", "darkrp")
        InstallQuestionReceiver("DarkRP_Vote", "darkrp")

        local killQuestion
        killQuestion = function(len, ply)
            local systems = DHUD.Config and DHUD.Config.Systems or {}
            if systems.Vote == false or Cfg().Enabled == false then
                return PassToOld("DarkRP_KillQuestion", len, ply)
            end

            pcall(function()
                local id = string.format("%d", net.ReadFloat() or 0)
                if DubzLib and DubzLib.Vote then
                    DubzLib.Vote.Remove(id)
                end
            end)
        end
        StoreOldReceiver("DarkRP_KillQuestion", killQuestion)
        DHUD.Vote.NetReceivers[string.lower("DarkRP_KillQuestion")] = killQuestion
        net.Receive("DarkRP_KillQuestion", killQuestion)

        local killVote
        killVote = function(len, ply)
            local systems = DHUD.Config and DHUD.Config.Systems or {}
            if systems.Vote == false or Cfg().Enabled == false then
                return PassToOld("DarkRP_KillVote", len, ply)
            end

            pcall(function()
                local id = string.format("%d", net.ReadFloat() or 0)
                if DubzLib and DubzLib.Vote then
                    DubzLib.Vote.Remove(id)
                end
            end)
        end
        StoreOldReceiver("DarkRP_KillVote", killVote)
        DHUD.Vote.NetReceivers[string.lower("DarkRP_KillVote")] = killVote
        net.Receive("DarkRP_KillVote", killVote)
    end
end

function DHUD.Vote.InstallDarkRPBridge()
    if not DarkRP or not DubzLib or not DubzLib.Vote then return end

    if DarkRP.createQuestion and DarkRP.createQuestion ~= DHUD.Vote.CreateQuestionBridge then
        DHUD.Vote.OldCreateQuestion = DHUD.Vote.OldCreateQuestion or DarkRP.createQuestion
    end

    if DarkRP.destroyQuestion and DarkRP.destroyQuestion ~= DHUD.Vote.DestroyQuestionBridge then
        DHUD.Vote.OldDestroyQuestion = DHUD.Vote.OldDestroyQuestion or DarkRP.destroyQuestion
    end

    if DarkRP.createVote and DarkRP.createVote ~= DHUD.Vote.CreateVoteBridge then
        DHUD.Vote.OldCreateVote = DHUD.Vote.OldCreateVote or DarkRP.createVote
    end

    if DarkRP.destroyVote and DarkRP.destroyVote ~= DHUD.Vote.DestroyVoteBridge then
        DHUD.Vote.OldDestroyVote = DHUD.Vote.OldDestroyVote or DarkRP.destroyVote
    end

    DHUD.Vote.CreateQuestionBridge = function(question, id, ...)
        local systems = DHUD.Config and DHUD.Config.Systems or {}
        if (systems.Vote == false or Cfg().Enabled == false) and isfunction(DHUD.Vote.OldCreateQuestion) then
            return DHUD.Vote.OldCreateQuestion(question, id, ...)
        end

        local yesText, noText, yesFn, noFn, duration, yesCommand, noCommand = ParseQuestionArgs({...})
        return CreateDarkRPQuestion(question, id, duration, yesText, noText, function(vote) RunQuestionAction(yesFn, yesCommand, vote) end, function(vote) RunQuestionAction(noFn, noCommand, vote) end)
    end

    DHUD.Vote.DestroyQuestionBridge = function(id)
        local systems = DHUD.Config and DHUD.Config.Systems or {}
        if (systems.Vote == false or Cfg().Enabled == false) and isfunction(DHUD.Vote.OldDestroyQuestion) then
            return DHUD.Vote.OldDestroyQuestion(id)
        end

        return DubzLib.Vote.Remove(id)
    end

    DHUD.Vote.CreateVoteBridge = function(question, id, ...)
        local systems = DHUD.Config and DHUD.Config.Systems or {}
        if (systems.Vote == false or Cfg().Enabled == false) and isfunction(DHUD.Vote.OldCreateVote) then
            return DHUD.Vote.OldCreateVote(question, id, ...)
        end

        local yesText, noText, yesFn, noFn, duration, yesCommand, noCommand = ParseQuestionArgs({...})
        return CreateDarkRPQuestion(question, id, duration, yesText, noText, function(vote) RunQuestionAction(yesFn, yesCommand, vote) end, function(vote) RunQuestionAction(noFn, noCommand, vote) end)
    end

    DHUD.Vote.DestroyVoteBridge = function(id)
        local systems = DHUD.Config and DHUD.Config.Systems or {}
        if (systems.Vote == false or Cfg().Enabled == false) and isfunction(DHUD.Vote.OldDestroyVote) then
            return DHUD.Vote.OldDestroyVote(id)
        end

        return DubzLib.Vote.Remove(id)
    end

    DarkRP.createQuestion = DHUD.Vote.CreateQuestionBridge
    DarkRP.destroyQuestion = DHUD.Vote.DestroyQuestionBridge
    if DarkRP.createVote then DarkRP.createVote = DHUD.Vote.CreateVoteBridge end
    if DarkRP.destroyVote then DarkRP.destroyVote = DHUD.Vote.DestroyVoteBridge end
    DHUD.Vote.InstallDarkRPMessageBridge()
end

local function FallbackIcon(path, x, y, size, col)
    path = tostring(path or "")
    if path == "" then return end

    path = string.lower(path)
    path = string.Replace(path, "\\", "/")
    path = string.gsub(path, "^materials/", "")
    path = string.gsub(path, "%.png$", "")

    local mat = iconCache[path]
    if mat == nil then
        local candidates = {
            "dubzlib/icons/" .. path .. ".png",
            "dlib/icons/" .. path .. ".png",
            path .. ".png"
        }

        mat = false

        for _, candidate in ipairs(candidates) do
            local candidateMat = Material(candidate, "smooth mips")
            if candidateMat and not candidateMat:IsError() then
                mat = candidateMat
                break
            end
        end

        iconCache[path] = mat
    end

    if not mat then return end

    surface.SetMaterial(mat)
    surface.SetDrawColor(col or color_white)
    surface.DrawTexturedRect(x, y, size, size)
end

local function DrawIcon(icon, x, y, size, col)
    if DHUD.Icon and DHUD.Icon.Draw and DHUD.Icon.Draw(icon, x, y, size, col) then
        return
    end

    if DubzLib.Icon and DubzLib.Icon.Draw then
        DubzLib.Icon.Draw(icon, x, y, size, col)
    end

    FallbackIcon(icon, x, y, size, col)
end

local function DrawIconChip(icon, x, y, accent, alpha, size)
    size = size or 20

    draw.RoundedBox(DubzLib.Radius("SM"), x, y, size, size, WithAlpha(accent, 36 * (alpha / 255)))
    DrawIcon(icon or "communication/forum", x + math.floor((size - 16) * 0.5), y + math.floor((size - 16) * 0.5), 16, WithAlpha(accent, alpha))
end

local function TrimText(text, font, maxWide)
    text = tostring(text or "")
    surface.SetFont(font)

    if surface.GetTextSize(text) <= maxWide then return text end

    local suffix = "..."
    local suffixWide = surface.GetTextSize(suffix)

    for i = #text, 1, -1 do
        local cut = string.sub(text, 1, i)
        if surface.GetTextSize(cut) + suffixWide <= maxWide then
            return cut .. suffix
        end
    end

    return suffix
end

local function MoveValue(current, target, speed)
    local nextValue = math.Approach(current, target, FrameTime() * speed)

    if math.abs(nextValue - target) <= 0.35 then
        return target
    end

    return nextValue
end

local function FadeValue(current, target, speed)
    local nextValue = math.Approach(current or 0, target, FrameTime() * speed)

    if math.abs(nextValue - target) <= 1 then
        return target
    end

    return nextValue
end

local function MaxVisible()
    if DHUD.Preview and (DHUD.Preview.VoteMaxVisibleUntil or 0) > CurTime() then
        return math.max(tonumber(DHUD.Preview.VoteMaxVisible) or 0, Cfg().MaxVisible or 5)
    end

    return Cfg().MaxVisible or 5
end

local function SlotPos(slot)
    local cfg = Cfg()
    local w = cfg.Width or 292
    local h = cfg.Height or 78
    local gap = cfg.Gap or 7
    local x = cfg.AnchorX or cfg.LeftPadding or 24
    local y = cfg.AnchorY or cfg.Y or math.floor(ScrH() * 0.36)

    if cfg.LeftPadding == false then
        x = ScrW() - w - (cfg.RightPadding or 24)
    end

    return x, y + ((slot - 1) * (h + gap))
end

local function OffscreenX(panel)
    if Cfg().LeftPadding == false then
        return ScrW() + panel:GetWide() + 28
    end

    return -panel:GetWide() - 28
end

local function PrepareQueuedVote(vote)
    if vote.DHUDPrepared then return end

    vote.DHUDPrepared = true
    vote.DHUDWasLive = false
    vote.DHUDDuration = tonumber(vote.Duration) or math.max((vote.Expires or CurTime()) - CurTime(), 1)
end

local function PauseQueuedVote(vote)
    PrepareQueuedVote(vote)

    if vote.DHUDWasLive then return end

    vote.Expires = CurTime() + vote.DHUDDuration

    if not vote.DHUDQueuedNotice then
        vote.DHUDQueuedNotice = true
        LocalNotice("Vote queued: " .. tostring(vote.Title or "New vote"), "hint")
    end
end

local function StartLiveVote(vote)
    PrepareQueuedVote(vote)

    if vote.DHUDWasLive then return end

    vote.DHUDWasLive = true
    vote.Expires = CurTime() + vote.DHUDDuration

    LocalNotice("Vote is now live: " .. tostring(vote.Title or "New vote"), "success")
end

local function ButtonPaint(self, w, h)
    HandleHoverSound(self)
    local accent = self.DubzAccent or DubzLib.Color("Primary")
    local icon = self.DubzIcon or "misc/check"
    local alpha = self:GetAlpha() or 255
    local chip = 20
    local pad = 0
    local bg = self:IsHovered() and DubzLib.Color("Card") or Color(35, 35, 35)
    local border = self:IsHovered() and WithAlpha(accent, 135) or WithAlpha(DubzLib.Color("BorderSoft"), 125)

    DubzLib.Draw.Panel(0, 0, w, h, {
        Radius = "SM",
        Color = WithAlpha(bg, alpha),
        Border = WithAlpha(border, math.min(alpha, 155)),
        Shadow = false
    })

    draw.RoundedBox(DubzLib.Radius("SM"), pad, h * 0.5 - chip * 0.5, chip, chip, WithAlpha(accent, 40))
    DrawIcon(icon, pad +2, h * 0.5 - 7, 16, WithAlpha(accent, alpha))

    DubzLib.Draw.Text(self:GetText(), DubzLib.Font("Small"), pad + chip + 7, h * 0.5, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    return true
end

local function RemovePanel(id)
    local pnl = DHUD.Vote.Panels[id]
    DHUD.Vote.Panels[id] = nil
    DHUD.Vote.PanelSlot[id] = nil

    if not IsValid(pnl) then return end

    pnl.Removing = true
    pnl.TargetX = OffscreenX(pnl)
    pnl.TargetAlpha = 0

    timer.Simple(0.24, function()
        if IsValid(pnl) then
            pnl:Remove()
        end
    end)
end

local function CreatePanel(vote, slot)
    local cfg = Cfg()
    local w = cfg.Width or 292
    local h = cfg.Height or 78
    local pad = cfg.Pad or 8
    local buttonH = cfg.ButtonHeight or 21
    local accentW = cfg.AccentWidth or 4
    local iconSize = cfg.IconChipSize or 20
    local isLottery = IsLotteryVote(vote)
    local targetX, targetY = SlotPos(slot)

    local pnl = vgui.Create("DPanel")
    if DHUD.TrackPanel then DHUD.TrackPanel(pnl) end
    pnl:SetSize(w, h)
    pnl:SetPaintBackground(false)
    pnl:SetAlpha(0)
    pnl.DrawAlpha = 0
    pnl.TargetAlpha = 255
    pnl.TargetX = targetX
    pnl.TargetY = targetY
    pnl.VoteID = vote.ID
    pnl.DHUDVotePanel = true
    pnl:SetPos(OffscreenX(pnl), targetY)

    local yes = vgui.Create("DButton", pnl)
    yes.DHUDVotePanel = true
    yes:SetText(DHUD.L and DHUD.L(vote.YesText or (isLottery and "Enter" or IsJobVote(vote) and "Approve" or "Yes")) or (vote.YesText or (isLottery and "Enter" or IsJobVote(vote) and "Approve" or "Yes")))
    yes:SetFont(DubzLib.Font("Small"))
    yes:SetTextColor(color_white)
    yes.DubzAccent = isLottery and LotteryAccent() or Accent(vote)
    yes.DubzIcon = isLottery and "economy/diamond" or IsJobVote(vote) and "darkrp/work" or "misc/check"
    yes.Paint = ButtonPaint
    yes.DoClick = function()
        if DubzLib.Vote then DubzLib.Vote.Answer(vote.ID, true) end
    end

    local no = vgui.Create("DButton", pnl)
    no.DHUDVotePanel = true
    no:SetText(DHUD.L and DHUD.L(vote.NoText or (isLottery and "Skip" or IsJobVote(vote) and "Deny" or "No")) or (vote.NoText or (isLottery and "Skip" or IsJobVote(vote) and "Deny" or "No")))
    no:SetFont(DubzLib.Font("Small"))
    no:SetTextColor(color_white)
    no.DubzAccent = HealthAccent()
    no.DubzIcon = "misc/cancel"
    no.Paint = ButtonPaint
    no.DoClick = function()
        if DubzLib.Vote then DubzLib.Vote.Answer(vote.ID, false) end
    end

    pnl.PerformLayout = function(self, pw, ph)
        local buttonW = math.floor((pw - accentW - pad * 2 - 6) * 0.5)
        local buttonY = ph - pad - buttonH

        yes:SetSize(buttonW, buttonH)
        no:SetSize(buttonW, buttonH)
        yes:SetPos(accentW + pad, buttonY)
        no:SetPos(accentW + pad + buttonW + 6, buttonY)
    end

    pnl.Think = function(self)
        local cfgNow = Cfg()
        local moveSpeed = cfgNow.MoveSpeed or 1450
        local fadeSpeed = cfgNow.FadeSpeed or 950
        local x, y = self:GetPos()

        self:SetPos(
            MoveValue(x, self.TargetX or x, moveSpeed),
            MoveValue(y, self.TargetY or y, moveSpeed)
        )

        self.DrawAlpha = FadeValue(self.DrawAlpha or 0, self.TargetAlpha or 255, fadeSpeed)
        self:SetAlpha(math.Clamp(self.DrawAlpha or 255, 0, 255))
    end

    pnl.Paint = function(self, pw, ph)
        local activeVote = DubzLib.Vote and DubzLib.Vote.Active and DubzLib.Vote.Active[self.VoteID]
        if not activeVote then return end

        local lottery = IsLotteryVote(activeVote)
        local jobVote = IsJobVote(activeVote)
        local alpha = math.Clamp(self.DrawAlpha or 255, 0, 255)
        local accent = Accent(activeVote)
        local icon = activeVote.Icon or (lottery and "economy/diamond" or jobVote and "darkrp/work" or "communication/forum")
        local progress = math.Clamp((activeVote.Expires - CurTime()) / math.max(activeVote.DHUDDuration or activeVote.Duration or 1, 1), 0, 1)
        local textX = accentW + pad + iconSize + 8
        local textW = pw - textX - pad

        local titleText = activeVote.Title
        if lottery and (not titleText or titleText == "") then
            titleText = "Join the lottery?"
        elseif jobVote and (not titleText or titleText == "") then
            titleText = "Approve job vote?"
        end

        local subtitleText = activeVote.Subtitle
        if lottery and (not subtitleText or subtitleText == "") then
            subtitleText = "Enter the lottery for a chance to win the pot."
        elseif jobVote and (not subtitleText or subtitleText == "") then
            subtitleText = "Approve or deny this job change request."
        end

        local title = TrimText(titleText, DubzLib.Font("Body"), textW)
        local subtitle = TrimText(subtitleText or "", DubzLib.Font("Small"), textW)

        draw.RoundedBox(DubzLib.Radius("MD"), 0, 0, pw, ph, WithAlpha(accent, alpha))

        DubzLib.Draw.Panel(accentW, -1, pw - accentW + 1, ph + 2, {
            Radius = "MD",
            Color = VoteBackground(math.min(alpha, (cfg.InnerAlpha or 255) * (alpha / 255))),
            Border = WithAlpha(cfg.Border or DubzLib.Color("BorderSoft"), math.min(alpha, 160)),
            Shadow = false
        })

        DrawIconChip(icon, accentW + pad, pad, accent, alpha, iconSize)

        DubzLib.Draw.Text(DHUD.L and DHUD.L(title) or title, DubzLib.Font("Body"), textX, pad - 1, WithAlpha(DubzLib.Color("Foreground"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if subtitle ~= "" then
            DubzLib.Draw.Text(DHUD.L and DHUD.L(subtitle) or subtitle, DubzLib.Font("Small"), textX, pad + 17, WithAlpha(DubzLib.Color("Muted"), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local barX = accentW + pad
        local barW = pw - accentW - pad * 2
        local barH = 2
        local barY = ph - pad - buttonH - 6

        draw.RoundedBox(DubzLib.Radius("XS"), barX, barY, barW, barH, WithAlpha(DubzLib.Color("Background2"), math.min(alpha, 120)))
        draw.RoundedBox(DubzLib.Radius("XS"), barX, barY, barW * progress, barH, WithAlpha(accent, alpha))

    end

    DHUD.Vote.Panels[vote.ID] = pnl
    return pnl
end

local function RebuildOrder(votes)
    local active = {}
    local known = {}

    for _, vote in ipairs(votes) do
        active[vote.ID] = vote
    end

    local kept = {}

    for _, id in ipairs(DHUD.Vote.Order or {}) do
        if active[id] then
            kept[#kept + 1] = id
            known[id] = true
        end
    end

    for _, vote in ipairs(votes) do
        if not known[vote.ID] then
            kept[#kept + 1] = vote.ID
            known[vote.ID] = true
        end
    end

    DHUD.Vote.Order = kept
    return active
end

local function SyncVotePanels()
    local cfg = Cfg()
    local systems = DHUD.Config and DHUD.Config.Systems or {}
    if systems.Vote == false or cfg.Enabled == false or not DubzLib or not DubzLib.Vote then
        for id in next, (DHUD.Vote.Panels or {}) do
            RemovePanel(id)
        end
        return
    end

    local votes = DubzLib.Vote.GetAll()
    local active = RebuildOrder(votes)
    local visible = {}

    for slot = 1, MaxVisible() do
        local id = DHUD.Vote.Order[slot]
        if id then
            visible[id] = slot
        end
    end

    for _, id in ipairs(DHUD.Vote.Order) do
        local vote = active[id]
        if vote then
            if visible[id] then
                StartLiveVote(vote)
            else
                PauseQueuedVote(vote)
            end
        end
    end

    for id in next, (DHUD.Vote.Panels) do
        if not active[id] or not visible[id] then
            RemovePanel(id)
        end
    end

    for id, slot in next, (visible) do
        local vote = active[id]
        if vote then
            local pnl = DHUD.Vote.Panels[id]

            if not IsValid(pnl) then
                pnl = CreatePanel(vote, slot)
            end

            DHUD.Vote.PanelSlot[id] = slot
            pnl.TargetX, pnl.TargetY = SlotPos(slot)
            pnl.TargetAlpha = 255
        end
    end
end

local nextPanelSync = 0
local function SyncVotePanelsHook()
    if CurTime() >= nextPanelSync then
        nextPanelSync = CurTime() + 0.05
        SyncVotePanels()
    end
end

local function PanelHasVoteButtons(pnl)
    if not IsValid(pnl) then return false end
    if pnl.DHUDVotePanel then return false end

    local foundAction
    local foundCancel
    for _, child in ipairs(pnl:GetChildren() or {}) do
        local text = string.lower(tostring(child.GetText and child:GetText() or ""))
        if text == "demote" or text == "vote" or text == "yes" or text == "approve" or text == "buy in" or text == "enter" then
            foundAction = true
        elseif text == "cancel" or text == "no" or text == "deny" or text == "pass" or text == "skip" then
            foundCancel = true
        elseif PanelHasVoteButtons(child) then
            return true
        end
    end

    return foundAction and foundCancel
end

local function IsDefaultVoteButtonText(text)
    text = string.lower(string.Trim(tostring(text or "")))
    return text == "demote"
        or text == "cancel"
        or text == "vote"
        or text == "yes"
        or text == "no"
        or text == "approve"
        or text == "deny"
        or text == "buy in"
        or text == "enter"
        or text == "pass"
        or text == "skip"
end

local function HideDefaultVoteButtons(pnl, depth)
    if not IsValid(pnl) or pnl.DHUDVotePanel or depth > 5 then return end

    local shouldHide = false

    if pnl.GetText and IsDefaultVoteButtonText(pnl:GetText()) then
        local stackX, stackY = SlotPos(1)
        local stackW = Cfg().Width or 292
        local x, y = pnl:LocalToScreen(0, 0)
        local nearVoteStack = x >= stackX - 12 and x <= stackX + stackW + 36 and y >= stackY - 18
        local buttonSized = pnl:GetWide() <= 180 and pnl:GetTall() <= 48

        shouldHide = nearVoteStack and buttonSized
    end

    if shouldHide then
        pnl:SetVisible(false)
        pnl:SetMouseInputEnabled(false)
        pnl:SetKeyboardInputEnabled(false)
    end

    for _, child in ipairs(pnl:GetChildren() or {}) do
        HideDefaultVoteButtons(child, depth + 1)
    end
end

local function HideDefaultVotePanels()
    if not VoteOverrideEnabled() or not DubzLib or not DubzLib.Vote or not next(DubzLib.Vote.Active or {}) then return end
    if not vgui or not IsValid(vgui.GetWorldPanel()) then return end

    for _, pnl in ipairs(vgui.GetWorldPanel():GetChildren() or {}) do
        if IsValid(pnl) and not pnl.DHUDVotePanel and PanelHasVoteButtons(pnl) then
            pnl:SetVisible(false)
            pnl:SetMouseInputEnabled(false)
            pnl:SetKeyboardInputEnabled(false)
        else
            HideDefaultVoteButtons(pnl, 0)
        end
    end
end

local nextBridgeCheck = 0
local function KeepDarkRPVoteBridgeHook()
    if CurTime() >= nextBridgeCheck then
        nextBridgeCheck = CurTime() + 0.25
        local systems = DHUD.Config and DHUD.Config.Systems or {}
        if systems.Vote ~= false and Cfg().Enabled ~= false and DarkRP and DHUD.Vote and DHUD.Vote.InstallDarkRPBridge and (
            (not DHUD.Vote.CreateQuestionBridge or DarkRP.createQuestion ~= DHUD.Vote.CreateQuestionBridge)
            or (DarkRP.createVote and DarkRP.createVote ~= DHUD.Vote.CreateVoteBridge)
        ) then
            DHUD.Vote.InstallDarkRPBridge()
        end
    end
end

hook.Add("Think", "DHUD.SyncVotePanels", SyncVotePanelsHook)
hook.Add("Think", "DHUD.HideDefaultDarkRPVotePanels", HideDefaultVotePanels)
hook.Add("Think", "DHUD.KeepDarkRPVoteBridge", KeepDarkRPVoteBridgeHook)

timer.Simple(0, function()
    if DHUD.Vote and DHUD.Vote.InstallDarkRPBridge then DHUD.Vote.InstallDarkRPBridge() end
    if DHUD.Vote and DHUD.Vote.InstallDarkRPMessageBridge then DHUD.Vote.InstallDarkRPMessageBridge() end
    if DHUD.Vote and DHUD.Vote.InstallDarkRPConsoleVoteBridge then DHUD.Vote.InstallDarkRPConsoleVoteBridge() end
end)

timer.Simple(2, function()
    if DHUD.Vote and DHUD.Vote.InstallDarkRPBridge then DHUD.Vote.InstallDarkRPBridge() end
    if DHUD.Vote and DHUD.Vote.InstallDarkRPMessageBridge then DHUD.Vote.InstallDarkRPMessageBridge() end
    if DHUD.Vote and DHUD.Vote.InstallDarkRPConsoleVoteBridge then DHUD.Vote.InstallDarkRPConsoleVoteBridge() end
end)

local function InstallVoteBridgeHook()
    if DHUD.Vote and DHUD.Vote.InstallDarkRPBridge then DHUD.Vote.InstallDarkRPBridge() end
    if DHUD.Vote and DHUD.Vote.InstallDarkRPMessageBridge then DHUD.Vote.InstallDarkRPMessageBridge() end
    if DHUD.Vote and DHUD.Vote.InstallDarkRPConsoleVoteBridge then DHUD.Vote.InstallDarkRPConsoleVoteBridge() end
end

hook.Add("InitPostEntity", "DHUD.InstallVoteBridge", InstallVoteBridgeHook)
hook.Add("OnReloaded", "DHUD.InstallVoteBridge", InstallVoteBridgeHook)

local function RemoveVotePanelHook(vote)
    if vote and vote.ID then
        RemovePanel(vote.ID)
    end
end

hook.Add("DubzLib.VoteRemoved", "DHUD.RemoveVotePanel", RemoveVotePanelHook)
