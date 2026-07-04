local DHUD = DHUD

local function ThemeColor(name, fallback)
    if DubzLib and DubzLib.Color then
        return DubzLib.Color(name)
    end

    return fallback
end

-- This file intentionally overwrites DHUD.Config on include.
-- That makes lua refresh / file reloads pick up HUDStyle and layout edits immediately.
DHUD.Config = {
    HUDStyle = "bar", -- "bar" or "card"
    Language = "en",

    Systems = {
        HUD = true,
        Scoreboard = true,
        MOTD = true,
        Notifications = true,
        DeathNotice = true,
        Voice = true,
        Vote = true,
        WeaponSelector = true,
        Doors = true,
        DoorOptions = true,
        Laws = true,
        Overhead = true,
        Ammo = true,
        Status = true,
        DeathScreen = true,
        Connection = true,
        DarkRPMenus = true,
        Vehicle = true
    },

    Clock = {
        Mode = "realtime", -- "realtime" or "atmos"
        RealtimeFormat = "%I:%M %p",
        AtmosGlobal = "Atmos_Time",
        AtmosFallback = "0:00 AM"
    },

    Interface = {
        HoverSounds = true,
        HoverSoundChoice = "rollover",
        HoverSound = "ui/buttonrollover.wav"
    },

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

    Credits = {
        Enabled = false,
        AutoDetect = true,
        ShowInScoreboard = false,
        Products = {}
    },

    Inventory = {
        Enabled = false,
        AutoDetect = true
    },

    PointShop = {
        Enabled = false,
        AutoDetect = true
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

    DeathScreen = {
        SupportEnabled = false,
        Enabled = true,
        Title = "You Died",
        Subtitle = "Take a breath. You can respawn when the server allows it.",
        Hint = "Press {key} to respawn",
        RespawnKey = "any",
        XPercent = 0.5,
        YPercent = 0.44,
        RandomMessagesEnabled = false,
        RandomMessages = {
            "You Died",
            "Down but not out",
            "Respawn when ready"
        },
        Width = 520,
        Height = 178,
        AccentWidth = 6,
        DimAlpha = 175,
        Blur = true,
        Icon = "players/skull"
    },

    Voice = {
        Enabled = true,
        Width = 292,
        Height = 42,
        Gap = 7,
        Right = 24,
        NotificationGap = 8,
        HoldTime = 0.8,
        MaxVisible = 4,
        Overhead = true,
        OverheadSize = 24,
        OverheadOffset = 16
    },

    Connection = {
        Enabled = true,
        Timeout = 6,
        Title = "Connection Interrupted",
        Subtitle = "Trying to reconnect to the server...",
        Icon = "communication/no_connection",
        OverlayAlpha = 205,
        WindowWidth = 420,
        WindowHeight = 198,
        AutoRetry = true,
        RetryDelay = 30,
        Blur = true,
        ShowDisconnect = true
    },

    Colors = {
        Health = Color(232, 84, 84),
        Armor = Color(91, 159, 232),
        Cash = Color(91, 201, 121),
        Gold = Color(221, 177, 74),
        Props = Color(238, 146, 80),
        Hunger = Color(238, 146, 80),
        Oxygen = Color(90, 206, 232),
        Identity = Color(190, 86, 82),
        Job = Color(235, 235, 235),
        Clock = Color(190, 86, 82),
        Background = Color(31, 25, 25),
        Background2 = Color(40, 32, 32),
        HUDAccent = Color(190, 86, 82),
        HUDBackground = Color(31, 25, 25),
        VoiceAccent = Color(190, 86, 82),
        VoiceBackground = Color(31, 25, 25),
        ScoreboardAccent = Color(190, 86, 82),
        ScoreboardBackground = Color(31, 25, 25),
        ScoreboardPanel = Color(40, 32, 32),
        MOTDAccent = Color(190, 86, 82),
        MOTDBackground = Color(31, 25, 25),
        MOTDCardBackground = Color(40, 32, 32),
        NotificationAccent = Color(190, 86, 82),
        NotificationBackground = Color(31, 25, 25),
        ConfigAccent = Color(190, 86, 82),
        ConfigBackground = Color(31, 25, 25),
        ConfigPanel = Color(40, 32, 32),
        ConfigField = Color(33, 27, 27),
        LawsAccent = Color(190, 86, 82),
        LawsBackground = Color(31, 25, 25),
        DoorAccent = Color(190, 86, 82),
        DoorBackground = Color(31, 25, 25),
        VoteAccent = Color(190, 86, 82),
        VoteBackground = Color(31, 25, 25),
        VehicleAccent = Color(190, 86, 82),
        VehicleBackground = Color(31, 25, 25),
        AmmoAccent = Color(221, 177, 74),
        AmmoBackground = Color(27, 28, 33),
        Warning = Color(238, 146, 80),
        Ammo = Color(221, 177, 74),
        Wanted = Color(232, 84, 84),
        Arrested = Color(91, 159, 232),
        License = Color(91, 201, 121),
        Lockdown = Color(238, 146, 80),
        Agenda = Color(190, 86, 82)
    },

    Radius = {
        XS = 4,
        SM = 6,
        MD = 10,
        LG = 14,
        XL = 18
    },

    Bar = {
        Enabled = true,
        AnimateNumbers = true,
        NumberAnimSpeed = 18,

        Layout = {
            Height = 42,
            Edge = "top",
            StartY = 6,
            StartX = 10,
            RightX = 10,
            Gap = 8,
            ClockWide = 104,
            LerpSpeed = 16,
            ReserveRightTrack = true
        },

        Section = {
            Height = 30,
            PadX = 12,
            IconSize = 16,
            IconWide = 24,
            ChipSize = 22,
            MinWide = 86,
            DefaultWide = 118,
            Background = nil,
            Border = nil,
            Shadow = false
        },

        BottomAccentLine = {
            Enabled = false,
            Height = 2,
            Color = nil,
            Alpha = 210
        },

        LeftEntries = {
            "identity",
            "health",
            "armor",
            "oxygen",
            "hunger",
            "salary",
            "wallet",
            "props"
        },

        RightEntries = {
            "clock",
            "arrested",
            "wanted",
            "gunlicense",
        },

        Entries = {
            identity = {
                Enabled = true,
                Type = "identity",
                Icon = "darkrp/account_circle",
                Accent = "identity",
                MinWide = 170
            },
            health = {
                Enabled = true,
                Type = "health",
                Icon = "health",
                Label = "HP",
                MinWide = 88
            },
            armor = {
                Enabled = "auto",
                Type = "armor",
                Icon = "armor",
                Label = "AR",
                MinWide = 88
            },
            oxygen = {
                Enabled = "auto",
                Type = "oxygen",
                Icon = "misc/spo2",
                Label = "O2",
                MinWide = 92
            },
            hunger = {
                Enabled = "auto",
                Type = "hunger",
                Icon = "players/hunger",
                Label = "Hunger",
                MinWide = 118
            },
            props = {
                Enabled = true,
                Type = "props",
                Icon = "misc/handyman",
                Label = "Props",
                MinWide = 112
            },
            salary = {
                Enabled = true,
                Type = "salary",
                Icon = "money",
                Label = "Salary",
                MinWide = 132
            },
            wallet = {
                Enabled = true,
                Type = "wallet",
                Icon = "wallet",
                Label = "Wallet",
                MinWide = 146
            },
            clock = {
                Enabled = true,
                Type = "clock",
                Icon = "communication/notifications",
                MinWide = 104
            },
            gunlicense = {
                Enabled = "auto",
                Type = "gunlicense",
                Icon = "economy/house",
                Label = "License",
                MinWide = 116
            },
            wanted = {
                Enabled = "auto",
                Type = "wanted",
                Icon = "admin/warning",
                Label = "Wanted",
                MinWide = 108
            },
            arrested = {
                Enabled = "auto",
                Type = "arrested",
                Icon = "darkrp/local_police",
                Label = "Arrested",
                MinWide = 118
            }
        }
    },

    Card = {
        Enabled = true,
        X = 20,
        BottomY = 30,
        Width = 324,
        BaseHeight = 92,
        Pad = 16,
        Background = nil,
        InnerAlpha = 235,
        Accent = nil, -- nil uses DubzLib.Color("Primary")
        NameColor = nil,
        JobColor = "job",
        AccentWidth = 6,
        Border = nil,
        Shadow = true,
        LerpSpeed = 14,
        RowHeight = 28,
        RowGap = 5,
        PlayerCardRadius = nil,
        MoneyHeight = 22,
        MoneyGap = 6,
        HeaderHeight = 58,
        BottomPad = 8,
        AvatarSize = 32,
        ShowMoney = true,
        ShowSalaryOnWallet = true,
        StatusChipSize = 22,
        StatusChipGap = 5,
        ClockEnabled = true,
        ClockIcon = "communication/notifications",
        ClockChipSize = 22,
        ClockOffsetX = -10,
        Order = {
            "health",
            "armor",
            "hunger",
            "oxygen",
            "money",
            "props"
        },

        Armor = {
            Enabled = "auto", -- true, false, or "auto"
            HideWhenEmpty = true,
            Label = "Armor",
            Icon = "armor",
            Accent = "armor",
            Max = 100
        },

        Props = {
            Enabled = true,
            Label = "Props",
            Icon = "misc/handyman",
            Accent = "props",
            Max = 100
        },

        Hunger = {
            Enabled = "auto", -- true, false, or "auto"; true always draws
            Var = "Energy",
            Label = "Hunger",
            Icon = "players/hunger",
            Accent = "hunger",
            FallbackValue = 100,
            Max = 100
        },

        Oxygen = {
            Enabled = "auto", -- true, false, or "auto"; auto shows underwater / while recovering
            Label = "Oxygen",
            Icon = "misc/spo2",
            Accent = "oxygen",
            Max = 100,
            DrainTime = 12,
            RecoverTime = 4,
            Damage = 8,
            DamageInterval = 1.25
        }
    },

    Status = {
        Enabled = true,
        AnnouncementEnabled = true,
        AnnouncementY = 82,
        AnnouncementGap = 22,
        AnnouncementIconSize = 18,
        WantedText = "Wanted!",
        ArrestedText = "Arrested!",
        LockdownText = "Lockdown in progress",
        AgendaPrefix = "Agenda",
        ArrestedDefaultDuration = 120,
        ArrestedTimerFallback = "Time left unknown",
        AgendaCard = {
            Enabled = true,
            X = 20,
            Y = 54,
            BarGap = 10,
            Width = 360,
            MinHeight = 64,
            Pad = 12,
            AccentWidth = 5,
            Background = nil,
            InnerAlpha = 235,
            Shadow = true,
            MaxLines = 3
        },

        Icons = {
            Wanted = "admin/warning",
            Arrested = "darkrp/local_police",
            GunLicense = "economy/house",
            Lockdown = "admin/gavel",
            Agenda = "darkrp/agenda"
        }
    },

    Door = {
        Enabled = true,
        Width = 380,
        Pad = 12,
        Gap = 4,
        AccentWidth = 5,
        Background = nil,
        InnerAlpha = 235,
        MaxLines = 6,
        YOffset = 34,
        DrawDistance = 250,
        FadeDistance = 250,
        RequireKeysForHover = true,
        TitleFont = "Header",
        DetailFont = "Body",
        HintFont = "Small",
        HintText = "Press F2",
        Icons = {
            Owned = "economy/house",
            Unowned = "economy/house",
            Locked = "admin/security",
            Vehicle = "misc/directions_run"
        }
    },

    DoorOptions = {
        Enabled = true,
        AnimSpeed = 13,
        HoverSpeed = 16,
        Slide = 22
    },

    DarkRPMenus = {
        Enabled = true,
        AnimationMenu = true,
        AnimationTitle = "Actions Menu",
        AnimationSubtitle = "Choose a gesture",
        AnimationWidth = 278,
        AnimationRowHeight = 36,
        AnimationXPercent = 0.61,
        ScanInterval = 0.25,
        WidthMin = 220,
        Pad = 10,
        AccentWidth = 5,
        InnerAlpha = 235,
        Keywords = {
            "animation",
            "animations",
            "gesture",
            "warrant",
            "wanted",
            "lottery",
            "emote",
            "gun",
            "gun license",
            "gunlicense",
            "license",
            "vote"
        }
    },

    Laws = {
        Enabled = true,
        StartOpen = false,
        Width = 360,
        X = 20,
        Y = 54,
        BarGap = 10,
        TopRight = true,
        Pad = 12,
        AccentWidth = 5,
        Background = nil,
        InnerAlpha = 255,
        TagWidth = 150,
        TagHeight = 28,
        TagText = "Laws - F1",
        Title = "Laws of the Land",
        EmptyText = "No laws are posted.",
        Icon = "admin/gavel",
        AnimSpeed = 10,
        Slide = 24
    },

    Overhead = {
        Enabled = true,
        DrawLocalPlayer = false,
        MaxDistance = 520,
        FadeDistance = 360,
        HeadOffset = 16,
        Icon = "misc/question_mark",
        IconSize = 42,
        TextX = 52,
        Width = 245,
        NameColor = "team",
        JobColor = Color(235, 235, 235),
        LineHeight = 2,
        Shadow = true
    },

    Ammo = {
        Enabled = true,
        HideDefault = true,
        Width = 178,
        Height = 52,
        RightPadding = 24,
        BottomPadding = 28,
        Pad = 12,
        Icon = "admin/security",
        IconChipSize = 28,
        Label = "Ammo",
        Accent = nil,
        AccentWidth = 5,
        Background = nil,
        InnerAlpha = 255,
        Border = nil,
        Shadow = false,
        ShadowAlpha = 80,
        LerpSpeed = 16,
        FadeLerpSpeed = 16,
        BulletBarHeight = 4,
        BulletBarGap = 1,
        BulletBarBottom = 6,
        MaxBulletSegments = 90
    },

    WeaponSelector = {
        Enabled = true,
        Position = "top",
        Width = 220,
        SlotWidth = 176,
        RowHeight = 30,
        RowGap = 5,
        SlotGap = 8,
        ColumnPadding = 6,
        HeaderHeight = 22,
        MaxVisibleRows = 8,
        RightPadding = 28,
        TopPadding = 44,
        CenterOffsetX = 0,
        YPercent = 0.12,
        ShowTime = 1.25,
        FadeTime = 0.22,
        AccentWidth = 0,
        Radius = "MD",
        Shadow = false,
        Background = nil,
        HeaderBackground = nil,
        ActiveBackground = nil,
        InnerAlpha = 218,
        HeaderAlpha = 235,
        InactiveAlpha = 205,
        ActiveAlpha = 245,
        TextColor = nil,
        MutedColor = nil,
        SlotColor = nil,
        Accent = nil,
        ShowSlotNumbers = true,
        ShowHeaderCounts = false,
        ShowEntryNumbers = false,
        ShowHeaderAccent = false,
        ShowRowAccent = false,
        SelectedTintAlpha = 18
    },

    Notifications = {
        Enabled = true,
        PickupOverride = true,
        Width = nil,
        MaxWidth = 520,
        MinWidth = 280,
        Height = 44,
        Gap = 8,
        Life = 4,
        RightPadding = 24,
        BottomOffset = 245,
        PadX = 8,
        IconChipSize = 26,
        AccentWidth = 4,
        MoveLerpSpeed = 16,
        FadeLerpSpeed = 14,
        ProgressLerpSpeed = 10,
        Background = nil,
        InnerAlpha = 235,
        Border = nil,
        Accent = nil,
        Shadow = false,
        ShadowAlpha = 70,
        MaxVisible = 8,
        ProgressLine = true,
        ProgressHeight = 2,
        Icons = {
            generic = "misc/lightbulb",
            hint = "misc/lightbulb",
            success = "misc/verified",
            error = "misc/cancel",
            warning = "misc/question_mark",
            undo = "misc/sync",
            progress = "misc/sync",
            cleanup = "misc/check"
        }
    },

    DeathNotice = {
        Enabled = true,
        Width = 350,
        Height = 36,
        Gap = 7,
        Right = 24,
        Top = 170,
        Life = 5.5,
        MaxVisible = 3,
        MaxQueued = 8,
        CauseWidth = 96
    },

    Vote = {
        Enabled = true,
        Width = 292,
        Height = 78,
        Gap = 10,
        MaxVisible = 5,
        LeftPadding = 24,
        RightPadding = nil,
        Y = 132,
        Pad = 8,
        ButtonHeight = 21,
        IconChipSize = 20,
        AccentWidth = 4,
        LerpSpeed = 18,
        FadeLerpSpeed = 16,
        Background = nil,
        InnerAlpha = 255,
        Border = nil,
        Shadow = false,
        ShadowAlpha = 0
    },

    Vehicle = {
        Enabled = true,
        Width = 320,
        Height = 132,
        RightPadding = 24,
        BottomPadding = 92,
        Pad = 12,
        AccentWidth = 5,
        Icon = "misc/directions_run",
        Unit = "mph",
        ShowGear = true,
        ShowRPM = true,
        ShowClass = false,
        ShowHealth = true,
        ShowFuel = true,
        InnerAlpha = 235,
        Shadow = false
    }
}
