-- ============================================================
-- SWExp: Safezone (сервер)
-- entities/swexp_safezone/init.lua
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Глобальный реестр safezone для быстрого поиска
SWExp.Safezones = SWExp.Safezones or {}

function ENT:Initialize()
    -- Невидимая сущность: маленькая модель для handle, без коллизий, без теней.
    self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid( SOLID_BBOX )
    self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    self:DrawShadow(false)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    if (self:GetRadius() or 0) <= 0 then
        self:SetRadius(1500)
    end
    if (self:GetHubName() or "") == "" then
        self:SetHubName("Хаб")
    end

    table.insert(SWExp.Safezones, self)

    print(string.format("[SWExp] Safezone '%s' создана в (%d, %d, %d), радиус %d",
        self:GetHubName(),
        math.Round(self:GetPos().x), math.Round(self:GetPos().y), math.Round(self:GetPos().z),
        self:GetRadius()))
end

function ENT:UpdateTransmitState()
    -- Передаём всегда — клиент рендерит для админов
    return TRANSMIT_ALWAYS
end

function ENT:OnRemove()
    for i = #SWExp.Safezones, 1, -1 do
        if SWExp.Safezones[i] == self then
            table.remove(SWExp.Safezones, i)
            break
        end
    end
end

-- ============================================================
-- Установка параметров до спавна
-- ============================================================

function ENT:SetupRadius(r) self:SetRadius(math.Clamp(r or 1500, 200, 10000)) end
function ENT:SetupHubName(s) self:SetHubName(tostring(s or "Хаб")) end

-- ============================================================
-- Публичные API для менеджера врагов
-- ============================================================

-- Быстрая проверка: находится ли точка внутри ЛЮБОЙ safezone (+ опциональный буфер).
function SWExp.IsInSafezone(vPos, bufferExtra)
    if not vPos then return false end
    bufferExtra = bufferExtra or 0
    for _, sz in ipairs(SWExp.Safezones) do
        if IsValid(sz) and sz:ContainsPos(vPos, bufferExtra) then
            return true, sz
        end
    end
    return false, nil
end

-- ============================================================
-- Админ-команды
-- ============================================================

concommand.Add("swexp_spawn_safezone", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[SWExp] Нет прав.")
        return
    end

    local radius  = tonumber(args[1]) or 1500
    local hubName = args[2] or "Хаб"
    local tr      = ply:GetEyeTrace()

    local ent = ents.Create("swexp_safezone")
    if IsValid(ent) then
        ent:SetPos(tr.HitPos + Vector(0, 0, 10))
        ent:SetupRadius(radius)
        ent:SetupHubName(hubName)
        ent:Spawn()
        ent:Activate()
        ply:ChatPrint(string.format("[SWExp] Safezone '%s' (R=%d) размещена.",
            hubName, radius))
    end
end)

concommand.Add("swexp_safezone_list", function(ply)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end

    ply:ChatPrint(string.format("[SWExp] Активных safezone: %d", #SWExp.Safezones))
    for i, sz in ipairs(SWExp.Safezones) do
        if IsValid(sz) then
            ply:ChatPrint(string.format("  #%d  '%s'  R=%d  (%d, %d, %d)",
                i, sz:GetHubName(), sz:GetRadius(),
                math.Round(sz:GetPos().x), math.Round(sz:GetPos().y), math.Round(sz:GetPos().z)))
        end
    end
end)

print("[SWExp] swexp_safezone (сервер) загружен.")
