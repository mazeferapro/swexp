--[[--
    SWExp: Тировый портал (swexp_tiered_gateway)

    АРХИТЕКТУРА:
    ═══════════════════════════════════════════════════════════
    Состояние портала разделено на ДВА независимых уровня:

    1. СВЯЗЬ (LinkedTo / NetworkVar Entity 2)
       — Постоянная. Устанавливается админом в меню.
       — Не пропадает после прохода игрока.
       — Обе стороны знают друг о друге: A.LinkedTo = B, B.LinkedTo = A

    2. АНИМАЦИЯ (CurrentState + двери swexp_tiered_door)
       — Временная. Запускается когда игрок с ключом жмёт E.
       — Цикл: CLOSED → OPENING (3.2с) → OPEN → [игрок входит] → CLOSING → CLOSED
       — После закрытия двери удаляются, но LinkedTo остаётся нетронутым.

    ИТОГ: Админ настраивает раз и навсегда. Игроки ходят сколько угодно раз.
    ═══════════════════════════════════════════════════════════

    Цвета тиров: 1=Зелёный  2=Синий  3=Оранжевый  4=Красный
]]--

AddCSLuaFile()

DEFINE_BASECLASS("base_gmodentity")
ENT.Type               = "anim"
ENT.Base               = "base_anim"
ENT.PrintName          = "SWExp Tiered Portal"
ENT.Category           = "SWExp Entities"
ENT.Spawnable          = true
ENT.AdminOnly          = true
ENT.AutomaticFrameAdvance = true

-- ============================================================================
-- КОНСТАНТЫ
-- ============================================================================

local STATE_CLOSED  = 0
local STATE_OPENING = 1
local STATE_OPEN    = 2
local STATE_CLOSING = 3

local TIER_COLORS = {
    [1] = Color(0,   220,  50),
    [2] = Color(50,  100, 255),
    [3] = Color(255, 140,   0),
    [4] = Color(220,  30,  30),
}

local TIER_NAMES = {
    [1] = "ТИР I  —  ПЕРИМЕТР",
    [2] = "ТИР II  —  ВНЕШНИЙ РУБЕЖ",
    [3] = "ТИР III  —  АНОМАЛЬНЫЙ СЕКТОР",
    [4] = "ТИР IV  —  СЕРДЦЕ ТЬМЫ",
}

local TIER_KEYS = {
    [1] = "key_tier1",
    [2] = "key_tier2",
    [3] = "key_tier3",
    [4] = "key_tier4",
}

-- ============================================================================
-- ГЛОБАЛЬНЫЙ ИНДЕКС ПОРТАЛОВ (SERVER) — по тирам
-- ============================================================================

local gpi = {}

if SERVER then
    gpi.INDEX     = gpi.INDEX or { [1]={}, [2]={}, [3]={}, [4]={} }
    gpi.MAX_CODES = 9 * 9 * 9

    function gpi.GetPortalByCode(tier, code)
        local n = tonumber(code)
        if not n or not gpi.INDEX[tier] then return nil end
        local ent = gpi.INDEX[tier][n]
        if IsValid(ent) then return ent end
        gpi.INDEX[tier][n] = nil
        return nil
    end

    function gpi.GeneratePortalCode(tier, ent)
        if not IsValid(ent) or not gpi.INDEX[tier] then return nil end
        if table.Count(gpi.INDEX[tier]) >= gpi.MAX_CODES then return nil end

        for _ = 1, 128 do
            local code = tonumber(
                tostring(math.random(1,9)) ..
                tostring(math.random(1,9)) ..
                tostring(math.random(1,9))
            )
            if not gpi.INDEX[tier][code] then
                gpi.INDEX[tier][code] = ent
                return code
            end
        end

        for i = 111, 999 do
            local s = tostring(i)
            if not string.find(s, "0", 1, true) then
                local n = tonumber(s)
                if not gpi.INDEX[tier][n] then
                    gpi.INDEX[tier][n] = ent
                    return n
                end
            end
        end
        return nil
    end

    function gpi.RemovePortalCode(tier, code)
        local n = tonumber(code)
        if not n or not gpi.INDEX[tier] then return false end
        if gpi.INDEX[tier][n] then
            gpi.INDEX[tier][n] = nil
            return true
        end
        return false
    end
end

-- ============================================================================
-- СЕТЕВЫЕ СТРОКИ
-- ============================================================================

if SERVER then
    util.AddNetworkString("SWExpPortal_OpenAdminMenu")
    util.AddNetworkString("SWExpPortal_SaveSettings")
    util.AddNetworkString("SWExpPortal_UseResult")
end

-- ============================================================================
-- СЕРВЕРНЫЕ ОБРАБОТЧИКИ
-- ============================================================================

local PlayerHasTierKey  -- объявляем заранее, определяем только на сервере

if SERVER then

    PlayerHasTierKey = function(pPlayer, tier)
        local keyID = TIER_KEYS[tier]
        if not keyID then return false end
        if not SWExp or not SWExp.Inventory then return false end

        local charID = SWExp.Inventory:GetCharacterID(pPlayer)
        if not charID then return false end

        local steamID   = pPlayer:SteamID64()
        local invData   = SWExp.Inventory.PlayerInventories[steamID]
        if not invData then return false end

        local playerInv = invData[charID]
        if not playerInv or not playerInv.items then return false end

        for _, item in pairs(playerInv.items) do
            if item.itemID == keyID then return true end
        end
        return false
    end

    -- ── Сохранить настройки из меню ──────────────────────────────────────────
    net.Receive("SWExpPortal_SaveSettings", function(len, ply)
        if not IsValid(ply) then return end
        if not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
        if SWExp and SWExp.Net and SWExp.Net.RateCheck then
            if not SWExp.Net:RateCheck(ply, "PortalSaveSettings") then return end
        end

        local ent      = net.ReadEntity()
        local newTier  = net.ReadInt(8)
        local linkCode = net.ReadString()
        if linkCode and #linkCode > 16 then return end

        if not IsValid(ent) or ent:GetClass() ~= "swexp_tiered_gateway" then return end

        -- Если портал сейчас открыт — закрыть анимацию перед изменением
        if ent:GetCurrentState() ~= STATE_CLOSED then
            ent:CloseAnimation()
        end

        -- Смена тира (сбрасывает старую связь)
        newTier = math.Clamp(newTier, 1, 4)
        if newTier ~= ent:GetTier() then
            ent:AdminUnlink()
            ent:ChangeTier(newTier)
        end

        -- Установить новую связь или разорвать
        local trimmedCode = string.Trim(linkCode)
        if trimmedCode ~= "" then
            local other = gpi.GetPortalByCode(ent:GetTier(), trimmedCode)
            if not IsValid(other) then
                ply:ChatPrint(string.format("[Portal] Портал с кодом %s (Тир %d) не найден.", trimmedCode, ent:GetTier()))
            elseif other == ent then
                ply:ChatPrint("[Portal] Нельзя связать портал с самим собой.")
            elseif IsValid(other:GetLinkedTo()) and other:GetLinkedTo() ~= ent then
                ply:ChatPrint(string.format("[Portal] Портал %s уже связан с другим порталом.", trimmedCode))
            else
                ent:AdminLink(other)
                ply:ChatPrint(string.format("[Portal] Портал %d (Тир %d) связан с %s.", ent:GetCode(), ent:GetTier(), trimmedCode))
            end
        else
            -- Пустой код → разорвать связь
            if IsValid(ent:GetLinkedTo()) then
                ent:AdminUnlink()
                ply:ChatPrint("[Portal] Связь разорвана.")
            end
        end
    end)

end

-- ============================================================================
-- ENTITY: DATA TABLES
-- ============================================================================

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:SetupDataTables()
    self:NetworkVar("Int",    0, "CurrentState")  -- анимационное состояние
    self:NetworkVar("Float",  0, "LastUsed")
    self:NetworkVar("Entity", 0, "PortalEnt")     -- активная дверь 1
    self:NetworkVar("Entity", 1, "PortalEnt2")    -- активная дверь 2
    self:NetworkVar("Entity", 2, "LinkedTo")      -- ПОСТОЯННАЯ связь
    self:NetworkVar("Int",    1, "Code")
    self:NetworkVar("Int",    2, "Tier")
end

function ENT:GravGunPickupAllowed() return false end
function ENT:GravGunPuntAllowed()   return false end

-- Только администраторы могут двигать портал физганом
function ENT:PhysgunPickup(ply)
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

function ENT:Initialize()
    self:SetModel("models/helios/props/rep_portal.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCurrentState(STATE_CLOSED)
    self:SetAngles(self:GetAngles() + Angle(0, 90, 0))

    if SERVER then
        local tier = self:GetTier()
        if tier < 1 or tier > 4 then
            self:SetTier(1)
            tier = 1
        end
        local code = gpi.GeneratePortalCode(tier, self)
        self:SetCode(code or 0)
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)  -- по умолчанию заморожен
        phys:SetMass(50000)
    end
end

-- Включаем физику при подхвате физганом
if SERVER then
    hook.Add("PhysgunPickup", "SWExp::PortalPhysgunPickup", function(ply, ent)
        if not IsValid(ent) or ent:GetClass() ~= "swexp_tiered_gateway" then return end
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(true) end
    end)

    -- Замораживаем и сохраняем позицию при отпускании
    hook.Add("PhysgunDrop", "SWExp::PortalPhysgunDrop", function(ply, ent)
        if not IsValid(ent) or ent:GetClass() ~= "swexp_tiered_gateway" then return end
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:SetVelocity(Vector(0,0,0))
            phys:SetAngleVelocity(Vector(0,0,0))
        end
        -- Сохраняем только если портал связан с другим
        if IsValid(ent:GetLinkedTo()) and SWExp and SWExp.SavePortals then
            SWExp.SavePortals()
            ply:ChatPrint("[Portal] Портал перемещён и сохранён.")
        else
            ply:ChatPrint("[Portal] Портал перемещён. Свяжите его и сохраните через swexp_save_portals.")
        end
    end)
end

-- ============================================================================
-- СВЯЗЬ: AdminLink / AdminUnlink
-- Постоянная — не затрагивает анимацию и двери
-- ============================================================================

-- silent=true используется при загрузке с диска, чтобы не триггерить лишнее сохранение
function ENT:AdminLink(other, silent)
    if not IsValid(other) then return end
    -- Разрываем предыдущие связи обоих порталов
    local myOld    = self:GetLinkedTo()
    local otherOld = other:GetLinkedTo()
    if IsValid(myOld)    and myOld    ~= other then myOld:SetLinkedTo(NULL)    end
    if IsValid(otherOld) and otherOld ~= self   then otherOld:SetLinkedTo(NULL) end

    self:SetLinkedTo(other)
    other:SetLinkedTo(self)

    -- Автосохранение после связывания (не при загрузке)
    if SERVER and not silent and SWExp and SWExp.SavePortals then
        SWExp.SavePortals()
    end
end

function ENT:AdminUnlink()
    local partner = self:GetLinkedTo()
    if IsValid(partner) then
        partner:CloseAnimation()
        partner:SetLinkedTo(NULL)
    end
    self:CloseAnimation()
    self:SetLinkedTo(NULL)

    -- Автосохранение после разрыва связи
    if SERVER and SWExp and SWExp.SavePortals then
        SWExp.SavePortals()
    end
end

-- ============================================================================
-- СМЕНА ТИРА (публичный метод для загрузки из файла)
-- ============================================================================

-- SetTierAdmin: устанавливает тир без проверки прав (вызывается при загрузке)
function ENT:SetTierAdmin(newTier)
    if newTier < 1 or newTier > 4 then return end
    if newTier == self:GetTier() then return end
    local oldTier = self:GetTier()
    local oldCode = self:GetCode()
    gpi.RemovePortalCode(oldTier, oldCode)
    self:SetTier(newTier)
    local newCode = gpi.GeneratePortalCode(newTier, self)
    self:SetCode(newCode or 0)
end

function ENT:ChangeTier(newTier)
    self:SetTierAdmin(newTier)
end

-- ============================================================================
-- USE: нажатие E
-- ============================================================================

if SERVER then
    function ENT:Use(activator, caller)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        -- Rate-limit через глобальный модуль (если загружен)
        if SWExp and SWExp.Net and SWExp.Net.RateCheck then
            if not SWExp.Net:RateCheck(activator, "PortalUse") then return end
        else
            -- Fallback на локальный кулдаун
            local sid = activator:SteamID64()
            self._useCD = self._useCD or {}
            if self._useCD[sid] and (CurTime() - self._useCD[sid]) < 1 then return end
            self._useCD[sid] = CurTime()
        end

        local isAdmin  = activator:IsAdmin() or activator:IsSuperAdmin()
        local curState = self:GetCurrentState()

        -- ── Если портал уже открывается/открыт — просто сообщаем ──────────────
        if curState == STATE_OPEN or curState == STATE_OPENING then
            net.Start("SWExpPortal_UseResult")
                net.WriteInt(0, 8)
            net.Send(activator)
            return
        end

        if curState ~= STATE_CLOSED then return end

        local partner = self:GetLinkedTo()

        -- ── Администратор без связанного портала → открыть меню настроек ──────
        if isAdmin and not IsValid(partner) then
            net.Start("SWExpPortal_OpenAdminMenu")
                net.WriteEntity(self)
                net.WriteInt(self:GetTier(), 8)
                net.WriteInt(self:GetCode(), 32)
                net.WriteString("")
                net.WriteBool(false)
            net.Send(activator)
            return
        end

        -- ── Все (включая админов) — проверка связи и ключа ───────────────────
        if not IsValid(partner) then
            net.Start("SWExpPortal_UseResult")
                net.WriteInt(2, 8)  -- не связан
            net.Send(activator)
            return
        end

        local tier = self:GetTier()
        if not PlayerHasTierKey(activator, tier) then
            net.Start("SWExpPortal_UseResult")
                net.WriteInt(1, 8)  -- нет ключа
            net.Send(activator)
            return
        end

        -- Всё ок — открываем
        self:OpenAnimation()
        partner:OpenAnimation()
    end
end

-- ============================================================================
-- КОНСОЛЬНАЯ КОМАНДА ДЛЯ ОТКРЫТИЯ МЕНЮ НАСТРОЕК (для смотрящего на портал)
-- Использование: swexp_portal_menu
-- ============================================================================

if SERVER then
    util.AddNetworkString("SWExpPortal_OpenAdminMenuCmd")

    concommand.Add("swexp_portal_menu", function(ply, cmd, args)
        if not IsValid(ply) then return end
        if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
            ply:ChatPrint("[Portal] Только администратор.")
            return
        end

        local tr  = ply:GetEyeTraceNoCursor()
        local ent = tr.Entity
        if not IsValid(ent) or ent:GetClass() ~= "swexp_tiered_gateway" then
            ply:ChatPrint("[Portal] Смотрите на портал (swexp_tiered_gateway).")
            return
        end

        local partner    = ent:GetLinkedTo()
        local linkedCode = IsValid(partner) and tostring(partner:GetCode()) or ""
        net.Start("SWExpPortal_OpenAdminMenu")
            net.WriteEntity(ent)
            net.WriteInt(ent:GetTier(), 8)
            net.WriteInt(ent:GetCode(), 32)
            net.WriteString(linkedCode)
            net.WriteBool(ent:GetCurrentState() ~= STATE_CLOSED)
        net.Send(ply)
    end)
end

-- ============================================================================
-- АНИМАЦИЯ ОТКРЫТИЯ / ЗАКРЫТИЯ (временная, не трогает LinkedTo)
-- ============================================================================

local GATE_POSITION  = Vector(0,  2, 39)
local GATE2_POSITION = Vector(0, -2, 39)
local GATE_ANGLE     = Angle(0, 0, -90)
local GATE2_ANGLE    = Angle(0, 0,  90)

function ENT:GetTierColor()
    return TIER_COLORS[self:GetTier()] or TIER_COLORS[1]
end

function ENT:CreateDoors(partnerGateway)
    local c = self:GetTierColor()

    local ps  = ents.Create("swexp_tiered_door")
    local ps2 = ents.Create("swexp_tiered_door")
    local po  = ents.Create("swexp_tiered_door")
    local po2 = ents.Create("swexp_tiered_door")

    ps:SetPos(self:LocalToWorld(GATE_POSITION))
    ps:Spawn()
    ps:SetAngles(self:LocalToWorldAngles(GATE_ANGLE))
    ps:SetNotSolid(true)
    ps:SetColour(c)
    ps:SetParent(self)

    ps2:SetPos(self:LocalToWorld(GATE2_POSITION))
    ps2:Spawn()
    ps2:SetAngles(self:LocalToWorldAngles(GATE2_ANGLE))
    ps2:SetNotSolid(true)
    ps2:SetColour(c)
    ps2:SetParent(self)

    po:SetPos(partnerGateway:LocalToWorld(GATE_POSITION))
    po:Spawn()
    po:SetAngles(partnerGateway:LocalToWorldAngles(GATE_ANGLE))
    po:SetNotSolid(true)
    po:SetColour(c)
    po:SetParent(partnerGateway)

    po2:SetPos(partnerGateway:LocalToWorld(GATE2_POSITION))
    po2:Spawn()
    po2:SetAngles(partnerGateway:LocalToWorldAngles(GATE2_ANGLE))
    po2:SetNotSolid(true)
    po2:SetColour(c)
    po2:SetParent(partnerGateway)

    ps:SetOther(po)
    po:SetOther(ps)
    ps2:SetOther(po2)
    po2:SetOther(ps2)

    self:SetPortalEnt(ps)
    self:SetPortalEnt2(ps2)
    partnerGateway:SetPortalEnt(po)
    partnerGateway:SetPortalEnt2(po2)
end

function ENT:DestroyDoors()
    local p1 = self:GetPortalEnt()
    local p2 = self:GetPortalEnt2()
    if IsValid(p1) then p1:Disable() p1:Remove() end
    if IsValid(p2) then p2:Disable() p2:Remove() end
    self:SetPortalEnt(NULL)
    self:SetPortalEnt2(NULL)
end

function ENT:OpenAnimation()
    if self:GetCurrentState() ~= STATE_CLOSED then return end

    local partner = self:GetLinkedTo()

    -- Создаём двери только на стороне, которая инициирует открытие
    -- Обе стороны вызывают OpenAnimation независимо, поэтому двери создаём здесь
    if IsValid(partner) and partner:GetCurrentState() == STATE_CLOSED then
        self:CreateDoors(partner)
    end

    self:SetCurrentState(STATE_OPENING)
    self:SetLastUsed(CurTime())
    self:ResetSequence(self:LookupSequence("opening"))
    self:SetPlaybackRate(1)
    self:EmitSound("mvm/mvm_deploy_giant.wav")

    timer.Simple(1.9, function()
        if not IsValid(self) then return end
        if self:GetCurrentState() ~= STATE_OPENING then return end
        self:EmitSound("mvm/mvm_deploy_giant.wav")
    end)

    timer.Simple(3.2, function()
        if not IsValid(self) then return end
        if self:GetCurrentState() ~= STATE_OPENING then return end
        util.ScreenShake(self:GetPos(), 5, 1, 3, 700)
        self:EmitSound("mvm/mvm_revive.wav")
        self:SetCurrentState(STATE_OPEN)
        if IsValid(self:GetPortalEnt())  then self:GetPortalEnt():Enable()  end
        if IsValid(self:GetPortalEnt2()) then self:GetPortalEnt2():Enable() end
    end)
end

function ENT:CloseAnimation()
    local curState = self:GetCurrentState()
    if curState == STATE_CLOSED or curState == STATE_CLOSING then return end

    self:DestroyDoors()

    local sqid = self:LookupSequence("closing")
    self:SetCurrentState(STATE_CLOSING)
    self:SetLastUsed(CurTime())
    self:ResetSequence(sqid)
    self:SetPlaybackRate(1)

    timer.Simple(self:SequenceDuration(sqid), function()
        if not IsValid(self) then return end
        self:SetCurrentState(STATE_CLOSED)
    end)
end

-- Вызывается из swexp_tiered_door после телепортации игрока
-- Закрывает анимацию обоих порталов — НО НЕ ТРОГАЕТ LinkedTo
function ENT:OnPlayerTeleported()
    local partner = self:GetLinkedTo()
    self:CloseAnimation()
    if IsValid(partner) then
        partner:CloseAnimation()
    end
end

function ENT:Think()
    self:FrameAdvance()
    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    if SERVER then
        -- Разрываем связь с партнёром
        local partner = self:GetLinkedTo()
        if IsValid(partner) then
            partner:SetLinkedTo(NULL)
        end
        gpi.RemovePortalCode(self:GetTier(), self:GetCode())
    end
end

-- ============================================================================
-- КЛИЕНТСКИЙ РЕНДЕР
-- ============================================================================

if CLIENT then

    local function GetTierColor(tier)
        return TIER_COLORS[tier] or TIER_COLORS[1]
    end

    -- Шрифты для 3D2D-панели (фиксированный размер, Exo 2)
    surface.CreateFont("SWExpPortal_Tiny",   { font = "Exo 2", size = 11, weight = 500, extended = true })
    surface.CreateFont("SWExpPortal_Small",  { font = "Exo 2", size = 14, weight = 600, extended = true })
    surface.CreateFont("SWExpPortal_Medium", { font = "Exo 2", size = 18, weight = 700, extended = true })
    surface.CreateFont("SWExpPortal_Large",  { font = "Exo 2", size = 24, weight = 800, extended = true })

    -- ──────────────────────────────────────────────────────────────────────────
    -- 3D2D-ПАНЕЛЬКА НА МОДЕЛИ (для всех игроков + админов)
    -- ──────────────────────────────────────────────────────────────────────────

    -- Позиция экрана на модели.
    -- Y=-47.75 = центр оригинальной панели (левый край был -50, ширина 150px*0.03=4.5ед, центр=-47.75)
    -- ox=-PW/2 рисует новую панель симметрично вокруг этого центра
    local PANEL_POS    = Vector(0, -47.75, 49)
    local PANEL_ANGLES = Angle(0, 0, 45)
    local PANEL_SCALE  = 0.03

    -- Размеры панели в пикселях 3D2D
    -- При PW=150 (оригинал) якорь Y=-50 центрирует панель на экране модели.
    -- При PW=260 нужно сдвинуть якорь влево на (260-150)*scale/2 пикс.
    -- Но проще: рисуем от (-PW/2) чтобы центр всегда был в якоре,
    -- и ставим PANEL_POS.y = -50 + 75*0.03 = -47.75 (середина старой панели)
    -- Итого: ox = смещение X в 3D2D-пространстве = -PW/2
    local PW, PH = 260, 170
    -- Центрирование: якорь стоит там где был центр оригинальной панели (150/2*0.03=2.25 от левого края)
    -- Новый левый край: ox = -(PW/2) в пикселях
    local ox = -(PW / 2)

    -- Цвета UI
    local C_BG       = Color(10, 14, 20, 210)
    local C_TEXT_DIM = Color(120, 150, 180, 200)
    local C_WHITE    = Color(220, 235, 255, 255)

    -- Отслеживаем hover-состояние кнопки на каждой entity
    -- [entIndex] = float 0..1
    local _btnHov = {}

    -- Последний трейс мыши для определения hover на 3D2D-кнопке
    -- Обновляется в Think, не в Draw (чтобы не нагружать рендер)
    local _lastHovEnt = nil

    hook.Add("Think", "SWExp::PortalPanelHover", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if vgui.CursorVisible() then return end

        local tr = lp:GetEyeTraceNoCursor()
        local ent = tr.Entity

        if IsValid(ent) and ent:GetClass() == "swexp_tiered_gateway" then
            _lastHovEnt = ent
        else
            _lastHovEnt = nil
        end

        -- Плавный hover
        for _, gw in ipairs(ents.FindByClass("swexp_tiered_gateway")) do
            if not IsValid(gw) then continue end
            local idx     = gw:EntIndex()
            local target  = (gw == _lastHovEnt) and 1 or 0
            local current = _btnHov[idx] or 0
            _btnHov[idx]  = Lerp(FrameTime() * 8, current, target)
        end
    end)

    function ENT:Draw()
        self:DrawModel()

        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        -- Показываем панельку только в радиусе взаимодействия
        local dist = lp:GetPos():Distance(self:GetPos())
        if dist > 300 then return end

        local tier    = self:GetTier()
        local state   = self:GetCurrentState()
        local col     = GetTierColor(tier)
        local tierLbl = TIER_NAMES[tier] or ("ТИР " .. tier)
        local isAdmin = lp:IsAdmin() or lp:IsSuperAdmin()
        local idx     = self:EntIndex()
        local hov     = _btnHov[idx] or 0

        -- Определяем текст и цвет кнопки / статуса
        local btnLabel, btnR, btnG, btnB
        local showBtn = false

        if state == STATE_OPEN or state == STATE_OPENING then
            btnLabel = "УЖЕ ОТКРЫТ"
            btnR, btnG, btnB = 40, 180, 60
        elseif state == STATE_CLOSING then
            btnLabel = "ЗАКРЫВАЕТСЯ..."
            btnR, btnG, btnB = 160, 120, 40
        else
            -- STATE_CLOSED
            local linked = IsValid(self:GetLinkedTo())
            if linked then
                btnLabel = isAdmin and "ОТКРЫТЬ" or "ОТКРЫТЬ"
                btnR, btnG, btnB = col.r, col.g, col.b
                showBtn = true
            else
                btnLabel = "НЕ НАСТРОЕН"
                btnR, btnG, btnB = 100, 100, 100
            end
        end

        cam.Start3D2D(self:LocalToWorld(PANEL_POS), self:LocalToWorldAngles(PANEL_ANGLES), PANEL_SCALE)

            -- Фон панели. ox = -PW/2, якорь = центр панели по X.
            surface.SetDrawColor(C_BG.r, C_BG.g, C_BG.b, C_BG.a)
            surface.DrawRect(ox, 0, PW, PH)
            surface.SetDrawColor(btnR, btnG, btnB, 160)
            surface.DrawOutlinedRect(ox, 0, PW, PH, 2)

            -- Заголовок (X=0 = центр т.к. TEXT_ALIGN_CENTER)
            draw.SimpleText("ТИРОВЫЙ ПОРТАЛ", "SWExpPortal_Small", 0, 8,
                C_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            -- Разделитель
            surface.SetDrawColor(btnR, btnG, btnB, 80)
            surface.DrawRect(ox + 6, 24, PW - 12, 1)

            -- Название тира
            draw.SimpleText(tierLbl, "SWExpPortal_Medium", 0, 32,
                Color(btnR, btnG, btnB, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

            -- Для админов — код и код партнёра
            if isAdmin then
                local partner  = self:GetLinkedTo()
                local partCode = IsValid(partner) and tostring(partner:GetCode()) or "---"
                draw.SimpleText("КОД: " .. tostring(self:GetCode()), "SWExpPortal_Small",
                    0, 58, C_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                draw.SimpleText("СВЯЗАН: " .. partCode, "SWExpPortal_Small",
                    0, 76, C_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

            -- Разделитель перед кнопкой
            local btnY = isAdmin and 102 or 66
            surface.SetDrawColor(btnR, btnG, btnB, 60)
            surface.DrawRect(ox + 6, btnY - 8, PW - 12, 1)

            -- Кнопка ОТКРЫТЬ (или статус)
            local btnAlpha     = showBtn and (160 + hov * 80) or 100
            local btnTextAlpha = showBtn and (200 + hov * 55) or 140
            draw.RoundedBox(4, ox + 8, btnY, PW - 16, 44, Color(btnR * 0.15, btnG * 0.15, btnB * 0.15, 200))
            surface.SetDrawColor(btnR, btnG, btnB, btnAlpha)
            surface.DrawOutlinedRect(ox + 8, btnY, PW - 16, 44, showBtn and (1 + math.Round(hov)) or 1)

            if showBtn and hov > 0.05 then
                surface.SetDrawColor(btnR, btnG, btnB, math.Round(hov * 30))
                surface.DrawRect(ox + 9, btnY + 1, PW - 18, 42)
            end

            draw.SimpleText(btnLabel, "SWExpPortal_Large", 0, btnY + 22,
                Color(btnR, btnG, btnB, btnTextAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if showBtn then
                draw.SimpleText("[E] открыть", "SWExpPortal_Tiny", 0, btnY + 52,
                    C_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

            if isAdmin then
                draw.SimpleText("swexp_portal_menu — настройки", "SWExpPortal_Tiny", 0, PH - 14,
                    Color(80, 110, 140, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

        cam.End3D2D()
    end

    -- ──────────────────────────────────────────────────────────────────────────
    -- 3D2D-МЕТКА НАД ПОРТАЛОМ (только для администраторов)
    -- Показывает расширенную информацию: код, связь, статус — в радиусе 800 ед.
    -- ──────────────────────────────────────────────────────────────────────────

    hook.Add("PostDrawOpaqueRenderables", "SWExp::TieredPortalAdminLabel", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if not (lp:IsAdmin() or lp:IsSuperAdmin()) then return end

        local eyeY  = EyeAngles().y
        local lpPos = lp:GetPos()

        for _, ent in ipairs(ents.FindByClass("swexp_tiered_gateway")) do
            if not IsValid(ent) then continue end

            local dist = lpPos:Distance(ent:GetPos())
            if dist > 900 then continue end

            local fade = math.Clamp(1 - (dist - 250) / 650, 0, 1)
            if fade < 0.02 then continue end

            local tier    = ent:GetTier()
            local state   = ent:GetCurrentState()
            local col     = GetTierColor(tier)
            local tierLbl = TIER_NAMES[tier] or ("ТИР " .. tier)

            local stateStr, stateCol
            if state == STATE_OPEN then
                stateStr = "ОТКРЫТ"
                stateCol = Color(80, 255, 80)
            elseif state == STATE_OPENING then
                stateStr = "ОТКРЫВАЕТСЯ..."
                stateCol = Color(255, 220, 60)
            elseif state == STATE_CLOSING then
                stateStr = "ЗАКРЫВАЕТСЯ..."
                stateCol = Color(200, 140, 40)
            else
                local linked = IsValid(ent:GetLinkedTo())
                stateStr = linked and "ГОТОВ" or "НЕ НАСТРОЕН"
                stateCol = linked and Color(160, 220, 255) or Color(160, 160, 160)
            end

            local a255 = math.Round(255 * fade)
            local a200 = math.Round(200 * fade)
            local a150 = math.Round(150 * fade)
            local a120 = math.Round(120 * fade)

            cam.Start3D2D(ent:GetPos() + Vector(0, 0, 60), Angle(0, eyeY - 90, 90), 0.10)
                local bw, bh = 310, 92
                local bx, by = -bw/2, -bh/2

                draw.RoundedBox(6, bx,   by,   bw, bh, Color(6, 11, 18, math.Round(210 * fade)))
                draw.RoundedBox(3, bx+3, by+8, 3, bh - 16, Color(col.r, col.g, col.b, a255))
                surface.SetDrawColor(col.r, col.g, col.b, a120)
                surface.DrawOutlinedRect(bx, by, bw, bh, 2)

                -- Строка 1: тир
                draw.SimpleText("ПОРТАЛ  " .. tierLbl, "SWUI.Small",
                    0, by + 8, Color(col.r, col.g, col.b, a255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                -- Строка 2: статус
                draw.SimpleText(stateStr, "SWUI.Tiny",
                    0, by + 30, Color(stateCol.r, stateCol.g, stateCol.b, a200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                -- Строка 3: код и связь
                local partner   = ent:GetLinkedTo()
                local linkedTxt = IsValid(partner) and ("→ " .. partner:GetCode()) or "не связан"
                draw.SimpleText(
                    string.format("Код: %d   %s", ent:GetCode(), linkedTxt),
                    "SWUI.Tiny", 0, by + 50,
                    Color(160, 185, 210, a200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                -- Строка 4: подсказка
                local adminHint = IsValid(ent:GetLinkedTo())
                    and "[E] открыть  |  swexp_portal_menu — настройки"
                    or  "[E] открыть меню настроек"
                draw.SimpleText(adminHint,
                    "SWUI.Tiny", 0, by + 68,
                    Color(100, 140, 170, a150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                -- Номер entity
                draw.SimpleText(string.format("#%d", ent:EntIndex()),
                    "SWUI.Tiny", bx + bw - 8, by + bh - 14,
                    Color(80, 110, 140, a150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            cam.End3D2D()
        end
    end)

    -- ──────────────────────────────────────────────────────────────────────────
    -- Уведомление о результате нажатия E
    -- ──────────────────────────────────────────────────────────────────────────

    net.Receive("SWExpPortal_UseResult", function()
        local code = net.ReadInt(8)
        local msgs = {
            [0] = { "Портал уже открывается — зайди в него.",       Color(160, 200, 255) },
            [1] = { "У вас нет ключа для этого портала!",            Color(255,  80,  80) },
            [2] = { "Этот портал не настроен администратором.",       Color(200, 180,  80) },
        }
        local m = msgs[code]
        if m then
            if chat and chat.AddText then
                chat.AddText(Color(80, 180, 255), "[Portal] ", m[2], m[1])
            end
        end
    end)

end

-- ============================================================================
-- SERVER: Очистка _useCD таблиц при выходе игрока (защита от утечек памяти)
-- ============================================================================

if SERVER then
    hook.Add("PlayerDisconnected", "SWExpPortal_UseCDCleanup", function(ply)
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()
        if not sid then return end
        for _, ent in ipairs(ents.FindByClass("swexp_tiered_gateway")) do
            if IsValid(ent) and istable(ent._useCD) then
                ent._useCD[sid] = nil
            end
        end
    end)
end
