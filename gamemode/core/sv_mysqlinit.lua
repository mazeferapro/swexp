-- core/sv_mysqlinit.lua
-- Создание таблиц при подключении к БД (аналог totrlw sv_mysqlinit.lua)

hook.Add('DatabaseInitialized', 'SWExp::CreateTables', function()

    -- players
    MySQLite.query([[
        CREATE TABLE IF NOT EXISTS swexp_players (
            id              INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
            steamid         VARCHAR(25) NOT NULL UNIQUE,
            community_id    VARCHAR(25) DEFAULT NULL,
            character_slots INT NOT NULL DEFAULT 1,
            donate_currency INT NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    ]], function()

        -- characters
        MySQLite.query([[
            CREATE TABLE IF NOT EXISTS swexp_characters (
                id           INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
                player_id    INT NOT NULL,
                clone_number VARCHAR(32) NOT NULL,
                callsign     VARCHAR(64) NOT NULL,
                `rank`       VARCHAR(64) NOT NULL DEFAULT 'CT'
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
        ]], function()

            -- inventory
            MySQLite.query([[
                CREATE TABLE IF NOT EXISTS swexp_inventory (
                    id           INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
                    character_id INT NOT NULL,
                    item_class   VARCHAR(128) NOT NULL,
                    item_data    TEXT DEFAULT NULL,
                    slot         VARCHAR(32) NOT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
            ]], function()

                -- cosmetics
                MySQLite.query([[
                    CREATE TABLE IF NOT EXISTS swexp_cosmetics (
                        id          INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
                        player_id   INT NOT NULL,
                        cosmetic_id VARCHAR(128) NOT NULL,
                        equipped    TINYINT(1) NOT NULL DEFAULT 0
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
                ]], function()

                    -- server_progress (всегда одна строка id=1)
                    MySQLite.query([[
                        CREATE TABLE IF NOT EXISTS swexp_server_progress (
                            id              INT NOT NULL DEFAULT 1 PRIMARY KEY,
                            tech_level      INT NOT NULL DEFAULT 1,
                            research_points INT NOT NULL DEFAULT 0,
                            materials       INT NOT NULL DEFAULT 0
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
                    ]], function()
                        MySQLite.query([[
                            INSERT IGNORE INTO swexp_server_progress (id, tech_level, research_points, materials)
                            VALUES (1, 1, 0, 0);
                        ]])

                        -- vehicles (пул ангара)
                        MySQLite.query([[
                            CREATE TABLE IF NOT EXISTS swexp_vehicles (
                                entity_class VARCHAR(128) NOT NULL PRIMARY KEY,
                                amount       INT NOT NULL DEFAULT 0
                            ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
                        ]], function()
                            print('[SWExp] Все таблицы БД созданы.')
                        end)

                    end)
                end)
            end)
        end)
    end)

end)