-- ============================================================
-- Star Wars: Expedition — Хранилище персонажа (сервер)
-- modules/char_locker/sv_char_locker.lua
-- ============================================================

if CLIENT then return end

-- Кулдаун открытия хранилища (секунды)
local OPEN_COOLDOWN = 1.5

-- ============================================================
-- Хук: игрок нажал E на swexp_char_locker
-- Синхронизирует данные хранилища и сообщает клиенту открыть UI
-- ============================================================

hook.Add('SWExp::LockerUse', 'SWExp::CharLocker_Open', function(pPlayer, locker)
    if not IsValid(pPlayer) then return end

    -- Rate-limit
    local rateOk = true
    if SWExp and SWExp.Net and SWExp.Net.RateCheck then
        rateOk = SWExp.Net:RateCheck(pPlayer, 'LockerOpen', OPEN_COOLDOWN)
    end
    if not rateOk then return end

    local char = pPlayer.SWExp_ActiveChar
    if not char then
        pPlayer:ChatPrint('[Хранилище] Выберите персонажа.')
        return
    end

    -- Если инвентарный модуль не загружен — предупреждаем
    if not SWExp.Inventory or not SWExp.Inventory.SyncInventoryToClient then
        pPlayer:ChatPrint('[Хранилище] Система инвентаря не готова.')
        MsgC(Color(255, 80, 80), '[SWExp][Locker] SWExp.Inventory не найден!\n')
        return
    end

    -- Синхронизируем актуальные данные инвентаря + хранилища клиенту
    -- (SyncInventoryToClient уже отправляет и inventory, и storage, и equipment)
    SWExp.Inventory:SyncInventoryToClient(pPlayer)

    -- Отдельным сообщением говорим клиенту открыть окно хранилища
    netstream.Start(pPlayer, 'SWExp::OpenCharLocker')

    MsgC(Color(0, 200, 255), '[SWExp][Locker] ', color_white,
        string.format('%s открыл хранилище персонажа #%s\n',
            pPlayer:Nick(), tostring(char.id)))
end)

-- ============================================================
-- Netstream: клиент явно запрашивает синхронизацию хранилища
-- (например при перетаскивании предметов)
-- ============================================================

netstream.Hook('SWExp::RequestLockerSync', function(pPlayer)
    if not IsValid(pPlayer) then return end

    local rateOk = true
    if SWExp and SWExp.Net and SWExp.Net.RateCheck then
        rateOk = SWExp.Net:RateCheck(pPlayer, 'LockerSync', 0.5)
    end
    if not rateOk then return end

    if not pPlayer.SWExp_ActiveChar then return end
    if not SWExp.Inventory or not SWExp.Inventory.SyncInventoryToClient then return end

    SWExp.Inventory:SyncInventoryToClient(pPlayer)
end)
