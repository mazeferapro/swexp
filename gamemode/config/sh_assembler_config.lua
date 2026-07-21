-- ============================================================
-- Star Wars: Expedition — Конфигурация Ассемблера
-- config/sh_assembler_config.lua
--
-- Рецепты крафта и настройки дневных лимитов расхода материалов.
--
-- КАК РАБОТАЕТ СИСТЕМА:
--   1. Игрок собирает «Материалы» на планете (один тип, разные зоны = разное кол-во)
--   2. Подходит к Ассемблеру и сдаёт материалы → они поступают в общий банк отряда
--   3. Для крафта расходуются материалы из банка
--   4. У каждого звания есть дневной лимит расхода (кол-во материалов в сутки)
--   5. Командир меняет лимиты прямо в игре через интерфейс Ассемблера
-- ============================================================

SWExp.AssemblerConfig = SWExp.AssemblerConfig or {}

-- ============================================================
-- КАТЕГОРИИ — порядок отображения в UI
-- ============================================================

SWExp.AssemblerConfig.Categories = {
    { id = "armor",      name = "Броня",        icon = "swexpicon/swexp-swexp-armor1.png"      },
    { id = "weapon",     name = "Оружие",       icon = "swexpicon/swexp-swords.png"      },
    { id = "ammo",       name = "Боеприпасы",   icon = "swexpicon/swexp-swexp-ammo.png" },
    { id = "medkit",     name = "Медикаменты",  icon = "swexpicon/swexp-health.png"      },
    { id = "tool",       name = "Инструменты",  icon = "swexpicon/swexp-wrench.png"      },
    { id = "key",        name = "Ключи",        icon = "swexpicon/swexp-lock.png"      },
    { id = "fort",       name = "Строительство",icon = "swexpicon/swexp-shotgunammo.png"       },
    { id = "granade",    name = "Гранаты",      icon = "swexpicon/swexp-nade-thermal.png"       },
}

-- ============================================================
-- РЕЦЕПТЫ
-- cost — количество материалов из общего банка
-- ============================================================

SWExp.AssemblerConfig.Recipes = {

    -- ====================  БРОНЯ  ====================
    -- Иконки НЕ указываем — они подтягиваются автоматически из sh_inventory.lua
    -- через SWExp.AssemblerConfig.GetRecipeIcon()

    -- Тир 1 (уровень 1)
    { id="armor_light_t1",  result="armor_light_t1",  category="armor", techLevel=1, cost=8,
      name="Лёгкая броня (Тир 1)",     desc="10% поглощения. Крюк-кошка."           },
    { id="armor_medium_t1", result="armor_medium_t1", category="armor", techLevel=1, cost=12,
      name="Средняя броня (Тир 1)",    desc="30% поглощения."                        },
    { id="armor_heavy_t1",  result="armor_heavy_t1",  category="armor", techLevel=1, cost=16,
      name="Тяжёлая броня (Тир 1)",    desc="40% поглощения."                        },
    { id="armor_eng_t1",    result="armor_eng_t1",    category="armor", techLevel=1, cost=12,
      name="Инженерная броня (Тир 1)", desc="25% поглощения. Датапад строителя."    },
    { id="armor_med_t1",    result="armor_med_t1",    category="armor", techLevel=1, cost=12,
      name="Броня медика (Тир 1)",     desc="25% поглощения. Дефибриллятор + Бакто-инжектор." },

    -- Тир 2 (уровень 2)
    { id="armor_light_t2",  result="armor_light_t2",  category="armor", techLevel=2, cost=20,
      name="Лёгкая броня (Тир 2)",     desc="15% поглощения. Крюк-кошка."           },
    { id="armor_medium_t2", result="armor_medium_t2", category="armor", techLevel=2, cost=28,
      name="Средняя броня (Тир 2)",    desc="35% поглощения."                        },
    { id="armor_heavy_t2",  result="armor_heavy_t2",  category="armor", techLevel=2, cost=36,
      name="Тяжёлая броня (Тир 2)",    desc="45% поглощения."                        },
    { id="armor_eng_t2",    result="armor_eng_t2",    category="armor", techLevel=2, cost=24,
      name="Инженерная броня (Тир 2)", desc="30% поглощения. Датапад строителя."    },
    { id="armor_med_t2",    result="armor_med_t2",    category="armor", techLevel=2, cost=24,
      name="Броня медика (Тир 2)",     desc="30% поглощения. Дефибриллятор + Бакто-инжектор." },

    -- Тир 3 (уровень 3)
    { id="armor_light_t3",  result="armor_light_t3",  category="armor", techLevel=3, cost=40,
      name="Лёгкая броня (Тир 3)",     desc="20% поглощения. Крюк-кошка."           },
    { id="armor_medium_t3", result="armor_medium_t3", category="armor", techLevel=3, cost=52,
      name="Средняя броня (Тир 3)",    desc="40% поглощения."                        },
    { id="armor_heavy_t3",  result="armor_heavy_t3",  category="armor", techLevel=3, cost=68,
      name="Тяжёлая броня (Тир 3)",    desc="50% поглощения."                        },
    { id="armor_eng_t3",    result="armor_eng_t3",    category="armor", techLevel=3, cost=44,
      name="Инженерная броня (Тир 3)", desc="35% поглощения. Датапад строителя."    },
    { id="armor_med_t3",    result="armor_med_t3",    category="armor", techLevel=3, cost=44,
      name="Броня медика (Тир 3)",     desc="35% поглощения. Дефибриллятор + Бакто-инжектор." },

    -- Тир 4 (уровень 4)
    { id="armor_light_t4",  result="armor_light_t4",  category="armor", techLevel=4, cost=70,
      name="Лёгкая броня (Тир 4)",     desc="25% поглощения. Крюк-кошка."           },
    { id="armor_medium_t4", result="armor_medium_t4", category="armor", techLevel=4, cost=90,
      name="Средняя броня (Тир 4)",    desc="45% поглощения."                        },
    { id="armor_heavy_t4",  result="armor_heavy_t4",  category="armor", techLevel=4, cost=110,
      name="Тяжёлая броня (Тир 4)",    desc="55% поглощения."                        },
    { id="armor_eng_t4",    result="armor_eng_t4",    category="armor", techLevel=4, cost=75,
      name="Инженерная броня (Тир 4)", desc="40% поглощения. Датапад строителя."    },
    { id="armor_med_t4",    result="armor_med_t4",    category="armor", techLevel=4, cost=75,
      name="Броня медика (Тир 4)",     desc="40% поглощения. Дефибриллятор + Бакто-инжектор." },

    -- Тир 5 (уровень 5)
    { id="armor_light_t5",  result="armor_light_t5",  category="armor", techLevel=5, cost=110,
      name="Лёгкая броня (Тир 5)",     desc="30% поглощения. Крюк-кошка."           },
    { id="armor_medium_t5", result="armor_medium_t5", category="armor", techLevel=5, cost=140,
      name="Средняя броня (Тир 5)",    desc="50% поглощения."                        },
    { id="armor_heavy_t5",  result="armor_heavy_t5",  category="armor", techLevel=5, cost=180,
      name="Тяжёлая броня (Тир 5)",    desc="60% поглощения."                        },
    { id="armor_eng_t5",    result="armor_eng_t5",    category="armor", techLevel=5, cost=120,
      name="Инженерная броня (Тир 5)", desc="45% поглощения. Датапад строителя."    },
    { id="armor_med_t5",    result="armor_med_t5",    category="armor", techLevel=5, cost=120,
      name="Броня медика (Тир 5)",     desc="45% поглощения. Дефибриллятор + Бакто-инжектор." },

    -- ====================  ОРУЖИЕ  ====================
    -- Иконки подтягиваются автоматически из sh_inventory.lua через GetRecipeIcon().
    -- icon указывается явно только для предметов без записи в инвентаре.
    -- Редкость → Тир: common=1, uncommon=2, rare=3, epic=4, legendary=5

    -- Тир 1 (common)
    { id="weapon_dc15s",         result="weapon_dc15s",         category="weapon", techLevel=1, cost=10,
      name="DC-15S Бластер-карабин",        desc="Укороченная бластерная винтовка клонов. Слот PRIMARY."          },
    { id="weapon_dc17",          result="weapon_dc17",          category="weapon", techLevel=1, cost=6,
      name="DC-17 Пистолет",                desc="Стандартный пистолет клонов. Слот SECONDARY."                   },

    -- Тир 2 (uncommon)
    { id="weapon_dc15a",         result="weapon_dc15a",         category="weapon", techLevel=2, cost=18,
      name="DC-15A Бластерная винтовка",    desc="Стандартная бластерная винтовка клонов. Слот PRIMARY."          },
    { id="weapon_dc15sg",        result="weapon_dc15sg",        category="weapon", techLevel=2, cost=20,
      name="DC-15SG Гренадёрская",          desc="DC-15S с подствольным гранатомётом. Слот PRIMARY."              },
    { id="weapon_dc15x",         result="weapon_dc15x",         category="weapon", techLevel=2, cost=22,
      name="DC-15X Снайперская",            desc="Снайперская версия DC-15. Слот PRIMARY."                        },
    { id="weapon_dc17e",         result="weapon_dc17e",         category="weapon", techLevel=2, cost=14,
      name="DC-17 Расширенный",             desc="DC-17 с расширенным магазином. Слот SECONDARY."                 },
    { id="weapon_dc17d",         result="weapon_dc17d",         category="weapon", techLevel=2, cost=16,
      name="DC-17 Двойные",                 desc="Пара стандартных DC-17 акимбо. Слот SECONDARY."                 },
    { id="weapon_dp24",          result="weapon_dp24",          category="weapon", techLevel=2, cost=18,
      name="DP-24",                         desc="Лёгкий бластерный пулемёт. Слот PRIMARY."                       },
    { id="weapon_rps6",          result="weapon_rps6",          category="weapon", techLevel=2, cost=24,
      name="RPS-6",                         desc="Ручной ракетный пусковой комплекс. Слот HEAVY."                 },
    { id="weapon_z6",            result="weapon_z6",            category="weapon", techLevel=2, cost=24,
      name="Z-6 Роторная пушка",            desc="Тяжёлая роторная бластерная пушка. Слот HEAVY."                 },

    -- Тир 3 (rare)
    { id="weapon_dc15ag",        result="weapon_dc15ag",        category="weapon", techLevel=3, cost=35,
      name="DC-15AG Гренадёрская",          desc="DC-15A с подствольным гранатомётом. Слот PRIMARY."              },
    { id="weapon_dc17de",        result="weapon_dc17de",        category="weapon", techLevel=3, cost=28,
      name="DC-17 Двойные улучшенные",      desc="Пара улучшенных DC-17 акимбо. Слот SECONDARY."                  },
    { id="weapon_dp23",          result="weapon_dp23",          category="weapon", techLevel=3, cost=38,
      name="DP-23",                         desc="Улучшенный бластерный пулемёт. Слот PRIMARY."                   },
    { id="weapon_",              result="weapon_",              category="weapon", techLevel=3, cost=38,
      name="DP-24C",                        desc="DP-24 с компактным кожухом. Слот PRIMARY.",                    },
    { id="weapon_e9",            result="weapon_e9",            category="weapon", techLevel=3, cost=32,
      name="E-9",                           desc="Компактная бластерная винтовка. Слот PRIMARY."                   },
    { id="weapon_dc15le",        result="weapon_dc15le",        category="weapon", techLevel=3, cost=40,
      name="DC-15LE",                       desc="Облегчённая версия DC-15. Слот PRIMARY."                         },
    { id="weapon_smartlauncher", result="weapon_smartlauncher", category="weapon", techLevel=3, cost=42,
      name="Smart Launcher",                desc="Самонаводящийся гранатомёт. Слот PRIMARY."                       },
    { id="weapon_hh12",          result="weapon_hh12",          category="weapon", techLevel=3, cost=45,
      name="HH-12",                         desc="Тяжёлый ракетный комплекс. Слот HEAVY."                         },
    { id="weapon_z6a",           result="weapon_z6a",           category="weapon", techLevel=3, cost=48,
      name="Z-6 Advanced",                  desc="Улучшенная роторная бластерная пушка. Слот HEAVY."               },

    -- Тир 4 (epic)
    { id="weapon_dp23c",         result="weapon_dp23c",         category="weapon", techLevel=4, cost=70,
      name="DP-23C",                        desc="DP-23 с компактным кожухом. Слот PRIMARY."                       },
    { id="weapon_westarm5",      result="weapon_westarm5",      category="weapon", techLevel=4, cost=75,
      name="Westarm-5",                     desc="Высокотехнологичная бластерная система. Слот PRIMARY."           },
    { id="weapon_plx1",          result="weapon_plx1",          category="weapon", techLevel=4, cost=90,
      name="PLX-1",                         desc="Тяжёлый противотанковый ракетный комплекс. Слот HEAVY."         },

    -- Тир 5 (legendary)
    { id="weapon_g125",          result="weapon_g125",          category="weapon", techLevel=5, cost=120,
      name="G-125",                         desc="Легендарный пистолет. Слот SECONDARY.",                         },
    { id="weapon_antimaterial",  result="weapon_antimaterial",  category="weapon", techLevel=5, cost=150,
      name="K-43 Противоматериальная",      desc="Легендарная снайперская винтовка. Слот PRIMARY."                },

    -- ====================  БОЕПРИПАСЫ  ====================
    -- ammo_blaster — нет записи в инвентаре, icon задаём явно.

    { id="ammo_blaster", result="ammo_blaster", amount=30, category="ammo", techLevel=1, cost=3,
      name="Энергоячейки (×30)", desc="Стандартные энергоячейки для бластеров.", icon="icon16/ammo.png" },

    -- ====================  МЕДИКАМЕНТЫ  ====================
    -- Иконки из инвентаря (swexpicon/swexp-health.png)

    { id="medkit",          result="medkit",          category="medkit", techLevel=1, cost=2,
      name="Аптечка (20 HP)",            desc="Восстанавливает 20 HP."                                 },
    { id="medkit_advanced", result="medkit_advanced", category="medkit", techLevel=2, cost=3,
      name="Аптечка улучшенная (40 HP)", desc="Восстанавливает 40 HP. Улучшенная формула бакто-геля." },
    { id="medkit_sci", result="medkit_sci", category="medkit", techLevel=3, cost=4,
      name="Научная аптечка (60 HP)", desc="Восстанавливает 60 HP." },
    { id="medkit_exo", result="medkit_exo", category="medkit", techLevel=4, cost=5,
      name="Экзо аптечка (80 HP)", desc="Восстанавливает 80 HP." },
    { id="medkit_nanit", result="medkit_nanit", category="medkit", techLevel=5, cost=6,
      name="Нанитная аптечка (100 HP)", desc="Восстанавливает 100 HP." },

    -- ====================  ИНСТРУМЕНТЫ  ====================
    -- Иконки из инвентаря

    { id="tool_scanner",    result="tool_scanner",    category="tool", techLevel=1, cost=20,
      name="Научный сканер",   desc="Основной инструмент сбора ОИ. Дорогой — берегите."               },
    { id="tool_flashlight", result="tool_flashlight", category="tool", techLevel=1, cost=6,
      name="Тактический фонарик", desc="Фонарик для тёмных зон. Экипируется в специальный слот, активируется ПКМ." },

    -- ====================  КЛЮЧИ  ====================
    -- Иконки из инвентаря (swexpicon/swexp-unlock.png)

    { id="key_tier1", result="key_tier1", category="key", techLevel=2, cost=30,
      name="Ключ врат Тир 1", desc="Открывает Зону 2. Теряется при смерти."   },
    { id="key_tier2", result="key_tier2", category="key", techLevel=3, cost=60,
      name="Ключ врат Тир 2", desc="Открывает Зону 3. Теряется при смерти."   },
    { id="key_tier3", result="key_tier3", category="key", techLevel=4, cost=100,
      name="Ключ врат Тир 3", desc="Открывает Зону 4 — максимальная опасность." },

    -- ====================  СТРОИТЕЛЬСТВО  ====================
    -- Иконки из инвентаря (icon16/brick.png)

    { id="fort_supply_1", result="fort_supply", amount=5,  category="fort", techLevel=1, cost=5,
      name="Строительные ресурсы (×5)",  desc="Полевые материалы для возведения базовых заграждений. (5 шт.)"  },
    { id="fort_supply_2", result="fort_supply", amount=15, category="fort", techLevel=2, cost=12,
      name="Строительные ресурсы (×15)", desc="Усиленный пакет строительных материалов. (15 шт.)"             },
    { id="fort_supply_3", result="fort_supply", amount=30, category="fort", techLevel=3, cost=22,
      name="Строительные ресурсы (×30)", desc="Большой запас материалов для серьёзных укреплений. (30 шт.)"   },
    
    -- ====================  СТРОИТЕЛЬСТВО  ====================

    { id="arccwknadebacta", result="arccwknadebacta", category="granade", techLevel=1, cost=5,
      name="Бакта-граната", desc="Граната с бактой." },

    { id="arccwknadefrag", result="arccwknadefrag", category="granade", techLevel=1, cost=5,
      name="Граната C-14 (фраг)", desc="Противотанковая граната." },

    { id="arccwknadethermal", result="arccwknadethermal", category="granade", techLevel=1, cost=5,
      name="Термальный детонатор", desc="Высокий урон по площади." },

    { id="arccwknadesmoke", result="arccwknadesmoke", category="granade", techLevel=1, cost=5,
      name="Дымовая граната", desc="Создаёт облако дыма." },

    { id="arccwknadeflashbang", result="arccwknadeflashbang", category="granade", techLevel=1, cost=5,
      name="Светошумовая граната", desc="Ослепляет противников." },

    { id="arccwknadestun", result="arccwknadestun", category="granade", techLevel=1, cost=5,
      name="Электрошоковая граната", desc="Парализует на короткое время." },
    
    { id="arccwknadeshock", result="arccwknadeshock", category="granade", techLevel=1, cost=5,
      name="Шок-граната", desc="Электрический разряд по площади." },

    { id="arccwknadethermite", result="arccwknadethermite", category="granade", techLevel=1, cost=5,
      name="Термитная шашка", desc="Прожигает металл." },

    { id="arccwknadeimpact", result="arccwknadeimpact", category="granade", techLevel=1, cost=5,
      name="Импактная граната", desc="Взрывается от удара." },

    { id="arccwknadedioxis", result="arccwknadedioxis", category="granade", techLevel=1, cost=5,
      name="Граната Диоксис", desc="Граната с диоксисом." },

    { id="arccwknadesequencecharger", result="arccwknadesequencecharger", category="granade", techLevel=1, cost=5,
      name="Секвинсер", desc="Большой бабах." },

    { id="arccwknadeantitankmine", result="arccwknadeantitankmine", category="granade", techLevel=1, cost=5,
      name="Анти-танк мина", desc="Противотанковая мина." },

    { id="arccwknadethermalimploder", result="arccwknadethermalimploder", category="granade", techLevel=1, cost=5,
      name="Усиленная термальная", desc="Улучшенная термальная граната." },

    { id="arccwknadeplasmagrenade", result="arccwknadeplasmagrenade", category="granade", techLevel=1, cost=5,
      name="Плазменная граната", desc="Взрывается плазмой." },

    { id="arccwknadec25", result="arccwknadec25", category="granade", techLevel=1, cost=5,
      name="С-25", desc="С-25" },

    { id="arccwknadesonar", result="arccwknadesonar", category="granade", techLevel=1, cost=5,
      name="Сонар граната", desc="Подсвечивает врагов." },

    { id="arccwknadeblaststick", result="arccwknadeblaststick", category="granade", techLevel=1, cost=5,
      name="Бластик", desc="Просто бластик." },

    { id="arccwknadedetonite", result="arccwknadedetonite", category="granade", techLevel=1, cost=5,
      name="Детонит", desc="Прикрепляется к поверхностям." },

    { id="arccwknadedecoy", result="arccwknadedecoy", category="granade", techLevel=1, cost=5,
      name="Декой", desc="Привлекает врагов." },
}

-- ============================================================
-- ДНЕВНЫЕ ЛИМИТЫ РАСХОДА МАТЕРИАЛОВ ПО УМОЛЧАНИЮ
-- rankID → сколько материалов из банка можно потратить за сутки
-- Командир меняет их в игре; значения ниже — стартовые по умолчанию.
-- ============================================================

SWExp.AssemblerConfig.DefaultDailyLimits = {
    TRP   = 30,    -- Рядовой
    CPL   = 40,    -- Капрал
    SGT   = 55,    -- Сержант
    SSGT  = 70,    -- Старший сержант
    SGM   = 85,    -- Сержант-майор
    LT    = 100,   -- Лейтенант
    CPT   = 120,   -- Капитан
    MAJ   = 150,   -- Майор
    CMDR  = 200,   -- Командир
    MCMDR = 999,   -- Маршал-командир (практически без ограничений)
}

-- Минимальный гарантированный лимит (для неизвестных/новых званий)
SWExp.AssemblerConfig.DefaultLimit = 30

-- ============================================================
-- Вспомогательные функции
-- ============================================================

function SWExp.AssemblerConfig.GetRecipesByCategory(categoryID)
    local result = {}
    for _, recipe in ipairs(SWExp.AssemblerConfig.Recipes) do
        if recipe.category == categoryID then
            table.insert(result, recipe)
        end
    end
    table.sort(result, function(a, b)
        if a.techLevel ~= b.techLevel then return a.techLevel < b.techLevel end
        return (a.cost or 0) < (b.cost or 0)
    end)
    return result
end

function SWExp.AssemblerConfig.GetRecipe(recipeID)
    for _, recipe in ipairs(SWExp.AssemblerConfig.Recipes) do
        if recipe.id == recipeID then return recipe end
    end
    return nil
end

function SWExp.AssemblerConfig.GetDefaultLimit(rankID)
    return SWExp.AssemblerConfig.DefaultDailyLimits[rankID]
        or SWExp.AssemblerConfig.DefaultLimit
end

-- ============================================================
-- Получить иконку рецепта: сначала из SWExp.Inventory.Items
-- (единственный источник правды), затем fallback на recipe.icon.
-- Благодаря этому достаточно прописать icon один раз — в
-- sh_inventory.lua, и ассемблер подхватит её автоматически.
-- ============================================================

function SWExp.AssemblerConfig.GetRecipeIcon(recipe)
    if not recipe then return nil end

    -- Приоритет: иконка зарегистрированного предмета инвентаря
    local inv = SWExp.Inventory
    if inv and inv.Items then
        local itemData = inv.Items[recipe.result]
        if itemData and itemData.icon and itemData.icon ~= "" then
            return itemData.icon
        end
    end

    -- Fallback: иконка, прописанная прямо в рецепте
    return recipe.icon or nil
end
