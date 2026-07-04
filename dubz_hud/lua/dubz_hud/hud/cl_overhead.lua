local DHUD = DHUD
DHUD.Overhead = DHUD.Overhead or {}

local function Cfg()
    return DHUD.Config and DHUD.Config.Overhead or {}
end

local function WithAlpha(col, alpha)
    if not col then col = color_white end
    return Color(col.r, col.g, col.b, alpha)
end

local function TeamColor(ply)
    return team.GetColor(ply:Team()) or DubzLib.Color("Success")
end

local function IsWanted(ply)
    if ply.getDarkRPVar then
        return ply:getDarkRPVar("wanted") == true
    end

    return false
end

local function CanSeeOverhead(lp, ply, headPos)
    if ply == lp then return true end

    local tr = util.TraceLine({
        start = lp:EyePos(),
        endpos = headPos,
        filter = lp,
        mask = MASK_VISIBLE
    })

    return not tr.Hit or tr.Entity == ply
end

local function DrawShadowedText(text, font, x, y, col, ax, ay, alpha)
    draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, alpha * 0.75), ax, ay)
    draw.SimpleText(text, font, x, y, col, ax, ay)
end

local function DrawNameplate(lp, ply, cfg, alpha)
    local head = ply:EyePos() + Vector(0, 0, cfg.HeadOffset or 18)
    if not CanSeeOverhead(lp, ply, head) then return end

    local screen = head:ToScreen()
    if not screen.visible then return end

    local x = screen.x
    local y = screen.y
    local name = ply:Nick()
    local job = team.GetName(ply:Team()) or "Unknown"
    local nameCol = WithAlpha(DubzLib.Color("Foreground"), alpha)
    local jobCol = WithAlpha(TeamColor(ply), alpha)

    if IsWanted(ply) then
        DrawShadowedText("Wanted!", DubzLib.Font("Header"), x, y - 34, Color(235, 45, 45, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, alpha)
    end

    DrawShadowedText(name, DubzLib.Font("Header"), x, y - 6, nameCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, alpha)
    DrawShadowedText(job, DubzLib.Font("Header"), x, y + 16, jobCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, alpha)
end

function DHUD.DrawOverheadHUD()
    local cfg = Cfg()
    if cfg.Enabled == false then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local maxDist = cfg.MaxDistance or 520
    local fadeDist = cfg.FadeDistance or maxDist * 0.7

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and (ply ~= lp or cfg.DrawLocalPlayer) then
            local dist = lp:GetPos():Distance(ply:GetPos())
            if dist <= maxDist then
                local alpha = 255
                if dist > fadeDist then
                    alpha = 255 * (1 - (dist - fadeDist) / math.max(maxDist - fadeDist, 1))
                end

                DrawNameplate(lp, ply, cfg, math.Clamp(alpha, 0, 255))
            end
        end
    end
end
