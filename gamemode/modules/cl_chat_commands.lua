-- ============================================================
-- Star Wars: Expedition — RP Chat Commands (Client)
-- modules/cl_chat_commands.lua
--
-- Получает net-сообщения от сервера и отображает их в чате.
-- ============================================================

if SERVER then return end

-- ============================================================
-- Цвета команд
-- ============================================================

local Colors = {
    -- /me
    me_prefix   = Color(255, 165,  0),   -- оранжевый «*»
    me_name     = Color(255, 200, 100),  -- имя
    me_text     = Color(255, 230, 180),  -- текст действия

    -- /do
    do_prefix   = Color(100, 200, 255),  -- голубой «**»
    do_text     = Color(180, 230, 255),  -- текст описания
    do_name     = Color(100, 170, 220),  -- «(Имя)»

    -- /try
    try_prefix  = Color(180, 100, 255),  -- фиолетовый «* ... пытается»
    try_name    = Color(200, 150, 255),
    try_text    = Color(220, 190, 255),

    -- /roll
    roll_prefix = Color(255, 220, 50),   -- жёлтый
    roll_name   = Color(255, 240, 130),
    roll_text   = Color(255, 255, 200),

    -- /ooc
    ooc_bracket = Color(120, 120, 120),  -- серый [(OOC)]
    ooc_name    = Color(160, 160, 160),
    ooc_text    = Color(200, 200, 200),

    -- /radio
    radio_bracket = Color(0, 200, 120),  -- зелёный [Рация]
    radio_name    = Color(100, 230, 160),
    radio_text    = Color(180, 255, 210),

    -- /rp
    rp_bracket  = Color(255, 80,  80),   -- красный [RP]
    rp_name     = Color(255, 140, 140),
    rp_text     = Color(255, 200, 200),

    -- /advert
    adv_bracket = Color(255, 200,  0),   -- золотой [Объявление]
    adv_name    = Color(255, 220, 100),
    adv_text    = Color(255, 240, 180),
}

-- ============================================================
-- Локальные команды: /me, /do, /try, /roll
-- ============================================================

net.Receive("SWExp::ChatCmd_Local", function()
    local cmdType = net.ReadString()
    local name    = net.ReadString()
    local text    = net.ReadString()
    print("[SWExp DEBUG] Клиент получил Local: тип=" .. cmdType .. ", имя=" .. name .. ", текст=" .. text)

    if cmdType == "me" then
        -- * ИМЯ текст действия
        chat.AddText(
            Colors.me_prefix,  "* ",
            Colors.me_name,    name .. " ",
            Colors.me_text,    text
        )

    elseif cmdType == "do" then
        -- ** текст описания (Имя)
        chat.AddText(
            Colors.do_prefix,  "** ",
            Colors.do_text,    text .. " ",
            Colors.do_name,    "(" .. name .. ")"
        )

    elseif cmdType == "try" then
        -- * ИМЯ пытается: текст [РЕЗУЛЬТАТ - X/100]
        chat.AddText(
            Colors.try_prefix, "* ",
            Colors.try_name,   name .. " ",
            Colors.try_prefix, "пытается: ",
            Colors.try_text,   text
        )

    elseif cmdType == "roll" then
        -- * ИМЯ бросает кубик: X/100
        chat.AddText(
            Colors.roll_prefix, "* ",
            Colors.roll_name,   name .. " ",
            Colors.roll_prefix, "бросает кубик: ",
            Colors.roll_text,   text
        )
    end
end)

-- ============================================================
-- Глобальные команды: /ooc, /rp, /advert
-- ============================================================

net.Receive("SWExp::ChatCmd_Global", function()
    local cmdType = net.ReadString()
    local name    = net.ReadString()
    local text    = net.ReadString()

    if cmdType == "ooc" then
        -- (OOC) Имя: текст
        chat.AddText(
            Colors.ooc_bracket, "(OOC) ",
            Colors.ooc_name,    name .. ": ",
            Colors.ooc_text,    text
        )

    elseif cmdType == "rp" then
        -- [RP] Имя: текст действия
        chat.AddText(
            Colors.rp_bracket, "[RP] ",
            Colors.rp_name,    name .. ": ",
            Colors.rp_text,    text
        )

    elseif cmdType == "advert" then
        -- [Объявление] Имя: текст
        chat.AddText(
            Colors.adv_bracket, "[Объявление] ",
            Colors.adv_name,    name .. ": ",
            Colors.adv_text,    text
        )
    end
end)

-- ============================================================
-- Радио: /radio
-- ============================================================

net.Receive("SWExp::ChatCmd_Radio", function()
    local freq = net.ReadInt(32)
    local name = net.ReadString()
    local text = net.ReadString()

    -- [Рация: 104 MHz] Имя: текст
    chat.AddText(
        Colors.radio_bracket, "[Рация: " .. freq .. " MHz] ",
        Colors.radio_name,    name .. ": ",
        Colors.radio_text,    text
    )
end)

-- ============================================================
-- Размер шрифта ChatHUD
-- Увеличиваем стандартный мелкий шрифт EasyChat (17–20px → 26px)
-- ============================================================

local CHATHUD_FONT_SIZE = 26  -- ← меняй это значение под себя

local function ApplyChatHudFontSize()
    if EasyChat and EasyChat.ChatHUD and EasyChat.ChatHUD.UpdateFontSize then
        EasyChat.ChatHUD:UpdateFontSize(CHATHUD_FONT_SIZE)
        return true
    end
    return false
end

-- Пробуем сразу, потом через тик, потом через хук
if not ApplyChatHudFontSize() then
    timer.Simple(0, function()
        if not ApplyChatHudFontSize() then
            hook.Add("ECInitialized", "SWExp::ChatHudFontSize", function()
                ApplyChatHudFontSize()
            end)
        end
    end)
end

print('[SWExp] RP команды чата (клиент) загружены.')
