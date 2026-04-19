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
            pPlayer.SWExp_Characters = tChars or {}

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

function GM:PlayerLoadout(pPlayer)
    return true
end

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
    local damage = (speed - 526) * 0.25
    
    return math.max(0, damage) -- Урон не может быть отрицательным
end