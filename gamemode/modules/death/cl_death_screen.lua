-- ============================================================
-- Star Wars: Expedition - Death Screen (Client)
-- modules/death/cl_death_screen.lua
-- ============================================================

if SERVER then return end

SWExp        = SWExp        or {}
SWExp.Death  = SWExp.Death  or {}

local State = {
    active   = false,
    delay    = 30,
    endAt    = 0,
    showAt   = 0,
}
SWExp.Death._State = State

print('[SWExp][Death] cl_death_screen.lua loaded')

-- ============================================================
-- Fonts
-- ============================================================

local function CreateFonts()
    local function S(n) return math.max(1, math.Round(n * (ScrH() / 1080))) end

    surface.CreateFont('SWUI.Death.Title', {
        font = 'Exo 2', size = S(96), weight = 800, extended = true,
    })
    surface.CreateFont('SWUI.Death.SubTitle', {
        font = 'Exo 2', size = S(28), weight = 500, extended = true,
    })
    surface.CreateFont('SWUI.Death.Timer', {
        font = 'Exo 2', size = S(72), weight = 700, extended = true,
    })
    surface.CreateFont('SWUI.Death.Hint', {
        font = 'Exo 2', size = S(20), weight = 600, extended = true,
    })
end

CreateFonts()
hook.Add('OnScreenSizeChanged', 'SWExp::Death::RecreateFonts', CreateFonts)

-- ============================================================
-- Config fallback
-- ============================================================

local function Cfg()
    return SWExp.DeathCfg or {
        OverlayColor = Color(8, 0, 0, 220),
        Title        = '\208\146\208\171 \208\159\208\158\208\147\208\152\208\145\208\155\208\152',
        SubTitle     = '\208\158\208\182\208\184\208\180\208\176\208\185\209\130\208\181 \208\178\208\190\208\183\209\128\208\190\208\182\208\180\208\181\208\189\208\184\209\143...',
        RespawnHint  = '\208\157\208\144\208\150\208\156\208\152\208\162\208\149 [\208\159\208\160\208\158\208\145\208\149\208\155] \208\148\208\155\208\175 \208\146\208\158\208\151\208\160\208\158\208\150\208\148\208\149\208\157\208\152\208\175',
    }
end

-- ============================================================
-- NetStream hooks
-- ============================================================

netstream.Hook('SWExp::DeathScreen::Show', function(nDelay, nEndAt)
    State.active = true
    State.delay  = tonumber(nDelay) or 30
    State.endAt  = tonumber(nEndAt) or (CurTime() + State.delay)
    State.showAt = CurTime()
    print('[SWExp][Death] Show received. Duration:', State.delay)
end)

netstream.Hook('SWExp::DeathScreen::Hide', function()
    State.active = false
    print('[SWExp][Death] Hide received')
end)

-- Local fallback: show screen as soon as player is dead.
hook.Add('Think', 'SWExp::Death::AutoShow', function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:Alive() then
        if State.active then State.active = false end
        return
    end

    if not State.active then
        local d = (SWExp.DeathCfg and SWExp.DeathCfg.RespawnDelay) or 30
        State.active = true
        State.delay  = d
        State.endAt  = CurTime() + d
        State.showAt = CurTime()
    end
end)

-- ============================================================
-- Helpers
-- ============================================================

local function GetTimer()
    local left = math.max(0, State.endAt - CurTime())
    local frac = 1 - math.Clamp(left / math.max(0.001, State.delay), 0, 1)
    return left, frac
end

local function DrawRoundedBox(r, x, y, w, h, col)
    if SWUI and SWUI.DrawRoundedRect then
        SWUI.DrawRoundedRect(x, y, w, h, r, col)
    else
        draw.RoundedBox(r, x, y, w, h, col)
    end
end

local function DrawText(text, font, x, y, col, alignH, alignV)
    if SWUI and SWUI.DrawText then
        SWUI.DrawText(text, font, x, y, col, alignH, alignV)
    else
        draw.SimpleText(text, font, x, y, col, alignH or TEXT_ALIGN_LEFT,
            alignV or TEXT_ALIGN_TOP)
    end
end

local function DrawTextShadow(text, font, x, y, col)
    if SWUI and SWUI.DrawTextShadow then
        SWUI.DrawTextShadow(text, font, x, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, 180)
    else
        draw.SimpleText(text, font, x + 2, y + 2, Color(0, 0, 0, 180),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, font, x, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function GetSWUIColor(name, fallback)
    if SWUI and SWUI.Colors and SWUI.Colors[name] then
        return SWUI.Colors[name]
    end
    return fallback
end

-- ============================================================
-- Main draw function
-- ============================================================

local function DrawDeathScreen()
    if not State.active then return end

    local cfg = Cfg()
    local sw, sh = ScrW(), ScrH()

    local fade = math.Clamp((CurTime() - State.showAt) / 0.4, 0, 1)
    local left = GetTimer()

    local cy = sh / 2

    -- Title: "ВЫ ПОГИБЛИ"
    local redBase  = GetSWUIColor('Red', Color(255, 51, 34))
    local titleCol = Color(redBase.r, redBase.g, redBase.b, math.floor(255 * fade))
    DrawTextShadow(cfg.Title, 'SWUI.Death.Title', sw / 2, cy - 60, titleCol)

    -- Subtitle / countdown / respawn hint
    local hiBase    = GetSWUIColor('TextHi', Color(228, 244, 255))
    local greenBase = GetSWUIColor('Green', Color(0, 238, 119))

    if left > 0 then
        local hintText = string.format(
            '\208\146\208\190\208\183\209\128\208\190\208\182\208\180\208\181\208\189\208\184\208\181 \209\135\208\181\209\128\208\181\208\183 %d \209\129\208\181\208\186.',
            math.ceil(left))
        DrawText(hintText, 'SWUI.Death.SubTitle', sw / 2, cy + 30,
            Color(hiBase.r, hiBase.g, hiBase.b, math.floor(255 * fade)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        local pulse = 0.5 + 0.5 * math.sin(CurTime() * 4)
        local hintCol = Color(greenBase.r, greenBase.g, greenBase.b,
            math.floor((120 + 135 * pulse) * fade))
        DrawText(cfg.RespawnHint, 'SWUI.Death.SubTitle', sw / 2, cy + 30, hintCol,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ============================================================
-- Hooks: HUDPaint + DrawOverlay (ensures it's always visible)
-- ============================================================

local lastFrame = 0

hook.Add('HUDPaint', 'SWExp::Death::Draw', function()
    if FrameNumber() == lastFrame then return end
    lastFrame = FrameNumber()
    DrawDeathScreen()
end)

hook.Add('DrawOverlay', 'SWExp::Death::DrawOverlay', function()
    if FrameNumber() == lastFrame then return end
    lastFrame = FrameNumber()
    DrawDeathScreen()
end)

-- ============================================================
-- Hide default HUD elements while death screen is active
-- ============================================================

local hideHUD = {
    CHudHealth          = true,
    CHudBattery         = true,
    CHudAmmo            = true,
    CHudSecondaryAmmo   = true,
    CHudCrosshair       = true,
    CHudDamageIndicator = true,
}

hook.Add('HUDShouldDraw', 'SWExp::Death::HideHUD', function(name)
    if State.active and hideHUD[name] then return false end
end)

-- ============================================================
-- Console command to test the screen manually
-- ============================================================

concommand.Add('swexp_death_test', function()
    State.active = true
    State.delay  = 30
    State.endAt  = CurTime() + 30
    State.showAt = CurTime()
    print('[SWExp][Death] test screen activated')
end)
