-- ============================================================================
-- cl_platform_cam.lua — Режим выбора платформы с орбитальной камерой
-- ============================================================================
-- Когда игрок нажимает «ВЫЗВАТЬ ТЕХНИКУ», меню закрывается и включается этот
-- режим: камера плавно вращается вокруг текущей платформы, внизу экрана
-- появляется панель с кнопками ← → «ВЫЗВАТЬ СЮДА» «ОТМЕНА».
-- ============================================================================

if SERVER then return end

SWExp           = SWExp or {}
SWExp.CarDealer = SWExp.CarDealer or {}

local Cam = {}
SWExp.CarDealer.PlatformCam = Cam

-- ============================================================================
-- Состояние
-- ============================================================================
Cam._active    = false
Cam._platforms = {}   -- { index, pos=Vector, ang=Angle, occupied=bool }
Cam._current   = 1    -- выбранная платформа (1-based)
Cam._vehClass  = ""
Cam._spawner   = nil  -- entity терминала
Cam._panel     = nil  -- VGUI root panel
Cam._angle     = 0    -- текущий угол орбиты (градусы)

-- Параметры орбиты
local ORBIT_RADIUS = 350   -- горизонтальный радиус (юниты)
local ORBIT_HEIGHT = 280   -- высота над платформой
local ORBIT_SPEED  = 22    -- градусов/сек
local CAM_FOV      = 65

-- ============================================================================
-- Вход / выход из режима
-- ============================================================================

function Cam:Enter(platforms, vehClass, spawner)
    if #platforms == 0 then
        chat.AddText(Color(255,80,80), "[SWExp] ", Color(200,180,180),
            "К этому терминалу не привязаны платформы.")
        return
    end

    self._active    = true
    self._platforms = platforms
    self._vehClass  = vehClass
    self._spawner   = spawner
    self._angle     = 0

    -- Выбираем первую свободную платформу
    self._current = 1
    for i, p in ipairs(platforms) do
        if not p.occupied then self._current = i break end
    end

    -- Разблокируем мышь
    gui.EnableScreenClicker(true)

    -- Создаём HUD-панель
    self:_CreatePanel()
end

function Cam:Exit()
    self._active = false
    gui.EnableScreenClicker(false)
    if IsValid(self._panel) then self._panel:Remove() end
    self._panel = nil
end

-- ============================================================================
-- Построение VGUI-оверлея
-- ============================================================================

function Cam:_CreatePanel()
    if IsValid(self._panel) then self._panel:Remove() end

    local sw, sh = ScrW(), ScrH()

    -- Прозрачный полноэкранный контейнер (перехватывает клики)
    local root = vgui.Create("DPanel")
    root:SetSize(sw, sh)
    root:SetPos(0, 0)
    root:MakePopup()
    root:SetKeyboardInputEnabled(false)
    root.Paint = function() end   -- полностью прозрачный
    self._panel = root

    -- ── Нижняя панель управления ────────────────────────────────
    local panW, panH = 680, 110
    local panX = (sw - panW) / 2
    local panY = sh - panH - 20

    local bar = vgui.Create("DPanel", root)
    bar:SetPos(panX, panY)
    bar:SetSize(panW, panH)

    -- Только кнопки, без фона панели
    bar.Paint = function() end

    -- Текст рисуем в root.Paint — координаты всегда корректные
    local shadow = Color(0, 0, 0, 180)

    local function ShadowText(text, font, x, y, col, ax, ay)
        draw.SimpleText(text, font, x + 2, y + 2, shadow, ax, ay)
        draw.SimpleText(text, font, x,     y,     col,    ax, ay)
    end

    root.Paint = function(_, w, h)
        local cam     = SWExp.CarDealer.PlatformCam
        local total   = #cam._platforms
        local plat    = cam._platforms[cam._current]
        local platNum = plat and plat.index or cam._current
        local occupied = plat and plat.occupied or false

        local cx    = w / 2
        local baseY = panY - 72

        ShadowText(
            cam._vehClass,
            "SWUI.Tiny", cx, baseY,
            Color(100, 160, 200, 220),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        ShadowText(
            "ПЛАТФОРМА  " .. platNum .. " / " .. total,
            "SWUI.Body", cx, baseY + 22,
            Color(220, 235, 255, 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        local statusTxt = occupied and "ЗАНЯТА" or "СВОБОДНА"
        local statusCol = occupied and Color(220, 80, 80) or Color(60, 220, 120)
        ShadowText(statusTxt, "SWUI.Small", cx, baseY + 46,
            statusCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- ── Стиль кнопок ──────────────────────────────────────────
    local function MakeBtn(parent, text, x, y, w, h, col, onClick)
        local btn = vgui.Create("DPanel", parent)
        btn:SetPos(x, y) btn:SetSize(w, h) btn:SetCursor("hand")
        btn.Paint = function(self, bw, bh)
            local hov = self:IsHovered()
            local bg  = hov and Color(col.r*0.35, col.g*0.35, col.b*0.35, 220)
                             or Color(col.r*0.18, col.g*0.18, col.b*0.18, 200)
            draw.RoundedBox(6, 0, 0, bw, bh, bg)
            surface.SetDrawColor(hov and col or Color(col.r*0.55, col.g*0.55, col.b*0.55))
            surface.DrawOutlinedRect(0, 0, bw, bh, 1)
            draw.SimpleText(text, "SWUI.Small", bw/2, bh/2,
                hov and Color(255,255,255) or col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.OnMousePressed = function() if onClick then onClick() end end
        return btn
    end

    local btnH  = 38
    local btnY  = panH - btnH - 10
    local gap   = 8

    -- ← НАЗАД
    MakeBtn(bar, "◄", 10, btnY, 50, btnH, Color(0,150,220), function()
        self:_Prev()
    end)

    -- → ВПЕРЁД
    MakeBtn(bar, "►", 68, btnY, 50, btnH, Color(0,150,220), function()
        self:_Next()
    end)

    -- ВЫЗВАТЬ СЮДА
    MakeBtn(bar, "ВЫЗВАТЬ СЮДА", 130, btnY, 340, btnH, Color(60, 200, 100), function()
        self:_Confirm()
    end)

    -- ОТМЕНА
    MakeBtn(bar, "ОТМЕНА", 480, btnY, panW - 480 - 10, btnH, Color(200, 80, 60), function()
        self:Exit()
    end)

    -- Подсказка клавиши Esc
    local hint = vgui.Create("DLabel", root)
    hint:SetText("[ESC] — отмена")
    hint:SetFont("SWUI.Tiny")
    hint:SetTextColor(Color(120, 140, 160))
    hint:SizeToContents()
    hint:SetPos(panX + panW - hint:GetWide() - 4, panY - hint:GetTall() - 4)
end

-- ============================================================================
-- Навигация между платформами
-- ============================================================================

function Cam:_Prev()
    if #self._platforms == 0 then return end
    self._current = self._current - 1
    if self._current < 1 then self._current = #self._platforms end
    self._angle = 0   -- сбрасываем угол для плавного старта
end

function Cam:_Next()
    if #self._platforms == 0 then return end
    self._current = self._current + 1
    if self._current > #self._platforms then self._current = 1 end
    self._angle = 0
end

-- ============================================================================
-- Подтверждение спавна
-- ============================================================================

function Cam:_Confirm()
    local plat = self._platforms[self._current]
    if not plat then return end

    if plat.occupied then
        chat.AddText(Color(255,80,80), "[SWExp] ", Color(200,180,180),
            "Выбранная платформа занята — выберите другую.")
        return
    end

    if not IsValid(self._spawner) then
        chat.AddText(Color(255,80,80), "[SWExp] ", Color(200,180,180),
            "Терминал недоступен.")
        self:Exit()
        return
    end

    net.Start("SWExp::CarDealer::SpawnOnPlatform")
        net.WriteEntity(self._spawner)
        net.WriteString(self._vehClass)
        net.WriteUInt(plat.index, 8)
    net.SendToServer()

    self:Exit()
end

-- ============================================================================
-- Орбитальная камера (CalcView)
-- ============================================================================

hook.Add("CalcView", "SWExp::PlatformCam_View", function(ply, origin, angles, fov)
    if not Cam._active then return end
    local plat = Cam._platforms[Cam._current]
    if not plat then return end

    local platPos = Vector(plat.pos.x, plat.pos.y, plat.pos.z)

    -- Обновляем угол орбиты
    Cam._angle = (Cam._angle + ORBIT_SPEED * FrameTime()) % 360
    local rad  = math.rad(Cam._angle)

    local camPos = platPos + Vector(
        math.cos(rad) * ORBIT_RADIUS,
        math.sin(rad) * ORBIT_RADIUS,
        ORBIT_HEIGHT
    )

    -- Смотрим в точку чуть выше центра платформы
    local target  = platPos + Vector(0, 0, 60)
    local lookDir = (target - camPos):GetNormalized()
    local camAng  = lookDir:Angle()

    return {
        origin     = camPos,
        angles     = camAng,
        fov        = CAM_FOV,
        drawviewer = false,
    }
end)

-- ============================================================================
-- Скрытие HUD в режиме камеры
-- ============================================================================

hook.Add("HUDShouldDraw", "SWExp::PlatformCam_HideHUD", function(name)
    if Cam._active then return false end
end)

-- ============================================================================
-- Блокировка движения игрока в режиме камеры
-- ============================================================================

hook.Add("CreateMove", "SWExp::PlatformCam_BlockMove", function(cmd)
    if not Cam._active then return end
    cmd:ClearButtons()
    cmd:ClearMovement()
end)

-- ============================================================================
-- ESC закрывает режим
-- ============================================================================

hook.Add("OnGamemodeLoaded", "SWExp::PlatformCam_EscKey", function()
    -- Отслеживаем нажатие ESC через Think
end)

hook.Add("Think", "SWExp::PlatformCam_EscapeCheck", function()
    if not Cam._active then return end
    if input.IsKeyDown(KEY_ESCAPE) then
        Cam:Exit()
    end
end)

-- ============================================================================
-- 3D-подсветка выбранной платформы
-- ============================================================================

hook.Add("PostDrawOpaqueRenderables", "SWExp::PlatformCam_Highlight", function()
    if not Cam._active then return end

    for i, plat in ipairs(Cam._platforms) do
        local pos  = Vector(plat.pos.x, plat.pos.y, plat.pos.z)
        local isCur = (i == Cam._current)

        -- Рисуем ореол над платформой
        local col = plat.occupied and Color(220, 60, 60, 180)
                 or (isCur and Color(60, 220, 120, 220) or Color(0, 120, 200, 100))

        render.SetColorMaterial()

        -- Вертикальный луч
        for h = 0, 120, 20 do
            local alpha = 180 - h * 1.2
            render.DrawBox(
                pos + Vector(0,0,h), Angle(0,0,0),
                Vector(-4,-4,0), Vector(4,4,8),
                Color(col.r, col.g, col.b, isCur and alpha or alpha * 0.4)
            )
        end
    end
end)

-- ============================================================================
-- Получение данных платформ от сервера
-- ============================================================================

net.Receive("SWExp::CarDealer::PlatformData", function()
    local vClass = net.ReadString()
    local json   = net.ReadString()
    local data   = util.JSONToTable(json) or {}

    -- Восстанавливаем Vector/Angle из таблиц (JSON не умеет Vector)
    local platforms = {}
    for _, p in ipairs(data) do
        table.insert(platforms, {
            index    = p.index,
            pos      = Vector(p.pos.x, p.pos.y, p.pos.z),
            ang      = Angle(p.ang.p, p.ang.y, p.ang.r),
            occupied = p.occupied or false,
        })
    end

    -- Сохраняем ссылку на терминал — берём ближайший к игроку
    local spawner = nil
    local bestDist = math.huge
    for _, ent in ipairs(ents.FindByClass("swexp_carspawner")) do
        local d = LocalPlayer():GetPos():Distance(ent:GetPos())
        if d < bestDist then bestDist = d spawner = ent end
    end

    Cam:Enter(platforms, vClass, spawner)
end)

print("[SWExp] Модуль камеры платформ (клиент) загружен.")
