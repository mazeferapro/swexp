-- ============================================================
-- Star Wars: Expedition — RP Chat Commands
-- modules/sv_chat_commands.lua
-- ============================================================

if CLIENT then return end

local RP_PROXIMITY = 700

-- ============================================================
-- Net-каналы
-- ============================================================

util.AddNetworkString("SWExp::ChatCmd_Local")
util.AddNetworkString("SWExp::ChatCmd_Global")
util.AddNetworkString("SWExp::ChatCmd_Radio")

-- ============================================================
-- Отправка
-- ============================================================

local function SendLocal(sender, cmdType, text)
    local pos = sender:GetPos()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetPos():DistToSqr(pos) <= (RP_PROXIMITY * RP_PROXIMITY) then
            net.Start("SWExp::ChatCmd_Local")
                net.WriteString(cmdType)
                net.WriteString(sender:Nick())
                net.WriteString(text)
            net.Send(ply)
        end
    end
end

local function SendGlobalCmd(sender, cmdType, text)
    net.Start("SWExp::ChatCmd_Global")
        net.WriteString(cmdType)
        net.WriteString(sender:Nick())
        net.WriteString(text)
    net.Broadcast()
end

-- ============================================================
-- Обработка команды. Возвращает true если команда перехвачена
-- ============================================================

local function ProcessRpCommand(ply, text)
    if not IsValid(ply) then return false end

    local trimmed = string.Trim(text)
    local cmd, arg = string.match(trimmed, "^/(%S+)%s*(.*)")
    if not cmd then return false end

    cmd = string.lower(cmd)
    arg = string.Trim(arg or "")

    local function noArg()
        ply:ChatPrint("[RP] Укажи текст после команды.")
    end

    if cmd == "me" then
        if #arg == 0 then noArg() else SendLocal(ply, "me", arg) end
        return true
    end

    if cmd == "do" then
        if #arg == 0 then noArg() else SendLocal(ply, "do", arg) end
        return true
    end

    if cmd == "try" then
        if #arg == 0 then
            noArg()
        else
            local roll = math.random(1, 100)
            local result = roll >= 50 and "УСПЕХ" or "ПРОВАЛ"
            SendLocal(ply, "try", arg .. " [" .. result .. " — " .. roll .. "/100]")
        end
        return true
    end

    if cmd == "roll" then
        local roll = math.random(1, 100)
        SendLocal(ply, "roll", tostring(roll) .. "/100")
        return true
    end

    if cmd == "ooc" then
        if #arg == 0 then noArg() else SendGlobalCmd(ply, "ooc", arg) end
        return true
    end

    if cmd == "radio" then
        if #arg == 0 then
            noArg()
        else
            local freq = ply:GetNWInt("swexp_radio_freq", 0)
            if freq == 0 then
                ply:ChatPrint("[Рация] Вы не подключены к частоте. Нажмите G.")
            else
                for _, target in ipairs(player.GetAll()) do
                    if IsValid(target) and target:GetNWInt("swexp_radio_freq", 0) == freq then
                        net.Start("SWExp::ChatCmd_Radio")
                            net.WriteInt(freq, 32)
                            net.WriteString(ply:Nick())
                            net.WriteString(arg)
                        net.Send(target)
                    end
                end
            end
        end
        return true
    end

    if cmd == "rp" then
        if #arg == 0 then noArg() else SendGlobalCmd(ply, "rp", arg) end
        return true
    end

    if cmd == "advert" then
        if #arg == 0 then noArg() else SendGlobalCmd(ply, "advert", arg) end
        return true
    end

    return false
end

-- ============================================================
-- Метод 1: hook.Add (стандарт + Srlion hook library)
-- ============================================================

hook.Add("PlayerSay", "SWExp::RpChatCommands", function(ply, text)
    if ProcessRpCommand(ply, text) then return "" end
end)

-- ============================================================
-- Метод 2: GM.PlayerSay (фолбек — вызывается gamemode.Call
--           если хуки не вернули значение)
-- ============================================================

local _origGMPlayerSay = GM and GM.PlayerSay
function GM:PlayerSay(ply, text, bTeam)
    if ProcessRpCommand(ply, text) then return "" end
    if _origGMPlayerSay then return _origGMPlayerSay(self, ply, text, bTeam) end
    return text
end

-- ============================================================
-- Метод 3: прямой патч EasyChat.SendGlobalMessage
-- Срабатывает 100% независимо от хуков и gamemode.Call
-- ============================================================

local function PatchEasyChat()
    if not EasyChat or not EasyChat.SendGlobalMessage then
        -- EasyChat ещё не загружен — попробуем позже
        timer.Simple(1, PatchEasyChat)
        return
    end

    if EasyChat._SWExp_Patched then return end  -- уже пропатчено
    EasyChat._SWExp_Patched = true

    local _origSend = EasyChat.SendGlobalMessage

    function EasyChat.SendGlobalMessage(ply, str, is_team, is_local)
        if ProcessRpCommand(ply, str) then return end  -- RP команда — блокируем
        return _origSend(ply, str, is_team, is_local)  -- иначе обычный чат
    end

    MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' EasyChat.SendGlobalMessage пропатчен.\n')
end

-- Запускаем сразу и через тик (на случай если EasyChat ещё грузится)
PatchEasyChat()
timer.Simple(0, PatchEasyChat)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' RP команды чата загружены (v3).\n')
