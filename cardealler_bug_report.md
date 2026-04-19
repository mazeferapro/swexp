# Отчёт об ошибках — модуль `cardealler`

**Геймод:** starwarsrp
**Дата анализа:** 2026-03-31
**Файлы:** `sv_dealer.lua`, `sv_carspawns.lua`, `sv_jobparser.lua`, `cl_interface.lua`, `sh_carspawnconfig.lua`

---

## 🔴 КРИТИЧЕСКИЕ ОШИБКИ

### [BUG-01] Несоответствие имён классов энтити (`sv_dealer.lua` ↔ `sv_carspawns.lua`)

**Файлы:** `sv_dealer.lua` (стр. 31), `sv_carspawns.lua` (стр. 168, 201)

В `sv_dealer.lua` дилер создаётся как `nextrp_carspawner`:
```lua
local dealer = ents.Create('nextrp_carspawner')
```

Но в `sv_carspawns.lua` в обработчике `NextRP::ReturnCar` ищется класс `swexp_carspawner`:
```lua
for _, terminal in ipairs(ents.FindByClass("swexp_carspawner")) do
```

И там же в обработчике `SWExp::AddPlatform` проверяется:
```lua
if not IsValid(eSpawner) or eSpawner:GetClass() ~= "swexp_carspawner" then
```

**Последствие:** Функция возврата техники (`NextRP::ReturnCar`) **никогда не найдёт** ни одного терминала, потому что ищет класс с другим именем. Игрок всегда будет получать ошибку "Вы должны пригнать технику в зону гаража". Кнопка "ДОБАВИТЬ ПЛАТФОРМУ" у администраторов тоже не будет работать.

---

### [BUG-02] Отсутствует обработчик отключения игрока (`sv_carspawns.lua`)

**Файл:** `sv_carspawns.lua`

Нет хука на `PlayerDisconnected`. Когда игрок отключается с активной техникой (`pPlayer.SpawnedVeh`), транспортное средство остаётся на карте и **никогда не возвращается в пул**. Счётчик пула постоянно уменьшается.

**Последствие:** Постепенное исчезновение техники из гаража. После нескольких рестартов / отключений игроков пул обнулится без возможности восстановления (до ручного редактирования БД).

**Необходимо добавить:**
```lua
hook.Add("PlayerDisconnected", "SWExp::ReturnVehOnDisconnect", function(ply)
    if IsValid(ply.SpawnedVeh) then
        local sClass = ply.SpawnedVehClass or ply.SpawnedVeh:GetClass()
        SWExp.CarDealer:UpdatePool(sClass, 1)
        ply.SpawnedVeh:Remove()
        ply.SpawnedVeh = nil
        ply.SpawnedVehClass = nil
    end
end)
```

---

### [BUG-03] Отсутствует проверка валидности `eSpawner` в `NextRP::SpawnCar` (`sv_carspawns.lua`, стр. 105–130)

**Файл:** `sv_carspawns.lua`, строки 105–130

Обработчик сети получает `eSpawner` от клиента, но не проверяет его валидность перед обращением к `eSpawner.Platforms`:
```lua
netstream.Hook('NextRP::SpawnCar', function(pPlayer, eSpawner, sClass, iSkin, tBodygroups)
    -- ... проверки игрока ...
    if not eSpawner.Platforms or ...  -- ← Lua ERROR если eSpawner = nil
```

**Последствие:** Если клиент отправит невалидный или nil-объект, сервер словит Lua-ошибку. Возможен краш хука.

---

## 🟠 ЗНАЧИМЫЕ ОШИБКИ

### [BUG-04] Гонка состояний при производстве техники (`sv_carspawns.lua`, стр. 61–101)

**Файл:** `sv_carspawns.lua`, строки 61–101

Проверка материалов и их списание не атомарны:
```lua
local currentMaterials = (SWExp.Assembler and SWExp.Assembler._bank) or 0
if currentMaterials < settings.materialCost then ... end
-- ← Другой игрок может сделать то же самое здесь
SWExp.Assembler._bank = currentMaterials - settings.materialCost
```

**Последствие:** Два игрока могут одновременно заказать дорогую технику. Оба пройдут проверку на `currentMaterials`, но вместе спишут суммарно больше, чем есть в банке. Баланс уйдёт в отрицательные значения.

---

### [BUG-05] `SaveDealers` молча теряет данные (`sv_dealer.lua`, стр. 60–88)

**Файл:** `sv_dealer.lua`, строки 60–88

При попытке сохранить дилеров, если `dealers.txt` не существует — функция создаёт файл и **возвращается**, не сохранив текущих дилеров:
```lua
if dealersInfo == nil then
    file.Write('dealers.txt', '[]')
    print('[NextRP] Создан файл для спавнера техники!')
    return  -- ← Сохранение отменено, дилеры потеряны!
end
```

**Последствие:** При первом вызове сохранения (если файл был удалён) все расставленные дилеры не сохраняются, что вводит администратора в заблуждение (команда выполнилась без ошибки).

---

### [BUG-06] `util.JSONToTable` может вернуть `nil` без проверки (`sv_dealer.lua`, стр. 72)

**Файл:** `sv_dealer.lua`, строка 72 (в `SaveDealers`)

```lua
dealersInfo = util.JSONToTable(dealersInfo)
-- dealersInfo может быть nil, если JSON повреждён
dealersInfo[game.GetMap()] = {}  -- ← Lua ERROR: attempt to index a nil value
```

Если файл `dealers.txt` содержит невалидный JSON, `util.JSONToTable` вернёт `nil`, а следующая строка вызовет Lua-ошибку. Та же проблема в `SpawnDealers`.

---

## 🟡 НЕЗНАЧИТЕЛЬНЫЕ ОШИБКИ И ЗАМЕЧАНИЯ

### [BUG-07] Отладочные `print` в продакшн-коде (`sv_dealer.lua`, стр. 19–28)

**Файл:** `sv_dealer.lua`, строки 19–28

В функции `SpawnDealers` остались дебаг-выводы, которые будут спамить серверную консоль при каждом старте/клинапе карты:
```lua
print 'pos'
print 'ang'
print 'platforms'
print 'faction'
print 'vehs'
```

---

### [BUG-08] Хрупкий `timer.Simple(1, ...)` для инициализации БД (`sv_jobparser.lua`, стр. 49–53)

**Файл:** `sv_jobparser.lua`, строки 49–53

```lua
timer.Simple(1, function()
    if MySQLite and MySQLite.isInitialized and MySQLite.isInitialized() then
        InitCarSettingsDB()
    end
end)
```

Таймер в 1 секунду — ненадёжный способ дождаться инициализации БД. Если база данных поднимается дольше 1 секунды (медленный сервер, сеть), настройки техники не загрузятся. Никакого повторного попытки нет.

---

### [BUG-09] `UpdatePool` не атомарна: in-memory и БД могут расходиться (`sv_carspawns.lua`, стр. 32–43)

**Файл:** `sv_carspawns.lua`, строки 32–43

```lua
SWExp.CarDealer.VehiclePool[class] = newCount  -- in-memory обновляется сразу
MySQLite.query(...)                             -- БД обновляется асинхронно
```

При падении сервера между этими двумя операциями in-memory и БД окажутся в разных состояниях. После перезапуска данные из БД перезапишут более актуальные in-memory данные.

---

### [BUG-10] `SWExp.Ranks.List` может быть nil при открытии редактора (`cl_interface.lua`, стр. 364)

**Файл:** `cl_interface.lua`, строка 364

```lua
for _, r in ipairs(SWExp.Ranks.List) do
```

Если `SWExp.Ranks` или `SWExp.Ranks.List` не инициализировались к моменту открытия редактора, будет Lua-ошибка. Нет защитной проверки.

---

### [BUG-11] Имя транспортного средства нельзя изменить в редакторе (`cl_interface.lua`, стр. 302–399)

**Файл:** `cl_interface.lua`, строки 302–399

В редакторе настроек (`SWExp::GetVeh`) нет поля ввода для `name` — оно захардкожено из данных энтити. При сохранении передаётся то же имя, которое было изначально. Пользователь не может переименовать транспорт через интерфейс.

---

### [BUG-12] `GetVehicleSettings` возвращает ссылку на `DefaultSettings` (`sh_carspawnconfig.lua`, стр. 33)

**Файл:** `sh_carspawnconfig.lua`, строка 33

```lua
return self.DefaultSettings  -- возвращается ссылка, не копия
```

Если где-либо в коде будет изменена возвращённая таблица, это модифицирует глобальные настройки по умолчанию для всех последующих вызовов.

---

## Сводная таблица

| ID | Серьёзность | Файл | Краткое описание |
|----|-------------|------|-----------------|
| BUG-01 | 🔴 Критичная | `sv_dealer.lua` / `sv_carspawns.lua` | Разные имена класса энтити: `nextrp_` vs `swexp_carspawner` — ReturnCar и AddPlatform не работают |
| BUG-02 | 🔴 Критичная | `sv_carspawns.lua` | Нет хука PlayerDisconnected — пул техники утекает |
| BUG-03 | 🔴 Критичная | `sv_carspawns.lua` | Нет IsValid(eSpawner) перед обращением к eSpawner.Platforms |
| BUG-04 | 🟠 Значимая | `sv_carspawns.lua` | Гонка состояний при списании материалов |
| BUG-05 | 🟠 Значимая | `sv_dealer.lua` | SaveDealers молча возвращается при отсутствии файла |
| BUG-06 | 🟠 Значимая | `sv_dealer.lua` | Нет проверки nil после util.JSONToTable |
| BUG-07 | 🟡 Незначит. | `sv_dealer.lua` | Дебаг print-ы в продакшн-коде |
| BUG-08 | 🟡 Незначит. | `sv_jobparser.lua` | Хрупкий timer.Simple(1) для загрузки БД |
| BUG-09 | 🟡 Незначит. | `sv_carspawns.lua` | Неатомарное обновление пула (memory vs БД) |
| BUG-10 | 🟡 Незначит. | `cl_interface.lua` | SWExp.Ranks.List может быть nil в редакторе |
| BUG-11 | 🟡 Незначит. | `cl_interface.lua` | Нет поля для редактирования имени транспорта |
| BUG-12 | 🟡 Незначит. | `sh_carspawnconfig.lua` | GetVehicleSettings возвращает ссылку на DefaultSettings |
