-- ============================================================
-- Star Wars: Expedition — Объект исследования (общая часть)
-- entities/swexp_research_point/shared.lua
-- ============================================================

ENT.Type        = "anim"
ENT.Base        = "base_gmodentity"
ENT.PrintName   = "Объект исследования"
ENT.Author      = "SWExp"
ENT.Category    = "SWEXP | Основное"
ENT.Spawnable   = false
ENT.AdminOnly   = true

-- NW-переменные (устанавливаются сервером):
--   SWExp_ResName      : string  — название типа
--   SWExp_ResMonologue : string  — внутренний монолог клона
--   SWExp_ResPoints    : int     — очки исследования за скан
--   SWExp_ColorR/G/B   : int     — цвет типа для HUD
--   SWExp_Scanned      : bool    — уже отсканировано
