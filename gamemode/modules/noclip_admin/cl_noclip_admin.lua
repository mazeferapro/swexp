-- ============================================================
-- Star Wars: Expedition — Admin ESP (клиент)
-- modules/noclip_admin/cl_noclip_admin.lua
--
-- Рисует над игроками и NPC:
--   • Ник (игроки) / класс (NPC)
--   • Полоску HP + числовое значение
-- Активируется только когда локальный игрок в noclip.
-- ============================================================

if not CLIENT then return end

-- ============================================================
-- Состояние
-- ============================================================

local espActive = false

-- ============================================================
-- Net: включить / выключить ESP
-- ============================================================

net.Receive("SWExp::AdminESP_Toggle", function()
    espActive = net.ReadBool()
end)

-- ============================================================
-- Шрифты
-- ============================================================

surface.CreateFont("SWExp_AdminESP_Name", {
    font    = "Exo2-Bold",
    size    = 15,
    weight  = 700,
    antialias = true,
    shadow  = true,
})

surface.CreateFont("SWExp_AdminESP_Small", {
    font    = "Exo2-Regular",
    size    = 13,
    weight  = 400,
    antialias = true,
    shadow  = true,
})

-- ============================================================
-- Цвета
-- ============================================================

local COL_PLAYER_NAME  = Color(100, 220, 255)   -- голубой
local COL_NPC_NAME     = Color(255, 190, 60)    -- оранжевый
local COL_ADMIN_NAME   = Color(255, 80,  80)    -- красный для других админов
local COL_HP_BG        = Color(0,   0,   0, 160)
local COL_HP_FULL      = Color(80,  220, 80)
local COL_HP_MID       = Color(220, 220, 40)
local COL_HP_LOW       = Color(220, 60,  60)
local COL_WHITE        = Color(255, 255, 255)

-- ============================================================
-- Утилиты
-- ============================================================

local function HpColor(frac)
    if frac > 0.6 then return COL_HP_FULL
    elseif frac > 0.3 then return COL_HP_MID
    else return COL_HP_LOW end
end

-- Рисует строку по центру X
local function DrawCentered(font, x, y, text, col)
    surface.SetFont(font)
    local tw, th = surface.GetTextSize(text)
    draw.SimpleText(text, font, x - tw * 0.5, y, col)
    return th
end

-- Рисует горизонтальную полосу HP
local function DrawHpBar(x, y, w, h, hp, maxHp)
    local frac = math.Clamp(hp / math.max(maxHp, 1), 0, 1)
    -- Фон
    surface.SetDrawColor(COL_HP_BG)
    surface.DrawRect(x - w * 0.5, y, w, h)
    -- Заполнение
    surface.SetDrawColor(HpColor(frac))
    surface.DrawRect(x - w * 0.5, y, w * frac, h)
    -- Текст HP
    local hpText = hp .. " / " .. maxHp
    draw.SimpleText(hpText, "SWExp_AdminESP_Small",
        x, y + h * 0.5,
        COL_WHITE,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    return h
end

-- ============================================================
-- Основной HUDPaint
-- ============================================================

hook.Add("HUDPaint", "SWExp::AdminESP_Draw", function()
    if not espActive then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local BAR_W = 80
    local BAR_H = 8

    -- ──────────────────────────────────────────────────────────
    -- Игроки
    -- ──────────────────────────────────────────────────────────
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if ply == lp then continue end
        if not ply:Alive() then continue end

        -- Точка над головой
        local headPos = ply:GetPos() + Vector(0, 0, ply:OBBMaxs().z + 14)
        local sp = headPos:ToScreen()
        if not sp.visible then continue end

        local sx, sy = sp.x, sp.y

        -- Ник
        local nameCol = (ply:IsAdmin() or ply:IsSuperAdmin()) and COL_ADMIN_NAME or COL_PLAYER_NAME
        local nick    = ply:Nick()
        local nameH   = DrawCentered("SWExp_AdminESP_Name", sx, sy, nick, nameCol)

        sy = sy + nameH + 2

        -- HP бар
        local hp    = math.max(ply:Health(), 0)
        local maxHp = math.max(ply:GetMaxHealth(), 1)
        DrawHpBar(sx, sy, BAR_W, BAR_H, hp, maxHp)
    end

    -- ──────────────────────────────────────────────────────────
    -- NPC
    -- ──────────────────────────────────────────────────────────
    for _, npc in ipairs(ents.FindByClass("npc_*")) do
        if not IsValid(npc) then continue end
        if npc:Health() <= 0 then continue end

        local headPos = npc:GetPos() + Vector(0, 0, npc:OBBMaxs().z + 14)
        local sp = headPos:ToScreen()
        if not sp.visible then continue end

        local sx, sy = sp.x, sp.y

        -- Название класса NPC
        local label  = npc:GetClass()
        local nameH  = DrawCentered("SWExp_AdminESP_Name", sx, sy, label, COL_NPC_NAME)

        sy = sy + nameH + 2

        -- HP бар
        local hp    = math.max(npc:Health(), 0)
        local maxHp = math.max(npc:GetMaxHealth(), 1)
        DrawHpBar(sx, sy, BAR_W, BAR_H, hp, maxHp)
    end
end)

print("[SWExp] cl_noclip_admin loaded.")
