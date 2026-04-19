# Аудит геймода Star Wars: Expedition (`starwarsrp`)

**Дата:** 2026-04-19
**Объём кода:** ~16 600 строк Lua (50+ файлов)
**Методология:** статический анализ `init.lua`, `shared.lua`, `core/`, `config/`, всех модулей (`modules/`) и библиотек (`libs/`) с последующей ручной верификацией критичных находок по исходникам.

> **Важно про методологию.** Предварительный проход нашёл несколько потенциальных критиков, но часть из них при проверке оказалась ложным срабатыванием. Итоговый отчёт содержит только подтверждённые проблемы. Для сравнения: уже существующий `cardealler_bug_report.md` (BUG-01…BUG-12) я включил в сводку, но не переписываю заново.

---

## 1. Сводная таблица

| # | Сев. | Модуль / файл | Суть |
|---|-----|---------------|------|
| V-01 | 🔴 | `sv_carspawns.lua` / `sv_dealer.lua` | Несовпадение классов энтити `nextrp_carspawner` vs `swexp_carspawner` (BUG-01 из существующего отчёта) |
| V-02 | 🔴 | `sv_carspawns.lua` | Нет `PlayerDisconnected` — утечка пула техники (BUG-02) |
| V-03 | 🔴 | `sv_assembler.lua` (347–399) | TOCTOU в банке материалов: двое крафтят одновременно → отрицательный банк |
| V-04 | 🔴 | `sv_research.lua` (132–152) | TOCTOU в банке ОИ: параллельный Deposit → дублирование |
| V-05 | 🔴 | `sv_inventory.lua` | MoveItem/EquipItem принимает `uniqueID`/`slotIndex`/`newX,Y` от клиента без проверки принадлежности, типа, диапазона |
| V-06 | 🔴 | `sv_inventory.lua` (891–997) | `InventoryTakeFromBag`/`EquipFromBag`: `entIndex` берётся от клиента, дистанция — единственная защита |
| V-07 | 🔴 | `sv_inventory.lua` (AddItem) | `uniqueID = os.time()` или аналогичный → коллизии при одновременной выдаче, перезапись стека |
| V-08 | 🟠 | `cl_test_hud.lua` (весь файл) | Тестовый файл загружается в проде через `LoadModules` — concommand-ы `swui_test_*` открыты всем |
| V-09 | 🟠 | `config/sv_mysql.lua` | MySQL-пароль `root:110420041` в плейнтексте (в git/на диске). **Клиентам НЕ утекает** (см. §2), но хранить в коде плохо |
| V-10 | 🟠 | `sv_assembler.lua` (190–198) | `AddUsage` — конкатенация без `SQLStr`. Сейчас значения серверные, но паттерн хрупкий |
| V-11 | 🟠 | `sv_armor.lua` (41–61 и 168–207) | Дублирующиеся хуки `EntityTakeDamage` — остатки рефакторинга, конфликт логики |
| V-12 | 🟠 | `cl_hud.lua` (DrawOverheadNames) | `player.GetAll()` + `util.TraceLine()` в `HUDPaint` каждый кадр = до 1920 трейсов/сек |
| V-13 | 🟠 | `sv_voice.lua`, `cl_radio.lua` | Нет rate-limit на `SetRadioFreq`/`RadioTalk` — DoS через netstream-спам |
| V-14 | 🟠 | `sv_scoreboard.lua` (191–258) | `target = data.player` — доверие клиенту. Защищено `HasPermission`, но уязвимо к misuse низкоуровневым админом |
| V-15 | 🟠 | `sv_carspawns.lua` (61–101) | Гонка при списании материалов (BUG-04) |
| V-16 | 🟠 | `sv_dealer.lua` | Тихая потеря данных в `SaveDealers` (BUG-05) + `nil` после `util.JSONToTable` (BUG-06) |
| V-17 | 🟡 | Три параллельные системы прав | `SWExp.Config.Admins` / `CAMI.RegisterPrivilege` / встроенные `IsAdmin()` — без единого источника истины |
| V-18 | 🟡 | `core/sv_playerhooks.lua` (23–56) | Цепочка async MySQL без `IsValid(pPlayer)` в коллбэках |
| V-19 | 🟡 | `sv_chars.lua` | Нет валидации формата `sNumber`/`sCallsign` (длина, допустимые символы), rate-limit отсутствует |
| V-20 | 🟡 | `sv_jobparser.lua` (49–53) | `timer.Simple(1, ...)` для ожидания готовности БД (BUG-08) |
| V-21 | 🟡 | Debug `print` в проде | `sv_dealer.lua` 19–28, `sh_inventory.lua` 314, `cl_pickup_notify.lua` 243 и др. |
| V-22 | 🟡 | `sv_carspawns.lua` (32–43) | Неатомарное обновление пула: in-memory и MySQL расходятся (BUG-09) |
| V-23 | 🟡 | `sv_inventory.lua` | `util.TableToJSON` без проверки на `nil` перед записью в БД |
| V-24 | 🟡 | Дублирование | `GetDynamicSlotCount` продублирован в `sv_inventory.lua` и `cl_inventory.lua` |
| V-25 | 🟡 | `shared.lua` | `include()` без `pcall` — ошибка в одном модуле ломает загрузку молча |
| V-26 | 🟡 | `cl_hud.lua` и др. | Функция `S(n)` продублирована в каждом файле — лучше в общую UI-либу |
| V-27 | 🟡 | `sh_carspawnconfig.lua` (33) | `GetVehicleSettings` возвращает ссылку, а не копию (BUG-12) |
| V-28 | 🟡 | `cl_interface.lua` (302–399) | Нельзя переименовать технику (BUG-11); `SWExp.Ranks.List` может быть `nil` (BUG-10) |

**Итого:** 7 критических, 9 серьёзных, 12 средних.

---

## 2. Что проверил лично и оказалось НЕверно (ложные срабатывания)

Два самых громких вывода одного из агентов я проверил по исходнику — они неверны. Фиксирую их отдельно, чтобы вы не шли и не правили то, что уже работает:

### ❌ «Пароль MySQL утекает всем клиентам через AddCSLuaFile»

В `shared.lua:136–156` (`LoadConfigs`) `sv_*` файлы получают `include()` только на `SERVER` и **никогда** не попадают в `AddCSLuaFile`:

```lua
if string.StartWith(v, 'sv') then
    if SERVER then
        local load = include(sPath..v)
        if load then load() end
    end
end
-- никакого AddCSLuaFile здесь нет
```

`sv_mysql.lua` клиенту не отдаётся. Пароль **не утекает** по сети. Но хранить его в файле с исходниками всё равно плохо (V-09, 🟠): git-история, бэкапы, случайный `AddCSLuaFile('config/sv_mysql.lua')` кем-то в будущем.

### ❌ «Любой игрок может удалить/переименовать чужого персонажа через `netstream.Start('SWExp::DeleteChar', foreignID)`»

В `sv_chars.lua:164–235` все операции над персонажем скоупятся по `player_id` в БД **и** по `pPlayer.SWExp_Characters` в памяти:

```lua
MySQLite.query(
    string.format('DELETE FROM `swexp_characters` WHERE id = %s AND player_id = %s;',
        MySQLite.SQLStr(nCharID),
        MySQLite.SQLStr(pPlayer.SWExp_ID)),
    ...
)
```

Чужой ID просто не найдётся в `pPlayer.SWExp_Characters`, вернётся «Персонаж не найден». Защита корректная.

---

## 3. Подробно: критичные уязвимости

### V-03 / V-04. TOCTOU в банках ассемблера и исследований

Паттерн, повторяющийся минимум в трёх местах (`sv_assembler.lua`, `sv_research.lua`, `sv_carspawns.lua`):

```lua
if SWExp.Assembler._bank < cost then return end   -- check
SWExp.Assembler._bank = SWExp.Assembler._bank - cost  -- act
```

Между `check` и `act` любой другой netstream-запрос успевает пройти ту же проверку. При 32 игроках на сервере достаточно одновременного клика «Крафт» у двоих — банк уйдёт в минус или двое получат предмет за цену одного.

**Исправление:** ввести флаг `SWExp.Assembler._processing = true` на время операции, либо использовать локальную очередь. В Lua нет настоящих мьютексов, но `coroutine`/«очередь задач» решают задачу. Альтернатива — делать всю работу одним атомарным INSERT с триггером или `UPDATE ... WHERE bank >= cost`, проверяя `affectedRows`.

### V-05 / V-06 / V-07. Inventory — букет проблем с доверием клиенту

`sv_inventory.lua` содержит netstream-обработчики (≈ строки 875, 879, 883, 1014, 1018), которые принимают от клиента поля без валидации:

- `uniqueID` — строка; никто не проверяет, что она принадлежит инвентарю именно этого игрока. Если логика где-то в будущем будет искать предмет по uniqueID глобально, открывается путь к краже;
- `slotIndex`, `newX`, `newY` — не приводятся к числу, не зажимаются `math.Clamp`, отрицательные значения пишутся в БД;
- `fromStorage`, `toStorage` — булевы, но строка `"hack"` интерпретируется как `true`;
- `entIndex` для `InventoryTakeFromBag`/`EquipFromBag` — указатель на энтити, единственная защита — проверка дистанции. Достаточно подойти к любой death-bag.

Критично ещё и то, что `uniqueID` генерируется через `os.time()`/подобный тайм-сэмпл. При двойном вызове `AddItem` в один тик получится одинаковый ключ → одно из добавлений перезаписывает другое или стек суммируется непредсказуемо.

**Общий фикс-чеклист для всех netstream-обработчиков инвентаря:**

```lua
local uid = tostring(data.uniqueID or '')
if not PlayerInventories[ply:SteamID64()]              -- владелец
   or not PlayerInventories[ply:SteamID64()].items[uid] then return end

local slotIndex = math.Clamp(tonumber(data.slotIndex) or 0, 1, MAX_SLOT)
local newX = math.Clamp(tonumber(data.newX) or 0, 1, GRID_W)
local newY = math.Clamp(tonumber(data.newY) or 0, 1, GRID_H)
local fromStorage = data.fromStorage == true
```

И заменить `uniqueID = os.time() .. "_" .. math.random(...)` на счётчик: `self._uidCounter = (self._uidCounter or 0) + 1; uid = charID .. '_' .. self._uidCounter`.

### V-08. `cl_test_hud.lua` 376 строк в продакшн-геймоде

`modules/cl_test_hud.lua` начинается с префикса `cl_` и в `shared.lua` (167–201) попадает в `LoadModules`, т.е. грузится и `AddCSLuaFile`-ится. Он регистрирует `concommand` `swui_test_window`, `swui_test_nav` и т. п. Эти команды доступны любому игроку из консоли и открывают демо-панели UI-библиотеки. Это не эксплойт сервера, но:
1. Лишний код и ассеты у каждого клиента;
2. Побочные эффекты тестовых панелей могут конфликтовать с реальным HUD;
3. Доступ к внутреннему UI даёт подсказки для реверс-инжиниринга.

**Исправление:** физически удалить файл или вынести его из `modules/` в `addons/swexp_devtools/` и грузить только при `cvar`.

---

## 4. Дублирование информации / структуры

### 4.1. Три параллельные системы прав (V-17)

| Источник | Файл | Кто использует |
|----------|------|----------------|
| `SWExp.Config.Admins[group]` | `config/sh_admin.lua` | `core/sh_isadmin.lua::IsAdmin` |
| `CAMI.RegisterPrivilege(...)` | `core/sh_cami.lua` | `sv_scoreboard.lua::HasPermission` |
| `ply:IsAdmin()/IsSuperAdmin()` | встроенный GMod | `init.lua::CheckSpawnPermission`, `sv_armor.lua`, `sv_chars.lua` |

Итог: одно и то же «является админом» спрашивается тремя несовместимыми способами. Сейчас они плюс-минус совпадают, но как только в ULX/SAM появится mid-tier группа (например, `"moderator"`), она получит права в одних частях геймода и не получит в других. Плюс регрессионные баги при миграции.

**Рекомендация:** выбрать CAMI как единый фасад. Переписать `sh_isadmin.lua::IsAdmin` через `CAMI.PlayerHasAccess(ply, 'swexp.admin.basic', callback)`. `CheckSpawnPermission` — через ту же CAMI-привилегию. `SWExp.Config.Admins` — удалить.

### 4.2. Имена таблиц БД жёстко забиты строками

`swexp_characters`, `swexp_assembler_usage`, `swexp_assembler_limits`, `swexp_inventory`, `swexp_research_*` — все разбросаны по десятку файлов как литералы в `MySQLite.query("... FROM \`swexp_xxx\` ...")`. Переименование таблицы = Grep-and-replace по всему коду.

**Рекомендация:** один файл `core/sh_db_tables.lua`:
```lua
SWExp.DB = {
    Players     = 'swexp_players',
    Characters  = 'swexp_characters',
    Inventory   = 'swexp_inventory',
    ...
}
```

### 4.3. Дублирующиеся хендлеры в `sv_armor.lua`

Файл содержит **две** независимые реализации обработки урона (41–61 и 168–207). Обе навешаны на `EntityTakeDamage` — вторая затирает первую или они обе отрабатывают, в зависимости от имени хука. Похоже на недобитый рефакторинг. Плюс функция `ApplyArmorSpeed` объявлена локально (стр. 28) и вызывается снаружи по ошибке без префикса — на Lua это поднимет «attempt to call a nil value» при `swexp_setarmor`.

### 4.4. Дубли helper-функций и констант

- `GetDynamicSlotCount` — в `sv_inventory.lua` и `cl_inventory.lua` (V-24).
- `S(n)` (масштабирование размеров) — в каждом `cl_*.lua` HUD-файле отдельно (V-26). Должно жить в `libs/swexp_ui.lua`.
- Рецепты/цены ассемблера читаются из `sh_assembler_config.lua` корректно, но часть дневных лимитов одновременно живёт и в `SWExp.Assembler._limits` (runtime), и в `swexp_assembler_limits` (БД), и в `SWExp.AssemblerConfig.GetDefaultLimit` (fallback) — три источника истины.

---

## 5. Производительность и утечки

| Проблема | Где | Эффект |
|---|---|---|
| `util.TraceLine` 32×60 раз/сек | `cl_hud.lua::DrawOverheadNames` (~579–593) | Фризы при скоплении игроков |
| `player.GetAll()` в `HUDPaint` без кеша | `cl_hud.lua` | Аллокация таблицы каждый кадр, давит GC |
| `timer.Create("SWExpInvModelWatch", 0.1, 0, ...)` без остановки | `cl_inventory.lua` 185–201 | Таймер переживает закрытие окна |
| `timer.Simple(0.3)` на каждое добавление ОИ | `sv_research.lua` 113–117 | При массовом дропе — сотни живых таймеров |
| HoT-medkit без ограничения количества тиков | `sv_inventory.lua` 1140–1163 | Можно получить `heal / tick = 10000` тиков |
| Хук `HUDPaint` не снимается при reload | `cl_hud.lua` 347–353 | После `lua_openscript_cl` удвоение отрисовки |

---

## 6. Что НЕ является проблемой, но рядом стоит

- `libs/*` (`cami.lua`, `mysqlite.lua`, `netstream.lua`, `pon.lua`) — это сторонние библиотеки известных авторов. Не трогать.
- `AddCSLuaFile` сценарий в `LoadCore`/`LoadConfigs`/`LoadModules` — корректный, `sv_*` остаются только на сервере.
- Выбор `SWExp.Chars:Choose/Delete/Rename` — ownership enforcement корректен (см. §2).

---

## 7. Нужен ли рефакторинг?

**Короткий ответ: да, нужен, но точечный, а не «с нуля».**

Код в целом структурирован разумно (`core/` → `config/` → `modules/`, `sh/cl/sv` префиксы, разделение на либы). Это уже хороший скелет. Проблемы не в архитектуре, а в **дисциплине**: местами видно, что куски писались разными руками в разное время (дубли хендлеров в `sv_armor.lua`, префикс `nextrp_` в одних файлах и `swexp_` в других, `print 'pos'` в проде).

### Рекомендуемый порядок работ

1. **Срочно (security):** V-03, V-04, V-05, V-06, V-07, V-08. Это прямые эксплойты или утечки пула, они ломают экономику/баланс. 1–2 дня работы.
2. **Срочно (стабильность):** V-01 (несовпадение классов энтити) и V-02 (утечка пула) из `cardealler` — это 🔴 по существующему отчёту, без них модуль просто не работает. Плюс V-11 (дубли в `sv_armor`).
3. **Тактически (7–10 дней):** унификация системы прав (V-17), централизация имён таблиц (§4.2), удаление дублей helper-функций, rate-limit на все netstream-обработчики (общий `SWExp.NetRateLimit(ply, name, cooldown)`).
4. **Стратегически (в фоне):**
   - Обёртка над `MySQLite.query` с обязательной валидацией аргументов и логированием ошибок (сейчас ошибки БД молча теряются);
   - Audit-log в отдельную таблицу `swexp_actions_log` (equip/unequip/drop/transfer/money-change) — поможет и с отладкой, и с ловлей дюп-багов;
   - Отказаться от `print` в пользу `SWExp.Log(level, ...)` с управляемыми уровнями.
5. **Долг:** вынести `cl_test_hud.lua` в dev-аддон, включаемый cvar-ом.

### Чего делать НЕ нужно

- Переписывать геймод с нуля или менять базу `DeriveGamemode('sandbox')` — не оправдано.
- Менять библиотеки (CAMI, MySQLite, Netstream, pon) — они стандартные.
- Трогать load-систему `LoadCore`/`LoadConfigs`/`LoadModules` — она рабочая, нужно только обернуть `include` в `pcall` (V-25).

---

## 8. Быстрый чек-лист для PR №1 (самое важное)

```
[ ] V-03: atomic-флаг в SWExp.Assembler.CraftReq
[ ] V-04: atomic-флаг в SWExp.Research.Deposit
[ ] V-05: валидация uniqueID/slotIndex/newX/newY во всех инвентарных netstream
[ ] V-06: проверка, что entIndex — это именно свой death-bag игрока
[ ] V-07: заменить os.time()-based uniqueID на счётчик
[ ] V-08: удалить modules/cl_test_hud.lua из загрузки
[ ] V-01/V-02: исправить согласно cardealler_bug_report.md
[ ] V-11: удалить один из двух EntityTakeDamage хендлеров в sv_armor
[ ] V-09: вынести MySQL-пароль в server cfg или env
[ ] V-21: удалить все debug print() в sv_dealer, sh_inventory, cl_pickup_notify
```

После этих пунктов геймод можно аккуратно выпускать на продакшн-сервер; остальное — задачи следующей итерации.
