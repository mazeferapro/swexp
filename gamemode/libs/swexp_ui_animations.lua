-- ============================================================
-- Star Wars: Expedition — UI Animation System
-- libs/swexp_ui_animations.lua
--
-- Система анимаций для SWUI библиотеки
-- Подключение: include('libs/swexp_ui_animations.lua') после swexp_ui.lua
-- ============================================================

if not CLIENT then return end

SWUI.Animations = SWUI.Animations or {}

-- ============================================================
-- EASING FUNCTIONS — функции плавности для анимаций
-- ============================================================

local Easing = {}

-- Линейная интерполяция
Easing.Linear = function(t) return t end

-- Квадратичные
Easing.InQuad    = function(t) return t * t end
Easing.OutQuad   = function(t) return t * (2 - t) end
Easing.InOutQuad = function(t) return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t end

-- Кубические (плавные, рекомендуется для UI)
Easing.InCubic    = function(t) return t * t * t end
Easing.OutCubic   = function(t) local f = t - 1 return f * f * f + 1 end
Easing.InOutCubic = function(t) return t < 0.5 and 4 * t * t * t or (t - 1) * (2 * t - 2) * (2 * t - 2) + 1 end

-- Квартик (еще более плавные)
Easing.InQuart    = function(t) return t * t * t * t end
Easing.OutQuart   = function(t) local f = t - 1 return 1 - f * f * f * f end
Easing.InOutQuart = function(t) return t < 0.5 and 8 * t * t * t * t or 1 - 8 * (t - 1) * (t - 1) * (t - 1) * (t - 1) end

-- Квинтик (самые плавные)
Easing.InQuint    = function(t) return t * t * t * t * t end
Easing.OutQuint   = function(t) local f = t - 1 return f * f * f * f * f + 1 end
Easing.InOutQuint = function(t) return t < 0.5 and 16 * t * t * t * t * t or 1 + 16 * (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1) end

-- Экспоненциальные (резкие)
Easing.InExpo  = function(t) return t == 0 and 0 or math.pow(2, 10 * (t - 1)) end
Easing.OutExpo = function(t) return t == 1 and 1 or 1 - math.pow(2, -10 * t) end

-- Back (эффект "отката")
Easing.OutBack = function(t)
    local s = 1.70158
    t = t - 1
    return t * t * ((s + 1) * t + s) + 1
end

-- Elastic (пружинистый эффект)
Easing.OutElastic = function(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

-- Bounce (отскок)
Easing.OutBounce = function(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

SWUI.Animations.Easing = Easing

-- ============================================================
-- ANIMATOR CLASS — объект анимации для панели
-- ============================================================

local Animator = {}
Animator.__index = Animator

function Animator:New(panel)
    local obj = {
        panel = panel,
        animations = {},
        nextID = 1,
    }
    setmetatable(obj, Animator)
    return obj
end

-- Добавить анимацию
function Animator:Add(property, targetValue, duration, easing, onComplete)
    local anim = {
        id = self.nextID,
        property = property,
        startValue = self.panel[property],
        targetValue = targetValue,
        duration = duration or 0.3,
        easing = easing or Easing.OutQuart,
        startTime = SysTime(),
        onComplete = onComplete,
    }
    
    self.animations[self.nextID] = anim
    self.nextID = self.nextID + 1
    
    return anim.id
end

-- Обновить все анимации
function Animator:Think()
    if not IsValid(self.panel) then return end
    
    local currentTime = SysTime()
    local toRemove = {}
    
    for id, anim in pairs(self.animations) do
        local elapsed = currentTime - anim.startTime
        local progress = math.min(elapsed / anim.duration, 1)
        
        -- Применить easing
        local easedProgress = anim.easing(progress)
        
        -- Интерполировать значение
        local current = Lerp(easedProgress, anim.startValue, anim.targetValue)
        self.panel[property] = current
        
        -- Завершена?
        if progress >= 1 then
            self.panel[anim.property] = anim.targetValue
            if anim.onComplete then anim.onComplete() end
            table.insert(toRemove, id)
        end
    end
    
    -- Удалить завершенные
    for _, id in ipairs(toRemove) do
        self.animations[id] = nil
    end
end

-- Остановить все анимации
function Animator:Stop()
    self.animations = {}
end

-- Остановить анимацию по ID
function Animator:StopAnimation(id)
    self.animations[id] = nil
end

SWUI.Animations.Animator = Animator

-- ============================================================
-- PRESET АНИМАЦИИ — готовые эффекты для меню
-- ============================================================

local Presets = {}

-- Появление окна: Fade + Scale
Presets.WindowOpen = function(panel, duration)
    duration = duration or 0.35
    
    panel:SetAlpha(0)
    panel._scaleX = 0.85
    panel._scaleY = 0.85
    
    local originalPaint = panel.Paint
    panel.Paint = function(self, w, h)
        local mx, my = w / 2, h / 2
        local sx, sy = self._scaleX or 1, self._scaleY or 1
        
        local mat = Matrix()
        mat:Translate(Vector(mx, my, 0))
        mat:Scale(Vector(sx, sy, 1))
        mat:Translate(Vector(-mx, -my, 0))
        
        cam.PushModelMatrix(mat)
        if originalPaint then originalPaint(self, w, h) end
        cam.PopModelMatrix()
    end
    
    -- Анимация альфы
    panel:AlphaTo(255, duration * 0.8, 0)
    
    -- Анимация масштаба
    local startTime = SysTime()
    local animThink
    animThink = function()
        if not IsValid(panel) then return end
        
        local elapsed = SysTime() - startTime
        local progress = math.min(elapsed / duration, 1)
        local eased = Easing.OutBack(progress)
        
        panel._scaleX = Lerp(eased, 0.85, 1)
        panel._scaleY = Lerp(eased, 0.85, 1)
        
        if progress < 1 then
            timer.Simple(0, animThink)
        else
            panel._scaleX = 1
            panel._scaleY = 1
        end
    end
    timer.Simple(0, animThink)
    
    SWUI.PlaySound(SWUI.Sounds.Open)
end

-- Закрытие окна: Fade + Scale
Presets.WindowClose = function(panel, duration, onComplete)
    duration = duration or 0.25
    
    if not panel._scaleX then panel._scaleX = 1 end
    if not panel._scaleY then panel._scaleY = 1 end
    
    -- Анимация альфы
    panel:AlphaTo(0, duration * 0.6, 0)
    
    -- Анимация масштаба
    local startTime = SysTime()
    local animThink
    animThink = function()
        if not IsValid(panel) then return end
        
        local elapsed = SysTime() - startTime
        local progress = math.min(elapsed / duration, 1)
        local eased = Easing.InQuart(progress)
        
        panel._scaleX = Lerp(eased, 1, 0.85)
        panel._scaleY = Lerp(eased, 1, 0.85)
        
        if progress < 1 then
            timer.Simple(0, animThink)
        else
            if onComplete then onComplete() end
        end
    end
    timer.Simple(0, animThink)
    
    SWUI.PlaySound(SWUI.Sounds.Close)
end

-- Slide In (слева/справа/сверху/снизу)
Presets.SlideIn = function(panel, direction, duration)
    direction = direction or "left" -- "left", "right", "top", "bottom"
    duration = duration or 0.4
    
    local w, h = panel:GetSize()
    local originalX, originalY = panel:GetPos()
    
    -- Начальные позиции за пределами экрана
    local startX, startY = originalX, originalY
    if direction == "left" then
        startX = -w
    elseif direction == "right" then
        startX = ScrW()
    elseif direction == "top" then
        startY = -h
    elseif direction == "bottom" then
        startY = ScrH()
    end
    
    panel:SetPos(startX, startY)
    panel:SetAlpha(0)
    
    -- Анимация позиции
    local startTime = SysTime()
    local animThink
    animThink = function()
        if not IsValid(panel) then return end
        
        local elapsed = SysTime() - startTime
        local progress = math.min(elapsed / duration, 1)
        local eased = Easing.OutQuart(progress)
        
        local x = Lerp(eased, startX, originalX)
        local y = Lerp(eased, startY, originalY)
        panel:SetPos(x, y)
        
        -- Fade in
        panel:SetAlpha(math.min(255, 255 * (progress / 0.5)))
        
        if progress < 1 then
            timer.Simple(0, animThink)
        end
    end
    timer.Simple(0, animThink)
end

-- Hover эффект для кнопок
Presets.ButtonHover = function(panel, hoverScale, duration)
    hoverScale = hoverScale or 1.03
    duration = duration or 0.15
    
    if not panel._animScale then panel._animScale = 1 end
    if not panel._animAlpha then panel._animAlpha = 255 end
    
    local originalPaint = panel.Paint
    panel.Paint = function(self, w, h)
        local scale = self._animScale or 1
        
        if scale ~= 1 then
            local mx, my = w / 2, h / 2
            local mat = Matrix()
            mat:Translate(Vector(mx, my, 0))
            mat:Scale(Vector(scale, scale, 1))
            mat:Translate(Vector(-mx, -my, 0))
            
            cam.PushModelMatrix(mat)
            if originalPaint then originalPaint(self, w, h) end
            cam.PopModelMatrix()
        else
            if originalPaint then originalPaint(self, w, h) end
        end
    end
    
    local originalEnter = panel.OnCursorEntered
    panel.OnCursorEntered = function(self)
        if originalEnter then originalEnter(self) end
        
        -- Анимация увеличения
        local startTime = SysTime()
        local startScale = self._animScale or 1
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / duration, 1)
            local eased = Easing.OutCubic(progress)
            
            self._animScale = Lerp(eased, startScale, hoverScale)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
    
    local originalExit = panel.OnCursorExited
    panel.OnCursorExited = function(self)
        if originalExit then originalExit(self) end
        
        -- Анимация уменьшения
        local startTime = SysTime()
        local startScale = self._animScale or hoverScale
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / duration, 1)
            local eased = Easing.OutCubic(progress)
            
            self._animScale = Lerp(eased, startScale, 1)
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
end

-- Плавное изменение цвета при наведении
Presets.ColorTransition = function(panel, normalColor, hoverColor, duration)
    duration = duration or 0.2
    
    if not panel._animColor then
        panel._animColor = ColorAlpha(normalColor, normalColor.a)
    end
    
    local originalEnter = panel.OnCursorEntered
    panel.OnCursorEntered = function(self)
        if originalEnter then originalEnter(self) end
        
        local startTime = SysTime()
        local startColor = ColorAlpha(self._animColor, self._animColor.a)
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / duration, 1)
            local eased = Easing.OutQuad(progress)
            
            self._animColor = Color(
                Lerp(eased, startColor.r, hoverColor.r),
                Lerp(eased, startColor.g, hoverColor.g),
                Lerp(eased, startColor.b, hoverColor.b),
                Lerp(eased, startColor.a, hoverColor.a)
            )
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
    
    local originalExit = panel.OnCursorExited
    panel.OnCursorExited = function(self)
        if originalExit then originalExit(self) end
        
        local startTime = SysTime()
        local startColor = ColorAlpha(self._animColor, self._animColor.a)
        
        local animThink
        animThink = function()
            if not IsValid(self) then return end
            
            local elapsed = SysTime() - startTime
            local progress = math.min(elapsed / duration, 1)
            local eased = Easing.OutQuad(progress)
            
            self._animColor = Color(
                Lerp(eased, startColor.r, normalColor.r),
                Lerp(eased, startColor.g, normalColor.g),
                Lerp(eased, startColor.b, normalColor.b),
                Lerp(eased, startColor.a, normalColor.a)
            )
            
            if progress < 1 then
                timer.Simple(0, animThink)
            end
        end
        timer.Simple(0, animThink)
    end
end

-- Ripple эффект при клике (волна)
Presets.RippleClick = function(panel)
    local ripples = {}
    
    local originalPaint = panel.Paint
    panel.Paint = function(self, w, h)
        if originalPaint then originalPaint(self, w, h) end
        
        -- Рисуем все активные волны
        for i = #ripples, 1, -1 do
            local ripple = ripples[i]
            local elapsed = SysTime() - ripple.startTime
            local progress = math.min(elapsed / ripple.duration, 1)
            
            if progress >= 1 then
                table.remove(ripples, i)
            else
                local eased = Easing.OutQuad(progress)
                local radius = ripple.maxRadius * eased
                local alpha = 60 * (1 - progress)
                
                draw.NoTexture()
                surface.SetDrawColor(255, 255, 255, alpha)
                
                -- Рисуем круг
                local segments = 32
                for j = 0, segments do
                    local angle1 = (j / segments) * math.pi * 2
                    local angle2 = ((j + 1) / segments) * math.pi * 2
                    
                    surface.DrawLine(
                        ripple.x + math.cos(angle1) * radius,
                        ripple.y + math.sin(angle1) * radius,
                        ripple.x + math.cos(angle2) * radius,
                        ripple.y + math.sin(angle2) * radius
                    )
                end
            end
        end
    end
    
    local originalClick = panel.OnMousePressed
    panel.OnMousePressed = function(self, keyCode)
        if originalClick then originalClick(self, keyCode) end
        
        if keyCode == MOUSE_LEFT then
            local x, y = self:CursorPos()
            local w, h = self:GetSize()
            local maxRadius = math.sqrt(w * w + h * h) / 2
            
            table.insert(ripples, {
                x = x,
                y = y,
                maxRadius = maxRadius,
                duration = 0.6,
                startTime = SysTime(),
            })
        end
    end
end

-- Shake эффект (тряска при ошибке)
Presets.Shake = function(panel, intensity, duration)
    intensity = intensity or 5
    duration = duration or 0.4
    
    local originalX, originalY = panel:GetPos()
    local startTime = SysTime()
    
    local animThink
    animThink = function()
        if not IsValid(panel) then return end
        
        local elapsed = SysTime() - startTime
        local progress = math.min(elapsed / duration, 1)
        
        if progress < 1 then
            local shake = intensity * (1 - progress)
            local offsetX = math.random(-shake, shake)
            local offsetY = math.random(-shake, shake)
            
            panel:SetPos(originalX + offsetX, originalY + offsetY)
            timer.Simple(0.016, animThink) -- ~60 FPS
        else
            panel:SetPos(originalX, originalY)
        end
    end
    timer.Simple(0, animThink)
    
    SWUI.PlaySound(SWUI.Sounds.Denied)
end

-- Expand/Collapse анимация (для выпадающих меню)
Presets.Expand = function(panel, targetHeight, duration, onComplete)
    duration = duration or 0.3
    
    local startHeight = panel:GetTall()
    local startTime = SysTime()
    
    local animThink
    animThink = function()
        if not IsValid(panel) then return end
        
        local elapsed = SysTime() - startTime
        local progress = math.min(elapsed / duration, 1)
        local eased = Easing.OutQuart(progress)
        
        local h = Lerp(eased, startHeight, targetHeight)
        panel:SetTall(h)
        
        if progress < 1 then
            timer.Simple(0, animThink)
        else
            if onComplete then onComplete() end
        end
    end
    timer.Simple(0, animThink)
end

SWUI.Animations.Presets = Presets

-- ============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

-- Применить fade анимацию к панели
function SWUI.FadeIn(panel, duration, delay, onComplete)
    duration = duration or 0.3
    delay = delay or 0
    
    panel:SetAlpha(0)
    
    if delay > 0 then
        timer.Simple(delay, function()
            if IsValid(panel) then
                panel:AlphaTo(255, duration, 0, onComplete)
            end
        end)
    else
        panel:AlphaTo(255, duration, 0, onComplete)
    end
end

function SWUI.FadeOut(panel, duration, delay, onComplete)
    duration = duration or 0.3
    delay = delay or 0
    
    if delay > 0 then
        timer.Simple(delay, function()
            if IsValid(panel) then
                panel:AlphaTo(0, duration, 0, onComplete)
            end
        end)
    else
        panel:AlphaTo(0, duration, 0, onComplete)
    end
end

-- Последовательный fade для списка панелей (stagger)
function SWUI.StaggerFadeIn(panels, duration, staggerDelay)
    duration = duration or 0.3
    staggerDelay = staggerDelay or 0.05
    
    for i, panel in ipairs(panels) do
        if IsValid(panel) then
            SWUI.FadeIn(panel, duration, (i - 1) * staggerDelay)
        end
    end
end

print('[SWExp] UI Animation System загружена.')