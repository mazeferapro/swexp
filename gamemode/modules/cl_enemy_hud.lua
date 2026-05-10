-- Star Wars: Expedition - HUD: noise indicator (eye shape) + threat tier
-- modules/cl_enemy_hud.lua
--
-- Eye indicator:
--   noise <= stealthThreshold  -> eye fully closed (thin slit)
--   noise grows                -> eye gradually opens
--   noise = max                -> eye fully open, pupil visible
--
-- Threat tier: colored dot + roman numeral, to the right of the eye.
--
-- Listens to net "SWExp::Enemy_NoiseUpdate": UInt(8) noise, UInt(4) tier

if not CLIENT then return end

local function S(n)
    return math.Round(n * (ScrH() / 1080))
end

local function CreateFonts()
    surface.CreateFont("SWUI.HUD.Armor", {
        font = "Exo 2", size = S(22), weight = 600, extended = true,
    })
end

CreateFonts()
hook.Add("OnScreenSizeChanged", "SWExp::Enemy_RecreateFonts", function()
    CreateFonts()
end)

local C = {
    Accent = Color(0, 184, 255),
    Yellow = Color(220, 180, 40),
    Orange = Color(255, 136, 0),
    Red    = Color(220, 60,  60),
}

local function NoiseColor(frac)
    if frac < 0.25 then return C.Accent end
    if frac < 0.5  then return C.Yellow end
    if frac < 0.8  then return C.Orange end
    return C.Red
end

local TierColor = {
    [0] = Color(90,  120, 140),
    [1] = Color(80,  200, 100),
    [2] = Color(80,  160, 255),
    [3] = Color(255, 180, 40),
    [4] = Color(220, 60,  60),
}

local TierRoman = { [0] = "-", [1] = "I", [2] = "II", [3] = "III", [4] = "IV" }

local STATE = { noise = 0, tier = 0, noiseSmooth = 0 }

local function NoiseMax()
    if SWExp and SWExp.EnemyConfig and SWExp.EnemyConfig.Noise then
        return SWExp.EnemyConfig.Noise.max or 100
    end
    return 100
end

net.Receive("SWExp::Enemy_NoiseUpdate", function()
    STATE.noise = net.ReadUInt(8)
    STATE.tier  = net.ReadUInt(4)
end)

local function Txt(text, font, x, y, col, aH, aV)
    if SWUI and SWUI.DrawTextShadow then
        SWUI.DrawTextShadow(text, font, x, y, col,
            aH or TEXT_ALIGN_LEFT, aV or TEXT_ALIGN_TOP, 2, 180)
    else
        draw.SimpleText(text, font, x, y, col,
            aH or TEXT_ALIGN_LEFT, aV or TEXT_ALIGN_TOP)
    end
end

-- Draw eye icon using surface.DrawLine
-- cx, cy   : center of eye
-- rw       : horizontal radius
-- rh       : max vertical radius (when fully open)
-- openFrac : 0=closed, 1=open
-- col      : draw color
local EYE_STEPS = 18
local function DrawEyeIcon(cx, cy, rw, rh, openFrac, col)
    -- minimum slit so eyelids never fully merge to a single line
    local f = 0.05 + openFrac * 0.95

    surface.SetDrawColor(col)

    local topPts = {}
    local botPts = {}
    for i = 0, EYE_STEPS do
        local t    = i / EYE_STEPS
        local px   = cx - rw + t * (2 * rw)
        local lift = math.sin(math.pi * t)
        topPts[i] = { x = math.Round(px), y = math.Round(cy - f * rh * lift) }
        botPts[i] = { x = math.Round(px), y = math.Round(cy + f * rh * lift) }
    end

    for i = 0, EYE_STEPS - 1 do
        surface.DrawLine(topPts[i].x, topPts[i].y, topPts[i+1].x, topPts[i+1].y)
    end
    for i = 0, EYE_STEPS - 1 do
        surface.DrawLine(botPts[i].x, botPts[i].y, botPts[i+1].x, botPts[i+1].y)
    end

    -- pupil appears once eye is sufficiently open
    if f > 0.18 then
        local pr = math.max(1, math.Round(rh * (f - 0.1) * 0.55))
        local pd = pr * 2
        draw.RoundedBox(pr, math.Round(cx - pr), math.Round(cy - pr), pd, pd, col)
    end
end

local function DrawNoiseCompact()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetObserverMode() ~= OBS_MODE_NONE then return end

    STATE.noiseSmooth = Lerp(FrameTime() * 6, STATE.noiseSmooth, STATE.noise)

    local nmax = NoiseMax()
    local frac = math.Clamp(STATE.noiseSmooth / nmax, 0, 1)
    local pct  = math.Round(frac * 100)
    local col  = NoiseColor(frac)

    -- stealth threshold: below this noise level the eye stays closed
    local stealthFrac
    if SWExp and SWExp.EnemyConfig and SWExp.EnemyConfig.Noise then
        local st = SWExp.EnemyConfig.Noise.stealthThreshold or 5
        stealthFrac = st / nmax
    else
        stealthFrac = 0.05
    end

    local openFrac
    if frac <= stealthFrac then
        openFrac = 0
    else
        openFrac = math.Clamp((frac - stealthFrac) / (1 - stealthFrac), 0, 1)
    end

    -- anchor to the HP bar (mirrors cl_hud.lua layout)
    local barW   = S(320)
    local barH   = S(8)
    local bx     = ScrW() / 2 - barW / 2
    local y      = ScrH() - S(56)
    local valMid = y + barH / 2

    -- position: right of the armor block
    local noiseX = bx + barW + S(12) + S(160)

    local eyeRW = S(9)
    local eyeRH = S(7)
    local eyeCX = noiseX + eyeRW
    local eyeCY = valMid

    DrawEyeIcon(eyeCX, eyeCY, eyeRW, eyeRH, openFrac, col)

    -- percentage text
    local textX = eyeCX + eyeRW + S(5)
    Txt(pct .. "%", "SWUI.HUD.Armor", textX, valMid, col,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- threat tier: dot + roman numeral
    surface.SetFont("SWUI.HUD.Armor")
    local pctW  = surface.GetTextSize(pct .. "%")
    local tier  = STATE.tier or 0
    local tCol  = TierColor[tier] or TierColor[0]
    local roman = TierRoman[tier] or TierRoman[0]
    local tierX = textX + pctW + S(10)
    local dot   = S(7)
    draw.RoundedBox(dot / 2, tierX, math.floor(valMid - dot / 2), dot, dot, tCol)
    Txt(roman, "SWUI.HUD.Armor", tierX + dot + S(4), valMid, tCol,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "SWExp::DrawEnemyHUD", function()
    DrawNoiseCompact()
end)

print("[SWExp] cl_enemy_hud loaded.")
