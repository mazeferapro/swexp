-- ============================================================
-- Star Wars: Expedition — Менеджер врагов
-- modules/sv_enemy_manager.lua
--
-- Реализация механики "Охотники Пустоши":
--   • ThreatTier игрока задаётся проходом через swexp_tiered_gateway.
--   • Noise (шум) растёт от стрельбы, harvest, scan, езды, урона.
--   • Целевое число врагов = f(ThreatTier × Noise), с капами.
--   • Спавн вне LOS, на дистанции, с звуковым предвестником.
--   • Вход в safezone → сброс тира и деспавн пула игрока.
--   • Выход из safezone → восстановление LastThreatTier.
--   • NPC, вошедший в safezone, удаляется.
-- ============================================================

if not SERVER then return end

SWExp.EnemyMgr = SWExp.EnemyMgr or {}
local Mgr = SWExp.EnemyMgr

-- ============================================================
-- Сетевые сообщения (для HUD)
-- ============================================================

util.AddNetworkString("SWExp::Enemy_NoiseUpdate")

-- ============================================================
-- Состояние
-- ============================================================

-- [steamID64] = { ply, tier, lastTier, noise, enemies = {ent=true,...}, lastHighNoise, isInSafezone, lastNoiseSent, lastNoiseSendTime }
Mgr.Pools = Mgr.Pools or {}

-- Очередь отложенных спавнов: { { pool, tier, spawnAt, omenPos, omenSound, placeholderCreated } ... }
Mgr.PendingSpawns = Mgr.PendingSpawns or {}

-- Глобальный счётчик врагов по тирам (для globalCap)
-- [tier] = count
Mgr.GlobalCount = Mgr.GlobalCount or { [1]=0, [2]=0, [3]=0, [4]=0 }

-- Маркировка: [ent:EntIndex()] = { tier, ownerSID }
Mgr.EnemyMeta = Mgr.EnemyMeta or {}

-- ============================================================
-- Утилиты
-- ============================================================

local function Cfg()
    return SWExp.EnemyConfig
end

local function Verbose(msg)
    local c = Cfg()
    if c and c.Debug and c.Debug.verbose then
        print("[SWExp/Enemy] " .. tostring(msg))
    end
end

local function GetOrCreatePool(ply)
    if not IsValid(ply) then return nil end
    local sid = ply:SteamID64()
    if not sid then return nil end
    local p = Mgr.Pools[sid]
    if not p then
        p = {
            ply               = ply,
            sid               = sid,
            tier              = 1,   -- текущий тир угрозы (1 = первая зона по умолчанию)
            lastTier          = 1,   -- тир до входа в safezone
            noise             = Cfg() and Cfg().Noise.startValue or 0,
            enemies           = {},  -- [ent] = true
            lastHighNoise     = 0,   -- CurTime() когда шум был выше порога
            isInSafezone      = false,
            lastNoiseSent     = -1,
            lastNoiseSendTime = 0,
            lastWaveSpawnTime = 0,
        }
        Mgr.Pools[sid] = p
    end
    p.ply = ply
    return p
end

local function RemovePool(sid)
    local p = Mgr.Pools[sid]
    if not p then return end
    -- Удаляем всех врагов пула
    for ent, _ in pairs(p.enemies) do
        if IsValid(ent) then
            Mgr.OnEnemyRemoved(ent)
            ent:Remove()
        end
    end
    Mgr.Pools[sid] = nil
end

-- Вызывается ПЕРЕД удалением NPC — корректирует счётчики
function Mgr.OnEnemyRemoved(ent)
    if not IsValid(ent) then return end
    local meta = Mgr.EnemyMeta[ent:EntIndex()]
    if not meta then return end
    local tier = meta.tier
    if tier and Mgr.GlobalCount[tier] then
        Mgr.GlobalCount[tier] = math.max(0, Mgr.GlobalCount[tier] - 1)
    end
    -- Убираем из пула владельца
    local p = Mgr.Pools[meta.ownerSID]
    if p and p.enemies[ent] then
        p.enemies[ent] = nil
    end
    Mgr.EnemyMeta[ent:EntIndex()] = nil
end

-- Подсчитать сколько живых врагов в пуле
local function CountPoolEnemies(pool)
    local n = 0
    for ent, _ in pairs(pool.enemies) do
        if IsValid(ent) and ent:Health() > 0 then
            n = n + 1
        else
            pool.enemies[ent] = nil
        end
    end
    return n
end

-- ============================================================
-- ШУМ
-- ============================================================

local function SendNoiseToPlayer(pool, force)
    if not IsValid(pool.ply) then return end
    local now = CurTime()
    local roundedNoise = math.Round(pool.noise)
    -- Отправляем только при изменении или раз в секунду
    if not force and roundedNoise == pool.lastNoiseSent and (now - pool.lastNoiseSendTime) < 1 then
        return
    end
    pool.lastNoiseSent     = roundedNoise
    pool.lastNoiseSendTime = now

    net.Start("SWExp::Enemy_NoiseUpdate")
        net.WriteUInt(roundedNoise, 8)
        net.WriteUInt(pool.tier or 0, 4)
    net.Send(pool.ply)
end

function Mgr.AddNoise(ply, amount, reason)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local pool = GetOrCreatePool(ply)
    if not pool then return end
    local c = Cfg()
    if not c then return end
    local old = pool.noise
    pool.noise = math.Clamp(pool.noise + (amount or 0), 0, c.Noise.max)
    if pool.noise > c.Noise.stealthThreshold then
        pool.lastHighNoise = CurTime()
    end
    if math.Round(pool.noise) ~= math.Round(old) then
        SendNoiseToPlayer(pool, false)
    end
    Verbose(string.format("%s +%.1f шума (%s) → %.1f",
        ply:Nick(), amount or 0, reason or "?", pool.noise))
end

function Mgr.SetNoise(ply, value)
    if not IsValid(ply) then return end
    local pool = GetOrCreatePool(ply)
    if not pool then return end
    local c = Cfg()
    if not c then return end
    pool.noise = math.Clamp(value or 0, 0, c.Noise.max)
    SendNoiseToPlayer(pool, true)
end

-- ============================================================
-- ТИР УГРОЗЫ
-- ============================================================

function Mgr.SetThreatTier(ply, tier)
    if not IsValid(ply) then return end
    local pool = GetOrCreatePool(ply)
    if not pool then return end
    pool.tier     = math.Clamp(tier or 0, 0, 4)
    pool.lastTier = pool.tier  -- синхронизируем lastTier чтобы вход в safezone не откатывал к старому значению
    ply:SetNWInt("SWExp_ThreatTier", pool.tier)
    Verbose(string.format("%s → ThreatTier=%d", ply:Nick(), pool.tier))
    SendNoiseToPlayer(pool, true)
end

function Mgr.GetThreatTier(ply)
    if not IsValid(ply) then return 0 end
    local pool = Mgr.Pools[ply:SteamID64() or ""]
    return (pool and pool.tier) or 0
end

-- ============================================================
-- SAFEZONE DETECTION
-- ============================================================

local function IsPlayerInSafezone(ply)
    if not SWExp.IsInSafezone then return false end
    local inZone = SWExp.IsInSafezone(ply:GetPos(), 0)
    return inZone
end

-- Вход игрока в safezone
local function OnPlayerEnterSafezone(pool)
    if not IsValid(pool.ply) then return end
    pool.isInSafezone = true
    if pool.tier > 0 then
        pool.lastTier = pool.tier
    end
    pool.tier  = 0
    pool.noise = 0
    pool.ply:SetNWInt("SWExp_ThreatTier", 0)
    SendNoiseToPlayer(pool, true)
    -- Деспавн всех врагов пула
    for ent, _ in pairs(pool.enemies) do
        if IsValid(ent) then
            Mgr.OnEnemyRemoved(ent)
            ent:Remove()
        end
    end
    pool.enemies = {}
    Verbose(string.format("%s вошёл в safezone (lastTier=%d)", pool.ply:Nick(), pool.lastTier))
end

-- Выход игрока из safezone
local function OnPlayerExitSafezone(pool)
    if not IsValid(pool.ply) then return end
    pool.isInSafezone = false
    local restore = (pool.lastTier and pool.lastTier > 0) and pool.lastTier or 1
    pool.tier = restore
    pool.ply:SetNWInt("SWExp_ThreatTier", pool.tier)
    SendNoiseToPlayer(pool, true)
    Verbose(string.format("%s вышел из safezone → tier=%d", pool.ply:Nick(), pool.tier))
end

-- ============================================================
-- ВЫБОР ТОЧКИ СПАВНА
-- ============================================================

local function TryFindSpawnPoint(pool)
    if not IsValid(pool.ply) then return nil end
    local c = Cfg()
    if not c then return nil end

    local sys       = c.System
    local plyPos    = pool.ply:GetPos()
    local minD      = sys.spawnMinDist
    local maxD      = sys.spawnMaxDist
    local maxTries  = sys.spawnMaxTries
    local szBuf     = sys.safezoneBuffer

    -- Список всех живых игроков для LOS-фильтра
    local viewers = {}
    for _, pl in ipairs(player.GetAll()) do
        if IsValid(pl) and pl:Alive() then
            table.insert(viewers, pl)
        end
    end

    for _ = 1, maxTries do
        -- Случайная точка в кольце
        local ang    = math.Rand(0, math.pi * 2)
        local dist   = math.Rand(minD, maxD)
        local cand   = plyPos + Vector(math.cos(ang) * dist, math.sin(ang) * dist, 0)

        -- Ищем пол: трейс вниз
        local tr = util.TraceLine({
            start  = cand + Vector(0, 0, 500),
            endpos = cand - Vector(0, 0, 3000),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if not tr.Hit then continue end
        cand = tr.HitPos + Vector(0, 0, 16)

        -- Проверка: не в safezone + буфер
        if SWExp.IsInSafezone and SWExp.IsInSafezone(cand, szBuf) then
            continue
        end

        -- LOS-фильтр: ни один игрок не должен видеть точку
        local seen = false
        for _, pl in ipairs(viewers) do
            local plEye = pl:EyePos()
            local los = util.TraceLine({
                start  = plEye,
                endpos = cand + Vector(0, 0, 40),
                mask   = MASK_OPAQUE,
                filter = pl,
            })
            if los.Fraction >= 0.99 then
                seen = true
                break
            end
        end
        if seen then continue end

        -- Проверка что точка в пределах мира
        if not util.IsInWorld(cand) then continue end

        -- Навмеш-валидация (если есть)
        if navmesh and navmesh.GetNearestNavArea then
            local area = navmesh.GetNearestNavArea(cand, false, 200, false, true, -2)
            -- Если навмеша нет совсем — разрешаем (фолбэк на обычную проверку)
            -- Если есть, но area не нашлась близко — пропускаем
            if navmesh.GetNavAreaCount and navmesh.GetNavAreaCount() > 0 then
                if not area or not IsValid(area) then continue end
            end
        end

        return cand
    end

    return nil
end

-- ============================================================
-- СПАВН
-- ============================================================

local function ApplyEnemyConfig(npc, tcfg, ownerPool)
    if not IsValid(npc) then return end

    -- HP
    npc:SetHealth(tcfg.hp)
    npc:SetMaxHealth(tcfg.hp)

    -- Зрение (не все NPC поддерживают, не критично если игнорируется)
    npc:SetKeyValue("SightDistance", tostring(tcfg.viewRange))

    -- Агрессия: сразу в "альтертный" режим + установка цели
    if tcfg.aggression and tcfg.aggression > 0 then
        if math.Rand(0, 1) < tcfg.aggression and IsValid(ownerPool.ply) then
            if npc.SetEnemy then
                npc:AddEntityRelationship(ownerPool.ply, D_HT, 99)
            end
            if npc.SetTarget then pcall(function() npc:SetTarget(ownerPool.ply) end) end
        end
    end
end

local function ActuallySpawnEnemy(pool, tier, pos)
    if not IsValid(pool.ply) then return end
    local tcfg = Cfg().GetTier(tier)
    if not tcfg then return end

    -- Ещё раз проверяем глобальный кап
    if (Mgr.GlobalCount[tier] or 0) >= (tcfg.globalCap or 999) then
        Verbose(string.format("Global cap reached for tier %d — skip", tier))
        return
    end

    -- Выбираем случайный класс
    local classes = tcfg.npcClasses or {}
    if #classes == 0 then
        Verbose("No NPC classes for tier " .. tier)
        return
    end
    local class = classes[math.random(#classes)]

    local npc = ents.Create(class)
    if not IsValid(npc) then
        Verbose("Failed to create NPC: " .. tostring(class))
        return
    end

    npc:SetPos(pos)
    npc:SetAngles(Angle(0, math.random(0, 359), 0))
    npc:Spawn()
    npc:Activate()

    if not IsValid(npc) then return end

    ApplyEnemyConfig(npc, tcfg, pool)

    -- Регистрация
    pool.enemies[npc] = true
    Mgr.EnemyMeta[npc:EntIndex()] = {
        tier     = tier,
        ownerSID = pool.sid,
    }
    Mgr.GlobalCount[tier] = (Mgr.GlobalCount[tier] or 0) + 1

    -- Хук на удаление (для корректного декремента)
    npc:CallOnRemove("SWExp::EnemyCleanup", function(removed)
        Mgr.OnEnemyRemoved(removed)
    end)

    Verbose(string.format("Spawned %s (tier %d) at (%d, %d, %d) for %s",
        class, tier, pos.x, pos.y, pos.z, pool.ply:Nick()))
end

-- Планирует спавн врага с предвестником
local function SchedulePendingSpawn(pool, tier, pos)
    local tcfg = Cfg().GetTier(tier)
    if not tcfg then return end

    local delay = math.Rand(tcfg.omenSoundMin or 3, tcfg.omenSoundMax or 5)

    -- Проигрываем звуковой предвестник в точке будущего спавна
    local sounds = tcfg.omenSounds or {}
    if #sounds > 0 then
        local snd = sounds[math.random(#sounds)]
        sound.Play(snd, pos, 90, math.random(85, 105), 1.0)
    end

    table.insert(Mgr.PendingSpawns, {
        pool    = pool,
        tier    = tier,
        pos     = pos,
        spawnAt = CurTime() + delay,
    })
end

-- Обрабатывает отложенные спавны
local function ProcessPendingSpawns()
    local now = CurTime()
    for i = #Mgr.PendingSpawns, 1, -1 do
        local ps = Mgr.PendingSpawns[i]
        if now >= ps.spawnAt then
            table.remove(Mgr.PendingSpawns, i)
            -- Повторная валидация пула и условий
            if IsValid(ps.pool.ply) and ps.pool.tier == ps.tier and not ps.pool.isInSafezone then
                -- Точка всё ещё не в safezone?
                local sys = Cfg().System
                if not (SWExp.IsInSafezone and SWExp.IsInSafezone(ps.pos, sys.safezoneBuffer)) then
                    ActuallySpawnEnemy(ps.pool, ps.tier, ps.pos)
                end
            end
        end
    end
end

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ ПУЛА
-- ============================================================

local function UpdatePool(pool, dt)
    if not IsValid(pool.ply) then
        RemovePool(pool.sid)
        return
    end

    local c = Cfg()
    if not c then return end

    -- Safezone detection
    local inSafe = IsPlayerInSafezone(pool.ply)
    if inSafe and not pool.isInSafezone then
        OnPlayerEnterSafezone(pool)
        return
    elseif (not inSafe) and pool.isInSafezone then
        OnPlayerExitSafezone(pool)
    end

    if pool.isInSafezone or pool.tier <= 0 then
        -- Нет активной угрозы — только шум затухает на 0 (в safezone) либо обычно
        local decay = c.Noise.decayPerSecond * dt
        if pool.isInSafezone then decay = decay * 5 end
        if pool.noise > 0 then
            pool.noise = math.max(0, pool.noise - decay)
            SendNoiseToPlayer(pool, false)
        end
        return
    end

    -- Затухание шума
    if pool.noise > 0 then
        pool.noise = math.max(0, pool.noise - c.Noise.decayPerSecond * dt)
    end
    SendNoiseToPlayer(pool, false)

    -- Целевое количество врагов
    local target  = c.GetTargetEnemyCount(pool.tier, pool.noise)
    local current = CountPoolEnemies(pool)

    -- Стелс: ниже порога — grace period и зачистка
    if pool.noise < c.Noise.stealthThreshold then
        if (CurTime() - (pool.lastHighNoise or 0)) >= c.System.lowNoiseGrace then
            -- Удаляем по одному врагу вдали от глаз игрока
            local hideDist = c.System.despawnHideDist
            for ent, _ in pairs(pool.enemies) do
                if IsValid(ent) then
                    local d = ent:GetPos():Distance(pool.ply:GetPos())
                    if d > hideDist then
                        Mgr.OnEnemyRemoved(ent)
                        ent:Remove()
                        break  -- по одному за тик
                    end
                end
            end
        end
        return
    end

    -- Спавн недостающих врагов
    if current < target then
        local tcfg = c.GetTier(pool.tier)
        if not tcfg then return end

        local interval = tcfg.waveSpawnInterval or 3
        if (CurTime() - (pool.lastWaveSpawnTime or 0)) < interval then return end

        -- Глобальный кап по тиру
        if (Mgr.GlobalCount[pool.tier] or 0) >= (tcfg.globalCap or 999) then return end

        local pos = TryFindSpawnPoint(pool)
        if pos then
            pool.lastWaveSpawnTime = CurTime()
            SchedulePendingSpawn(pool, pool.tier, pos)
        end
    end
end

-- ============================================================
-- БАРЬЕР SAFEZONE ДЛЯ NPC
-- ============================================================

local function EnforceSafezoneBarrier()
    if not SWExp.IsInSafezone then return end
    if not SWExp.Safezones or #SWExp.Safezones == 0 then return end
    -- Проверяем только НАШИХ NPC (зарегистрированных в EnemyMeta)
    for idx, meta in pairs(Mgr.EnemyMeta) do
        local ent = Entity(idx)
        if IsValid(ent) then
            if SWExp.IsInSafezone(ent:GetPos(), 0) then
                Mgr.OnEnemyRemoved(ent)
                local pos = ent:GetPos()
                local fx = EffectData()
                fx:SetOrigin(pos)
                fx:SetScale(1)
                util.Effect("ParticleEffect", fx)
                ent:Remove()
            end
        end
    end
end

-- ============================================================
-- УРОН: damageScale
-- ============================================================

hook.Add("EntityTakeDamage", "SWExp::EnemyDamageScale", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) then return end
    local meta = Mgr.EnemyMeta[attacker:EntIndex()]
    if not meta then return end
    local tcfg = Cfg() and Cfg().GetTier(meta.tier)
    if not tcfg then return end
    dmginfo:ScaleDamage(tcfg.damageScale or 1)
end)

-- ============================================================
-- ХУКИ НА СОБЫТИЯ ИГРОКА
-- ============================================================

-- Проход портала — источник ThreatTier
hook.Add("SWExp::PlayerPassedPortal", "SWExp::EnemyMgr_PortalTier", function(ply, srcTier, destTier)
    if not IsValid(ply) then return end
    srcTier = srcTier or 1

    -- Схема: портал тира N соединяет зону N и зону N+1.
    -- По умолчанию игрок в зоне 1. В safezone = 0.
    --   currentTier <= srcTier  -> идёт ВПЕРЁД  -> зона srcTier+1
    --   currentTier >  srcTier  -> идёт НАЗАД   -> зона srcTier
    local pool = Mgr.Pools[ply:SteamID64() or ""]
    local currentTier = (pool and pool.tier) or 1

    local newTier
    if currentTier <= srcTier then
        newTier = srcTier + 1
    else
        newTier = srcTier
    end

    newTier = math.Clamp(newTier, 1, 4)
    Mgr.SetThreatTier(ply, newTier)
    Mgr.AddNoise(ply, 5, "portal")
end)

-- Harvest ноды — фиксированный шум
hook.Add("SWExp::NodeHarvested", "SWExp::EnemyMgr_Harvest", function(ply, node, tier)
    if not IsValid(ply) then return end
    local c = Cfg()
    if not c then return end
    Mgr.AddNoise(ply, c.Noise.Sources.harvest, "harvest")
end)

-- Scan точки — фиксированный шум
hook.Add("SWExp::ResearchScanned", "SWExp::EnemyMgr_Scan", function(ply, point, tier)
    if not IsValid(ply) then return end
    local c = Cfg()
    if not c then return end
    Mgr.AddNoise(ply, c.Noise.Sources.scan, "scan")
end)

-- Выстрел игрока
hook.Add("EntityFireBullets", "SWExp::EnemyMgr_Fire", function(ent, data)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    local wep = ent:GetActiveWeapon()
    local class = IsValid(wep) and wep:GetClass() or ""
    local n = Cfg() and Cfg().GetWeaponShotNoise(class) or 4
    if n > 0 then
        Mgr.AddNoise(ent, n, "shot:" .. class)
    end
end)

-- Получение урона от нашего NPC → небольшой шум (борьба шумная)
hook.Add("EntityTakeDamage", "SWExp::EnemyMgr_PlayerHurtByNPC", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() then return end
    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) then return end
    local meta = Mgr.EnemyMeta[attacker:EntIndex()]
    if not meta then return end
    local c = Cfg()
    if c then
        Mgr.AddNoise(target, c.Noise.Sources.takeDamage, "takeDmg")
    end
end)

-- Взрыв рядом
hook.Add("EntityEmitSound", "SWExp::EnemyMgr_Explosion", function(data)
    -- Пропускаем — слишком дорого парсить все звуки. Будем трекать взрывы через SCR urns?
    -- В данной версии — только граната/RPG отлавливаются через WeaponShot.
end)

-- Езда на технике
-- Ранее был hook.Add("Think", ...), который вхолостую крутился 66 раз/сек
-- ради CurTime()-проверки. Заменено на обычный таймер 1 Hz.
timer.Create("SWExp::EnemyMgr_VehicleNoise", 1, 0, function()
    local c = Cfg()
    if not c then return end
    local perSec = c.Noise.Sources.vehiclePerSec or 0
    if perSec <= 0 then return end
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply:InVehicle() then
            Mgr.AddNoise(ply, perSec, "vehicle")
        end
    end
end)

-- Смерть игрока → сброс тира на 1, пул очищается
hook.Add("PlayerDeath", "SWExp::EnemyMgr_PlayerDeath", function(victim)
    if not IsValid(victim) then return end
    local sid = victim:SteamID64()
    if not sid then return end
    local p = Mgr.Pools[sid]
    if p then
        p.tier     = 0
        p.lastTier = 0
        p.noise    = 0
        p.enemies  = {}
        -- Удаляем всех связанных врагов
        for idx, meta in pairs(Mgr.EnemyMeta) do
            if meta.ownerSID == sid then
                local ent = Entity(idx)
                if IsValid(ent) then
                    Mgr.OnEnemyRemoved(ent)
                    ent:Remove()
                end
            end
        end
        victim:SetNWInt("SWExp_ThreatTier", 0)
        SendNoiseToPlayer(p, true)
    end
end)

-- Респавн → Сброс на 1 (как мы договаривались — последний тир = 1 если нет сохранённого)
hook.Add("PlayerSpawn", "SWExp::EnemyMgr_PlayerSpawn", function(ply)
    if not IsValid(ply) then return end
    local p = GetOrCreatePool(ply)
    if not p then return end
    -- Дефолтный тир = 1 (первая зона). Safezone сбросит до 0 если игрок там.
    p.tier     = 1
    p.lastTier = 1
    p.noise    = 0
    ply:SetNWInt("SWExp_ThreatTier", 1)
    SendNoiseToPlayer(p, true)
end)

-- Первый заход игрока → пул уже создан PlayerSpawn, но NW-переменные
-- ещё не дошли до клиента (сеть не готова при PlayerInitialSpawn).
-- Ждём SWExp::PlayerFullLoad (триггерится при первом SetupMove) и
-- принудительно отправляем актуальный тир и шум.
hook.Add("SWExp::PlayerFullLoad", "SWExp::EnemyMgr_FullLoad", function(ply)
    if not IsValid(ply) then return end
    local p = GetOrCreatePool(ply)
    if not p then return end
    -- Если игрок заходит прямо в safezone — сразу сбрасываем тир
    if IsPlayerInSafezone(ply) then
        if not p.isInSafezone then
            OnPlayerEnterSafezone(p)
        end
    end
    -- Досылаем актуальный тир и шум клиенту
    ply:SetNWInt("SWExp_ThreatTier", p.tier or 0)
    SendNoiseToPlayer(p, true)
end)

-- Disconnect → чистка пула
hook.Add("PlayerDisconnected", "SWExp::EnemyMgr_Disconnect", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if sid then RemovePool(sid) end
end)

-- ============================================================
-- ГЛАВНЫЙ ТАЙМЕР
-- ============================================================

local function StartMgrTimer()
    local c = Cfg()
    local interval = (c and c.System and c.System.thinkInterval) or 0.5
    timer.Create("SWExp::EnemyMgr::Tick", interval, 0, function()
        local dt = interval
        for sid, pool in pairs(Mgr.Pools) do
            UpdatePool(pool, dt)
        end
        ProcessPendingSpawns()
        EnforceSafezoneBarrier()
    end)
end

hook.Add("SWExp::EndLoading", "SWExp::EnemyMgr_Start", function()
    StartMgrTimer()
    print("[SWExp] Менеджер врагов запущен (интервал " ..
        tostring(Cfg() and Cfg().System.thinkInterval or 0.5) .. "с).")
end)

-- На случай если хук SWExp::EndLoading уже был вызван до регистрации
-- (при hot reload) — стартуем сразу
timer.Simple(1, function()
    if not timer.Exists("SWExp::EnemyMgr::Tick") then
        StartMgrTimer()
    end
end)

-- ============================================================
-- АДМИН-КОМАНДЫ
-- ============================================================

concommand.Add("swexp_enemy_settier", function(ply, args, argStr)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local parts = string.Explode(" ", argStr)
    local tier = tonumber(parts[1])
    if not tier then
        ply:ChatPrint("[SWExp] Usage: swexp_enemy_settier <0-4>")
        return
    end
    tier = math.Clamp(math.floor(tier), 0, 4)
    Mgr.SetThreatTier(ply, tier)
    ply:ChatPrint("[SWExp] Threat tier set to " .. tier)
end)

concommand.Add("swexp_enemy_addnoise", function(ply, cmd, args, argStr)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local parts = string.Explode(" ", argStr)
    local amount = tonumber(parts[1]) or 10
    Mgr.AddNoise(ply, amount, "admin")
    ply:ChatPrint("[SWExp] Added " .. amount .. " noise.")
end)

concommand.Add("swexp_enemy_clearnoise", function(ply, cmd, args, argStr)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local pool = Mgr.Pools[ply:SteamID64() or ""]
    if pool then
        pool.noise = 0
        SendNoiseToPlayer(pool, true)
        ply:ChatPrint("[SWExp] Noise cleared.")
    end
end)

print("[SWExp] sv_enemy_manager loaded.")
