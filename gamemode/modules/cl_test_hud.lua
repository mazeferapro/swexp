-- ============================================================
-- Star Wars: Expedition — Animation Examples & Documentation
-- libs/swexp_ui_animations_examples.lua
--
-- Примеры использования системы анимаций SWUI
-- ============================================================

--[[
═══════════════════════════════════════════════════════════════
ИНСТАЛЛЯЦИЯ
═══════════════════════════════════════════════════════════════

1. Добавьте в shared.lua (или gamemode/shared.lua) ПОСЛЕ загрузки swexp_ui.lua:

    if CLIENT then
        include('libs/swexp_ui_animations.lua')
        include('libs/swexp_ui_animated.lua')
    end
    AddCSLuaFile('libs/swexp_ui_animations.lua')
    AddCSLuaFile('libs/swexp_ui_animated.lua')

2. Готово! Теперь доступны анимированные компоненты через SWUI.Animated.*

═══════════════════════════════════════════════════════════════
ДОСТУПНЫЕ КОМПОНЕНТЫ
═══════════════════════════════════════════════════════════════

1. SWUI.Animated.CreateWindow(title, w, h, parent, accentColor)
   - Окно с плавным появлением (fade + scale)
   - Анимированное закрытие при вызове :Close()

2. SWUI.Animated.CreateButton(parent, x, y, w, h, label, style, onClick)
   - Кнопка с hover анимацией (масштабирование)
   - Ripple эффект при клике

3. SWUI.Animated.CreateCategoryNav(parent, items, x, y, w, h, onChange, cornerRadius)
   - Навигация с плавной активацией
   - Stagger fade in при появлении
   - Анимация индикатора активности

4. SWUI.Animated.CreateListRow(parent, h, selected, locked, onClick)
   - Строка списка с hover анимацией
   - Плавная смена selected состояния
   - Shake эффект при попытке нажать на locked

5. SWUI.Animated.CreateDropdown(parent, x, y, w, items, defaultIndex, onChange)
   - Выпадающее меню с expand/collapse анимацией
   - Плавные hover переходы

═══════════════════════════════════════════════════════════════
ПРИМЕР 1: Анимированное окно
═══════════════════════════════════════════════════════════════
]]

concommand.Add('swui_test_window', function()
    -- Создание окна с анимацией
    local window = SWUI.Animated.CreateWindow('Тестовое окно', 600, 400)
    window:Center()
    
    -- Добавляем контент
    local btn = SWUI.Animated.CreateButton(
        window, 
        20, 60, 200, 40, 
        'Закрыть', 
        'primary',
        function()
            window:Close()  -- Автоматически анимированное закрытие
        end
    )
end)

--[[
═══════════════════════════════════════════════════════════════
ПРИМЕР 2: Категорийная навигация с анимацией
═══════════════════════════════════════════════════════════════
]]

concommand.Add('swui_test_nav', function()
    local window = SWUI.Animated.CreateWindow('Тест навигации', 800, 600)
    window:Center()
    
    local categories = {
        { id = 'weapons',  icon = '🔫', label = 'Оружие',     count = 12 },
        { id = 'armor',    icon = '🛡️', label = 'Броня',      count = 8  },
        { id = 'consumable', icon = '💊', label = 'Расходники', count = 24 },
        { id = 'misc',     icon = '📦', label = 'Разное',     count = 5  },
    }
    
    local nav = SWUI.Animated.CreateCategoryNav(
        window,
        categories,
        20, 60,
        200, 520,
        function(categoryID)
            print('Выбрана категория:', categoryID)
        end
    )
    
    -- Область контента справа
    local content = vgui.Create('DPanel', window)
    content:SetPos(240, 60)
    content:SetSize(540, 520)
    content.Paint = function(self, w, h)
        SWUI.DrawText('Контент категории здесь', 'SWUI.Header', w / 2, h / 2, SWUI.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

--[[
═══════════════════════════════════════════════════════════════
ПРИМЕР 3: Список с анимированными строками
═══════════════════════════════════════════════════════════════
]]

concommand.Add('swui_test_list', function()
    local window = SWUI.Animated.CreateWindow('Анимированный список', 400, 500)
    window:Center()
    
    local scroll = SWUI.CreateScrollList(window, 20, 60, 360, 420)
    
    local selectedRow = nil
    
    for i = 1, 15 do
        local isLocked = (i % 5 == 0)  -- Каждая 5-я строка заблокирована
        
        local row = SWUI.Animated.CreateListRow(
            scroll,
            60,
            false,
            isLocked,
            function()
                -- Снять выделение с предыдущей
                if selectedRow and IsValid(selectedRow) then
                    selectedRow:SetSelectedAnimated(false)
                end
                
                -- Выделить текущую
                row:SetSelectedAnimated(true)
                selectedRow = row
                
                print('Выбран элемент:', i)
            end
        )
        
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        
        -- Добавляем контент в строку
        local label = vgui.Create('DLabel', row)
        label:SetPos(10, 10)
        label:SetFont('SWUI.Body')
        label:SetTextColor(SWUI.Colors.TextHi)
        label:SetText('Элемент списка #' .. i .. (isLocked and ' (Заблокирован)' or ''))
        label:SizeToContents()
        
        -- Stagger fade in
        row:SetAlpha(0)
        SWUI.FadeIn(row, 0.3, i * 0.04)
    end
end)

--[[
═══════════════════════════════════════════════════════════════
ПРИМЕР 4: Dropdown меню
═══════════════════════════════════════════════════════════════
]]

concommand.Add('swui_test_dropdown', function()
    local window = SWUI.Animated.CreateWindow('Тест Dropdown', 400, 300)
    window:Center()
    
    local items = {
        'Вариант 1',
        'Вариант 2',
        'Вариант 3',
        'Вариант 4',
        'Вариант 5',
    }
    
    local dropdown = SWUI.Animated.CreateDropdown(
        window,
        20, 60,
        360,
        items,
        1,
        function(index, text)
            print('Выбрано:', index, text)
        end
    )
end)

--[[
═══════════════════════════════════════════════════════════════
ПРИМЕР 5: Использование Preset анимаций вручную
═══════════════════════════════════════════════════════════════
]]

concommand.Add('swui_test_presets', function()
    local window = SWUI.Animated.CreateWindow('Preset анимации', 600, 450)
    window:Center()
    
    -- Кнопка 1: Shake при клике
    local btn1 = SWUI.CreateButton(window, 50, 60, 200, 40, 'Shake эффект', 'primary', function(self)
        SWUI.Animations.Presets.Shake(self, 8, 0.5)
    end)
    
    -- Кнопка 2: Slide In анимация
    local btn2 = SWUI.CreateButton(window, 50, 110, 200, 40, 'Slide эффект', 'primary')
    SWUI.Animations.Presets.SlideIn(btn2, 'left', 0.6)
    
    -- Кнопка 3: Ripple эффект
    local btn3 = SWUI.CreateButton(window, 50, 160, 200, 40, 'Ripple эффект', 'primary')
    SWUI.Animations.Presets.RippleClick(btn3)
    
    -- Панель с Color Transition
    local panel = vgui.Create('DPanel', window)
    panel:SetPos(300, 60)
    panel:SetSize(250, 350)
    panel.Paint = function(self, w, h)
        local col = self._animColor or SWUI.Colors.PanelBG
        SWUI.DrawRoundedRect(0, 0, w, h, 8, col)
        surface.SetDrawColor(SWUI.Colors.Border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        SWUI.DrawText('Наведи для смены цвета', 'SWUI.Body', w / 2, h / 2, SWUI.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    SWUI.Animations.Presets.ColorTransition(
        panel,
        SWUI.Colors.PanelBG,
        SWUI.Colors.Accent,
        0.3
    )
end)

--[[
═══════════════════════════════════════════════════════════════
ПРИМЕР 6: Интеграция с существующими SWUI окнами
═══════════════════════════════════════════════════════════════

Если у вас уже есть код с SWUI.CreateWindow, можно легко добавить анимации:
]]

-- БЫЛО:
-- local window = SWUI.CreateWindow('Инвентарь', 800, 600)

-- СТАЛО:
-- local window = SWUI.Animated.CreateWindow('Инвентарь', 800, 600)

-- Или добавить анимацию к существующему окну:
-- local window = SWUI.CreateWindow('Инвентарь', 800, 600)
-- SWUI.Animations.Presets.WindowOpen(window, 0.35)

--[[
═══════════════════════════════════════════════════════════════
ПРИМЕР 7: Stagger fade для группы элементов
═══════════════════════════════════════════════════════════════
]]

concommand.Add('swui_test_stagger', function()
    local window = SWUI.Animated.CreateWindow('Stagger Fade In', 400, 500)
    window:Center()
    
    local panels = {}
    
    for i = 1, 10 do
        local panel = vgui.Create('DPanel', window)
        panel:SetPos(50, 60 + (i - 1) * 40)
        panel:SetSize(300, 35)
        panel.Paint = function(self, w, h)
            SWUI.DrawRoundedRect(0, 0, w, h, 6, SWUI.Colors.PanelBG)
            surface.SetDrawColor(SWUI.Colors.Border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            
            SWUI.DrawText('Элемент #' .. i, 'SWUI.Body', 10, h / 2, SWUI.Colors.TextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        
        table.insert(panels, panel)
    end
    
    -- Применяем stagger fade
    SWUI.StaggerFadeIn(panels, 0.3, 0.06)
end)

--[[
═══════════════════════════════════════════════════════════════
РАСШИРЕННОЕ ИСПОЛЬЗОВАНИЕ
═══════════════════════════════════════════════════════════════

ДОСТУПНЫЕ EASING ФУНКЦИИ:
- SWUI.Animations.Easing.Linear
- SWUI.Animations.Easing.InQuad / OutQuad / InOutQuad
- SWUI.Animations.Easing.InCubic / OutCubic / InOutCubic
- SWUI.Animations.Easing.InQuart / OutQuart / InOutQuart (рекомендуется для UI)
- SWUI.Animations.Easing.InQuint / OutQuint / InOutQuint
- SWUI.Animations.Easing.InExpo / OutExpo
- SWUI.Animations.Easing.OutBack (с эффектом "отката")
- SWUI.Animations.Easing.OutElastic (пружинистый)
- SWUI.Animations.Easing.OutBounce (отскок)

СОЗДАНИЕ КАСТОМНОЙ АНИМАЦИИ:

local panel = vgui.Create('DPanel', parent)
panel._customValue = 0

local startTime = SysTime()
local duration = 0.5

local animThink
animThink = function()
    if not IsValid(panel) then return end
    
    local elapsed = SysTime() - startTime
    local progress = math.min(elapsed / duration, 1)
    local eased = SWUI.Animations.Easing.OutQuart(progress)
    
    panel._customValue = Lerp(eased, 0, 100)
    
    if progress < 1 then
        timer.Simple(0, animThink)
    else
        print('Анимация завершена!')
    end
end
timer.Simple(0, animThink)

═══════════════════════════════════════════════════════════════
ПРОИЗВОДИТЕЛЬНОСТЬ
═══════════════════════════════════════════════════════════════

- Все анимации оптимизированы для 60 FPS
- Используют timer.Simple(0) вместо Think hooks для лучшей производительности
- Автоматически очищаются при удалении панелей (IsValid проверки)
- Можно безопасно использовать десятки анимаций одновременно

═══════════════════════════════════════════════════════════════
СОВЕТЫ
═══════════════════════════════════════════════════════════════

1. Для UI элементов используйте OutQuart или OutCubic easing
2. Для появления окон - OutBack (дает приятный "отскок")
3. Для плавного исчезновения - InQuart
4. Duration 0.2-0.4 секунды оптимальна для большинства UI анимаций
5. Stagger delay 0.03-0.06 для списков дает приятный эффект

]]

print('[SWExp] Animation Examples загружены. Доступные команды:')
print('  swui_test_window   - Тест анимированного окна')
print('  swui_test_nav      - Тест категорийной навигации')
print('  swui_test_list     - Тест списка с анимациями')
print('  swui_test_dropdown - Тест dropdown меню')
print('  swui_test_presets  - Тест preset анимаций')
print('  swui_test_stagger  - Тест stagger fade эффекта')


-- ============================================================
-- СОЗДАТЬ ФАЙЛ gamemode/modules/cl_scoreboard.lua
-- Кастомный скорборд с правильными никами
-- ============================================================

-- Переопределяем GetName для клиента
local meta = FindMetaTable('Player')
local oldGetName = meta.GetName

function meta:GetName()
    local customNick = self:GetNWString('SWExp_Nick', '')
    if customNick ~= '' then
        return customNick
    end
    return oldGetName(self)
end

-- Также Name и Nick
meta.Name = meta.GetName
meta.Nick = meta.GetName

print('[SWExp Client] Scoreboard nickname override loaded')