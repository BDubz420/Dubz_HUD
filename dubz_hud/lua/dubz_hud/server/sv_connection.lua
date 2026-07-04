local DHUD = DHUD

util.AddNetworkString("DHUD.Connection.Heartbeat")

timer.Create("DHUD.Connection.Heartbeat", 1, 0, function()
    net.Start("DHUD.Connection.Heartbeat")
        net.WriteUInt(math.floor(CurTime()) % 65535, 16)
    net.Broadcast()
end)
