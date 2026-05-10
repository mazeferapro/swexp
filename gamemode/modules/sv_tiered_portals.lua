--[[--
    SWExp: Серверный модуль тировых порталов
    modules/sv_tiered_portals.lua

    Содержит:
    - Сохранение/загрузка порталов и их связей (portal_links.txt, по карте)
    - Команда swexp_give_portal_key для выдачи ключей (GM/тест)
    - Команда swexp_save_portals для ручного сохранения

    Основная сетевая логика находится в
    entities/swexp_tiered_gateway/shared.lua
]]--

if CLIENT then return end

-- ============================================================================
-- СОХРАНЕНИЕ / ЗАГРУЗКА ПОРТАЛОВ
-- ============================================================================

local DATA_FILE = "portal_links.txt"

-- Лимиты для валидации данных портала (защита от повреждённого / злонамеренного файла)
local MAX_COORD       = 100000     -- разумные пределы карты в юнитах
local MAX_PORTALS_PER_MAP = 512
local MAX_TIER        = 4
local MAX_CODE        = 99999

local function IsNum(v) return type(v) == "number" and v == v end -- отсеивает NaN

local function IsValidVecTbl(t)
    if type(t) ~= "table" then return false end
    if not (IsNum(t.x) and IsNum(t.y) and IsNum(t.z)) then return false end
    if math.abs(t.x) > MAX_COORD or math.abs(t.y) > MAX_COORD or math.abs(t.z) > MAX_COORD then
        return false
    end
    return true
end

local function IsValidAngTbl(t)
    if type(t) ~= "table" then return false end
    if not (IsNum(t.p) and IsNum(t.y) and IsNum(t.r)) then return false end
    if math.abs(t.p) > 360 or math.abs(t.y) > 360 or math.abs(t.r) > 360 then
        return false
    end
    return true
end

local function IsValidPortalEntry(data)
    if type(data) ~= "table" then return false end
    if not IsValidVecTbl(data.pos) then return false end
    if not IsValidAngTbl(data.ang) then return false end
    if not IsNum(data.tier) or data.tier < 1 or data.tier > MAX_TIER then return false end
    if not IsNum(data.code) or data.code < 0 or data.code > MAX_CODE then return false end
    if data.linkedCode ~= nil and (not IsNum(data.linkedCode) or data.linkedCode < 0 or data.linkedCode > MAX_CODE) then
        return false
    end
    return true
end

-- Читаем весь файл и возвращаем таблицу (или {})
local function ReadPortalFile()
    if not file.Exists(DATA_FILE, "DATA") then
        file.Write(DATA_FILE, "{}")
        return {}
    end
    local raw = file.Read(DATA_FILE, "DATA")
    if not raw or raw == "" then return {} end
    local t = util.JSONToTable(raw)
    if type(t) ~= "table" then
        MsgC(Color(255, 80, 80), "[SWExp Portals] portal_links.txt повреждён — загружаем пустой набор.\n")
        return {}
    end
    return t
end

-- Сохраняем все порталы текущей карты в файл
local function SavePortals()
    local mapName = game.GetMap()
    local allData = ReadPortalFile()

    local portals = {}
    for _, ent in ipairs(ents.FindByClass("swexp_tiered_gateway")) do
        if not IsValid(ent) then continue end

        local linkedCode = 0
        local partner = ent:GetLinkedTo()
        if IsValid(partner) then
            linkedCode = partner:GetCode()
        end

        local pos = ent:GetPos()
        local ang = ent:GetAngles()

        portals[#portals + 1] = {
            pos        = { x = pos.x,   y = pos.y,   z = pos.z   },
            ang        = { p = ang.p,   y = ang.y,   r = ang.r   },
            tier       = ent:GetTier(),
            code       = ent:GetCode(),
            linkedCode = linkedCode,
        }
    end

    allData[mapName] = portals
    file.Write(DATA_FILE, util.TableToJSON(allData, true))
    MsgC(Color(0, 200, 255), string.format("[SWExp Portals] Сохранено %d порталов для карты '%s'.\n", #portals, mapName))
end

-- Спавним порталы из файла и восстанавливаем связи
local function LoadPortals()
    local mapName = game.GetMap()
    local allData = ReadPortalFile()
    local portals = allData[mapName]

    if not portals or #portals == 0 then
        MsgC(Color(180, 180, 180), "[SWExp Portals] Нет сохранённых порталов для карты '" .. mapName .. "'.\n")
        return
    end

    -- Первый проход: спавним все порталы (с валидацией)
    local spawned = {}   -- [savedCode] = entity
    local skipped = 0
    local cap = math.min(#portals, MAX_PORTALS_PER_MAP)
    for i = 1, cap do
        local data = portals[i]
        if not IsValidPortalEntry(data) then
            skipped = skipped + 1
            continue
        end

        local ent = ents.Create("swexp_tiered_gateway")
        if not IsValid(ent) then continue end

        ent:SetPos(Vector(data.pos.x, data.pos.y, data.pos.z))
        ent:SetAngles(Angle(data.ang.p, data.ang.y, data.ang.r))

        -- Выставляем тир ДО Spawn, чтобы Initialize взял правильный тир
        -- (тир хранится в NetworkVar, поэтому ставим после Spawn)
        ent:Spawn()
        ent:Activate()

        -- Устанавливаем тир (может отличаться от дефолтного 1)
        if data.tier and data.tier ~= ent:GetTier() then
            ent:SetTierAdmin(data.tier)
        end

        spawned[data.code] = { ent = ent, linkedCode = data.linkedCode or 0 }
    end

    if skipped > 0 then
        MsgC(Color(255, 180, 0),
            string.format("[SWExp Portals] Пропущено %d невалидных записей портала при загрузке.\n", skipped))
    end
    if #portals > MAX_PORTALS_PER_MAP then
        MsgC(Color(255, 180, 0),
            string.format("[SWExp Portals] Превышен лимит порталов на карту (%d > %d). Остальные проигнорированы.\n",
                #portals, MAX_PORTALS_PER_MAP))
    end

    -- Второй проход: восстанавливаем связи (оба конца уже существуют)
    for savedCode, info in pairs(spawned) do
        local ent    = info.ent
        local lc     = info.linkedCode
        if lc == 0 then continue end                     -- не был связан
        if not IsValid(ent) then continue end
        if IsValid(ent:GetLinkedTo()) then continue end  -- уже связан (другой проход)

        local partnerInfo = spawned[lc]
        if not partnerInfo then continue end
        local partner = partnerInfo.ent
        if not IsValid(partner) then continue end

        ent:AdminLink(partner, true)  -- silent: не сохранять при загрузке
    end

    MsgC(Color(0, 200, 255), string.format("[SWExp Portals] Загружено %d порталов для карты '%s'.\n", #portals, mapName))
end

-- Загружаем после инициализации всех entity
hook.Add("InitPostEntity",  "SWExp::LoadPortals", LoadPortals)
hook.Add("PostCleanupMap",  "SWExp::LoadPortals", LoadPortals)

-- Регистрируем глобальную функцию для вызова из gateway shared.lua
SWExp = SWExp or {}
SWExp.SavePortals = SavePortals

-- ============================================================================
-- CONCOMMAND: ручное сохранение
-- ============================================================================

concommand.Add("swexp_save_portals", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[Portal] Только Суперадмин может сохранять порталы.")
        return
    end
    SavePortals()
    if IsValid(ply) then
        ply:ChatPrint("[Portal] Порталы сохранены.")
    end
end)

-- ============================================================================
-- КОМАНДА: выдать ключ тира игроку (для ГМ / тестирования)
-- Использование: swexp_give_portal_key <1-4> [часть ника]
-- ============================================================================

concommand.Add("swexp_give_portal_key", function(ply, cmd, args)
    if not IsValid(ply) then return end
    if not ply.IsSuperAdmin or not ply:IsSuperAdmin() then
        ply:ChatPrint("[Portal] Только Суперадмин может выдавать ключи.")
        return
    end

    local tier = tonumber(args[1])
    if not tier or tier < 1 or tier > 4 then
        ply:ChatPrint("[Portal] Использование: swexp_give_portal_key <1-4> [ник]")
        return
    end

    local keyIDs = { "key_tier1", "key_tier2", "key_tier3", "key_tier4" }
    local keyID  = keyIDs[tier]

    local target = ply
    if args[2] then
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(args[2]), 1, true) then
                target = p
                break
            end
        end
    end

    if not SWExp or not SWExp.Inventory then
        ply:ChatPrint("[Portal] Система инвентаря не загружена.")
        return
    end

    local ok, err = SWExp.Inventory:AddItem(target, keyID, 1)
    local tierLabels = { "I", "II", "III", "IV" }
    if ok then
        ply:ChatPrint("[Portal] Ключ Tier " .. (tierLabels[tier] or tier) .. " выдан: " .. target:Nick())
        if target ~= ply then
            target:ChatPrint("[Portal] Вы получили Ключ врат (Tier " .. (tierLabels[tier] or tier) .. ").")
        end
    else
        ply:ChatPrint("[Portal] Ошибка: " .. tostring(err))
    end
end)

MsgC(Color(0, 200, 255), "[SWExp] Модуль тировых порталов загружен.\n")
