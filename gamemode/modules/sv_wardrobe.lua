-- ============================================================
-- Star Wars: Expedition — Шкаф (сервер)
-- modules/sv_wardrobe.lua
--
-- Хранит бодигруппы/скин раздельно для каждой модели персонажа.
-- Структура: swexp_char_bodygroups (character_id, model, bodygroups, skin)
-- Одна запись = одна модель одного персонажа.
-- Это важно т.к. модель меняется при надевании/снятии брони.
-- ============================================================

if CLIENT then return end

SWExp.Wardrobe = SWExp.Wardrobe or {}

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ БД
-- ============================================================

hook.Add('DatabaseInitialized', 'SWExp::Wardrobe_DBInit', function()
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS `swexp_char_bodygroups` (
            `character_id` INTEGER NOT NULL,
            `model`        VARCHAR(255) NOT NULL,
            `bodygroups`   TEXT,
            `skin`         INTEGER DEFAULT 0,
            PRIMARY KEY (`character_id`, `model`)
        );
    ]])
    MsgC(Color(190, 252, 3), '[ SWExp.Wardrobe ] ', color_white, 'Таблица swexp_char_bodygroups готова.\n')
end)

-- ============================================================
-- ЗАГРУЗКА БОДИГРУПП ИЗ БД
-- Загружает ВСЕ записи персонажа одним запросом.
-- Результат: char.bodygroupsData = { [model] = { skin, bodygroups } }
-- ============================================================

function SWExp.Wardrobe.LoadData(pPlayer, charID, cb)
    if not IsValid(pPlayer) then return end
    if tonumber(charID) == -1 then
        -- Виртуальный ADMIN-персонаж — пустые данные
        local char = pPlayer.SWExp_ActiveChar
        if char then char.bodygroupsData = {} end
        if cb then cb({}) end
        return
    end

    MySQLite.query(
        string.format(
            "SELECT `model`, `bodygroups`, `skin` FROM `swexp_char_bodygroups` WHERE `character_id` = %d;",
            tonumber(charID)
        ),
        function(rows)
            local data = {}
            if rows then
                for _, row in ipairs(rows) do
                    local bg = util.JSONToTable(row.bodygroups or '{}') or {}
                    -- Ключи из JSON всегда строки — конвертируем в числа
                    local bgNum = {}
                    for k, v in pairs(bg) do
                        bgNum[tonumber(k)] = tonumber(v)
                    end
                    data[row.model] = {
                        skin       = tonumber(row.skin) or 0,
                        bodygroups = bgNum,
                    }
                end
            end

            local char = pPlayer.SWExp_ActiveChar
            -- Проверяем что активный персонаж не сменился пока шёл запрос
            if char and tonumber(char.id) == tonumber(charID) then
                char.bodygroupsData = data
            end
            if cb then cb(data) end
        end,
        function(err)
            MsgC(Color(255, 80, 80), '[ SWExp.Wardrobe ] Ошибка загрузки: ', tostring(err), '\n')
            -- Устанавливаем пустые данные чтобы ApplyWhenReady не ждал вечно
            local char = pPlayer.SWExp_ActiveChar
            if char and tonumber(char.id) == tonumber(charID) then
                char.bodygroupsData = {}
            end
            return true
        end
    )
end

-- ============================================================
-- ПРИМЕНЕНИЕ БОДИГРУПП ДЛЯ ТЕКУЩЕЙ МОДЕЛИ
-- ============================================================

function SWExp.Wardrobe.ApplyBodygroups(pPlayer)
    if not IsValid(pPlayer) then return end
    local char = pPlayer.SWExp_ActiveChar
    if not char then return end

    local model    = pPlayer:GetModel()
    local allData  = char.bodygroupsData
    if not allData then return end

    local modelData = allData[model]
    if not modelData then return end  -- для этой модели настроек нет — оставляем дефолт

    pPlayer:SetSkin(modelData.skin or 0)

    for k, v in pairs(modelData.bodygroups or {}) do
        pPlayer:SetBodygroup(tonumber(k), tonumber(v))
    end
end

-- ============================================================
-- ХУКИ — загружаем и применяем при смене персонажа/модели
-- ============================================================

-- ── Вспомогательная функция: применить бодигруппы с ожиданием готовности данных ──
-- Если данные ещё не загружены из БД (LoadData ещё не вернул callback),
-- повторяем попытку каждые 0.15 с — не более 20 раз (итого до 3 секунд).
local function ApplyWhenReady(pPlayer, attempt)
    if not IsValid(pPlayer) then return end
    attempt = attempt or 0

    local char = pPlayer.SWExp_ActiveChar
    -- Данные готовы — bodygroupsData инициализирован (может быть пустой таблицей)
    if char and char.bodygroupsData ~= nil then
        SWExp.Wardrobe.ApplyBodygroups(pPlayer)
    elseif attempt < 20 then
        timer.Simple(0.15, function()
            ApplyWhenReady(pPlayer, attempt + 1)
        end)
    end
end

-- Выбор персонажа: загружаем данные из БД, затем применяем
hook.Add('SWExp::CharacterSelected', 'SWExp::Wardrobe_OnSelect', function(pPlayer, char)
    if not char then return end
    -- Сбрасываем bodygroupsData — сигнал «данные ещё не готовы»
    if pPlayer.SWExp_ActiveChar then
        pPlayer.SWExp_ActiveChar.bodygroupsData = nil
    end
    SWExp.Wardrobe.LoadData(pPlayer, char.id, function()
        -- Данные готовы — применяем для текущей модели (базовая или броня)
        if IsValid(pPlayer) then
            SWExp.Wardrobe.ApplyBodygroups(pPlayer)
        end
    end)
end)

-- Спавн: модель восстанавливается, применяем бодигруппы поверх
hook.Add('PlayerSpawn', 'SWExp::Wardrobe_OnSpawn', function(pPlayer)
    timer.Simple(0.3, function()
        if IsValid(pPlayer) then
            SWExp.Wardrobe.ApplyBodygroups(pPlayer)
        end
    end)
end)

-- Броня надета — модель сменилась на playerModel предмета
hook.Add('SWExp::ArmorEquipped', 'SWExp::Wardrobe_OnArmorEquip', function(pPlayer)
    ApplyWhenReady(pPlayer)
end)

-- Броня снята — модель вернулась к базовой
hook.Add('SWExp::ArmorUnequipped', 'SWExp::Wardrobe_OnArmorUnequip', function(pPlayer)
    ApplyWhenReady(pPlayer)
end)

-- Броня восстановлена при входе/смене персонажа — ApplyEquippedArmor поставил модель брони,
-- нужно переприменить бодигруппы поверх (SetModel сбрасывает их в 0).
-- LoadCharacterInventory асинхронный — данные шкафа могут быть ещё не загружены.
hook.Add('SWExp::ArmorRestored', 'SWExp::Wardrobe_OnArmorRestored', function(pPlayer)
    ApplyWhenReady(pPlayer)
end)

-- ============================================================
-- NETSTREAM: Сохранить бодигруппы для текущей модели
-- ============================================================

netstream.Hook('SWExp::SaveBodygroups', function(pPlayer, tData)
    if not IsValid(pPlayer) then return end
    if not istable(tData)   then return end

    local char = pPlayer.SWExp_ActiveChar
    if not char then return end

    local model = pPlayer:GetModel()

    -- ── Валидация ──────────────────────────────────────────
    local skin = math.Clamp(tonumber(tData.skin) or 0, 0, 63)
    local bodygroups = {}
    if istable(tData.bodygroups) then
        for k, v in pairs(tData.bodygroups) do
            local bgID  = tonumber(k)
            local subID = tonumber(v)
            if bgID and subID and bgID >= 0 and bgID < 128 and subID >= 0 and subID < 64 then
                bodygroups[bgID] = subID
            end
        end
    end

    -- ── Применяем мгновенно ────────────────────────────────
    pPlayer:SetSkin(skin)
    for k, v in pairs(bodygroups) do
        pPlayer:SetBodygroup(k, v)
    end

    -- ── Сохраняем в памяти ────────────────────────────────
    char.bodygroupsData = char.bodygroupsData or {}
    char.bodygroupsData[model] = { skin = skin, bodygroups = bodygroups }

    -- ── ADMIN-персонаж (id = -1) не пишется в БД ──────────
    if tonumber(char.id) == -1 then return end

    local charID = tonumber(char.id)
    local sBG    = util.TableToJSON(bodygroups)

    -- REPLACE INTO атомарно удаляет старую запись и вставляет новую
    MySQLite.query(
        string.format(
            "REPLACE INTO `swexp_char_bodygroups` (`character_id`, `model`, `bodygroups`, `skin`) VALUES (%d, %s, %s, %d);",
            charID,
            MySQLite.SQLStr(model),
            MySQLite.SQLStr(sBG),
            skin
        ),
        nil,
        function(err)
            MsgC(Color(255, 80, 80), '[ SWExp.Wardrobe ] Ошибка сохранения: ', tostring(err), '\n')
            return true
        end
    )

    MsgC(Color(190, 252, 3), '[ SWExp.Wardrobe ] ', color_white,
        pPlayer:Nick(), ' → сохранён внешний вид для "', model, '"\n')
end)

-- ============================================================
-- ОБОГАЩЕНИЕ СПИСКА ПЕРСОНАЖЕЙ ДАННЫМИ БОДИГРУПП
-- Добавляет char._skin и char._bodygroups (для базовой модели) к каждому
-- персонажу в tChars одним батч-запросом, затем вызывает cb(tChars).
-- ============================================================

function SWExp.Wardrobe.EnrichWithBodygroups(tChars, cb)
    if not tChars or #tChars == 0 then cb(tChars) return end

    -- Собираем реальные ID (пропускаем -1 и пустые слоты)
    local ids = {}
    for _, c in ipairs(tChars) do
        local id = tonumber(c.id)
        if id and id ~= -1 then
            ids[#ids + 1] = id
        end
    end

    if #ids == 0 then cb(tChars) return end

    MySQLite.query(
        "SELECT `character_id`, `model`, `bodygroups`, `skin` FROM `swexp_char_bodygroups` WHERE `character_id` IN (" .. table.concat(ids, ',') .. ");",
        function(rows)
            -- Строим быстрый словарь: bgLookup[charId][model] = {skin, bodygroups}
            local bgLookup = {}
            if rows then
                for _, row in ipairs(rows) do
                    local cid = tonumber(row.character_id)
                    bgLookup[cid] = bgLookup[cid] or {}
                    local bg = util.JSONToTable(row.bodygroups or '{}') or {}
                    local bgNum = {}
                    for k, v in pairs(bg) do bgNum[tonumber(k)] = tonumber(v) end
                    bgLookup[cid][row.model] = { skin = tonumber(row.skin) or 0, bodygroups = bgNum }
                end
            end

            -- Прикрепляем данные к каждому персонажу по его базовой модели
            for _, c in ipairs(tChars) do
                local cid = tonumber(c.id)
                if cid and cid ~= -1 and c.model then
                    local entry = bgLookup[cid] and bgLookup[cid][c.model]
                    if entry then
                        c._skin       = entry.skin
                        c._bodygroups = entry.bodygroups
                    end
                end
            end

            cb(tChars)
        end,
        function(err)
            MsgC(Color(255, 80, 80), '[ SWExp.Wardrobe ] EnrichWithBodygroups ошибка: ', tostring(err), '\n')
            cb(tChars)  -- отправляем без бодигрупп при ошибке
            return true
        end
    )
end

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Шкаф (сервер) загружен.\n')
