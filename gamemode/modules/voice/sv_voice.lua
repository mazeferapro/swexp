-- modules/sv_voice.lua
if CLIENT then return end

-- Радиус обычного голоса (в юнитах). 500 юнитов = ~13 метров
local PROXIMITY_DIST = 500

-- ============================================================
-- Хук управления голосовым чатом
-- ============================================================
hook.Add("PlayerCanHearPlayersVoice", "SWExp::VoiceSystem", function(listener, talker)
    if not IsValid(talker) or not IsValid(listener) then return false, false end

    -- 1. Проверяем, говорит ли игрок в рацию (микрофон нажат, рация включена, mic не замьючен)
    if talker:GetNWBool("swexp_radio_talking", false)
       and talker:GetNWBool("swexp_radio_enabled", false)
       and talker:GetNWBool("swexp_radio_mic", true) then

        -- Берём частоту активного канала говорящего
        local activeCh  = talker:GetNWInt("swexp_radio_active_ch", 1)
        local tFreq     = talker:GetNWInt("swexp_radio_freq" .. activeCh, 0)

        if tFreq > 0 and listener:GetNWBool("swexp_radio_enabled", false) then
            -- Слушатель слышит, если хотя бы один из его 3 каналов совпадает с частотой передатчика
            for ch = 1, 3 do
                if listener:GetNWInt("swexp_radio_freq" .. ch, 0) == tFreq then
                    return true, false  -- слышно, без 3D-позиционирования
                end
            end
        end
    end

    -- 2. Локальный 3D-голос (если рация не используется или частоты не совпали)
    local distSqr = talker:GetPos():DistToSqr(listener:GetPos())
    if distSqr <= (PROXIMITY_DIST * PROXIMITY_DIST) then
        return true, true
    end

    return false, false
end)

-- ============================================================
-- Netstream — настройка частот и активного канала
-- ============================================================

-- Установить всю конфигурацию разом: {f1, f2, f3, ch}
netstream.Hook("SWExp::RadioSetConfig", function(ply, data)
    if type(data) ~= "table" then return end
    ply:SetNWInt("swexp_radio_freq1",    math.Clamp(tonumber(data.f1) or 0, 0, 999999))
    ply:SetNWInt("swexp_radio_freq2",    math.Clamp(tonumber(data.f2) or 0, 0, 999999))
    ply:SetNWInt("swexp_radio_freq3",    math.Clamp(tonumber(data.f3) or 0, 0, 999999))
    ply:SetNWInt("swexp_radio_active_ch", math.Clamp(tonumber(data.ch) or 1, 1, 3))
end)

-- Включить / выключить рацию
netstream.Hook("SWExp::RadioEnabled", function(ply, state)
    ply:SetNWBool("swexp_radio_enabled", tobool(state))

    -- При выключении рации сбрасываем флаг передачи
    if not tobool(state) then
        ply:SetNWBool("swexp_radio_talking", false)
    end
end)

-- Включить / выключить микрофон рации
netstream.Hook("SWExp::RadioMic", function(ply, state)
    ply:SetNWBool("swexp_radio_mic", tobool(state))
end)

-- Сменить активный канал (1 / 2 / 3)
netstream.Hook("SWExp::RadioSetChannel", function(ply, ch)
    ply:SetNWInt("swexp_radio_active_ch", math.Clamp(tonumber(ch) or 1, 1, 3))
end)

-- Флаг «говорю в рацию прямо сейчас» (клиент отправляет при нажатии/отпускании голоса)
netstream.Hook("SWExp::RadioTalk", function(ply, state)
    ply:SetNWBool("swexp_radio_talking", tobool(state))
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Модуль 3D-голоса и рации загружен.\n')
