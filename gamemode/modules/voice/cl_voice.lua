-- ============================================================
-- Star Wars: Expedition — Voice HUD
-- modules/voice/cl_voice.lua
-- ============================================================
if SERVER then return end

-- ============================================================
-- 1. Убиваем дефолтную GMod-панель голоса
-- ============================================================
hook.Add("InitPostEntity", "SWExp::DisableDefaultVoice", function()
    timer.Simple(1, function()
        if IsValid(g_VoicePanelList) then g_VoicePanelList:Remove() end
        GAMEMODE.PlayerStartVoice = function() end
        GAMEMODE.PlayerEndVoice   = function() end
    end)
end)

-- ============================================================
-- 2. Отслеживание говорящих игроков
-- ============================================================
local SpeakingPlayers = {}  -- [ply] = CurTime() когда начал

hook.Add("PlayerStartVoice", "SWExp::VoiceStart", function(ply)
    SpeakingPlayers[ply] = CurTime()
end)

hook.Add("PlayerEndVoice", "SWExp::VoiceEnd", function(ply)
    SpeakingPlayers[ply] = nil
end)

-- ============================================================
-- 3. Вспомогательные функции
-- ============================================================
local function S(n) return math.Round(n * (ScrH() / 1080)) end

-- Активная частота конкретного игрока
local function GetPlayerActiveFreq(ply)
    local ch = ply:GetNWInt("swexp_radio_active_ch", 1)
    return ply:GetNWInt("swexp_radio_freq"..ch, 0)
end

-- Слышит ли наш клиент радиопередачу от talker?
-- Возвращает true + номер нашего канала, который совпал (или false)
local function CheckCanHearRadio(talker)
    -- Говорящий должен быть в состоянии "передаёт по рации"
    if not talker:GetNWBool("swexp_radio_talking", false) then return false end
    if not talker:GetNWBool("swexp_radio_enabled", false) then return false end

    local tFreq = GetPlayerActiveFreq(talker)
    if tFreq == 0 then return false end

    local me = LocalPlayer()
    if not me:GetNWBool("swexp_radio_enabled", false) then return false end

    -- Ищем совпадение на любом из наших 3 каналов
    for ch = 1, 3 do
        if me:GetNWInt("swexp_radio_freq"..ch, 0) == tFreq then
            return true, ch, tFreq
        end
    end
    return false
end

-- ============================================================
-- 4. HUD: список говорящих (правый центр экрана)
-- ============================================================
hook.Add("HUDPaint", "SWExp::VoiceDraw", function()
    -- Подстраховка: гасим дефолтную панель если вдруг появилась
    if IsValid(g_VoicePanelList) and g_VoicePanelList:IsVisible() then
        g_VoicePanelList:SetVisible(false)
    end

    local me = LocalPlayer()

    -- Собираем и сортируем говорящих
    local talkers = {}
    for ply, t in pairs(SpeakingPlayers) do
        if IsValid(ply) then
            table.insert(talkers, { ply = ply, t = t })
        else
            SpeakingPlayers[ply] = nil
        end
    end
    if #talkers == 0 then return end

    table.sort(talkers, function(a, b) return a.t < b.t end)

    -- Стартовая позиция
    local x = ScrW() - S(20)
    local y = ScrH() * 0.45

    surface.SetFont("SWUI.Small")

    for _, data in ipairs(talkers) do
        local ply = data.ply

        -- Имя
        local name = ply:GetNWString("swexp_display_name", "")
        if name == "" then name = ply:Nick() end

        -- Радио?
        local isRadio, hearCh, tFreq = CheckCanHearRadio(ply)

        -- Для локального игрока: считаем радио если рация включена и он говорит
        if ply == me then
            local meCh  = me:GetNWInt("swexp_radio_active_ch", 1)
            local meFreq = me:GetNWInt("swexp_radio_freq"..meCh, 0)
            if me:GetNWBool("swexp_radio_enabled", false)
               and me:GetNWBool("swexp_radio_talking", false)
               and meFreq > 0 then
                isRadio = true
                hearCh  = meCh
                tFreq   = meFreq
            end
        end

        -- Формируем отображаемый текст
        local tag = ""
        if isRadio and tFreq then
            tag = " [КН"..hearCh.." · "..tFreq.." МГц]"
        end
        local displayName = name..tag

        local tw = surface.GetTextSize(displayName)

        local boxH = S(36)
        local boxW = tw + S(56)   -- место для имени + эквалайзер слева
        local boxX = x - boxW

        -- Громкость: у себя симулируем анимацию, у других — реальная
        local vol
        if ply == me then
            vol = 0.5 + math.sin(CurTime() * 15) * 0.5
        else
            vol = ply:VoiceVolume()
        end

        local pulse = 100 + math.Clamp(vol * 155, 0, 155)

        local colOuter = isRadio and Color(0, 238, 119, pulse) or Color(0, 184, 255, pulse)
        local colInner = isRadio and Color(0,  45,  18, 224)   or Color(6,  12,  18, 224)
        local colText  = isRadio and SWUI.Colors.Green         or SWUI.Colors.TextHi

        -- Плашка
        draw.RoundedBox(S(8),   boxX,     y,     boxW,     boxH,     colOuter)
        draw.RoundedBox(S(7),   boxX + 1, y + 1, boxW - 2, boxH - 2, colInner)

        -- Текст (правый край, чтобы не перекрывал эквалайзер слева)
        SWUI.DrawText(displayName, "SWUI.Small",
            boxX + boxW - S(14), y + boxH/2,
            colText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- Анимированный эквалайзер (3 столбика)
        local eqX  = boxX + S(18)
        local eqY  = y + boxH/2
        local bW   = S(3)
        local mH   = S(16)
        local t    = CurTime() * 10

        local h1 = math.Clamp(mH * vol * (0.5 + math.sin(t)     * 0.5) + S(4), S(4), mH)
        local h2 = math.Clamp(mH * vol * (0.5 + math.cos(t)     * 0.5) + S(4), S(4), mH)
        local h3 = math.Clamp(mH * vol * (0.5 + math.sin(t + 1) * 0.5) + S(4), S(4), mH)

        surface.SetDrawColor(colOuter.r, colOuter.g, colOuter.b, colOuter.a)
        surface.DrawRect(eqX - S(6), eqY - h1/2, bW, h1)
        surface.DrawRect(eqX,        eqY - h2/2, bW, h2)
        surface.DrawRect(eqX + S(6), eqY - h3/2, bW, h3)

        y = y + boxH + S(8)
    end
end)
