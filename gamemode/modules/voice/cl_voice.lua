-- ============================================================
-- Star Wars: Expedition — Voice HUD
-- modules/cl_voice.lua
-- ============================================================

if SERVER then return end

-- ============================================================
-- 1. ПОЛНОЕ ОТКЛЮЧЕНИЕ СТАНДАРТНОЙ СИСТЕМЫ GMOD
-- ============================================================
hook.Add("InitPostEntity", "SWExp::DisableDefaultVoice", function()
    -- Убиваем базовые функции Sandbox, которые спавнят эти уродливые панели
    timer.Simple(1, function()
        if IsValid(g_VoicePanelList) then 
            g_VoicePanelList:Remove() 
        end
        GAMEMODE.PlayerStartVoice = function() end
        GAMEMODE.PlayerEndVoice = function() end
    end)
end)

-- ============================================================
-- 2. СИСТЕМА ОТСЛЕЖИВАНИЯ ГОВОРЯЩИХ
-- ============================================================
local SpeakingPlayers = {}

hook.Add("PlayerStartVoice", "SWExp::VoiceStart", function(ply)
    SpeakingPlayers[ply] = CurTime()
end)

hook.Add("PlayerEndVoice", "SWExp::VoiceEnd", function(ply)
    SpeakingPlayers[ply] = nil
end)

-- Локальная функция масштабирования под 1080p
local function S(n) return math.Round(n * (ScrH() / 1080)) end

-- ============================================================
-- 3. ОТРИСОВКА НОВОГО ИНТЕРФЕЙСА (В стиле SWUI)
-- ============================================================
hook.Add("HUDPaint", "SWExp::VoiceDraw", function()
    -- Подстраховка: если какой-то аддон всё же попытался показать дефолтную панель
    if IsValid(g_VoicePanelList) and g_VoicePanelList:IsVisible() then
        g_VoicePanelList:SetVisible(false)
    end

    local localPly = LocalPlayer()
    local myFreq = localPly:GetNWInt("swexp_radio_freq", 0)
    
    -- Стартовая позиция по Y (справа посередине)
    local y = ScrH() * 0.45
    local x = ScrW() - S(20)
    
    -- Собираем в массив для сортировки
    local talkers = {}
    for ply, time in pairs(SpeakingPlayers) do
        if IsValid(ply) then
            table.insert(talkers, {ply = ply, time = time})
        else
            SpeakingPlayers[ply] = nil
        end
    end
    
    -- Сортируем по времени начала разговора (кто раньше начал - тот выше)
    table.sort(talkers, function(a, b) return a.time < b.time end)

    surface.SetFont("SWUI.Small")

    for _, data in ipairs(talkers) do
        local ply = data.ply
        
        -- Получаем красивый ник
        local name = ply.SWExp_DisplayName or ply:GetNWString("swexp_display_name", "")
        if name == "" then name = ply:Nick() end
        
        -- Проверяем, говорит ли игрок по рации вместе с нами
        local plyFreq = ply:GetNWInt("swexp_radio_freq", 0)
        local isRadio = (myFreq > 0 and plyFreq == myFreq and ply:GetNWBool("swexp_radio_talking", false))
        
        local tw, th = surface.GetTextSize(name)
        
        local boxH = S(36)
        local boxW = tw + S(56) -- Место для текста и мини-эквалайзера
        local boxX = x - boxW
        
        -- Громкость голоса (от 0 до 1)
        local vol = ply:VoiceVolume()
        -- Если это сам игрок, симулируем скачки, так как VoiceVolume у локального игрока обычно = 0
        if ply == localPly then
            vol = 0.5 + math.sin(CurTime() * 15) * 0.5
        end
        
        -- Анимация от громкости голоса (пульсация обводки)
        local pulse = 100 + math.Clamp(vol * 155, 0, 155)
        
        local colOuter = isRadio and Color(0, 238, 119, pulse) or Color(0, 184, 255, pulse)
        local colInner = isRadio and Color(0, 50, 20, 220)     or Color(6, 12, 18, 220)
        local colText  = isRadio and SWUI.Colors.Green         or SWUI.Colors.TextHi
        
        -- Отрисовка плашки (как в SWUI)
        draw.RoundedBox(S(8), boxX, y, boxW, boxH, colOuter)
        draw.RoundedBox(S(7), boxX + 1, y + 1, boxW - 2, boxH - 2, colInner)
        
        -- Отрисовка текста (выравнивание по правому краю)
        SWUI.DrawText(name, "SWUI.Small", boxX + boxW - S(14), y + boxH / 2, colText, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        
        -- ============================================================
        -- АНИМИРОВАННЫЙ ЭКВАЛАЙЗЕР
        -- ============================================================
        local eqX = boxX + S(18)
        local eqY = y + boxH / 2
        
        -- Рисуем 3 столбика эквалайзера, которые прыгают от громкости
        local barW = S(3)
        local maxH = S(16)
        
        local t = CurTime() * 10
        local h1 = math.Clamp(maxH * vol * (0.5 + math.sin(t) * 0.5) + S(4), S(4), maxH)
        local h2 = math.Clamp(maxH * vol * (0.5 + math.cos(t) * 0.5) + S(4), S(4), maxH)
        local h3 = math.Clamp(maxH * vol * (0.5 + math.sin(t + 1) * 0.5) + S(4), S(4), maxH)

        surface.SetDrawColor(colOuter)
        surface.DrawRect(eqX - S(6), eqY - h1 / 2, barW, h1)
        surface.DrawRect(eqX,        eqY - h2 / 2, barW, h2)
        surface.DrawRect(eqX + S(6), eqY - h3 / 2, barW, h3)
        
        y = y + boxH + S(8)
    end
end)