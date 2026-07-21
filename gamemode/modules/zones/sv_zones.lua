-- ============================================================
-- Star Wars: Expedition — Серверный модуль зон (сервер)
-- modules/sv_zones.lua
--
-- Общая логика для swexp_mat_zone и swexp_res_zone:
--   • Net-строки для меню настройки
--   • Обработка USE-запроса: открыть меню
--   • Обработка сохранения настроек от клиента
--   • Сохранение / загрузка позиций и настроек зон на диск
--     (файл zones_data.txt, отдельная запись на карту)
-- ============================================================

if CLIENT then return end

util.AddNetworkString("SWExp::Zone_OpenMenu")    -- сервер → клиент: открыть меню настройки
util.AddNetworkString("SWExp::Zone_SaveSettings") -- клиент → сервер: сохранить настройки

-- ============================================================
-- СОХРАНЕНИЕ / ЗАГРУЗКА
-- ============================================================

local DATA_FILE  = "swexp_zones_data.txt"
local MAX_COORD  = 100000
local MAX_ZONES  = 1024

local function IsNum(v) return type(v) == "number" and v == v end

local function IsValidVec(t)
    if type(t) ~= "table" then return false end
    if not (IsNum(t.x) and IsNum(t.y) and IsNum(t.z)) then return false end
    if math.abs(t.x) > MAX_COORD or math.abs(t.y) > MAX_COORD or math.abs(t.z) > MAX_COORD then
        return false
    end
    return true
end

local function IsValidEntry(d)
    if type(d) ~= "table" then return false end
    if d.class ~= "swexp_mat_zone" and d.class ~= "swexp_res_zone" then return false end
    if not IsValidVec(d.pos) then return false end
    if not IsValidVec(d.ang) then return false end  -- ang хранится как {x=p,y=y,z=r}
    if not IsNum(d.tier)     or d.tier     < 1  or d.tier     > 4    then return false end
    if not IsNum(d.radius)   or d.radius   < 100 or d.radius   > 3000 then return false end
    if not IsNum(d.respawn)  or d.respawn  < 10  or d.respawn  > 600  then return false end
    if not IsNum(d.maxCount) or d.maxCount < 1   or d.maxCount > 30   then return false end
    return true
end

local function ReadFile()
    if not file.Exists(DATA_FILE, "DATA") then return {} end
    local raw = file.Read(DATA_FILE, "DATA")
    if not raw or raw == "" then return {} end
    local t = util.JSONToTable(raw)
    return type(t) == "table" and t or {}
end

-- Сохраняем все зоны текущей карты.
local function SaveZones()
    local mapName = game.GetMap()
    local allData = ReadFile()

    local zones  = {}
    local skipped = 0
    local classes = { "swexp_mat_zone", "swexp_res_zone" }

    for _, class in ipairs(classes) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if not IsValid(ent) then continue end
            if #zones >= MAX_ZONES then skipped = skipped + 1; continue end

            local pos = ent:GetPos()
            local ang = ent:GetAngles()

            local defaultMax = (class == "swexp_mat_zone") and 5 or 4

            zones[#zones + 1] = {
                class    = class,
                pos      = { x = pos.x, y = pos.y, z = pos.z },
                ang      = { x = ang.p, y = ang.y, z = ang.r },
                tier     = ent:GetNWInt("SWExp_ZoneTier",     1),
                radius   = ent:GetNWInt("SWExp_ZoneRadius",   600),
                respawn  = ent:GetNWInt("SWExp_ZoneRespawn",  90),
                maxCount = ent:GetNWInt("SWExp_ZoneMaxCount", defaultMax),
            }
        end
    end

    allData[mapName] = zones
    file.Write(DATA_FILE, util.TableToJSON(allData, true))

    local msg = string.format("[SWExp] Зоны сохранены: %d для карты '%s'.", #zones, mapName)
    if skipped > 0 then
        msg = msg .. string.format(" Пропущено (лимит): %d.", skipped)
    end
    MsgC(Color(0, 200, 255), msg .. "\n")
    return #zones
end

-- Загружаем зоны текущей карты.
local function LoadZones()
    local mapName = game.GetMap()
    local allData = ReadFile()
    local zones   = allData[mapName]

    if not zones or #zones == 0 then
        MsgC(Color(180, 180, 180),
            "[SWExp] Нет сохранённых зон для карты '" .. mapName .. "'.\n")
        return
    end

    -- Удаляем старые зоны (на случай горячей перезагрузки)
    for _, class in ipairs({ "swexp_mat_zone", "swexp_res_zone" }) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if IsValid(ent) then ent:Remove() end
        end
    end

    local loaded  = 0
    local skipped = 0
    local cap = math.min(#zones, MAX_ZONES)

    for i = 1, cap do
        local d = zones[i]
        if not IsValidEntry(d) then
            skipped = skipped + 1
            continue
        end

        local ent = ents.Create(d.class)
        if not IsValid(ent) then continue end

        -- Восстанавливаем ВСЕ три компоненты позиции — включая Z.
        ent:SetPos(Vector(d.pos.x, d.pos.y, d.pos.z))
        ent:SetAngles(Angle(d.ang.x, d.ang.y, d.ang.z))
        ent:Spawn()
        ent:Activate()

        -- Применяем сохранённые настройки.
        if IsValid(ent) and ent.ApplySettings then
            ent:ApplySettings(d.tier, d.radius, d.respawn, d.maxCount)
        end

        loaded = loaded + 1
    end

    if skipped > 0 then
        MsgC(Color(255, 180, 0),
            string.format("[SWExp] Зоны: пропущено %d невалидных записей.\n", skipped))
    end
    MsgC(Color(0, 200, 255),
        string.format("[SWExp] Зоны загружены: %d для карты '%s'.\n", loaded, mapName))
end

-- Автозагрузка при старте и смене карты.
hook.Add("InitPostEntity", "SWExp::LoadZones", function()
    timer.Simple(1, LoadZones)   -- даём серверу полностью подняться
end)
hook.Add("PostCleanupMap", "SWExp::LoadZones", function()
    timer.Simple(1, LoadZones)
end)

-- Экспортируем для внешнего использования.
SWExp = SWExp or {}
SWExp.SaveZones = SaveZones
SWExp.LoadZones = LoadZones

-- ============================================================
-- Конкоманды
-- ============================================================

-- swexp_save_zones — ручное сохранение (суперадмин / консоль сервера).
concommand.Add("swexp_save_zones", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[SWExp] Только Суперадмин может сохранять зоны.")
        return
    end
    local n = SaveZones()
    if IsValid(ply) then
        ply:ChatPrint(string.format("[SWExp] Сохранено %d зон.", n))
    end
end)

-- swexp_load_zones — ручная перезагрузка зон из файла.
concommand.Add("swexp_load_zones", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[SWExp] Только Суперадмин может загружать зоны.")
        return
    end
    LoadZones()
    if IsValid(ply) then
        ply:ChatPrint("[SWExp] Зоны перезагружены.")
    end
end)

-- ============================================================
-- Клиент нажал E на зону → открываем меню настройки
-- (вызывается из ENT:Use обоих типов зон)
-- ============================================================

function SWExp.Zone_OpenMenu(ply, zone)
    if not IsValid(ply) or not IsValid(zone) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end

    local class = zone:GetClass()
    if class ~= "swexp_mat_zone" and class ~= "swexp_res_zone" then return end

    local defaultMax = (class == "swexp_mat_zone") and 5 or 4

    net.Start("SWExp::Zone_OpenMenu")
        net.WriteEntity(zone)
        net.WriteString(class)
        net.WriteInt(zone:GetNWInt("SWExp_ZoneTier",     1),          8)
        net.WriteInt(zone:GetNWInt("SWExp_ZoneRadius",   600),        16)
        net.WriteInt(zone:GetNWInt("SWExp_ZoneRespawn",  90),         16)
        net.WriteInt(zone:GetNWInt("SWExp_ZoneMaxCount", defaultMax), 8)
    net.Send(ply)
end

-- ============================================================
-- Клиент сохранил настройки зоны
-- ============================================================

net.Receive("SWExp::Zone_SaveSettings", function(len, ply)
    if not IsValid(ply) then return end
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end

    local zone     = net.ReadEntity()
    local tier     = math.Clamp(net.ReadInt(8),  1,   4)
    local radius   = math.Clamp(net.ReadInt(16), 100, 3000)
    local respawn  = math.Clamp(net.ReadInt(16), 10,  600)
    local maxCount = math.Clamp(net.ReadInt(8),  1,   30)

    if not IsValid(zone) then return end
    local class = zone:GetClass()
    if class ~= "swexp_mat_zone" and class ~= "swexp_res_zone" then return end

    zone:ApplySettings(tier, radius, respawn, maxCount)

    -- Автосохранение позиций всех зон на диск — чтобы после cleanup
    -- зоны восстановились на правильных координатах (включая Z).
    SaveZones()

    ply:ChatPrint(string.format("[SWExp] Зона обновлена и сохранена: Тир %d | R=%d | T=%ds | Макс=%d",
        tier, radius, respawn, maxCount))

    print(string.format("[SWExp] %s изменил зону #%d: Тир=%d R=%d T=%d Max=%d",
        ply:Nick(), zone:EntIndex(), tier, radius, respawn, maxCount))
end)

print("[SWExp] Серверный модуль зон загружен.")
