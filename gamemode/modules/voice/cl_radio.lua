-- ============================================================
-- Star Wars: Expedition — Comlink / Radio
-- modules/voice/cl_radio.lua
-- ============================================================
if SERVER then return end

SWExp.Radio = SWExp.Radio or {}

-- ============================================================
-- Дефолтные клавиши
-- ============================================================
local DEFAULT_MENU_KEY    = KEY_G
local DEFAULT_TOGGLE_KEY  = KEY_NONE
local DEFAULT_MIC_KEY     = KEY_NONE
local DEFAULT_CHANNEL_KEY = KEY_NONE

function SWExp.Radio:GetMenuKey()    return cookie.GetNumber("swexp_key_comlink_menu",  DEFAULT_MENU_KEY)    end
function SWExp.Radio:GetToggleKey()  return cookie.GetNumber("swexp_key_radio_toggle",  DEFAULT_TOGGLE_KEY)  end
function SWExp.Radio:GetMicKey()     return cookie.GetNumber("swexp_key_radio_mic",     DEFAULT_MIC_KEY)     end
function SWExp.Radio:GetChannelKey() return cookie.GetNumber("swexp_key_radio_channel", DEFAULT_CHANNEL_KEY) end

-- ============================================================
-- Геттеры состояния из NWVar
-- ============================================================
local function GetFreq(ch)    return LocalPlayer():GetNWInt("swexp_radio_freq"..ch, 0)           end
local function GetActiveCh()  return LocalPlayer():GetNWInt("swexp_radio_active_ch", 1)           end
local function IsEnabled()    return LocalPlayer():GetNWBool("swexp_radio_enabled", false)        end
local function IsMicOn()      return LocalPlayer():GetNWBool("swexp_radio_mic", true)             end

-- ============================================================
-- Вспомогательная: создать кнопку с динамической отрисовкой
--   getState()  -> bool (или число / строка для активного канала)
--   painter(s,w,h, state) -> отрисовка
-- ============================================================
local function MakeBtn(parent, x, y, w, h, painter, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.Paint  = painter
    btn.DoClick = onClick
    return btn
end

-- ============================================================
-- Цвета (локальные псевдонимы для краткости)
-- ============================================================
local function C(r,g,b,a) return Color(r,g,b,a or 255) end
local COL = {
    OnBG    = C(0,  80, 140, 230),
    OffBG   = C(100, 22, 18, 230),
    ActBG   = C(0,  25,  50, 220),
    PassBG  = C(12, 18, 26,  200),
    SaveBG  = C(0,  70, 120, 210),
    SaveHov = C(0, 100, 170, 240),
    RowAct  = C(0,  20,  45, 200),
    RowPass = C(6,  12,  18, 180),
}

-- ============================================================
-- Меню комлинка
-- ============================================================
function SWExp.Radio:OpenMenu()
    if IsValid(self.Frame) then self.Frame:Remove() end

    -- Локальное состояние формы (не ждём ответа сервера для UI)
    local st = {
        freqs    = { GetFreq(1), GetFreq(2), GetFreq(3) },
        activeCh = GetActiveCh(),
        enabled  = IsEnabled(),
        mic      = IsMicOn(),
    }

    -- FRAME_W — внешний размер окна; PAD — отступ с каждой стороны внутри content
    local FRAME_W = 440
    local FRAME_H = 430
    local PAD     = 20
    local CW      = FRAME_W - PAD * 2   -- 400

    local frame, content = SWUI.Animated.CreateWindow("КОМЛИНК", FRAME_W, FRAME_H)
    self.Frame = frame

    -- ---- Хелпер для отрисовки типовой кнопки toggle ----
    local function TogglePainter(getOn, lblOn, lblOff)
        return function(s, w, h)
            local on  = getOn()
            local hov = s:IsHovered()
            local bg  = on  and COL.OnBG  or COL.OffBG
            if hov then bg = Color(bg.r + 20, bg.g + 20, bg.b + 20, bg.a) end
            local brd = on and SWUI.Colors.Accent or SWUI.Colors.Red
            draw.RoundedBox(7, 0, 0, w, h, bg)
            surface.SetDrawColor(brd.r, brd.g, brd.b, hov and 255 or 180)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            SWUI.DrawText(on and lblOn or lblOff, "SWUI.Body",
                w/2, h/2, SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- ==================================================
    -- Строка 1: РАЦИЯ + МИК  (y=14)
    -- ==================================================
    local HALF = math.floor(CW / 2) - 4

    MakeBtn(content, PAD, 14, HALF, 38,
        TogglePainter(function() return st.enabled end, "РАЦИЯ: ВКЛ", "РАЦИЯ: ВЫКЛ"),
        function()
            st.enabled = not st.enabled
            netstream.Start("SWExp::RadioEnabled", st.enabled)
        end
    )

    MakeBtn(content, PAD + HALF + 8, 14, CW - HALF - 8, 38,
        TogglePainter(function() return st.mic end, "МИК: ВКЛ", "МИК: ВЫКЛ"),
        function()
            st.mic = not st.mic
            netstream.Start("SWExp::RadioMic", st.mic)
        end
    )

    -- ==================================================
    -- Разделитель + заголовок секции (y=64)
    -- ==================================================
    local secLbl = vgui.Create("DLabel", content)
    secLbl:SetPos(PAD, 64)
    secLbl:SetFont("SWUI.Small")
    secLbl:SetTextColor(SWUI.Colors.Accent)
    secLbl:SetText("ЧАСТОТЫ КАНАЛОВ")
    secLbl:SizeToContents()

    -- ==================================================
    -- 3 строки каналов (y=84 + i*80)
    -- ROW: [label][input 230px][channel btn 152px]
    -- ==================================================
    local ROW_H   = 70
    local INP_W   = 226
    local CBTN_W  = CW - INP_W - 12   -- 162
    local ROWS_Y  = 84

    for i = 1, 3 do
        local captI = i
        local ry    = ROWS_Y + (i - 1) * (ROW_H + 6)

        -- Фон строки — динамический (читает st.activeCh)
        local rowPnl = vgui.Create("DPanel", content)
        rowPnl:SetPos(PAD, ry)
        rowPnl:SetSize(CW, ROW_H)
        rowPnl.Paint = function(s, w, h)
            local isAct = (st.activeCh == captI)
            draw.RoundedBox(8, 0, 0, w, h, isAct and COL.RowAct or COL.RowPass)
            local brd = isAct and SWUI.Colors.BorderHi or SWUI.Colors.Border
            surface.SetDrawColor(brd.r, brd.g, brd.b, isAct and 220 or 100)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        -- Метка канала
        local lbl = vgui.Create("DLabel", rowPnl)
        lbl:SetPos(12, 7)
        lbl:SetFont("SWUI.Tiny")
        lbl:SetTextColor(SWUI.Colors.TextDim)
        lbl:SetText("КАНАЛ " .. i)
        lbl:SizeToContents()

        -- Поле ввода частоты
        local inp = SWUI.CreateInput(rowPnl, 12, 26, INP_W, 32, "частота МГц")
        local initV = st.freqs[i]
        inp:SetValue(initV and initV > 0 and tostring(initV) or "")

        inp.Entry.Think = function(s)
            local txt = s:GetValue()
            local flt = string.gsub(txt, "[^0-9]", "")
            if txt ~= flt then
                s:SetValue(flt)
                s:SetCaretPos(#flt)
            end
            st.freqs[captI] = tonumber(flt) or 0
        end

        if i == 1 then
            timer.Simple(0.1, function()
                if IsValid(inp) and IsValid(inp.Entry) then
                    inp.Entry:RequestFocus()
                end
            end)
        end

        -- Кнопка выбора активного канала (динамическая)
        MakeBtn(rowPnl, INP_W + 14, 26, CBTN_W, 32,
            function(s, w, h)
                local isAct = (st.activeCh == captI)
                local hov   = s:IsHovered()
                local bg    = isAct and COL.ActBG  or (hov and C(20,30,45) or COL.PassBG)
                local brd   = isAct and SWUI.Colors.Accent or (hov and SWUI.Colors.BorderHi or SWUI.Colors.Border)
                local lbl2  = isAct and "* АКТИВНЫЙ" or "ПАССИВНЫЙ"
                local txtC  = isAct and SWUI.Colors.Accent or (hov and SWUI.Colors.Text or SWUI.Colors.TextDim)
                draw.RoundedBox(6, 0, 0, w, h, bg)
                surface.SetDrawColor(brd.r, brd.g, brd.b, isAct and 200 or (hov and 160 or 80))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                SWUI.DrawText(lbl2, "SWUI.Tiny", w/2, h/2, txtC, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end,
            function()
                st.activeCh = captI
                netstream.Start("SWExp::RadioSetChannel", captI)
                if SWUI.PlaySound then SWUI.PlaySound(SWUI.Sounds and SWUI.Sounds.Click or nil, 0.4) end
            end
        )
    end

    -- ==================================================
    -- Кнопка СОХРАНИТЬ (внизу)
    -- ==================================================
    local SAVE_Y = ROWS_Y + 3 * (ROW_H + 6) + 8

    MakeBtn(content, PAD, SAVE_Y, CW, 40,
        function(s, w, h)
            local hov = s:IsHovered()
            draw.RoundedBox(8, 0, 0, w, h, hov and COL.SaveHov or COL.SaveBG)
            surface.SetDrawColor(SWUI.Colors.Accent.r, SWUI.Colors.Accent.g, SWUI.Colors.Accent.b, hov and 230 or 150)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            SWUI.DrawText("СОХРАНИТЬ", "SWUI.Body", w/2, h/2,
                SWUI.Colors.TextHi, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end,
        function()
            netstream.Start("SWExp::RadioSetConfig", {
                f1 = st.freqs[1] or 0,
                f2 = st.freqs[2] or 0,
                f3 = st.freqs[3] or 0,
                ch = st.activeCh,
            })
            for ch = 1, 3 do
                local freq = st.freqs[ch] or 0
                if freq > 0 then
                    local tag = ch == st.activeCh and "АКТИВНЫЙ" or "пассивный"
                    chat.AddText(
                        SWUI.Colors.Accent, "[Комлинк] ",
                        SWUI.Colors.TextDim, "Канал "..ch.." ["..tag.."]: ",
                        SWUI.Colors.TextHi,  freq.." МГц"
                    )
                end
            end
            frame:Close()
        end
    )
end

-- ============================================================
-- Быстрые действия по бинду
-- ============================================================
function SWExp.Radio:ToggleEnabled()
    local new = not IsEnabled()
    netstream.Start("SWExp::RadioEnabled", new)
    chat.AddText(
        new and SWUI.Colors.Accent or SWUI.Colors.Warn, "[Комлинк] ",
        SWUI.Colors.TextHi, new and "Рация включена" or "Рация отключена"
    )
    surface.PlaySound(new and "npc/combine_soldier/vo/on1.wav" or "npc/combine_soldier/vo/off1.wav")
end

function SWExp.Radio:ToggleMic()
    local new = not IsMicOn()
    netstream.Start("SWExp::RadioMic", new)
    chat.AddText(
        SWUI.Colors.Accent, "[Комлинк] ",
        SWUI.Colors.TextHi, new and "Микрофон включён" or "Микрофон отключён"
    )
    surface.PlaySound("npc/combine_soldier/vo/"..(new and "on1" or "off1")..".wav")
end

function SWExp.Radio:CycleChannel()
    if not IsEnabled() then return end
    local next = (GetActiveCh() % 3) + 1
    netstream.Start("SWExp::RadioSetChannel", next)
    local freq = GetFreq(next)
    chat.AddText(
        SWUI.Colors.Accent, "[Комлинк] ",
        SWUI.Colors.TextHi, "Активный канал: "..next.." ",
        freq > 0 and SWUI.Colors.TextDim or SWUI.Colors.Warn,
        freq > 0 and ("("..freq.." МГц)") or "(частота не задана)"
    )
    surface.PlaySound("buttons/button17.wav")
end

-- ============================================================
-- Обработка клавиш
-- ============================================================
hook.Add("PlayerButtonDown", "SWExp::RadioInputDown", function(ply, btn)
    if not IsFirstTimePredicted() then return end
    if vgui.CursorVisible() or ply:IsTyping() then return end

    if btn == SWExp.Radio:GetMenuKey() then
        SWExp.Radio:OpenMenu(); return
    end
    if btn ~= KEY_NONE and btn == SWExp.Radio:GetToggleKey() then
        SWExp.Radio:ToggleEnabled(); return
    end
    if btn ~= KEY_NONE and btn == SWExp.Radio:GetMicKey() then
        SWExp.Radio:ToggleMic(); return
    end
    if btn ~= KEY_NONE and btn == SWExp.Radio:GetChannelKey() then
        SWExp.Radio:CycleChannel(); return
    end
end)

-- ============================================================
-- PTT-хуки: говорим — отправляем флаг на сервер
-- ============================================================
hook.Add("PlayerStartVoice", "SWExp::RadioVoiceStart", function(ply)
    if ply ~= LocalPlayer() then return end
    if not IsEnabled() or not IsMicOn() then return end
    local freq = GetFreq(GetActiveCh())
    if freq > 0 then
        netstream.Start("SWExp::RadioTalk", true)
        surface.PlaySound("npc/combine_soldier/vo/on1.wav")
    end
end)

hook.Add("PlayerEndVoice", "SWExp::RadioVoiceEnd", function(ply)
    if ply ~= LocalPlayer() then return end
    -- Всегда сбрасываем флаг, если он был установлен
    if GetFreq(GetActiveCh()) > 0 then
        netstream.Start("SWExp::RadioTalk", false)
        surface.PlaySound("npc/combine_soldier/vo/off1.wav")
    end
end)

-- ============================================================
-- HUD-индикатор (левый нижний угол, над панелью персонажа)
-- ============================================================
local function S(n) return math.Round(n * (ScrH() / 1080)) end

hook.Add("HUDPaint", "SWExp::RadioHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local enabled   = ply:GetNWBool("swexp_radio_enabled", false)
    local activeCh  = ply:GetNWInt("swexp_radio_active_ch", 1)
    local isTalking = ply:GetNWBool("swexp_radio_talking", false)
    local micOn     = ply:GetNWBool("swexp_radio_mic", true)

    -- Базовые размеры
    local boxW = S(180)
    local rowH = S(22)
    local gap  = S(3)
    local x    = S(20)

    -- Якорь: над нижней панелью персонажа
    local charY = ScrH() - S(72) - S(24)

    if not enabled then
        -- Одна серая плашка "РАЦИЯ: ВЫКЛ"
        local y = charY - rowH - S(6)
        draw.RoundedBox(S(6)+1, x-1, y-1, boxW+2, rowH+2, Color(55, 55, 60, 200))
        draw.RoundedBox(S(6),   x,   y,   boxW,   rowH,   Color(10, 10, 14, 220))
        SWUI.DrawText("РАЦИЯ: ВЫКЛ", "SWUI.Tiny",
            x + boxW/2, y + rowH/2, Color(75, 80, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    -- Три плашки: рисуем сверху вниз, канал 3 → 2 → 1 (активный — ближе к персонажу)
    local totalH = 3*rowH + 2*gap
    local startY = charY - totalH - S(6)

    for i = 1, 3 do
        local chIdx = 4 - i          -- i=1→ch3, i=2→ch2, i=3→ch1
        local y     = startY + (i-1)*(rowH+gap)
        local freq  = ply:GetNWInt("swexp_radio_freq"..chIdx, 0)
        local isAct = (chIdx == activeCh)
        local isXmt = isAct and isTalking

        local colOuter, colInner, colText
        if isXmt then
            -- Передаём: зелёный
            colOuter = SWUI.Colors.Green
            colInner = Color(0, 40, 18, 235)
            colText  = SWUI.Colors.Green
        elseif isAct and not micOn then
            -- Активный, но мик выключен: красноватый
            colOuter = Color(180, 50, 40, 200)
            colInner = Color(18, 6, 6, 235)
            colText  = Color(200, 100, 90)
        elseif isAct then
            -- Активный, слушаем: синий
            colOuter = SWUI.Colors.Accent
            colInner = Color(0, 18, 36, 235)
            colText  = SWUI.Colors.TextHi
        else
            -- Пассивный
            colOuter = Color(24, 48, 68, 150)
            colInner = Color(6, 12, 18, 200)
            colText  = SWUI.Colors.TextDim
        end

        draw.RoundedBox(S(6)+1, x-1, y-1, boxW+2, rowH+2, colOuter)
        draw.RoundedBox(S(6),   x,   y,   boxW,   rowH,   colInner)

        local freqStr = freq > 0 and (freq.." МГц") or "---"
        local prefix
        if isXmt then
            prefix = "> КН"..chIdx..": "
        elseif isAct and not micOn then
            prefix = "x КН"..chIdx..": "
        elseif isAct then
            prefix = "* КН"..chIdx..": "
        else
            prefix = "  КН"..chIdx..": "
        end

        SWUI.DrawText(prefix..freqStr, "SWUI.Tiny",
            x + boxW/2, y + rowH/2, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
