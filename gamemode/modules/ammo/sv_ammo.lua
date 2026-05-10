-- ============================================================
-- Star Wars: Expedition — Серверная логика боеприпасов (v2)
-- modules/ammo/sv_ammo.lua
--
-- Хранение боезапаса в БД на character_id.
-- Перезаписан с нуля по фидбеку:
--   * Сохранение делается в правильных точках (CharacterSelected с трекингом
--     предыдущего charID, PlayerDeath, PlayerDisconnected, автосейв, смена карты).
--   * Гранаты: при отсутствии в инвентаре SWEP снимается; при clip=0 SWEP
--     выдаваемый ARC9/ARCCW снимается через корректный детект пустого магазина.
-- ============================================================

SWExp.Ammo            = SWExp.Ammo or {}
SWExp.Ammo.PlayerData = SWExp.Ammo.PlayerData or {}  -- [steamID64][charID] = { [ammoType]=count }
SWExp.Ammo._AllowGive = SWExp.Ammo._AllowGive or {}

-- ============================================================
-- 0. ТАБЛИЦА В БД
-- ============================================================

hook.Add("DatabaseInitialized", "SWExp::Ammo::CreateTable", function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_ammo (
            character_id INT NOT NULL,
            ammo_type    VARCHAR(64) NOT NULL,
            amount       INT NOT NULL DEFAULT 0,
            PRIMARY KEY (character_id, ammo_type)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    ]], function()
        print("[SWExp][Ammo] Таблица swexp_ammo готова.")
    end)
end)

-- ============================================================
-- 1. УТИЛИТЫ
-- ============================================================

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

local function ensureBank(pPlayer, charID)
    local sid = pPlayer:SteamID64()
    SWExp.Ammo.PlayerData[sid] = SWExp.Ammo.PlayerData[sid] or {}
    SWExp.Ammo.PlayerData[sid][charID] = SWExp.Ammo.PlayerData[sid][charID] or {}
    return SWExp.Ammo.PlayerData[sid][charID]
end

local function getBank(pPlayer, charID)
    local sid = pPlayer:SteamID64()
    return SWExp.Ammo.PlayerData[sid] and SWExp.Ammo.PlayerData[sid][charID]
end

-- ============================================================
-- 2. SNAPSHOT — снять текущий резерв игрока в банк
-- ============================================================

function SWExp.Ammo:Snapshot(pPlayer, charID)
    charID = charID or getCharID(pPlayer)
    if not charID then return end
    local bank = ensureBank(pPlayer, charID)

    -- HL2 ammo (AR2/Pistol/SMG1)
    for _, t in pairs(SWExp.Ammo.Types or {}) do
        local id = game.GetAmmoID(t.name)
        if id and id >= 0 then
            bank[t.name] = pPlayer:GetAmmoCount(id) or 0
        end
    end

    -- ArcCW гранаты — clip каждого SWEP
    for _, g in ipairs(SWExp.Ammo.Grenades or {}) do
        local wep = pPlayer:GetWeapon(g.swep)
        if IsValid(wep) then
            bank[g.ammo] = wep:Clip1() or 0
        end
        -- Если SWEP'а нет на руках — оставляем в банке то, что было
    end
end

-- ============================================================
-- 3. ЗАГРУЗКА / СОХРАНЕНИЕ
-- ============================================================

function SWExp.Ammo:Load(pPlayer, charID, callback)
    charID = charID or getCharID(pPlayer)
    if not charID then if callback then callback({}) end return end

    MySQLite.query(
        string.format("SELECT ammo_type, amount FROM swexp_ammo WHERE character_id = %d", charID),
        function(rows)
            local data = {}
            for _, row in ipairs(rows or {}) do
                data[row.ammo_type] = tonumber(row.amount) or 0
            end
            local sid = pPlayer:SteamID64()
            SWExp.Ammo.PlayerData[sid] = SWExp.Ammo.PlayerData[sid] or {}
            SWExp.Ammo.PlayerData[sid][charID] = data
            if callback then callback(data) end
        end
    )
end

-- Сохраняем КОНКРЕТНОГО персонажа (не текущего!).
-- Используется при смене персонажа: нужно записать СТАРЫЙ charID до того,
-- как игрок ушёл на новый.
function SWExp.Ammo:SaveForChar(pPlayer, charID, doSnapshot)
    if not IsValid(pPlayer) or not charID then return end
    if doSnapshot ~= false then
        -- Снимок имеет смысл только для текущего активного персонажа
        if getCharID(pPlayer) == charID then
            self:Snapshot(pPlayer, charID)
        end
    end
    local bank = getBank(pPlayer, charID)
    if not bank then return end

    MySQLite.query(string.format("DELETE FROM swexp_ammo WHERE character_id = %d", charID),
        function()
            for ammoType, amount in pairs(bank) do
                if (amount or 0) > 0 then
                    MySQLite.query(string.format(
                        "INSERT INTO swexp_ammo (character_id, ammo_type, amount) VALUES (%d, %s, %d)",
                        charID, MySQLite.SQLStr(ammoType), amount
                    ))
                end
            end
        end
    )
end

-- Сохраняет текущего активного персонажа
function SWExp.Ammo:Save(pPlayer)
    local cid = getCharID(pPlayer)
    if not cid then return end
    self:SaveForChar(pPlayer, cid, true)
end

-- ============================================================
-- 4. ВЫДАЧА (с обходом обёртки GiveAmmo)
-- ============================================================

function SWExp.Ammo:Give(pPlayer, ammoType, amount)
    if not IsValid(pPlayer) or not ammoType or (amount or 0) <= 0 then return false end
    local charID = getCharID(pPlayer)
    if not charID then return false end
    local bank = ensureBank(pPlayer, charID)
    bank[ammoType] = (bank[ammoType] or 0) + amount

    -- HL2 тип
    local id = game.GetAmmoID(ammoType)
    if id and id >= 0 then
        SWExp.Ammo._AllowGive[pPlayer] = true
        if SWExp.Ammo._OriginalGiveAmmo then
            SWExp.Ammo._OriginalGiveAmmo(pPlayer, amount, ammoType, true)
        else
            pPlayer:GiveAmmo(amount, ammoType, true)
        end
        SWExp.Ammo._AllowGive[pPlayer] = nil
    else
        -- ArcCW граната: добавляем в clip, если SWEP уже на руках
        for _, gr in ipairs(SWExp.Ammo.Grenades or {}) do
            if gr.ammo == ammoType then
                local wep = pPlayer:GetWeapon(gr.swep)
                if IsValid(wep) then
                    wep:SetClip1((wep:Clip1() or 0) + amount)
                end
                break
            end
        end
    end
    return true
end

-- Применить сохранённый запас к игроку (после спавна/выбора персонажа)
function SWExp.Ammo:Apply(pPlayer)
    local charID = getCharID(pPlayer)
    if not charID then return end
    local bank = getBank(pPlayer, charID)
    if not bank then return end

    for ammoType, amount in pairs(bank) do
        if (amount or 0) > 0 then
            local id = game.GetAmmoID(ammoType)
            if id and id >= 0 then
                pPlayer:SetAmmo(amount, ammoType)
            else
                -- ArcCW: ждём, пока SWEP появится (выдаётся в EquipItem)
                for _, gr in ipairs(SWExp.Ammo.Grenades or {}) do
                    if gr.ammo == ammoType then
                        timer.Simple(0.4, function()
                            if IsValid(pPlayer) then
                                local wep = pPlayer:GetWeapon(gr.swep)
                                if IsValid(wep) then wep:SetClip1(amount) end
                            end
                        end)
                        break
                    end
                end
            end
        end
    end
end

-- ============================================================
-- 5. ИНТЕГРАЦИЯ С ЖИЗНЕННЫМ ЦИКЛОМ ПЕРСОНАЖА
--    Трекаем _SWExp_PrevCharID, чтобы при выборе НОВОГО персонажа
--    сохранить банк ПРЕДЫДУЩЕГО.
-- ============================================================

hook.Add("SWExp::CharacterSelected", "SWExp::Ammo::OnCharSelect", function(pPlayer, char)
    if not IsValid(pPlayer) or not char then return end
    local newCharID = tonumber(char.id)

    -- 1. Сохранить ПРЕДЫДУЩЕГО персонажа (если был)
    local prev = pPlayer._SWExp_PrevCharID
    if prev and prev ~= newCharID then
        -- Снимок нельзя — у игрока уже стоит SWExp_ActiveChar = новый.
        -- Кеш PlayerData[sid][prev] был обновлён прошлым Snapshot/Save,
        -- так что просто сбрасываем в БД, что лежит в кеше.
        SWExp.Ammo:SaveForChar(pPlayer, prev, false)
    end

    -- 2. Загрузить НОВОГО и применить
    SWExp.Ammo:Load(pPlayer, newCharID, function()
        timer.Simple(0.3, function()
            if IsValid(pPlayer) then SWExp.Ammo:Apply(pPlayer) end
        end)
    end)

    pPlayer._SWExp_PrevCharID = newCharID
end)

-- Перед сменой / выходом — снимок (чтобы _SWExp_PrevCharID имел свежие данные)
hook.Add("DoPlayerDeath", "SWExp::Ammo::OnDeath", function(pPlayer)
    SWExp.Ammo:Snapshot(pPlayer)
    SWExp.Ammo:Save(pPlayer)
end)

hook.Add("PlayerDisconnected", "SWExp::Ammo::OnDisconnect", function(pPlayer)
    SWExp.Ammo:Save(pPlayer)
    SWExp.Ammo._AllowGive[pPlayer] = nil
end)

hook.Add("ShutDown", "SWExp::Ammo::OnShutdown", function()
    for _, ply in ipairs(player.GetAll()) do
        SWExp.Ammo:Save(ply)
    end
end)

-- Респавн на той же роли → Apply (восстанавливаем после StripAmmo)
hook.Add("PlayerSpawn", "SWExp::Ammo::OnSpawn", function(pPlayer)
    timer.Simple(0.5, function()
        if IsValid(pPlayer) and pPlayer:Alive() then
            SWExp.Ammo:Apply(pPlayer)
        end
    end)
end)

-- Автосейв раз в 60 секунд
timer.Create("SWExp::Ammo::AutoSave", 60, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then SWExp.Ammo:Save(ply) end
    end
end)

-- ============================================================
-- 6. ИНТЕГРАЦИЯ С ИНВЕНТАРЁМ (Equip / Unequip)
-- ============================================================

hook.Add("SWExp::ItemEquipped", "SWExp::Ammo::OnEquip", function(pPlayer, slotType, slotIndex, itemID, amount)
    if not IsValid(pPlayer) then return end
    local itemData = SWExp.Inventory and SWExp.Inventory:GetItemData(itemID)
    if not itemData then return end

    -- Гранаты теперь обрабатывает модуль grenade/sv_grenade.lua —
    -- никаких SWEP не выдаётся при Equip.

    -- Обычное оружие → применить сохранённый резерв
    if itemData.weaponClass then
        timer.Simple(0.15, function()
            if IsValid(pPlayer) then SWExp.Ammo:Apply(pPlayer) end
        end)
    end
end)

-- ============================================================
-- 7. ОБРАБОТКА ИСПОЛЬЗОВАНИЯ ПАЧКИ
-- ============================================================

function SWExp.Ammo.UseBox(pPlayer, item)
    local box = SWExp.Ammo.BoxesByItemID and SWExp.Ammo.BoxesByItemID[item.itemID]
    if not box then return false end
    SWExp.Ammo:Give(pPlayer, box.ammoType, box.count)
    pPlayer:EmitSound("items/ammo_pickup.wav", 60, 100, 0.6)
    return true
end

-- ============================================================
-- 8. (УДАЛЕНО) Автоснятие пустых гранат — теперь это делает
--    модуль grenade/sv_grenade.lua после броска.
-- ============================================================

--[[ устаревший код, оставлен закомментированным для истории
local function RemoveGrenadeFromSlot(pPlayer, gr)
    if not IsValid(pPlayer) or not gr then return end
    pPlayer:StripWeapon(gr.swep)

    local sid = pPlayer:SteamID64()
    local cid = getCharID(pPlayer)
    if not cid then return end

    -- Очистить банк (граната израсходована)
    local bank = SWExp.Ammo.PlayerData[sid] and SWExp.Ammo.PlayerData[sid][cid]
    if bank then bank[gr.ammo] = 0 end

    -- Найти и убрать слот в equipment
    local equip = SWExp.Inventory
                  and SWExp.Inventory.PlayerEquipment
                  and SWExp.Inventory.PlayerEquipment[sid]
                  and SWExp.Inventory.PlayerEquipment[sid][cid]
    if not equip then return end

    for slotType, slots in pairs(equip) do
        if istable(slots) then
            for slotIdx, slotItem in pairs(slots) do
                if slotItem and slotItem.itemID == gr.key then
                    equip[slotType][slotIdx] = nil
                    MySQLite.query(string.format(
                        "DELETE FROM swexp_equipment WHERE character_id = %d AND slot_type = %s AND slot_index = %d",
                        cid, MySQLite.SQLStr(slotType), slotIdx
                    ))
                    if SWExp.Inventory.SyncInventoryToClient then
                        SWExp.Inventory:SyncInventoryToClient(pPlayer)
                    end
                end
            end
        end
    end
end

-- Защита от ложного срабатывания в первые секунды после Equip:
-- помечаем время выдачи гранаты, и проверяем clip только спустя >0.5 сек.
SWExp.Ammo._GrenadeEquipTime = SWExp.Ammo._GrenadeEquipTime or {}

hook.Add("SWExp::ItemEquipped", "SWExp::Ammo::TrackGrenadeEquipTime", function(pPlayer, _, _, itemID)
    if SWExp.Ammo.GrenadesByKey and SWExp.Ammo.GrenadesByKey[itemID] then
        SWExp.Ammo._GrenadeEquipTime[pPlayer] = CurTime()
    end
end)

local function CheckPlayerEmptyGrenades(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local equipTime = SWExp.Ammo._GrenadeEquipTime[ply] or 0
    if CurTime() - equipTime < 0.6 then return end -- защита от гонки

    for _, gr in ipairs(SWExp.Ammo.Grenades or {}) do
        local wep = ply:GetWeapon(gr.swep)
        if IsValid(wep) and (wep:Clip1() or 0) <= 0 then
            -- Дополнительная страховка: проверим, что и ArcCW ammo резерв = 0.
            -- ArcCW регистрирует свои ammo type'ы, и game.GetAmmoID может их найти.
            local id = game.GetAmmoID(gr.ammo)
            local reserve = (id and id >= 0) and (ply:GetAmmoCount(id) or 0) or 0
            if reserve <= 0 then
                RemoveGrenadeFromSlot(ply, gr)
            end
        end
    end
end

--]]
-- конец удалённого блока auto-unequip пустых гранат

-- ============================================================
-- 9. БЛОК ВАНИЛЬНОЙ ВЫДАЧИ ПАТРОНОВ ОТ Give() и БАЗ ОРУЖИЯ
-- ============================================================

local PLAYER_META = FindMetaTable("Player")
if PLAYER_META and not SWExp.Ammo._OriginalGiveAmmo then
    SWExp.Ammo._OriginalGiveAmmo = PLAYER_META.GiveAmmo
    PLAYER_META.GiveAmmo = function(self, amount, ammoType, hidePopup)
        if SWExp.Ammo._AllowGive[self] == true then
            return SWExp.Ammo._OriginalGiveAmmo(self, amount, ammoType, hidePopup)
        end
        return 0
    end
    print("[SWExp][Ammo] Player:GiveAmmo обёрнут (разрешён только нашему модулю)")
end

local IGNORED_WEAPONS = {
    ["mvp_perfecthands"] = true,
    ["weapon_physgun"]   = true,
    ["gmod_tool"]        = true,
    ["gmod_camera"]      = true,
    ["weapon_fists"]     = true,
}

local function SyncAmmoToBank(pPlayer)
    if not IsValid(pPlayer) then return end
    local cid = getCharID(pPlayer)
    if not cid then return end
    local bank = getBank(pPlayer, cid) or {}

    -- Все ammo type'ы у текущих SWEP'ов
    for _, w in ipairs(pPlayer:GetWeapons()) do
        if not IsValid(w) then continue end
        if IGNORED_WEAPONS[w:GetClass()] then continue end
        local atID = w:GetPrimaryAmmoType()
        if atID and atID >= 0 then
            local atName = game.GetAmmoName(atID)
            if atName then
                local saved = bank[atName] or 0
                pPlayer:SetAmmo(saved, atName)
            end
        end
    end
end

hook.Add("WeaponEquip", "SWExp::Ammo::ZeroVanillaAmmo", function(weapon, pPlayer)
    if not IsValid(pPlayer) or not pPlayer:IsPlayer() then return end
    if not IsValid(weapon) then return end
    if IGNORED_WEAPONS[weapon:GetClass()] then return end
    if SWExp.Ammo._AllowGive[pPlayer] then return end

    for _, delay in ipairs({0, 0.05, 0.1, 0.3, 0.5, 1.0}) do
        timer.Simple(delay, function()
            if IsValid(pPlayer) and not SWExp.Ammo._AllowGive[pPlayer] then
                SyncAmmoToBank(pPlayer)
            end
        end)
    end
end)

print("[SWExp][Ammo] sv_ammo.lua загружен (v2)")
