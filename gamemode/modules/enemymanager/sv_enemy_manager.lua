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
    if IsValid(pool.ply) then
        pool.ply:SetNWInt("SWExp_ThreatTier", 0)
    end
    SendNoiseToPlayer(pool, true)
    -- Деспавн пула после задержки enterSafezoneDespawn (из конфига),
    -- а не мгновенно. Это позволяет настроить сколько времени враги "преследуют" после входа в хаб.
    local c = Cfg()
    local delay = (c and c.System and c.System.enterSafezoneDespawn) or 5
    timer.Simple(delay, function()
        if IsValid(pool.ply) and pool.isInSafezone and Mgr.Pools[pool.sid] == pool then
            for ent, _ in pairs(pool.enemies) do
                if IsValid(ent) then
                    Mgr.OnEnemyRemoved(ent)
                    ent:Remove()
                end
            end
            pool.enemies = {}
            Verbose(string.format("%s вошёл в safezone, пул деспавнится через %ds (lastTier=%d)", pool.ply:Nick(), delay, pool.lastTier))
        end
    end)
    Verbose(string.format("%s вошёл в safezone (lastTier=%d) — деспавн пула запланирован через %ds", pool.ply:Nick(), pool.lastTier, delay))
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
-- ВЫБОР ТОЧКИ СПАВНА (navmesh-based)
-- ============================================================

-- Глобальный кэш всех nav-зон карты (строится один раз).
local _navAllAreas = nil

local function GetAllNavAreas()
    if _navAllAreas then return _navAllAreas end
    if not navmesh or not navmesh.GetAllNavAreas then
        _navAllAreas = {}
        return _navAllAreas
    end
    _navAllAreas = navmesh.GetAllNavAreas() or {}
    print(string.format("[SWExp] Nav cache: %d зон загружено.", #_navAllAreas))
    return _navAllAreas
end

hook.Add("PostCleanupMap", "SWExp::EnemyMgr_NavCacheReset", function()
    _navAllAreas = nil
end)

-- Кэш кандидатов на пул: пересчитывается раз в N секунд
-- или когда игрок переместился дальше порога.
local NAV_CAND_LIFETIME  = 8    -- секунды жизни кэша кандидатов
local NAV_CAND_MOVE_DIST = 300  -- пересчёт если игрок сдвинулся дальше (u)

local function GetPoolCandidates(pool, plyPos, minD, maxD)
    local now = CurTime()
    local pc  = pool._navCandCache

    -- Кэш ещё актуален?
    if pc and (now - pc.builtAt) < NAV_CAND_LIFETIME then
        if pc.plyPos:DistToSqr(plyPos) < NAV_CAND_MOVE_DIST ^ 2 then
            return pc.list
        end
    end

    -- Перестраиваем список кандидатов.
    -- Фильтр только по горизонтальному расстоянию (XY).
    -- Вертикальную валидность определяет навмеш и трейс геометрии
    -- в TryFindSpawnPoint — высота игрока как эталон ненадёжна
    -- (прыжок, лифт, склон).
    local allAreas = GetAllNavAreas()
    local minD2    = minD * minD
    local maxD2    = maxD * maxD
    local list     = {}

    for _, area in ipairs(allAreas) do
        if not IsValid(area) then continue end
        local ac = area:GetCenter()
        local dx = ac.x - plyPos.x
        local dy = ac.y - plyPos.y
        local d2 = dx * dx + dy * dy
        if d2 < minD2 or d2 > maxD2 then continue end
        table.insert(list, area)
    end

    pool._navCandCache = {
        list    = list,
        builtAt = now,
        plyPos  = Vector(plyPos.x, plyPos.y, plyPos.z),
    }
    Verbose(string.format("Nav candidates: %d зон (из %d) для %s",
        #list, #allAreas, IsValid(pool.ply) and pool.ply:Nick() or "?"))
    return list
end

local function TryFindSpawnPoint(pool)
    if not IsValid(pool.ply) then return nil end
    local c = Cfg()
    if not c then return nil end

    local sys      = c.System
    local plyPos   = pool.ply:GetPos()
    local minD     = sys.spawnMinDist
    local maxD     = sys.spawnMaxDist
    local maxTries = sys.spawnMaxTries
    local szBuf    = sys.safezoneBuffer

    -- Нет navmesh → не спавним (лучше пропустить, чем спавнить в текстурах).
    local allAreas = GetAllNavAreas()
    if #allAreas == 0 then
        Verbose("Нет navmesh на карте — спавн пропущен.")
        return nil
    end

    -- Кандидаты (из кэша — O(1) при повторных вызовах).
    local candidates = GetPoolCandidates(pool, plyPos, minD, maxD)
    if #candidates == 0 then
        Verbose("Нет nav-кандидатов в радиусе.")
        return nil
    end

    -- Список всех живых игроков для LOS-фильтра.
    local viewers = {}
    for _, pl in ipairs(player.GetAll()) do
        if IsValid(pl) and pl:Alive() then
            table.insert(viewers, pl)
        end
    end

    for _ = 1, maxTries do
        local area = candidates[math.random(#candidates)]
        if not IsValid(area) then continue end

        local pos = area:GetRandomPoint()

        -- ── 0. Финальная проверка навмеша ───────────────────────────────
        -- GetRandomPoint() может вернуть точку на краю большой зоны —
        -- уже за границей карты или вне проходимой поверхности.
        -- GetNearestNavArea с маленьким радиусом подтверждает, что
        -- итоговая позиция реально покрыта навмешем.
        local confirmArea = navmesh.GetNearestNavArea(pos, false, 32, false, false)
        if not IsValid(confirmArea) then continue end

        -- Используем центр ближайшей подтверждённой зоны — это гарантирует
        -- XY строго внутри навмеша, а не на краю зоны.
        pos = confirmArea:GetClosestPointOnArea(pos)
        pos.z = pos.z + 2

        -- ── 1. Safezone ─────────────────────────────────────────────
        if SWExp.IsInSafezone and SWExp.IsInSafezone(pos, szBuf) then continue end

        -- ── 1b. Проверка пола: реальная геометрия совпадает с навмешем ──
        -- На краю карты навмеш может нависать над пропастью.
        -- Трассируем вниз — твёрдая поверхность должна быть в пределах
        -- 48 u. Это единственный критерий: навмеш сам является
        -- источником истины о проходимости, эталон высоты игрока не нужен.
        local groundTr = util.TraceLine({
            start  = pos + Vector(0, 0, 4),
            endpos = pos - Vector(0, 0, 48),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if not groundTr.Hit then continue end
        pos = Vector(pos.x, pos.y, groundTr.HitPos.z + 10)

        -- ── 2. PointContents — не внутри solid-кисти ────────────────
        local inSolid = false
        for _, dz in ipairs({ 2, 24, 48, 70 }) do
            if bit.band(util.PointContents(pos + Vector(0, 0, dz)), CONTENTS_SOLID) ~= 0 then
                inSolid = true; break
            end
        end
        if inSolid then continue end

        -- ── 3. Просвет 76 u вверх — NPC должен поместиться ──────────
        local ceilTr = util.TraceLine({
            start  = pos,
            endpos = pos + Vector(0, 0, 76),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if ceilTr.Hit then continue end

        -- ── 4. LOS-фильтр — вне поля зрения всех игроков ────────────
        local seen = false
        for _, pl in ipairs(viewers) do
            local los = util.TraceLine({
                start  = pl:EyePos(),
                endpos = pos + Vector(0, 0, 40),
                mask   = MASK_OPAQUE,
                filter = pl,
            })
            if los.Fraction >= 0.99 then seen = true; break end
        end
        if seen then continue end

        -- ── 5. В пределах мира ───────────────────────────────────────
        if not util.IsInWorld(pos) then continue end

        return pos
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

    -- Пост-спавн проверка: NPC не должен находиться внутри геометрии.
    -- После Activate() физдвижок мог сдвинуть энтити — проверяем
    -- реальную позицию через PointContents (надёжнее нулевого TraceHull).
    local spawnedPos = npc:GetPos()
    local postStuck = false
    for _, dz in ipairs({ 2, 24, 48, 70 }) do
        local contents = util.PointContents(spawnedPos + Vector(0, 0, dz))
        if bit.band(contents, CONTENTS_SOLID) ~= 0 then
            postStuck = true; break
        end
    end
    if postStuck then
        Verbose(string.format("Post-spawn stuck check failed for %s at (%d,%d,%d) — removed",
            class, spawnedPos.x, spawnedPos.y, spawnedPos.z))
        npc:Remove()
        return
    end

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
        -- Защитный фикс: isInSafezone=true, но тир почему-то ненулевой
        -- (например, SetThreatTier вызвали снаружи после OnPlayerEnterSafezone).
        -- Принудительно обнуляем, чтобы клиент видел правильный тир.
        if pool.isInSafezone and pool.tier ~= 0 then
            pool.tier = 0
            pool.noise = 0
            if IsValid(pool.ply) then
                pool.ply:SetNWInt("SWExp_ThreatTier", 0)
                SendNoiseToPlayer(pool, true)
            end
        end

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

    -- Leash-диспавн: враг ушёл слишком далеко от игрока → удалить тихо.
    -- Срабатывает и при активной угрозе: если NPC застрял, потерялся
    -- или карта не позволила ему добраться — не висит в пуле вечно.
    local leashDist = c.System.leashDist or (c.System.spawnMaxDist * 1.5)
    local leashDist2 = leashDist * leashDist
    for ent, _ in pairs(pool.enemies) do
        if IsValid(ent) then
            if ent:GetPos():DistToSqr(pool.ply:GetPos()) > leashDist2 then
                Verbose(string.format("Leash despawn: %s слишком далеко от %s",
                    ent:GetClass(), pool.ply:Nick()))
                Mgr.OnEnemyRemoved(ent)
                ent:Remove()
            end
        else
            pool.enemies[ent] = nil
        end
    end

    -- Стелс: ниже порога — grace period и зачистка
    if pool.noise < c.Noise.stealthThreshold then
        if (CurTime() - (pool.lastHighNoise or 0)) >= c.System.lowNoiseGrace then
            -- Удаляем по одному врагу за тик.
            -- Сначала — дальних (hideDist+), потом всех оставшихся:
            -- без этой второй ветки враги ближе hideDist никогда не чистились.
            local hideDist = c.System.despawnHideDist
            local removedOne = false
            for ent, _ in pairs(pool.enemies) do
                if IsValid(ent) then
                    local d = ent:GetPos():Distance(pool.ply:GetPos())
                    if d > hideDist then
                        Mgr.OnEnemyRemoved(ent)
                        ent:Remove()
                        removedOne = true
                        break  -- по одному за тик
                    end
                end
            end
            -- Если дальних врагов не осталось, убираем ближних —
            -- grace period уже давно вышел, игрок «стелсится» достаточно долго.
            if not removedOne then
                for ent, _ in pairs(pool.enemies) do
                    if IsValid(ent) then
                        Mgr.OnEnemyRemoved(ent)
                        ent:Remove()
                        break  -- тоже по одному
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
    -- Копируем индексы, т.к. OnEnemyRemoved + Remove модифицирует EnemyMeta
    local indices = {}
    for idx, _ in pairs(Mgr.EnemyMeta) do
        indices[#indices + 1] = idx
    end
    for _, idx in ipairs(indices) do
        local meta = Mgr.EnemyMeta[idx]
        if not meta then continue end
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

-- Смерть игрока → сохраняем pre-death тир и шум (для дефибриллятора),
-- затем сбрасываем пул и счётчики.
hook.Add("PlayerDeath", "SWExp::EnemyMgr_PlayerDeath", function(victim)
    if not IsValid(victim) then return end
    local sid = victim:SteamID64()
    if not sid then return end
    local p = Mgr.Pools[sid]
    if p then
        -- Сохраняем состояние для возможного дефибриллятор-реса.
        -- PlayerSpawn ниже прочитает _defibrRevive и восстановит.
        p._preDeathTier  = p.tier or 0
        p._preDeathNoise = p.noise or 0

        p.tier     = 0
        p.lastTier = 0
        p.noise    = 0
        p.enemies  = {}
        -- Удаляем всех связанных врагов (копия, т.к. On+Remove меняет meta)
        local toClean = {}
        for idx, meta in pairs(Mgr.EnemyMeta) do
            if meta.ownerSID == sid then
                toClean[#toClean + 1] = idx
            end
        end
        for _, idx in ipairs(toClean) do
            local ent = Entity(idx)
            if IsValid(ent) then
                Mgr.OnEnemyRemoved(ent)
                ent:Remove()
            end
        end
        victim:SetNWInt("SWExp_ThreatTier", 0)
        SendNoiseToPlayer(p, true)
    end
end)

-- Респавн:
--   • дефибриллятор (ply._defibrRevive == true) — восстанавливаем
--     pre-death тир и шум. Локация ставится самим аддоном (deathPos
--     через 0.15с после Spawn) → тир соответствует месту реса.
--   • обычный респавн — сброс на тир 1, шум 0; локация — точка спавна
--     (см. swexp_player_spawn / GM:PlayerSelectSpawn).
hook.Add("PlayerSpawn", "SWExp::EnemyMgr_PlayerSpawn", function(ply)
    if not IsValid(ply) then return end
    local p = GetOrCreatePool(ply)
    if not p then return end

    if ply._defibrRevive then
        local restoreTier = p._preDeathTier or 1
        if restoreTier < 1 then restoreTier = 1 end
        p.tier     = restoreTier
        p.lastTier = restoreTier
        p.noise    = p._preDeathNoise or 0
        p._preDeathTier  = nil
        p._preDeathNoise = nil
        ply:SetNWInt("SWExp_ThreatTier", p.tier)
        SendNoiseToPlayer(p, true)
        return
    end

    -- Дефолтный тир = 1 (первая зона). Safezone-проверка ниже в Update
    -- сбросит до 0, если игрок появился внутри хаба.
    p.tier     = 1
    p.lastTier = 1
    p.noise    = 0
    p._preDeathTier  = nil
    p._preDeathNoise = nil
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

-- Disconnect → чистка пула.
-- ВАЖНО: перед удалением пула кэшируем тир на игроке, чтобы
-- sv_spawn_location.lua мог корректно сохранить его в БД,
-- даже если его PlayerDisconnected-хук выполнится после нашего.
-- (порядок hook.Add хуков в GMod не гарантирован — pairs не упорядочен)
hook.Add("PlayerDisconnected", "SWExp::EnemyMgr_Disconnect", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid then return end
    local p = Mgr.Pools[sid]
    if p then
        -- В safezone tier=0, но lastTier хранит реальное значение.
        local effective = (p.tier and p.tier > 0) and p.tier
            or (p.lastTier and p.lastTier > 0) and p.lastTier
            or 1
        ply.SWExp_DisconnectTier = effective
    end
    RemovePool(sid)
end)

-- ============================================================
-- ГЛАВНЫЙ ТАЙМЕР
-- ============================================================

local function StartMgrTimer()
    local c = Cfg()
    local interval = (c and c.System and c.System.thinkInterval) or 0.5
    timer.Create("SWExp::EnemyMgr::Tick", interval, 0, function()
        local dt = interval
        -- Безопасная итерация: копируем ключи, т.к. Update может удалять пулы (и модифицировать таблицу)
        local sids = {}
        for sid, _ in pairs(Mgr.Pools) do
            sids[#sids + 1] = sid
        end
        for _, sid in ipairs(sids) do
            local pool = Mgr.Pools[sid]
            if pool then
                UpdatePool(pool, dt)
            end
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