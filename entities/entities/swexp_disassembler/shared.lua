-- ============================================================
-- Star Wars: Expedition — Дисассемблер (общая часть)
-- entities/swexp_disassembler/shared.lua
--
-- Стационарный дисассемблер на базе. Игрок подходит и нажимает E,
-- чтобы разобрать предмет из инвентаря, получив назад
-- половину стоимости (материалы зачисляются в общий банк).
-- ============================================================

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Дисассемблер"
ENT.Author    = "SWExp"
ENT.Category  = "SWEXP | Основное"
ENT.Spawnable = true
ENT.AdminOnly = true
