-- ============================================================
-- Star Wars: Expedition — Зона точек исследования (сервер)
-- entities/swexp_res_zone/init.lua
--
-- Спавнится через Q-menu администратором.
-- USE (E) на кубе → меню настройки (тир, радиус, респавн).
-- Периодически спавнит swexp_research_point внутри радиуса.
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

    local tier    = 1
    local tierCfg = SWExp.ZoneConfig and SWExp.ZoneConfig.GetTier(tier)

    local radius  = tierCfg and tierCfg.radius      or 600
    local maxRes  = tierCfg and tierCfg.maxRes       or 4
    local rspTime = tierCfg and tierCfg.respawnTime  or 90
    local col     = tierCfg and tierCfg.color        or Color(80, 160, 255)

    self:SetNWInt("SWExp_ZoneTier",     tier)
    self:SetNWInt("SWExp_ZoneRadius",   radius)
    self:SetNWInt("SWExp_ZoneRespawn",  rspTime)
    self:SetNWInt("SWExp_ZoneMaxCount", maxRes)
    self:SetNWInt("SWExp_ColorR",       col.r)
    self:SetNWInt("SWExp_ColorG",       col.g)
    self:SetNWInt("SWExp_ColorB",       col.b)

    self._tier      = tier
    self._radius    = radius
    self._maxRes    = maxRes
    self._respawn   = rspTime
    self._resPoints = {}

    timer.Simple(3, function()
        if IsValid(self) then self:SpawnCycle() end
    end)

    print(string.format("[SWExp] Res-зона #%d создана: Тир=%d R=%d T=%ds",
        self:EntIndex(), tier, radius, rspTime))
end

-- ============================================================
-- Применить новые настройки
-- ============================================================

function ENT:ApplySettings(tier, radius, respawn, maxCount)
    tier    = math.Clamp(tier,    1, 4)
    radius  = math.Clamp(radius,  100, 3000)
    respawn = math.Clamp(respawn, 10,  600)

    local tierCfg    = SWExp.ZoneConfig and SWExp.ZoneConfig.GetTier(tier)
    local defaultMax = tierCfg and tierCfg.maxRes or 4
    local col        = tierCfg and tierCfg.color  or Color(80, 160, 255)

    local maxRes = maxCount and math.Clamp(maxCount, 1, 30) or defaultMax

    self._tier    = tier
    self._radius  = radius
    self._maxRes  = maxRes
    self._respawn = respawn

    self:SetNWInt("SWExp_ZoneTier",     tier)
    self:SetNWInt("SWExp_ZoneRadius",   radius)
    self:SetNWInt("SWExp_ZoneRespawn",  respawn)
    self:SetNWInt("SWExp_ZoneMaxCount", maxRes)
    self:SetNWInt("SWExp_ColorR",       col.r)
    self:SetNWInt("SWExp_ColorG",       col.g)
    self:SetNWInt("SWExp_ColorB",       col.b)

    timer.Remove("SWExp::ResZone_" .. self:EntIndex())
    for _, e in ipairs(self._resPoints) do
        if IsValid(e) then e:Remove() end
    end
    self._resPoints = {}

    timer.Simple(2, function()
        if IsValid(self) then self:SpawnCycle() end
    end)
end

-- ============================================================
-- USE
-- ============================================================

function ENT:Use(activator, caller)
    if not IsValid(activator) then return end
    if not (activator:IsAdmin() or activator:IsSuperAdmin()) then return end

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
    for _, e in ipairs(self._resPoints) do
        if IsValid(e) then clean[#clean + 1] = e end
    end
    self._resPoints = clean
end

function ENT:RandomSpawnPos()
    local center = self:GetPos()
    local radius = self._radius

    for _ = 1, 20 do
        local angle = math.random() * math.pi * 2
        local dist  = math.random() * radius * 0.85

        -- Стартуем чуть выше уровня центра зоны — внутри пространства,
        -- а не над потолком. Иначе трейс бил по крыше снаружи и возвращал
        -- её Z вместо нужного пола, из-за чего ноды оказывались в потолке.
        local sx = center.x + math.cos(angle) * dist
        local sy = center.y + math.sin(angle) * dist
        local sz = center.z + 16

        local tr = util.TraceLine({
            start  = Vector(sx, sy, sz),
            endpos = Vector(sx, sy, sz - 400),
            mask   = MASK_SOLID_BRUSHONLY,
        })

        if tr.Hit and not tr.StartSolid then
            local dz = tr.HitPos.z - center.z
            if dz >= -200 and dz <= 64 then
                return tr.HitPos + tr.HitNormal * 4
            end
        end
    end

    -- Fallback: прямо у центра зоны без лишнего трейса.
    return center + Vector(0, 0, 4)
end

-- ============================================================
-- Спавн точки исследования
-- ============================================================

function ENT:SpawnResPoint()
    local pos = self:RandomSpawnPos()
    local ent = ents.Create("swexp_research_point")
    if not IsValid(ent) then return end

    ent:SetupTier(self._tier)
    ent:SetPos(pos)
    ent:Spawn()
    ent:Activate()
    ent._ownerZone = self

    self._resPoints[#self._resPoints + 1] = ent
end

-- ============================================================
-- Цикл спавна
-- ============================================================

function ENT:SpawnCycle()
    if not IsValid(self) then return end
    self:CleanupLists()

    -- Заполняем зону только если она полностью пуста (начальный спавн / после ApplySettings / safety net).
    -- Обычный респавн после использования идёт через OnNodeDepleted с точной задержкой self._respawn.
    if #self._resPoints == 0 then
        for _ = 1, self._maxRes do
            self:SpawnResPoint()
        end
    end

    timer.Create("SWExp::ResZone_" .. self:EntIndex(), self._respawn, 1, function()
        if IsValid(self) then self:SpawnCycle() end
    end)
end

-- ============================================================
-- Callback от точки исследования
-- ============================================================

function ENT:OnNodeDepleted(node)
    self:CleanupLists()
    -- Респавн отдельной истощённой точки происходит ровно через заданное время self._respawn
    -- (настраивается в меню зоны по E).
    local delay = math.max(10, self._respawn)
    timer.Simple(delay, function()
        if not IsValid(self) then return end
        self:CleanupLists()
        if #self._resPoints < self._maxRes then
            self:SpawnResPoint()
        end
    end)
end

-- ============================================================
-- Удаление
-- ============================================================

function ENT:OnRemove()
    timer.Remove("SWExp::ResZone_" .. self:EntIndex())
    for _, e in ipairs(self._resPoints) do
        if IsValid(e) then e:Remove() end
    end
    print(string.format("[SWExp] Res-зона #%d удалена.", self:EntIndex()))
end

print("[SWExp] swexp_res_zone (сервер) загружен.")
