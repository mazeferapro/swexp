-- ============================================================
-- SWExp: Player Spawn Point (server)
-- entities/swexp_player_spawn/init.lua
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Глобальный реестр точек спавна
SWExp = SWExp or {}
SWExp.PlayerSpawns = SWExp.PlayerSpawns or {}

function ENT:Initialize()
    -- Невидимая сущность: маленькая модель-ручка, без коллизий, без теней.
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:DrawShadow(false)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    if (self:GetSpawnLabel() or "") == "" then
        self:SetSpawnLabel("Spawn")
    end

    table.insert(SWExp.PlayerSpawns, self)

    print(string.format("[SWExp] PlayerSpawn '%s' создана в (%d, %d, %d)",
        self:GetSpawnLabel(),
        math.Round(self:GetPos().x), math.Round(self:GetPos().y), math.Round(self:GetPos().z)))
end

function ENT:UpdateTransmitState()
    -- Передаём всегда — клиент рендерит только для админов
    return TRANSMIT_ALWAYS
end

function ENT:OnRemove()
    for i = #SWExp.PlayerSpawns, 1, -1 do
        if SWExp.PlayerSpawns[i] == self then
            table.remove(SWExp.PlayerSpawns, i)
            break
        end
    end
end

-- ============================================================
-- Установка параметров
-- ============================================================

function ENT:SetupLabel(s) self:SetSpawnLabel(tostring(s or "Spawn")) end

-- ============================================================
-- Публичные API
-- ============================================================

-- Получить список всех валидных точек спавна
function SWExp.GetPlayerSpawns()
    local list = {}
    for _, ent in ipairs(SWExp.PlayerSpawns or {}) do
        if IsValid(ent) then table.insert(list, ent) end
    end
    return list
end

-- Выбрать случайную точку спавна (или nil, если нет ни одной)
function SWExp.PickRandomPlayerSpawn()
    local list = SWExp.GetPlayerSpawns()
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

-- ============================================================
-- Админ-команды
-- ============================================================

concommand.Add("swexp_spawn_playerspawn", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[SWExp] Нет прав.")
        return
    end

    local label = args[1] or "Spawn"
    local tr    = ply:GetEyeTrace()

    local ent = ents.Create("swexp_player_spawn")
    if IsValid(ent) then
        ent:SetPos(tr.HitPos + Vector(0, 0, 5))
        ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        ent:SetupLabel(label)
        ent:Spawn()
        ent:Activate()
        ply:ChatPrint(string.format("[SWExp] PlayerSpawn '%s' установлен.", label))
    end
end)

concommand.Add("swexp_playerspawn_list", function(ply)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end

    local list = SWExp.GetPlayerSpawns()
    ply:ChatPrint(string.format("[SWExp] Активных точек спавна: %d", #list))
    for i, ent in ipairs(list) do
        if IsValid(ent) then
            ply:ChatPrint(string.format("  #%d  '%s'  (%d, %d, %d)",
                i, ent:GetSpawnLabel(),
                math.Round(ent:GetPos().x), math.Round(ent:GetPos().y), math.Round(ent:GetPos().z)))
        end
    end
end)

print("[SWExp] swexp_player_spawn (сервер) загружен.")
