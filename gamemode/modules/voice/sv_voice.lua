-- modules/sv_voice.lua
if CLIENT then return end

-- Радиус обычного голоса (в юнитах). 500 юнитов = ~13 метров
local PROXIMITY_DIST = 500 

-- Хук управления голосовым чатом
hook.Add("PlayerCanHearPlayersVoice", "SWExp::VoiceSystem", function(listener, talker)
    if not IsValid(talker) or not IsValid(listener) then return false, false end

    -- 1. Проверяем, говорит ли игрок в рацию
    if talker:GetNWBool("swexp_radio_talking", false) then
        local tFreq = talker:GetNWInt("swexp_radio_freq", 0)
        local lFreq = listener:GetNWInt("swexp_radio_freq", 0)

        -- Если оба на одной частоте и частота задана, они слышат друг друга везде (без 3D)
        if tFreq > 0 and tFreq == lFreq then
            return true, false
        end
    end

    -- 2. Локальный 3D голос (если рация не используется или частоты не совпали)
    local distSqr = talker:GetPos():DistToSqr(listener:GetPos())
    if distSqr <= (PROXIMITY_DIST * PROXIMITY_DIST) then
        -- true (слышно), true (использовать 3D звук)
        return true, true
    end

    -- Если слишком далеко, не слышим
    return false, false
end)

-- Прием данных с клиента
netstream.Hook("SWExp::SetRadioFreq", function(ply, freq)
    freq = tonumber(freq) or 0
    ply:SetNWInt("swexp_radio_freq", freq)
end)

netstream.Hook("SWExp::RadioTalk", function(ply, state)
    ply:SetNWBool("swexp_radio_talking", tobool(state))
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Модуль 3D-голоса и рации загружен.\n')