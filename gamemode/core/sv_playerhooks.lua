-- core/sv_playerhooks.lua
-- Загрузка игрока при входе

if CLIENT then return end

-- ============================================================
-- PlayerInitialSpawn → ждём полной загрузки клиента
-- ============================================================

function GM:PlayerInitialSpawn(pPlayer)
    hook.Add('SetupMove', pPlayer, function(self, ply, _, cmd)
        if self == ply and not cmd:IsForced() then
            hook.Run('SWExp::PlayerFullLoad', self)
            hook.Remove('SetupMove', self)
        end
    end)
end

-- ============================================================
-- PlayerFullLoad → ищем/создаём запись в swexp_players
-- ============================================================

hook.Add('SWExp::PlayerFullLoad', 'SWExp::LoadPlayerData', function(pPlayer)
    local sSteamID = pPlayer:SteamID()

    MySQLite.query(
        string.format('SELECT * FROM `swexp_players` WHERE steamid = %s;', MySQLite.SQLStr(sSteamID)),
        function(tData)
            if tData and istable(tData) and tData[1] then
                pPlayer.SWExp_ID             = tonumber(tData[1].id)
                pPlayer.SWExp_CharSlots      = tonumber(tData[1].character_slots) or 1
                pPlayer.SWExp_DonateCurrency = tonumber(tData[1].donate_currency) or 0
                pPlayer.SWExp_Characters     = {}

                hook.Run('SWExp::PlayerIDRetrieved', pPlayer, tonumber(tData[1].id))
            else
                MySQLite.query(
                    string.format(
                        'INSERT INTO `swexp_players` (steamid, community_id, character_slots, donate_currency) VALUES (%s, %s, %s, %s);',
                        MySQLite.SQLStr(pPlayer:SteamID()),
                        MySQLite.SQLStr(pPlayer:SteamID64()),
                        1, 0
                    ),
                    function(_, insertID)
                        pPlayer.SWExp_ID             = insertID
                        pPlayer.SWExp_CharSlots      = 1
                        pPlayer.SWExp_DonateCurrency = 0
                        pPlayer.SWExp_Characters     = {}

                        hook.Run('SWExp::PlayerIDRetrieved', pPlayer, insertID)
                    end
                )
            end
        end
    )
end)

-- ============================================================
-- PlayerIDRetrieved → грузим персонажей, открываем меню
-- ============================================================

hook.Add('SWExp::PlayerIDRetrieved', 'SWExp::LoadCharacters', function(pPlayer, playerID)
    MySQLite.query(
        string.format('SELECT * FROM `swexp_characters` WHERE player_id = %s ORDER BY id ASC;',
            MySQLite.SQLStr(playerID)),
        function(tChars)
            tChars = tChars or {}

            -- Нормализуем модели (та же логика, что и в SWExp.Chars:Load)
            local DEFAULT_MODEL = 'models/player/olive/cadet/cadet.mdl'
            for _, char in ipairs(tChars) do
                if not char.model or char.model == "" or char.model == "NULL" then
                    char.model = DEFAULT_MODEL
                end
            end

            -- Добавляем виртуального ADMIN-персонажа ТОЛЬКО в локальный список.
            -- player_id = -1 и _virtual = true гарантируют, что он никогда
            -- не попадёт ни в один SQL-запрос (INSERT / UPDATE / DELETE).
            if pPlayer:IsAdmin() or pPlayer:IsSuperAdmin() then
                table.insert(tChars, {
                    id           = -1,
                    player_id    = -1,
                    clone_number = "####",
                    callsign     = pPlayer.SWExp_RealSteamName or pPlayer:Nick(),
                    ['rank']     = "ADMIN",
                    model        = DEFAULT_MODEL,
                    _virtual     = true,
                })
            end

            pPlayer.SWExp_Characters = tChars

            -- Открываем меню выбора персонажа
            netstream.Start(pPlayer, 'SWExp::OpenCharSelect', pPlayer.SWExp_Characters)
        end
    )
end)

-- ============================================================
-- Стандартные хуки GMod
-- ============================================================

function GM:PlayerSpawn(pPlayer)
    pPlayer:StripWeapons()
    pPlayer:StripAmmo()

    pPlayer:SetMaxHealth(100)
    pPlayer:SetHealth(100)
    pPlayer:SetArmor(0)

    -- Применяем скорость с учётом брони
    if SWExp.Armor and SWExp.Armor.ApplyArmorSpeed then
        SWExp.Armor.ApplyArmorSpeed(pPlayer)
    end
end

-- ============================================================
-- Выдача базового оружия
-- Вешаем на несколько точек, потому что pPlayer:Spawn() из
-- sv_chars.lua не всегда триггерит GM:PlayerLoadout.
-- ============================================================

local function SWExp_GiveDefaultWeapons(pPlayer)
    if not IsValid(pPlayer) then return end
    if not pPlayer:Alive() then return end

    -- Базовое оружие для всех игроков (true → без стартового запаса патронов)
    pPlayer:Give('mvp_perfecthands', true)

    -- Если выбран админский персонаж (rank == "ADMIN") —
    -- дополнительно выдаём physgun и tool gun.
    -- Привязка идёт к роли персонажа, а не к группе аккаунта.
    local char = pPlayer.SWExp_ActiveChar
    if char and char['rank'] == 'ADMIN' then
        pPlayer:Give('weapon_physgun', true)
        pPlayer:Give('gmod_tool', true)
    end

    pPlayer:SelectWeapon('mvp_perfecthands')
end

function GM:PlayerLoadout(pPlayer)
    SWExp_GiveDefaultWeapons(pPlayer)
    return true
end

-- На случай если PlayerLoadout не сработает после pPlayer:Spawn()
-- (см. SWExp.Chars:Choose в modules/sv_chars.lua) — выдаём
-- оружие отложенно на следующий тик после выбора персонажа.
hook.Add('SWExp::CharacterSelected', 'SWExp::GiveLoadoutOnCharSelect', function(pPlayer, char)
    timer.Simple(0, function()
        SWExp_GiveDefaultWeapons(pPlayer)
    end)
end)

-- Запасной триггер на обычный респавн (после смерти и т.п.) —
-- если по какой-то причине GM:PlayerLoadout проглатывается.
hook.Add('PlayerSpawn', 'SWExp::GiveLoadoutOnSpawn', function(pPlayer)
    timer.Simple(0, function()
        SWExp_GiveDefaultWeapons(pPlayer)
    end)
end)

function GM:PlayerSelectSpawn(pPlayer)
    local spawns = ents.FindByClass('swexp_spawn')
    if #spawns > 0 then
        return spawns[math.random(#spawns)]
    end
    return self.BaseClass.PlayerSelectSpawn(self, pPlayer)
end

function GM:PlayerDeath(victim, inflictor, attacker)
    hook.Run('SWExp::PlayerDied', victim, inflictor, attacker)
end

function GM:PlayerDisconnected(pPlayer)
    hook.Run('SWExp::PlayerDisconnecting', pPlayer)
end

-- ============================================================
-- Реалистичный урон от падения
-- ============================================================

function GM:GetFallDamage(pPlayer, speed)
    -- Формула вычисляет урон на основе скорости столкновения с землей (speed).
    -- При падении с небольшой высоты урон будет 0, со средней - снимет часть ХП, с большой - убьет.
    speed = tonumber(speed) or 0
    local damage = (speed - 526) * 0.25

    -- Защита от эксплойтов: если движок/аддон сообщит аномально большую скорость
    -- (например teleport/noclip exit с инерцией), урон ограничен сверху 200 HP.
    return math.Clamp(damage, 0, 200)
end