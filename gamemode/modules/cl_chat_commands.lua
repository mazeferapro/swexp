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
-- Шрифт ChatHUD (плашка сообщений без открытого окна чата)
--
-- Баг был в том, что мы меняли только размер шрифта
-- (EasyChat.ChatHUD:UpdateFontSize), а имя шрифта оставалось
-- по умолчанию. Плюс у EasyChat свой JSON-конфиг, который
-- читается с задержкой и затирает наши значения.
-- Поэтому применяем шрифт надёжно: через все возможные API
-- и держим перепривязку через хук репейнта ChatHUD.
-- ============================================================

local CHATHUD_FONT_NAME = 'Exo 2'   -- ← имя шрифта (как в TTF metadata)
local CHATHUD_FONT_SIZE = 26        -- ← размер в пикселях

-- Перерегистрируем все известные внутренние шрифты ChatHUD
local function RebuildChatHudFonts()
    -- Стандартные имена шрифтов EasyChat ChatHUD во всех версиях
    local fontNames = {
        'EasyChatHUDFont',
        'ECChatHUDFont',
        'easychat_default',
        'EasyChatFont',
    }

    for _, fName in ipairs(fontNames) do
        surface.CreateFont(fName, {
            font      = CHATHUD_FONT_NAME,
            size      = CHATHUD_FONT_SIZE,
            weight    = 600,
            extended  = true,
            antialias = true,
            shadow    = false,
        })
    end
end

local function ApplyChatHudFont(reason)
    if not EasyChat or not EasyChat.ChatHUD then return false end

    -- 1) Convar'ы EasyChat — переживают перезаход
    local cvName = GetConVar('easychat_hud_font_name')
                or GetConVar('easychat_font_name')
    local cvSize = GetConVar('easychat_hud_font_size')
                or GetConVar('easychat_font_size')

    if cvName then RunConsoleCommand(cvName:GetName(), CHATHUD_FONT_NAME) end
    if cvSize then RunConsoleCommand(cvSize:GetName(), tostring(CHATHUD_FONT_SIZE)) end

    -- 2) Прямой вызов методов ChatHUD
    if EasyChat.ChatHUD.UpdateFont then
        EasyChat.ChatHUD:UpdateFont(CHATHUD_FONT_NAME)
    elseif EasyChat.ChatHUD.SetFontName then
        EasyChat.ChatHUD:SetFontName(CHATHUD_FONT_NAME)
    elseif EasyChat.ChatHUD.SetFont then
        EasyChat.ChatHUD:SetFont(CHATHUD_FONT_NAME)
    end

    if EasyChat.ChatHUD.UpdateFontSize then
        EasyChat.ChatHUD:UpdateFontSize(CHATHUD_FONT_SIZE)
    end

    -- 3) Перерегистрируем все возможные имена шрифтов
    RebuildChatHudFonts()

    -- 4) Заставляем ChatHUD перерисоваться с новым шрифтом
    if EasyChat.ChatHUD.InvalidateLayout then
        EasyChat.ChatHUD:InvalidateLayout(true)
    end

    print(string.format(
        '[SWExp] ChatHUD font applied: %s @ %dpx (reason=%s, cvName=%s)',
        CHATHUD_FONT_NAME, CHATHUD_FONT_SIZE, reason or '?',
        cvName and cvName:GetName() or 'nil'
    ))

    return true
end

-- Применяем при загрузке (несколько попыток с разной задержкой)
hook.Add('ECInitialized', 'SWExp::ChatHudFont_OnInit', function()
    ApplyChatHudFont('ECInitialized')
end)

hook.Add('InitPostEntity', 'SWExp::ChatHudFont_OnInitPostEntity', function()
    timer.Simple(0,   function() ApplyChatHudFont('IPE+0')  end)
    timer.Simple(0.5, function() ApplyChatHudFont('IPE+0.5') end)
    timer.Simple(2,   function() ApplyChatHudFont('IPE+2')   end)
    timer.Simple(5,   function() ApplyChatHudFont('IPE+5')   end)
end)

-- Если EasyChat уже загружен в момент первого запуска файла
timer.Simple(0, function()
    ApplyChatHudFont('initial')
end)

-- Ручная команда для отладки
concommand.Add('swexp_chathud_font', function(_, _, args)
    if args[1] then CHATHUD_FONT_NAME = args[1] end
    if args[2] then CHATHUD_FONT_SIZE = tonumber(args[2]) or CHATHUD_FONT_SIZE end
    ApplyChatHudFont('concommand')
end, nil, 'Применить шрифт ChatHUD: swexp_chathud_font "Exo 2" 26')

print('[SWExp] RP команды чата (клиент) загружены.')
