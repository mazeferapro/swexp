-- ============================================================
-- SWExp: Rate-limit helper для net/netstream хуков
-- core/sv_net_ratelimit.lua
--
-- Использование:
--   if not SWExp.Net:RateCheck(ply, "InventoryMoveItem", 0.05) then return end
--
-- Дефолтные лимиты задаются в SWExp.Net.DefaultCooldowns.
-- На PlayerDisconnected per-player таблица автоматически очищается.
-- ============================================================

if CLIENT then return end

SWExp = SWExp or {}
SWExp.Net = SWExp.Net or {}

-- Per-player [sid][key] = CurTime() следующего разрешённого вызова
SWExp.Net._RateState = SWExp.Net._RateState or {}

-- Дефолтные кулдауны (секунды) для известных ключей
SWExp.Net.DefaultCooldowns = SWExp.Net.DefaultCooldowns or {
    -- Inventory
    InventoryMoveItem       = 0.05,
    InventoryDropItem       = 0.25,
    InventoryEquipItem      = 0.20,
    InventoryUnequipItem    = 0.20,
    InventoryUseItem        = 0.25,
    InventorySplitItem      = 0.20,
    InventoryMergeItems     = 0.10,
    InventoryTakeFromBag    = 0.15,
    InventoryEquipFromBag   = 0.25,
    InventoryOpen           = 0.50,
    UseMedkitHotkey         = 1.00,
    -- Assembler / Research
    Assembler_DepositReq    = 0.75,
    Assembler_CraftReq      = 0.50,
    Assembler_SetLimit      = 0.50,
    Assembler_RefreshMyUsage = 8,
    Research_DepositRequest = 0.75,
    -- Portal
    PortalUse               = 0.50,
    PortalSaveSettings      = 0.25,
    -- CarDealer
    CreateCar               = 2.00,
    SpawnCar                = 1.00,
    ReturnCar               = 1.00,
}

-- ============================================================
-- Публичный API
-- ============================================================

--- Проверить / обновить rate-limit для игрока.
--- Возвращает true, если вызов разрешён; false — если нужно дропнуть пакет.
function SWExp.Net:RateCheck(ply, key, cooldown)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    cooldown = cooldown or self.DefaultCooldowns[key] or 0.1

    local sid  = ply:SteamID64()
    local bucket = self._RateState[sid]
    if not bucket then
        bucket = {}
        self._RateState[sid] = bucket
    end

    local now  = CurTime()
    local next = bucket[key] or 0
    if next > now then
        return false
    end
    bucket[key] = now + cooldown
    return true
end

--- Сброс всех лимитов игрока (например, после смерти/респавна)
function SWExp.Net:ResetRates(ply)
    if not IsValid(ply) then return end
    self._RateState[ply:SteamID64()] = nil
end

-- ============================================================
-- Очистка при выходе игрока
-- ============================================================

hook.Add("PlayerDisconnected", "SWExp::Net_RateCleanup", function(ply)
    if not IsValid(ply) then return end
    SWExp.Net._RateState[ply:SteamID64()] = nil
end)

print("[SWExp] Модуль rate-limit (core) загружен.")
