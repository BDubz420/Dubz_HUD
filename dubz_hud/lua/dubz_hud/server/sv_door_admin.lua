local DHUD = DHUD

util.AddNetworkString("DHUD.SetDoorTitle")

local allowedDoorClasses = {
    prop_door_rotating = true,
    func_door = true,
    func_door_rotating = true,
    func_movelinear = true
}

local function RateLimited(ply)
    if not IsValid(ply) then return false end

    local nextAllowed = tonumber(ply.DHUD_NextDoorTitleEdit or 0) or 0
    if CurTime() < nextAllowed then return true end

    ply.DHUD_NextDoorTitleEdit = CurTime() + 0.75
    return false
end

local function IsDoor(ent)
    if not IsValid(ent) then return false end
    if ent:IsVehicle() then return true end

    if ent.isDoor then
        local ok, result = pcall(function()
            return ent:isDoor()
        end)

        if ok and result then return true end
    end

    return allowedDoorClasses[string.lower(ent:GetClass() or "")] == true
end

local function PlayerIsLookingAt(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end

    local trace = ply:GetEyeTrace()
    if not trace or trace.Entity ~= ent then return false end

    local hitPos = trace.HitPos or ent:GetPos()
    return ply:EyePos():DistToSqr(hitPos) <= 40000
end

local function Notify(ply, text, kind)
    if not IsValid(ply) then return end

    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, kind or 0, 4, text)
    else
        ply:ChatPrint(text)
    end
end

local function WithDoorAccess(ply, callback)
    if CAMI and CAMI.PlayerHasAccess then
        CAMI.PlayerHasAccess(ply, "DarkRP_ChangeDoorSettings", function(allowed)
            callback(allowed == true)
        end)
        return
    end

    callback(IsValid(ply) and ply:IsAdmin())
end

net.Receive("DHUD.SetDoorTitle", function(_, ply)
    if not IsValid(ply) then return end
    if RateLimited(ply) then return end

    local ent = net.ReadEntity()
    local title = string.Trim(string.sub(net.ReadString() or "", 1, 80))

    if title == "" then return end

    WithDoorAccess(ply, function(allowed)
        if not IsValid(ply) then return end

        if not allowed then
            Notify(ply, "You do not have permission to change door settings.", 1)
            return
        end

        if not IsDoor(ent) or not ent.setKeysTitle then
            Notify(ply, "You must be looking at a door or vehicle.", 1)
            return
        end

        if not PlayerIsLookingAt(ply, ent) then
            Notify(ply, "Move closer to set the door title.", 1)
            return
        end

        local ok = pcall(function()
            ent:setKeysTitle(title)
        end)
        if not ok then
            Notify(ply, "Door title could not be updated.", 1)
            return
        end

        if DarkRP and DarkRP.storeDoorData then
            DarkRP.storeDoorData(ent)
        end

        Notify(ply, "Door title updated.", 0)
    end)
end)
