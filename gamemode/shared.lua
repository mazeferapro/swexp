GM.Name          = 'Star Wars: Expedition'
GM.Version       = '1.0.0'
GM.ServerVersion = '1.0.0'
GM.Author        = ''
GM.Email         = ''
GM.Website       = ''
GM.FolderName    = engine.ActiveGamemode()

DeriveGamemode('sandbox')

MsgC('\n==============================================\n=\n')
MsgC('= SWExp начал загружаться.\n= Версия: '..GM.Version..'\n=\n')
MsgC('==============================================\n\n')

-- ============================================================
-- Глобальная таблица геймода
-- ============================================================
SWExp = SWExp or {}

-- ============================================================
-- Загрузка либ
-- ============================================================

include('libs/nw.lua')
AddCSLuaFile('libs/nw.lua')
MsgC('NW загружен.\n')

include('libs/pon.lua')
AddCSLuaFile('libs/pon.lua')
MsgC('PON загружен.\n')

include('libs/netstream.lua')
AddCSLuaFile('libs/netstream.lua')
MsgC('NetStream v2 загружен.\n')

include('libs/mysqlite.lua')
AddCSLuaFile('libs/mysqlite.lua')
MsgC('MySQLite загружен.\n')

include('libs/cami.lua')
AddCSLuaFile('libs/cami.lua')
MsgC('CAMI загружен.\n')

if CLIENT then
    include('libs/swexp_ui.lua')
    include('libs/swexp_ui_animated.lua')
    include('libs/swexp_ui_animations.lua')
end
AddCSLuaFile('libs/swexp_ui.lua')
AddCSLuaFile('libs/swexp_ui_animated.lua')
AddCSLuaFile('libs/swexp_ui_animations.lua')
MsgC('SWUI загружен.\n')

-- ============================================================
-- Загрузка ядра (core/)
-- sv_ → только сервер
-- cl_ → только клиент + AddCSLuaFile
-- sh_ → shared + AddCSLuaFile
-- Поддерживает подпапки (аналогично totrlw)
-- ============================================================

function SWExp.LoadCore(self)
    local sPath = GM.FolderName..'/gamemode/core/'
    local files, folders = file.Find(sPath..'/*', 'LUA')

    for k, v in pairs(files) do
        local loaded = false

        if string.StartWith(v, 'sv') then
            if SERVER then
                local load = include(sPath..v)
                if load then load() end
            end
            loaded = true
        end

        if string.StartWith(v, 'cl') then
            if CLIENT then
                local load = include(sPath..v)
                if load then load() end
            end
            AddCSLuaFile(sPath..v)
            loaded = true
        end

        if string.StartWith(v, 'sh') then
            local load = include(sPath..v)
            if load then load() end
            AddCSLuaFile(sPath..v)
            loaded = true
        end

        if loaded then
            MsgC(Color(190, 252, 3), '[ SWExp ]', '[ Ядро ]', ' Файл "'..v..'" загружен успешно!\n')
        end
    end

    for k, v in pairs(folders) do
        local subFiles = file.Find(sPath..v..'/*.lua', 'LUA')

        for kf, vf in pairs(subFiles) do
            if string.StartWith(vf, 'sv') then
                if SERVER then
                    local load = include(sPath..v..'/'..vf)
                    if load then load() end
                end
            end

            if string.StartWith(vf, 'cl') then
                if CLIENT then
                    local load = include(sPath..v..'/'..vf)
                    if load then load() end
                end
                AddCSLuaFile(sPath..v..'/'..vf)
            end

            if string.StartWith(vf, 'sh') then
                local load = include(sPath..v..'/'..vf)
                if load then load() end
                AddCSLuaFile(sPath..v..'/'..vf)
            end

            MsgC(Color(190, 252, 3), '[ SWExp ]', '[ Ядро | ', v, ' ]', ' Файл "'..vf..'" загружен успешно!\n')
        end
    end
end

-- ============================================================
-- Загрузка конфигов (config/)
-- ============================================================

function SWExp.LoadConfigs(self)
    local sPath = GM.FolderName..'/gamemode/config/'
    local files, _ = file.Find(sPath..'/*.lua', 'LUA')

    for k, v in pairs(files) do
        if string.StartWith(v, 'sv') then
            if SERVER then
                local load = include(sPath..v)
                if load then load() end
            end
        end

        if string.StartWith(v, 'cl') then
            if CLIENT then
                local load = include(sPath..v)
                if load then load() end
            end
            AddCSLuaFile(sPath..v)
        end

        if string.StartWith(v, 'sh') then
            local load = include(sPath..v)
            if load then load() end
            AddCSLuaFile(sPath..v)
        end

        MsgC(Color(190, 252, 3), '[ SWExp ]', '[ Конфиг ]', ' Файл "'..v..'" загружен успешно!\n')
    end
end

-- ============================================================
-- Загрузка модулей (modules/)
-- Поддерживает файлы в корне папки modules/ и подпапки
-- ============================================================

function SWExp.LoadModules(self)
    local sPath = GM.FolderName..'/gamemode/modules/'
    local files, folders = file.Find(sPath..'/*', 'LUA')

    for k, v in pairs(files) do
        local loaded = false

        if string.StartWith(v, 'sv') then
            if SERVER then
                local load = include(sPath..v)
                if load then load() end
            end
            loaded = true
        end

        if string.StartWith(v, 'cl') then
            if CLIENT then
                local load = include(sPath..v)
                if load then load() end
            end
            AddCSLuaFile(sPath..v)
            loaded = true
        end

        if string.StartWith(v, 'sh') then
            local load = include(sPath..v)
            if load then load() end
            AddCSLuaFile(sPath..v)
            loaded = true
        end

        if loaded then
            MsgC(Color(190, 252, 3), '[ SWExp ]', '[ Модули ]', ' Файл "'..v..'" загружен успешно!\n')
        end
    end

    for k, v in pairs(folders) do
        local subFiles = file.Find(sPath..v..'/*.lua', 'LUA')

        for kf, vf in pairs(subFiles) do
            if string.StartWith(vf, 'sv') then
                if SERVER then
                    local load = include(sPath..v..'/'..vf)
                    if load then load() end
                end
            end

            if string.StartWith(vf, 'cl') then
                if CLIENT then
                    local load = include(sPath..v..'/'..vf)
                    if load then load() end
                end
                AddCSLuaFile(sPath..v..'/'..vf)
            end

            if string.StartWith(vf, 'sh') then
                local load = include(sPath..v..'/'..vf)
                if load then load() end
                AddCSLuaFile(sPath..v..'/'..vf)
            end

            MsgC(Color(190, 252, 3), '[ SWExp ]', '[ Модули | ', v, ' ]', ' Файл "'..vf..'" загружен успешно!\n')
        end
    end
end

-- ============================================================
-- Запуск загрузки
-- ============================================================

hook.Run('SWExp::PreCoreLoad')
SWExp:LoadCore()
hook.Run('SWExp::CoreLoaded')

hook.Run('SWExp::PreConfigLoad')
SWExp:LoadConfigs()
hook.Run('SWExp::ConfigLoaded')

hook.Run('SWExp::PreModulesLoad')
SWExp:LoadModules()
hook.Run('SWExp::ModulesLoaded')

hook.Run('SWExp::EndLoading')

MsgC('\n==============================================\n=\n')
MsgC('= SWExp завершил загрузку.\n= '..GM.Version..'\n=\n')
MsgC('==============================================\n')