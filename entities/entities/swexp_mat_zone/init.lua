-- ============================================================
-- Star Wars: Expedition — Зона добычи материалов (сервер)
-- entities/swexp_mat_zone/init.lua
--
-- Спавнится через Q-menu администратором.
-- USE (E) на кубе → меню настройки (тир, радиус, респавн).
-- Периодически спавнит swexp_material_node внутри радиуса.
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local CUBE_MODEL = "models/hunter/blocks/cube025x025x025.mdl"

-- ============================================================
-- Инициализация
-- ============================================================

function ENT:Initialize()
    self:SetModel(CUBE_MODEL)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:DrawShadow(false)
    -- Игроки проходят сквозь куб, но трейс USE всё равно попадает на него
    self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:EnableGravity(false)
        phys:SetMass(1)
    end

    -- Берём дефолтные значения тира 1 из конфига
    local tier    = 1
    local tierCfg = SWExp.ZoneConfig and SWExp.ZoneConfig.GetTier(tier)

    local radius  = tierCfg and tierCfg.radius      or 600
    local maxMat  = tierCfg and tierCfg.maxMat      or 5
    local rspTime = tierCfg and tierCfg.respawnTime  or 90
    local col     = tierCfg and tierCfg.color        or Color(80, 200, 100)

    -- NW переменные (читаются клиентом для рендера и меню)
    self:SetNWInt("SWExp_ZoneTier",     tier)
    self:SetNWInt("SWExp_ZoneRadius",   radius)
    self:SetNWInt("SWExp_ZoneRespawn",  rspTime)
    self:SetNWInt("SWExp_ZoneMaxCount", maxMat)
    self:SetNWInt("SWExp_ColorR",       col.r)
    self:SetNWInt("SWExp_ColorG",       col.g)
    self:SetNWInt("SWExp_ColorB",       col.b)

    -- Локальное состояние
    self._tier     = tier
    self._radius   = radius
    self._maxMat   = maxMat
    self._respawn  = rspTime
    self._matNodes = {}

    -- Первый цикл спавна
    timer.Simple(3, function()
        if IsValid(self) then self:SpawnCycle() end
    end)

    print(string.format("[SWExp] Mat-зона #%d создана: Тир=%d R=%d T=%ds",
        self:EntIndex(), tier, radius, rspTime))
end

-- ============================================================
-- Применить новые настройки (вызывается из sv_zones.lua)
-- ============================================================

function ENT:ApplySettings(tier, radius, respawn, maxCount)
    tier     = math.Clamp(tier,    1, 4)
    radius   = math.Clamp(radius,  100, 3000)
    respawn  = math.Clamp(respawn, 10,  600)

    local tierCfg    = SWExp.ZoneConfig and SWExp.ZoneConfig.GetTier(tier)
    local defaultMax = tierCfg and tierCfg.maxMat or 5
    local col        = tierCfg and tierCfg.color  or Color(80, 200, 100)

    -- Если maxCount передан явно — используем его, иначе берём из конфига тира
    local maxMat = maxCount and math.Clamp(maxCount, 1, 30) or defaultMax

    self._tier    = tier
    self._radius  = radius
    self._maxMat  = maxMat
    self._respawn = respawn

    self:SetNWInt("SWExp_ZoneTier",     tier)
    self:SetNWInt("SWExp_ZoneRadius",   radius)
    self:SetNWInt("SWExp_ZoneRespawn",  respawn)
    self:SetNWInt("SWExp_ZoneMaxCount", maxMat)
    self:SetNWInt("SWExp_ColorR",       col.r)
    self:SetNWInt("SWExp_ColorG",       col.g)
    self:SetNWInt("SWExp_ColorB",       col.b)

    timer.Remove("SWExp::MatZone_" .. self:EntIndex())
    for _, e in ipairs(self._matNodes) do
        if IsValid(e) then e:Remove() end
    end
    self._matNodes = {}

    timer.Simple(2, function()
        if IsValid(self) then self:SpawnCycle() end
    end)
end

-- ============================================================
-- USE: открыть меню настройки для администратора
-- ============================================================

function ENT:Use(activator, caller)
    if not IsValid(activator) then return end
    if not (activator:IsAdmin() or activator:IsSuperAdmin()) then return end

    -- Кулдаун на открытие меню (1 сек)
    local sid = activator:SteamID64()
    local now = CurTime()
    self._useCD = self._useCD or {}
    if self._useCD[sid] and (now - self._useCD[sid]) < 1 then return end
    self._useCD[sid] = now

    SWExp.Zone_OpenMenu(activator, self)
end

-- ============================================================
-- Вспомогательные
-- ============================================================

function ENT:CleanupLists()
    local clean = {}
    for _, e in ipairs(self._matNodes) do
        if IsValid(e) then clean[#clean + 1] = e end
    end
    self._matNodes = clean
end

function ENT:RandomSpawnPos()
    local center = self:GetPos()
    local radius = self._radius

    for _ = 1, 20 do
        -- Равномерное распределение по кругу без sqrt-перекоса к краям
        local angle = math.random() * math.pi * 2
        local dist  = math.random() * radius * 0.85   -- не дальше 85% радиуса

        local offset = Vector(math.cos(angle) * dist, math.sin(angle) * dist, 0)
        local start  = center + offset + Vector(0, 0, 512)  -- стартуем высоко над точкой

        local tr = util.TraceLine({
            start  = start,
            endpos = start - Vector(0, 0, 1200),
            mask   = MASK_SOLID_BRUSHONLY,
        })

        if tr.Hit and not tr.StartSolid then
            local dz = tr.HitPos.z - center.z
            if dz >= -100 and dz <= radius then
                return tr.HitPos + tr.HitNormal * 4
            end
        end
    end

    -- Fallback: прямо над центром зоны
    local tr = util.TraceLine({
        start  = center + Vector(0, 0, 512),
        endpos = center - Vector(0, 0, 512),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and (tr.HitPos + tr.HitNormal * 4) or (center + Vector(0, 0, 4))
end

-- ============================================================
-- Спавн нода
-- ============================================================

function ENT:SpawnMatNode()
    local pos = self:RandomSpawnPos()
    local ent = ents.Create("swexp_material_node")
    if not IsValid(ent) then return end

    ent:SetupTier(self._tier)
    ent:SetPos(pos)
    ent:Spawn()
    ent:Activate()
    ent._ownerZone = self

    self._matNodes[#self._matNodes + 1] = ent
end

-- ============================================================
-- Цикл спавна
-- ============================================================

function ENT:SpawnCycle()
    if not IsValid(self) then return end
    self:CleanupLists()

    local need = self._maxMat - #self._matNodes
    for _ = 1, need do
        self:SpawnMatNode()
    end

    timer.Create("SWExp::MatZone_" .. self:EntIndex(), self._respawn, 1, function()
        if IsValid(self) then self:SpawnCycle() end
    end)
end

-- ============================================================
-- Callback от нода (исчерпан)
-- ============================================================

function ENT:OnNodeDepleted(node)
    self:CleanupLists()
    timer.Simple(math.random(15, 30), function()
        if not IsValid(self) then return end
        self:CleanupLists()
        if #self._matNodes < self._maxMat then
            self:SpawnMatNode()
        end
    end)
end

-- ============================================================
-- Удаление
-- ============================================================

function ENT:OnRemove()
    timer.Remove("SWExp::MatZone_" .. self:EntIndex())
    for _, e in ipairs(self._matNodes) do
        if IsValid(e) then e:Remove() end
    end
    print(string.format("[SWExp] Mat-зона #%d удалена.", self:EntIndex()))
end

print("[SWExp] swexp_mat_zone (сервер) загружен.")
