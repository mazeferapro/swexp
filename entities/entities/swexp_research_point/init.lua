-- ============================================================
-- Star Wars: Expedition — Объект исследования (сервер)
-- entities/swexp_research_point/init.lua
--
-- Тир передаётся через ENT:SetupTier(tier) до Spawn().
-- Параметры (очки ОИ) берутся из sh_zone_config.lua.
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
-- Инициализация
-- ============================================================

function ENT:Initialize()
    local tier = self._pendingTier or 1
    tier = math.Clamp(tier, 1, 4)

    -- Получаем конфиг тира и случайный тип точки исследования
    local tierCfg  = SWExp.ZoneConfig and SWExp.ZoneConfig.GetTier(tier)
    local typeData = SWExp.ZoneConfig and SWExp.ZoneConfig.GetResType(tier)

    -- Фоллбэк
    if not tierCfg or not typeData then
        tierCfg  = { resPoints = 1 }
        typeData = {
            name     = "Аномалия",
            color    = Color(80, 160, 255),
            models   = { "models/props_c17/canister01a.mdl" },
            monologue = "Что-то здесь не так.",
        }
    end

    local model = typeData.models[math.random(#typeData.models)]

    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)

    -- NW данные для клиента
    self:SetNWInt("SWExp_Tier",          tier)
    self:SetNWString("SWExp_ResName",    typeData.name)
    self:SetNWString("SWExp_ResMonologue", typeData.monologue)
    self:SetNWInt("SWExp_ResPoints",     tierCfg.resPoints)
    self:SetNWInt("SWExp_ColorR",        typeData.color.r)
    self:SetNWInt("SWExp_ColorG",        typeData.color.g)
    self:SetNWInt("SWExp_ColorB",        typeData.color.b)
    self:SetNWBool("SWExp_Scanned",      false)

    print(string.format("[SWExp] Точка исследования [Тир %d] создана: %s (+%d ОИ)",
        tier, typeData.name, tierCfg.resPoints))
end

-- ============================================================
-- API: установить тир до спавна (вызывается из зоны)
-- ============================================================

function ENT:SetupTier(tier)
    self._pendingTier = math.Clamp(tier or 1, 1, 4)
end

-- ============================================================
-- Сканирование (вызывается из SWEP сканера)
-- ============================================================

function ENT:DoScan(scanner)
    if not IsValid(scanner) then return false end
    if self:GetNWBool("SWExp_Scanned") then return false end

    self:SetNWBool("SWExp_Scanned", true)

    local points = self:GetNWInt("SWExp_ResPoints", 1)
    local name   = self:GetNWString("SWExp_ResName", "")
    local tier   = self:GetNWInt("SWExp_Tier", 1)

    if SWExp and SWExp.Research then
        SWExp.Research.AddCollected(scanner, points)
    end

    net.Start("SWExp::Research_Scanned")
        net.WriteInt(points, 8)
        net.WriteString(name)
    net.Send(scanner)

    -- Уведомляем систему врагов о действии (шум от scan)
    hook.Run("SWExp::ResearchScanned", scanner, self, tier)

    print(string.format("[SWExp] %s отсканировал %s [Тир %d] (+%d ОИ)",
        scanner:Nick(), name, tier, points))

    -- Уведомляем зону что точка просканирована
    if IsValid(self._ownerZone) then
        self._ownerZone:OnNodeDepleted(self)
    end

    timer.Simple(0.8, function()
        if IsValid(self) then self:Remove() end
    end)

    return true
end

-- ============================================================
-- Команды спавна для администраторов
-- ============================================================

concommand.Add("swexp_spawn_research", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[SWExp] Нет прав.")
        return
    end

    local tier = tonumber(args[1]) or 1
    local tr   = ply:GetEyeTrace()
    local ent  = ents.Create("swexp_research_point")
    if IsValid(ent) then
        ent:SetupTier(tier)
        ent:SetPos(tr.HitPos + tr.HitNormal * 3)
        ent:Spawn()
        ent:Activate()
        ply:ChatPrint(string.format("[SWExp] Точка исследования [Тир %d] размещена: %s",
            tier, ent:GetNWString("SWExp_ResName", "?")))
    end
end)

concommand.Add("swexp_spawn_research_all", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        ply:ChatPrint("[SWExp] Только для суперадминов.")
        return
    end

    local base = ply:GetPos() + Vector(0, 0, 10)
    for tier = 1, 4 do
        for i = 1, 2 do
            local ent = ents.Create("swexp_research_point")
            if IsValid(ent) then
                ent:SetupTier(tier)
                ent:SetPos(base + Vector((tier - 1) * 120, (i - 1) * 90, 0))
                ent:Spawn()
                ent:Activate()
            end
        end
    end
    ply:ChatPrint("[SWExp] 8 точек исследования (по 2 каждого тира) размещено.")
end)

print("[SWExp] swexp_research_point (сервер) загружен.")
