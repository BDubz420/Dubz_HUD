local DHUD = DHUD

local function CalculateAtmosTime(time)
    time = tonumber(time) or 0
    local formatted = os.date("!%I:%M %p", time * 3600)

    if string.sub(formatted, 1, 1) == "0" then
        formatted = string.sub(formatted, 2)
    end

    return formatted
end

SetGlobalString("Atmos_Time", GetGlobalString("Atmos_Time", "0:00 AM"))

timer.Create("DHUD.AtmosClockBridge", 1, 0, function()
    if not AtmosGlobal or AtmosGlobal.m_Time == nil then return end

    SetGlobalString("Atmos_Time", CalculateAtmosTime(AtmosGlobal.m_Time))
end)
