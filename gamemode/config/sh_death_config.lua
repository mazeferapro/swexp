-- ============================================================
-- Star Wars: Expedition — Death Screen Config
-- config/sh_death_config.lua
--
-- Конфиг экрана смерти и задержки возрождения.
-- ============================================================

SWExp           = SWExp           or {}
SWExp.DeathCfg  = SWExp.DeathCfg  or {}

-- Длительность блокировки респавна (секунды)
SWExp.DeathCfg.RespawnDelay = 30

-- Можно ли пропустить экран смерти нажатием пробела по истечении таймера
SWExp.DeathCfg.AllowManualRespawn = true

-- Заголовок (большая надпись по центру)
SWExp.DeathCfg.Title    = 'ВЫ ПОГИБЛИ'
SWExp.DeathCfg.SubTitle = 'Ожидайте возрождения...'

-- Подсказка по кнопке возрождения
SWExp.DeathCfg.RespawnHint = 'НАЖМИТЕ [ПРОБЕЛ] ДЛЯ ВОЗРОЖДЕНИЯ'
