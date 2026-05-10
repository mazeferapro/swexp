-- ============================================================
-- Star Wars: Expedition — Серверный модуль зон (сервер)
-- modules/sv_zones.lua
--
-- Общая логика для swexp_mat_zone и swexp_res_zone:
--   • Net-строки для меню настройки
--   • Обработка USE-запроса: открыть меню
--   • Обработка сохранения настроек от клиента
-- ============================================================

if CLIENT then return end

util.AddNetworkString("SWExp::Zone_OpenMenu")   -- сервер → клиент: открыть меню настройки
util.AddNetworkString("SWExp::Zone_SaveSettings") -- клиент → сервер: сохранить настройки

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

    ply:ChatPrint(string.format("[SWExp] Зона обновлена: Тир %d | R=%d | T=%ds | Макс=%d",
        tier, radius, respawn, maxCount))

    print(string.format("[SWExp] %s изменил зону #%d: Тир=%d R=%d T=%d Max=%d",
        ply:Nick(), zone:EntIndex(), tier, radius, respawn, maxCount))
end)

print("[SWExp] Серверный модуль зон загружен.")
