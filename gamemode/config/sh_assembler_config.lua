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
    { id = "armor",   name = "Броня",        icon = "icon16/shield.png"  },
    { id = "weapon",  name = "Оружие",       icon = "icon16/gun.png"     },
    { id = "ammo",    name = "Боеприпасы",   icon = "icon16/bomb.png"    },
    { id = "medkit",  name = "Медикаменты",  icon = "icon16/heart.png"   },
    { id = "tool",    name = "Инструменты",  icon = "icon16/wrench.png"  },
    { id = "key",     name = "Ключи",        icon = "icon16/key.png"     },
}

-- ============================================================
-- РЕЦЕПТЫ
-- cost — количество материалов из общего банка
-- ============================================================

SWExp.AssemblerConfig.Recipes = {

    -- ====================  БРОНЯ  ====================

    -- Тир 1 (уровень 1)
    { id="armor_light_t1",    result="armor_light_t1",    category="armor",  techLevel=1, cost=8,
      name="Лёгкая броня (Тир 1)",    desc="Разведчик — 10% поглощения. Открывает крюк-кошку.",          icon="icon16/user.png"    },
    { id="armor_medium_t1",   result="armor_medium_t1",   category="armor",  techLevel=1, cost=12,
      name="Средняя броня (Тир 1)",   desc="Универсальный — 20% поглощения. 2 слота основного оружия.",  icon="icon16/shield.png"  },
    { id="armor_heavy_t1",    result="armor_heavy_t1",    category="armor",  techLevel=1, cost=16,
      name="Тяжёлая броня (Тир 1)",   desc="Тяжеловес — 30% поглощения. Открывает слот тяжёлого.",      icon="icon16/shield.png"  },
    { id="armor_engineer_t1", result="armor_engineer_t1", category="armor",  techLevel=1, cost=12,
      name="Инженерная броня (Тир 1)",desc="Инженер — 15% поглощения. Датапад строителя.",               icon="icon16/wrench.png"  },
    { id="armor_medic_t1",    result="armor_medic_t1",    category="armor",  techLevel=1, cost=12,
      name="Медицинская броня (Тир 1)",desc="Медик — 15% поглощения. Дефибриллятор + Бакто-инжектор.",  icon="icon16/heart.png"   },

    -- Тир 2 (уровень 2)
    { id="armor_light_t2",    result="armor_light_t2",    category="armor",  techLevel=2, cost=20,
      name="Лёгкая броня (Тир 2)",    desc="Разведчик — 15% поглощения. Крюк-кошка Mk.II.",             icon="icon16/user.png"    },
    { id="armor_medium_t2",   result="armor_medium_t2",   category="armor",  techLevel=2, cost=28,
      name="Средняя броня (Тир 2)",   desc="Универсальный — 25% поглощения.",                           icon="icon16/shield.png"  },
    { id="armor_heavy_t2",    result="armor_heavy_t2",    category="armor",  techLevel=2, cost=36,
      name="Тяжёлая броня (Тир 2)",   desc="Тяжеловес — 40% поглощения.",                               icon="icon16/shield.png"  },
    { id="armor_engineer_t2", result="armor_engineer_t2", category="armor",  techLevel=2, cost=24,
      name="Инженерная броня (Тир 2)",desc="Инженер — 20% поглощения.",                                  icon="icon16/wrench.png"  },
    { id="armor_medic_t2",    result="armor_medic_t2",    category="armor",  techLevel=2, cost=24,
      name="Медицинская броня (Тир 2)",desc="Медик — 20% поглощения.",                                   icon="icon16/heart.png"   },

    -- Тир 3 (уровень 3)
    { id="armor_light_t3",    result="armor_light_t3",    category="armor",  techLevel=3, cost=40,
      name="Лёгкая броня (Тир 3)",    desc="Разведчик — 20% поглощения.",                               icon="icon16/user.png"    },
    { id="armor_medium_t3",   result="armor_medium_t3",   category="armor",  techLevel=3, cost=52,
      name="Средняя броня (Тир 3)",   desc="Универсальный — 30% поглощения.",                           icon="icon16/shield.png"  },
    { id="armor_heavy_t3",    result="armor_heavy_t3",    category="armor",  techLevel=3, cost=68,
      name="Тяжёлая броня (Тир 3)",   desc="Тяжеловес — 50% поглощения.",                               icon="icon16/shield.png"  },
    { id="armor_engineer_t3", result="armor_engineer_t3", category="armor",  techLevel=3, cost=44,
      name="Инженерная броня (Тир 3)",desc="Инженер — 25% поглощения.",                                  icon="icon16/wrench.png"  },
    { id="armor_medic_t3",    result="armor_medic_t3",    category="armor",  techLevel=3, cost=44,
      name="Медицинская броня (Тир 3)",desc="Медик — 25% поглощения.",                                   icon="icon16/heart.png"   },

    -- Тир 4 (уровень 4)
    { id="armor_light_t4",    result="armor_light_t4",    category="armor",  techLevel=4, cost=70,
      name="Лёгкая броня (Тир 4)",    desc="Разведчик — 25% поглощения.",                               icon="icon16/user.png"    },
    { id="armor_medium_t4",   result="armor_medium_t4",   category="armor",  techLevel=4, cost=90,
      name="Средняя броня (Тир 4)",   desc="Универсальный — 40% поглощения.",                           icon="icon16/shield.png"  },
    { id="armor_heavy_t4",    result="armor_heavy_t4",    category="armor",  techLevel=4, cost=110,
      name="Тяжёлая броня (Тир 4)",   desc="Тяжеловес — 60% поглощения.",                               icon="icon16/shield.png"  },
    { id="armor_engineer_t4", result="armor_engineer_t4", category="armor",  techLevel=4, cost=75,
      name="Инженерная броня (Тир 4)",desc="Инженер — 30% поглощения.",                                  icon="icon16/wrench.png"  },
    { id="armor_medic_t4",    result="armor_medic_t4",    category="armor",  techLevel=4, cost=75,
      name="Медицинская броня (Тир 4)",desc="Медик — 30% поглощения.",                                   icon="icon16/heart.png"   },

    -- Тир 5 (уровень 5)
    { id="armor_light_t5",    result="armor_light_t5",    category="armor",  techLevel=5, cost=110,
      name="Лёгкая броня (Тир 5)",    desc="Разведчик — 30% поглощения.",                               icon="icon16/user.png"    },
    { id="armor_medium_t5",   result="armor_medium_t5",   category="armor",  techLevel=5, cost=140,
      name="Средняя броня (Тир 5)",   desc="Универсальный — 50% поглощения.",                           icon="icon16/shield.png"  },
    { id="armor_heavy_t5",    result="armor_heavy_t5",    category="armor",  techLevel=5, cost=180,
      name="Тяжёлая броня (Тир 5)",   desc="Тяжеловес — 70% поглощения.",                               icon="icon16/shield.png"  },
    { id="armor_engineer_t5", result="armor_engineer_t5", category="armor",  techLevel=5, cost=120,
      name="Инженерная броня (Тир 5)",desc="Инженер — 35% поглощения.",                                  icon="icon16/wrench.png"  },
    { id="armor_medic_t5",    result="armor_medic_t5",    category="armor",  techLevel=5, cost=120,
      name="Медицинская броня (Тир 5)",desc="Медик — 35% поглощения.",                                   icon="icon16/heart.png"   },
    { id="armor_exotic_t5",   result="armor_exotic_t5",   category="armor",  techLevel=5, cost=220,
      name="Экзотическая броня (Тир 5)",desc="Биотехнологический прототип Вонгов. Уникальные параметры.",icon="icon16/star.png"    },

    -- ====================  ОРУЖИЕ  ====================

    { id="weapon_dc17",     result="weapon_dc17",     category="weapon", techLevel=1, cost=6,
      name="DC-17 Пистолет",          desc="Стандартный пистолет клонов.",                              icon="icon16/gun.png"     },
    { id="weapon_dc15a",    result="weapon_dc15a",    category="weapon", techLevel=1, cost=10,
      name="DC-15A Бластерная винтовка",desc="Стандартная бластерная винтовка клонов.",                 icon="icon16/gun.png"     },
    { id="weapon_z6",       result="weapon_z6",       category="weapon", techLevel=4, cost=90,
      name="Z-6 Роторная пушка",      desc="Тяжёлая роторная пушка. Требует слот HEAVY.",               icon="icon16/bomb.png"    },
    { id="weapon_artifact", result="weapon_artifact", category="weapon", techLevel=5, cost=150,
      name="Артефактное оружие",       desc="Оружие древней цивилизации — уникальный тип урона.",        icon="icon16/lightning.png"},

    -- ====================  БОЕПРИПАСЫ  ====================

    { id="ammo_blaster",      result="ammo_blaster",      amount=30, category="ammo", techLevel=1, cost=3,
      name="Энергоячейки (×30)",      desc="Стандартные энергоячейки для бластеров.",                   icon="icon16/lightbulb.png"},
    { id="ammo_grenade",      result="ammo_grenade",      amount=2,  category="ammo", techLevel=2, cost=8,
      name="Осколочные гранаты (×2)", desc="Стандартные фрагментационные гранаты.",                     icon="icon16/bomb.png"    },
    { id="ammo_thermal_det",  result="ammo_thermal_det",  amount=2,  category="ammo", techLevel=3, cost=15,
      name="Термальные детонаторы (×2)",desc="Тепловые гранаты — эффективны против скоплений Вонгов.", icon="icon16/bomb.png"    },

    -- ====================  МЕДИКАМЕНТЫ  ====================

    { id="medkit",          result="medkit",         category="medkit", techLevel=1, cost=5,
      name="Аптечка (50 HP)",          desc="Восстанавливает 50 HP.",                                   icon="icon16/heart.png"   },
    { id="medkit_advanced", result="medkit_advanced", category="medkit", techLevel=2, cost=10,
      name="Аптечка улучшенная (80 HP)",desc="Восстанавливает 80 HP. Улучшенная формула бакто-геля.",  icon="icon16/heart.png"   },
    { id="stim_stamina",    result="stim_stamina",    category="medkit", techLevel=2, cost=8,
      name="Стимулятор выносливости",  desc="Временно снимает ограничение бега на 30 сек.",             icon="icon16/heart_add.png"},
    { id="antidote",        result="antidote",        category="medkit", techLevel=3, cost=18,
      name="Антидот Вонгских токсинов",desc="Нейтрализует биологические яды Юужань Вонгов.",            icon="icon16/heart_add.png"},

    -- ====================  ИНСТРУМЕНТЫ  ====================

    { id="tool_scanner", result="tool_scanner", category="tool", techLevel=1, cost=20,
      name="Научный сканер",           desc="Основной инструмент сбора ОИ. Дорогой — берегите.",        icon="icon16/transmit.png"},
    { id="tool_shield",  result="tool_shield",  category="tool", techLevel=3, cost=45,
      name="Персональный щит",         desc="Временный энергетический щит. Слот SPECIAL.",              icon="icon16/bullet_shield.png"},
    { id="implant_vong", result="implant_vong", category="tool", techLevel=4, cost=60,
      name="Вонгский биоимплант",      desc="Временный бонус к выносливости и HP.",                     icon="icon16/asterisk_orange.png"},

    -- ====================  КЛЮЧИ  ====================

    { id="key_tier1", result="key_tier1", category="key", techLevel=2, cost=30,
      name="Ключ врат Тир 1",          desc="Открывает Зону 2. Теряется при смерти.",                   icon="icon16/key.png"     },
    { id="key_tier2", result="key_tier2", category="key", techLevel=3, cost=60,
      name="Ключ врат Тир 2",          desc="Открывает Зону 3. Теряется при смерти.",                   icon="icon16/key.png"     },
    { id="key_tier3", result="key_tier3", category="key", techLevel=4, cost=100,
      name="Ключ врат Тир 3",          desc="Открывает Зону 4 — максимальная опасность.",               icon="icon16/key.png"     },
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
