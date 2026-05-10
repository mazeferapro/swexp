-- ============================================================
-- Star Wars: Expedition — Точка добычи материалов (сервер)
-- entities/swexp_material_node/init.lua
--
-- Тир передаётся снаружи через ENT:SetupTier(tier) до Spawn(),
-- либо через concommand аргументом.
-- Параметры дропа берутся из sh_zone_config.lua.
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ============================================================
-- Инициализация
-- ============================================================

function ENT:Initialize()
    -- Тир задаётся зоной через SetupTier() до Spawn().
    -- Если не задан — используем тир 1.
    local tier = self._pendingTier or 1
    tier = math.Clamp(tier, 1, 4)

    -- Получаем конфиг тира и случайный тип для этого тира
    local tierCfg  = SWExp.ZoneConfig and SWExp.ZoneConfig.GetTier(tier)
    local typeData = SWExp.ZoneConfig and SWExp.ZoneConfig.GetMatType(tier)

    -- Фоллбэк если конфиг ещё не загружен
    if not tierCfg or not typeData then
        tierCfg  = { matAmount = { min = 1, max = 3 }, matCharges = { min = 1, max = 2 } }
        typeData = {
            name     = "Ресурс",
            color    = Color(180, 180, 180),
            models   = { "models/props_junk/garbage_metalcan001a.mdl" },
            sound    = "physics/metal/metal_box_impact_hard1.wav",
            monologue = "...",
        }
    end

    local model = typeData.models[math.random(#typeData.models)]
    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)

    local amount  = math.random(tierCfg.matAmount.min,  tierCfg.matAmount.max)
    local charges = math.random(tierCfg.matCharges.min, tierCfg.matCharges.max)

    -- NW данные для клиента
    self:SetNWInt("SWExp_Tier",           tier)
    self:SetNWString("SWExp_MatName",     typeData.name)
    self:SetNWString("SWExp_MatMonologue",typeData.monologue)
    self:SetNWString("SWExp_MatSound",    typeData.sound)
    self:SetNWInt("SWExp_MatAmount",      amount)
    self:SetNWInt("SWExp_MatCharges",     charges)
    self:SetNWInt("SWExp_MatMaxCharges",  charges)
    self:SetNWInt("SWExp_ColorR",         typeData.color.r)
    self:SetNWInt("SWExp_ColorG",         typeData.color.g)
    self:SetNWInt("SWExp_ColorB",         typeData.color.b)
    self:SetNWBool("SWExp_Depleted",      false)
    self:SetNWString("SWExp_MatItemID",   "mat_basic")

    print(string.format("[SWExp] Узел добычи [Тир %d] создан: %s (×%d, %d зар.)",
        tier, typeData.name, amount, charges))
end

-- ============================================================
-- API: установить тир до спавна (вызывается из зоны)
-- ============================================================

function ENT:SetupTier(tier)
    self._pendingTier = math.Clamp(tier or 1, 1, 4)
end

-- ============================================================
-- Добыча (вызывается из sv_gathering.lua)
-- ============================================================

function ENT:DoGather(player)
    if not IsValid(player) then return false end
    if self:GetNWBool("SWExp_Depleted") then return false end

    local charges = self:GetNWInt("SWExp_MatCharges", 1)
    local amount  = self:GetNWInt("SWExp_MatAmount",  2)
    local itemID  = self:GetNWString("SWExp_MatItemID", "mat_basic")
    local name    = self:GetNWString("SWExp_MatName", "Материалы")
    local sound   = self:GetNWString("SWExp_MatSound", "")

    if SWExp and SWExp.Inventory then
        local ok = SWExp.Inventory:AddItem(player, itemID, amount)
        if not ok then
            net.Start("SWExp::Gather_Result")
                net.WriteBool(false)
                net.WriteString("Нет места в инвентаре!")
                net.WriteInt(0, 8)
                net.WriteString(name)
            net.Send(player)
            return false
        end
    end

    charges = charges - 1
    self:SetNWInt("SWExp_MatCharges", charges)

    if sound ~= "" then
        self:EmitSound(sound, 65, math.random(90, 110), 0.8)
    end

    net.Start("SWExp::Gather_Result")
        net.WriteBool(true)
        net.WriteString("")
        net.WriteInt(amount, 8)
        net.WriteString(name)
    net.Send(player)

    -- Уведомляем систему врагов о действии (шум от harvest)
    hook.Run("SWExp::NodeHarvested", player, self, self:GetNWInt("SWExp_Tier", 1))

    print(string.format("[SWExp] %s добыл %d × %s [Тир %d] (зарядов: %d)",
        player:Nick(), amount, name, self:GetNWInt("SWExp_Tier", 1), charges))

    if charges <= 0 then
        self:SetNWBool("SWExp_Depleted", true)
        -- Уведомляем зону что нод исчерпан
        if IsValid(self._ownerZone) then
            self._ownerZone:OnNodeDepleted(self)
        end
        timer.Simple(1.5, function()
            if IsValid(self) then self:Remove() end
        end)
    end

    return true
end

-- ============================================================
-- Команды спавна для администраторов
-- ============================================================

concommand.Add("swexp_spawn_matnode", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[SWExp] Нет прав.")
        return
    end

    local tier = tonumber(args[1]) or 1
    local tr   = ply:GetEyeTrace()
    local ent  = ents.Create("swexp_material_node")
    if IsValid(ent) then
        ent:SetupTier(tier)
        ent:SetPos(tr.HitPos + tr.HitNormal * 4)
        ent:Spawn()
        ent:Activate()
        ply:ChatPrint(string.format("[SWExp] Узел добычи [Тир %d] размещён: %s",
            tier, ent:GetNWString("SWExp_MatName", "?")))
    end
end)

concommand.Add("swexp_spawn_matnodes_all", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        ply:ChatPrint("[SWExp] Только для суперадминов.")
        return
    end

    local base = ply:GetPos() + Vector(0, 0, 10)
    for tier = 1, 4 do
        for i = 1, 2 do
            local ent = ents.Create("swexp_material_node")
            if IsValid(ent) then
                ent:SetupTier(tier)
                ent:SetPos(base + Vector((tier - 1) * 120, (i - 1) * 90, 0))
                ent:Spawn()
                ent:Activate()
            end
        end
    end
    ply:ChatPrint("[SWExp] 8 узлов добычи (по 2 каждого тира) размещено.")
end)

print("[SWExp] swexp_material_node (сервер) загружен.")
