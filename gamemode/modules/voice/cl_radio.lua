-- modules/cl_radio.lua
if SERVER then return end

SWExp.Radio = SWExp.Radio or {}

-- Оставляем только кнопку для открытия меню
local DEFAULT_MENU_KEY = KEY_G

function SWExp.Radio:GetMenuKey()
    return cookie.GetNumber('swexp_key_comlink_menu', DEFAULT_MENU_KEY)
end

-- ============================================================
-- UI Комлинка
-- ============================================================
function SWExp.Radio:OpenMenu()
    if IsValid(self.Frame) then self.Frame:Remove() end

    local frame = SWUI.Animated.CreateWindow('КОМЛИНК', 400, 220)
    local content = frame.Content 
    self.Frame = frame

    local currentFreq = LocalPlayer():GetNWInt("swexp_radio_freq", 0)
    local displayFreq = currentFreq > 0 and tostring(currentFreq) or ""

    local l1 = vgui.Create('DLabel', content)
    l1:SetPos(20, 20)
    l1:SetFont('SWUI.Body')
    l1:SetTextColor(SWUI.Colors.TextHi)
    l1:SetText('Частота (MHz):')
    l1:SizeToContents()

    local inp = SWUI.CreateInput(content, 20, 50, 360, 38, "Например: 104")
    inp:SetValue(displayFreq)
    
    timer.Simple(0.1, function()
        if IsValid(inp.Entry) then inp.Entry:RequestFocus() end
    end)
    
    inp.Entry.Think = function(s)
        local text = s:GetValue()
        local filtered = string.gsub(text, "[^0-9]", "")
        if text ~= filtered then
            s:SetValue(filtered)
            s:SetCaretPos(#filtered)
        end
    end

    SWUI.CreateButton(content, 'ПОДКЛЮЧИТЬСЯ', 20, 110, 170, 40, 'accent', function()
        local freq = tonumber(inp:GetValue()) or 0
        netstream.Start("SWExp::SetRadioFreq", freq)
        
        if freq > 0 then
            chat.AddText(SWUI.Colors.Accent, "[Комлинк] ", SWUI.Colors.TextHi, "Вы подключились к частоте " .. freq .. " MHz.")
        else
            chat.AddText(SWUI.Colors.Warn, "[Комлинк] ", SWUI.Colors.TextHi, "Вы отключились от частоты.")
        end
        frame:Close()
    end)

    SWUI.CreateButton(content, 'ОТКЛЮЧИТЬСЯ', 210, 110, 170, 40, 'danger', function()
        netstream.Start("SWExp::SetRadioFreq", 0)
        chat.AddText(SWUI.Colors.Warn, "[Комлинк] ", SWUI.Colors.TextHi, "Вы отключились от рации.")
        frame:Close()
    end)
end

-- ============================================================
-- Обработка кнопок (Только меню)
-- ============================================================
hook.Add("PlayerButtonDown", "SWExp::RadioInputDown", function(ply, btn)
    if not IsFirstTimePredicted() then return end
    if vgui.CursorVisible() or ply:IsTyping() then return end

    if btn == SWExp.Radio:GetMenuKey() then
        SWExp.Radio:OpenMenu()
    end
end)

-- ============================================================
-- Активация рации и звуковые эффекты (пшик)
-- ============================================================
hook.Add("PlayerStartVoice", "SWExp::RadioVoiceStart", function(ply)
    local myFreq = LocalPlayer():GetNWInt("swexp_radio_freq", 0)
    
    -- Если мы на частоте и говорящий тоже на ней
    if myFreq > 0 and ply:GetNWInt("swexp_radio_freq", 0) == myFreq then
        -- Характерный звук включения рации
        surface.PlaySound("npc/combine_soldier/vo/on1.wav")
        
        if ply == LocalPlayer() then
            netstream.Start("SWExp::RadioTalk", true)
        end
    end
end)

hook.Add("PlayerEndVoice", "SWExp::RadioVoiceEnd", function(ply)
    local myFreq = LocalPlayer():GetNWInt("swexp_radio_freq", 0)
    
    if myFreq > 0 and ply:GetNWInt("swexp_radio_freq", 0) == myFreq then
        -- Звук выключения рации
        surface.PlaySound("npc/combine_soldier/vo/off1.wav")
        
        if ply == LocalPlayer() then
            netstream.Start("SWExp::RadioTalk", false)
        end
    end
end)

-- ============================================================
-- HUD Индикатор
-- ============================================================
local function S(n) return math.Round(n * (ScrH() / 1080)) end

hook.Add("HUDPaint", "SWExp::RadioHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local freq = ply:GetNWInt("swexp_radio_freq", 0)
    if freq == 0 then return end

    local isTalking = ply:GetNWBool("swexp_radio_talking", false)
    
    -- Высчитываем позицию точно над панелью персонажа
    local charH = S(72)
    local charY = ScrH() - charH - S(24)
    
    local boxW = S(160)
    local boxH = S(24)
    local x = S(20)
    local y = charY - boxH - S(6)
    
    -- Используем цвета и альфу точно как в функции Panel() из cl_hud.lua
    local colOuter = isTalking and SWUI.Colors.Green or Color(0, 184, 255, 255) -- SWUI.Colors.Accent
    local colInner = isTalking and Color(0, 50, 20, 255) or Color(6, 12, 18, 255)
    local colText  = isTalking and SWUI.Colors.Green or SWUI.Colors.TextDim
    
    -- Отрисовка плашки с радиусом S(10), как у панели персонажа
    draw.RoundedBox(S(10) + 1, x - 1, y - 1, boxW + 2, boxH + 2, colOuter)
    draw.RoundedBox(S(10), x, y, boxW, boxH, colInner)
    
    local text = isTalking and ("ПЕРЕДАЧА: " .. freq .. " MHz") or ("ЧАСТОТА: " .. freq .. " MHz")
    
    -- Текст ровно по центру плашки
    SWUI.DrawText(text, "SWUI.Tiny", x + boxW / 2, y + boxH / 2, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)