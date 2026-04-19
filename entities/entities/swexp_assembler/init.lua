-- ============================================================
-- Star Wars: Expedition — Ассемблер (сервер)
-- entities/swexp_assembler/init.lua
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local USE_RADIUS  = 150
local USE_COOLDOWN = 1.0   -- секунд между открытиями для одного игрока
local _lastUse    = {}

function ENT:Initialize()
    self:SetModel("models/props_c17/TrapPropeller_engine.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

-- ============================================================
-- E — открываем меню ассемблера на клиенте
-- ============================================================

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    -- Кулдаун: игнорируем повторные вызовы пока зажата E
    local sid = activator:SteamID64()
    local now = CurTime()
    if _lastUse[sid] and (now - _lastUse[sid]) < USE_COOLDOWN then return end
    _lastUse[sid] = now

    local dist = activator:GetPos():Distance(self:GetPos())
    if dist > USE_RADIUS then return end

    if not SWExp or not SWExp.Assembler then
        activator:ChatPrint("[SWExp] Система ассемблера не инициализирована.")
        return
    end

    SWExp.Assembler.SendMenuData(activator)
end

-- ============================================================
-- Команда спавна для администраторов
-- ============================================================

concommand.Add("swexp_spawn_assembler", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[SWExp] Нет прав.")
        return
    end

    local tr  = ply:GetEyeTrace()
    local ent = ents.Create("swexp_assembler")
    if IsValid(ent) then
        ent:SetPos(tr.HitPos + tr.HitNormal * 2)
        ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
        ent:Spawn()
        ent:Activate()
        ply:ChatPrint("[SWExp] Ассемблер размещён.")
    end
end)

print("[SWExp] swexp_assembler (сервер) загружен.")
