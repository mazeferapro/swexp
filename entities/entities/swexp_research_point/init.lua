-- ============================================================
-- Star Wars: Expedition — Объект исследования (сервер)
-- entities/swexp_research_point/init.lua
-- ============================================================

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Net-строки объявлены в modules/sv_research.lua

-- ============================================================
-- Типы объектов исследования
-- ============================================================

local RESEARCH_TYPES = {
    {
        name    = "Вонгская биотехнология",
        color   = Color(120, 220, 80),
        points  = 1,
        models  = {
            "models/props_lab/beaker01.mdl",
            "models/props_lab/jar001a.mdl",
        },
        monologues = {
            "Это... живое? Или было живым? Вонги делают всё из органики. Даже оружие. Нужно сканировать — учёные разберутся.",
            "Органический имплант. Следы вонгской биотехнологии. Противно смотреть, но данные важнее брезгливости.",
        },
    },
    {
        name    = "Следы присутствия",
        color   = Color(255, 200, 60),
        points  = 1,
        models  = {
            "models/props_junk/garbage_metalcan001a.mdl",
            "models/props_junk/garbage_bag001a.mdl",
        },
        monologues = {
            "Здесь кто-то был. Недавно. Следы не наши — оборудование незнакомое. Надо зафиксировать, пока не исчезло.",
            "Лагерная стоянка? Нет, слишком свежее. Кто-то следит за нами с этой планеты.",
        },
    },
    {
        name    = "Аномалия планеты",
        color   = Color(80, 160, 255),
        points  = 1,
        models  = {
            "models/props_c17/canister01a.mdl",
            "models/props_combine/combine_mine01.mdl",
        },
        monologues = {
            "Сенсоры зашкаливают. Энергетическая аномалия, либо помехи — не разберу. Нужен скан для Кончордо.",
            "Странное место. Воздух другой. Что-то здесь не так с самой планетой.",
        },
    },
    {
        name    = "Мёртвый Вонг",
        color   = Color(220, 80, 80),
        points  = 2,
        models  = {
            "models/props_junk/metal_wire001a.mdl",
            "models/props_c17/oildrum001a.mdl",
        },
        monologues = {
            "Вонг. Мёртв. Но не от нашего оружия — следы ритуала. Они убивают своих за трусость? Это важно знать.",
            "Их не жалко. Но что убило его здесь, вдали от боя? Болезнь? Ритуальное самоубийство?",
        },
    },
    {
        name    = "Артефакт древней цивилизации",
        color   = Color(200, 130, 255),
        points  = 2,
        models  = {
            "models/props_c17/fishingtackle01.mdl",
            "models/props_junk/PopCan01a.mdl",
        },
        monologues = {
            "Это старше всего, что я видел. Намного старше. Здесь жили разумные существа до Вонгов. Что с ними стало?",
            "Артефакт. Непонятного назначения. Учёные с базы за такое отдадут половину разработок. Надо сканировать аккуратно.",
        },
    },
}

-- ============================================================
-- Инициализация
-- ============================================================

function ENT:Initialize()
    local typeData = RESEARCH_TYPES[math.random(#RESEARCH_TYPES)]
    local model    = typeData.models[math.random(#typeData.models)]
    local mono     = typeData.monologues[math.random(#typeData.monologues)]

    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)

    -- NW данные для клиента
    self:SetNWString("SWExp_ResName",      typeData.name)
    self:SetNWString("SWExp_ResMonologue", mono)
    self:SetNWInt("SWExp_ResPoints",       typeData.points)
    self:SetNWInt("SWExp_ColorR",          typeData.color.r)
    self:SetNWInt("SWExp_ColorG",          typeData.color.g)
    self:SetNWInt("SWExp_ColorB",          typeData.color.b)
    self:SetNWBool("SWExp_Scanned",        false)

    print("[SWExp] Объект исследования создан: " .. typeData.name)
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

    -- Добавляем ОИ в личный пул игрока (НЕ в общий банк)
    -- В общий банк они попадут только после сдачи на терминале исследований
    if SWExp and SWExp.Research then
        SWExp.Research.AddCollected(scanner, points)
    end

    -- Уведомляем игрока о том что данные получены и ждут сдачи
    net.Start("SWExp::Research_Scanned")
        net.WriteInt(points, 8)
        net.WriteString(name)
    net.Send(scanner)

    -- Удаляем объект через паузу (чтобы клиент успел получить NW)
    timer.Simple(0.8, function()
        if IsValid(self) then self:Remove() end
    end)

    return true
end

-- ============================================================
-- Команда спавна для администраторов
-- ============================================================

concommand.Add("swexp_spawn_research", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:ChatPrint("[SWExp] Нет прав.")
        return
    end

    local tr  = ply:GetEyeTrace()
    local ent = ents.Create("swexp_research_point")
    if IsValid(ent) then
        ent:SetPos(tr.HitPos + tr.HitNormal * 3)
        ent:Spawn()
        ent:Activate()
        ply:ChatPrint("[SWExp] Объект исследования размещён: " ..
            ent:GetNWString("SWExp_ResName", "?"))
    end
end)

-- Спавн всех типов для тестирования
concommand.Add("swexp_spawn_research_all", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not ply:IsSuperAdmin() then
        ply:ChatPrint("[SWExp] Только для суперадминов.")
        return
    end

    local base = ply:GetPos() + Vector(0, 0, 10)
    for i = 1, 5 do
        local ent = ents.Create("swexp_research_point")
        if IsValid(ent) then
            ent:SetPos(base + Vector(i * 80, 0, 0))
            ent:Spawn()
            ent:Activate()
        end
    end
    ply:ChatPrint("[SWExp] 5 объектов исследования размещено.")
end)

print("[SWExp] swexp_research_point (сервер) загружен.")
