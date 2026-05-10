-- ============================================================
-- Star Wars: Expedition — Серверная логика гранатных слотов
-- modules/grenade/sv_grenade.lua
--
-- Алгоритм броска:
--   1. Клиент шлёт netstream "SWExp::ThrowGrenade" с slotIndex 1..3
--   2. Сервер проверяет: жив, есть граната в слоте, не на кулдауне
--   3. Сохраняет текущее активное оружие (чтобы вернуть после броска)
--   4. Временно даёт SWEP гранаты (ArcCW) с Clip1=1, селектит его
--   5. Эмулирует бросок через PrimaryAttack или +attack
--   6. После Throw SWEP -> Strip и удаление 1 шт. из слота
-- ============================================================

SWExp.Grenade            = SWExp.Grenade or {}
SWExp.Grenade.Cooldowns  = SWExp.Grenade.Cooldowns or {}
SWExp.Grenade.PendingSWEP = SWExp.Grenade.PendingSWEP or {}

local function getCharID(pPlayer)
    if not IsValid(pPlayer) then return nil end
    if pPlayer.SWExp_ActiveChar and pPlayer.SWExp_ActiveChar.id then
        local id = tonumber(pPlayer.SWExp_ActiveChar.id)
        -- Виртуальный ADMIN-персонаж (id = -1) не хранится в БД — игнорируем
        if id == -1 then return nil end
        return id
    end
    return nil
end

local function SafeGiveWeapon(pPlayer, class)
    if SWExp.Ammo and SWExp.Ammo._AllowGive then
        SWExp.Ammo._AllowGive[pPlayer] = true
    end
    pPlayer:Give(class, true)
    if SWExp.Ammo and SWExp.Ammo._AllowGive then
        SWExp.Ammo._AllowGive[pPlayer] = nil
    end
end

local function ConsumeFromSlot(pPlayer, slotIndex)
    local cid = getCharID(pPlayer)
    if not cid then return false end
    local sid = pPlayer:SteamID64()
    local equip = SWExp.Inventory.PlayerEquipment[sid]
                  and SWExp.Inventory.PlayerEquipment[sid][cid]
    if not equip or not equip["grenade"] then return false end
    local item = equip["grenade"][slotIndex]
    if not item then return false end

    equip["grenade"][slotIndex] = nil
    MySQLite.query(string.format(
        "DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d",
        cid, MySQLite.SQLStr("grenade"), slotIndex
    ))
    if SWExp.Inventory.SyncInventoryToClient then
        SWExp.Inventory:SyncInventoryToClient(pPlayer)
    end
    return true, item
end

local function FinishThrow(pPlayer)
    local pending = SWExp.Grenade.PendingSWEP[pPlayer]
    if not pending then return end
    SWExp.Grenade.PendingSWEP[pPlayer] = nil

    if IsValid(pPlayer) then
        pPlayer:StripWeapon(pending.swep)
        if pending.prevWep and IsValid(pPlayer:GetWeapon(pending.prevWep)) then
            pPlayer:SelectWeapon(pending.prevWep)
        end
    end
end

netstream.Hook("SWExp::ThrowGrenade", function(pPlayer, data)
    if not IsValid(pPlayer) or not pPlayer:Alive() then return end
    if not istable(data) then return end
    local slotIndex = tonumber(data.slotIndex)
    local maxSlots = (SWExp.Grenade.Config and SWExp.Grenade.Config.SlotCount) or 3
    if not slotIndex or slotIndex < 1 or slotIndex > maxSlots then return end

    local cd = SWExp.Grenade.Cooldowns[pPlayer] or 0
    if CurTime() < cd then
        netstream.Start(pPlayer, "SWExp::GrenadeFeedback",
            { type = "cooldown", remaining = cd - CurTime() })
        return
    end

    if SWExp.Grenade.PendingSWEP[pPlayer] then
        netstream.Start(pPlayer, "SWExp::GrenadeFeedback", { type = "busy" })
        return
    end

    local cid = getCharID(pPlayer)
    if not cid then return end
    local sid = pPlayer:SteamID64()
    local equip = SWExp.Inventory.PlayerEquipment[sid]
                  and SWExp.Inventory.PlayerEquipment[sid][cid]
    local slotItem = equip and equip["grenade"] and equip["grenade"][slotIndex]
    if not slotItem then
        netstream.Start(pPlayer, "SWExp::GrenadeFeedback", { type = "empty" })
        return
    end

    local itemData = SWExp.Inventory:GetItemData(slotItem.itemID)
    if not itemData or not itemData.grenadeSWEP then
        netstream.Start(pPlayer, "SWExp::GrenadeFeedback", { type = "invalid" })
        return
    end

    local prevWep = nil
    local activeWep = pPlayer:GetActiveWeapon()
    if IsValid(activeWep) then prevWep = activeWep:GetClass() end

    SafeGiveWeapon(pPlayer, itemData.grenadeSWEP)
    timer.Simple(0.05, function()
        if not IsValid(pPlayer) then return end
        local wep = pPlayer:GetWeapon(itemData.grenadeSWEP)
        if not IsValid(wep) then
            netstream.Start(pPlayer, "SWExp::GrenadeFeedback", { type = "invalid" })
            return
        end
        wep:SetClip1(1)
        pPlayer:SelectWeapon(itemData.grenadeSWEP)

        SWExp.Grenade.PendingSWEP[pPlayer] = {
            swep      = itemData.grenadeSWEP,
            slotIdx   = slotIndex,
            prevWep   = prevWep,
            expireAt  = CurTime() + (SWExp.Grenade.Config.SWEPMaxLifetime or 4),
        }
        SWExp.Grenade.Cooldowns[pPlayer] = CurTime()
            + (SWExp.Grenade.Config.ThrowCooldown or 1.5)

        ConsumeFromSlot(pPlayer, slotIndex)

        timer.Simple(0.2, function()
            if not IsValid(pPlayer) then return end
            local wepNow = pPlayer:GetWeapon(itemData.grenadeSWEP)
            if not IsValid(wepNow) then return end
            local thrown = false
            if wepNow.PrimaryAttack then
                local ok = pcall(function() wepNow:PrimaryAttack() end)
                if ok then thrown = true end
            end
            if not thrown then
                pPlayer:ConCommand("+attack")
                timer.Simple(0.1, function()
                    if IsValid(pPlayer) then pPlayer:ConCommand("-attack") end
                end)
            end
        end)
    end)
end)

timer.Create("SWExp::Grenade::PendingWatchdog", 0.25, 0, function()
    for pPlayer, pending in pairs(SWExp.Grenade.PendingSWEP) do
        if not IsValid(pPlayer) or not pPlayer:Alive() then
            SWExp.Grenade.PendingSWEP[pPlayer] = nil
        else
            local wep = pPlayer:GetWeapon(pending.swep)
            local expired = CurTime() >= pending.expireAt
            local emptied = IsValid(wep) and (wep:Clip1() or 0) <= 0
            if expired or emptied or not IsValid(wep) then
                FinishThrow(pPlayer)
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "SWExp::Grenade::Cleanup", function(pPlayer)
    SWExp.Grenade.Cooldowns[pPlayer] = nil
    SWExp.Grenade.PendingSWEP[pPlayer] = nil
end)

hook.Add("DoPlayerDeath", "SWExp::Grenade::Death", function(pPlayer)
    SWExp.Grenade.PendingSWEP[pPlayer] = nil
end)

print("[SWExp][Grenade] sv_grenade.lua загружен")
