-- ============================================================
-- Star Wars: Expedition - RP Chat Commands
-- modules/sv_chat_commands.lua
-- ============================================================

if CLIENT then return end

local RP_PROXIMITY = 700

-- ============================================================
-- DEBUG: set to false after you confirm everything works.
-- ============================================================

local DEBUG_CHAT = true

local function dprint(msg)
    if not DEBUG_CHAT then return end
    MsgC(Color(255, 200, 0), '[SWExp][Chat] ', color_white, tostring(msg), '\n')
end

dprint('sv_chat_commands.lua loaded. RP_PROXIMITY = ' .. RP_PROXIMITY)

-- ============================================================
-- Net channels
-- ============================================================

util.AddNetworkString("SWExp::ChatCmd_Local")
util.AddNetworkString("SWExp::ChatCmd_Global")
util.AddNetworkString("SWExp::ChatCmd_Radio")

-- ============================================================
-- Sending helpers
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
-- /me /do /try /roll /ooc /looc /radio /rp /advert handler
-- Также: // как алиас /ooc
-- ============================================================

local function ProcessRpCommand(ply, text)
    if not IsValid(ply) then return false end

    local trimmed = string.Trim(text)

    local function noArg()
        ply:ChatPrint("[RP] Укажи текст после команды.")
    end

    -- Алиас // → /ooc
    if string.sub(trimmed, 1, 2) == "//" then
        local arg = string.Trim(string.sub(trimmed, 3))
        if #arg == 0 then noArg() else SendGlobalCmd(ply, "ooc", arg) end
        return true
    end

    local cmd, arg = string.match(trimmed, "^/(%S+)%s*(.*)")
    if not cmd then return false end

    cmd = string.lower(cmd)
    arg = string.Trim(arg or "")

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
            SendLocal(ply, "try", arg .. " [" .. result .. " - " .. roll .. "/100]")
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

    -- /looc — локальный OOC (по дистанции)
    if cmd == "looc" then
        if #arg == 0 then noArg() else SendLocal(ply, "looc", arg) end
        return true
    end

    -- /radio — исправлено: берём активный канал и его частоту
    if cmd == "radio" then
        if #arg == 0 then
            noArg()
        else
            if not ply:GetNWBool("swexp_radio_enabled", false) then
                ply:ChatPrint("[Рация] Рация выключена. Нажмите G.")
                return true
            end
            local activeCh = ply:GetNWInt("swexp_radio_active_ch", 1)
            local freq     = ply:GetNWInt("swexp_radio_freq" .. activeCh, 0)
            if freq == 0 then
                ply:ChatPrint("[Рация] Канал " .. activeCh .. " не настроен.")
            else
                for _, target in ipairs(player.GetAll()) do
                    if IsValid(target) and target:GetNWBool("swexp_radio_enabled", false) then
                        for ch = 1, 3 do
                            if target:GetNWInt("swexp_radio_freq" .. ch, 0) == freq then
                                net.Start("SWExp::ChatCmd_Radio")
                                    net.WriteInt(freq, 32)
                                    net.WriteString(ply:Nick())
                                    net.WriteString(arg)
                                net.Send(target)
                                break
                            end
                        end
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

    -- Неизвестная команда — сообщаем и подавляем сообщение
    ply:ChatPrint("[RP] Неизвестная команда: /" .. cmd .. ". Доступные: /me, /do, /try, /roll, /ooc, /looc, /radio, /rp, /advert")
    return true
end

-- ============================================================
-- Method 1: hook.Add PlayerSay (also works with Srlion hook lib)
-- ============================================================

hook.Add("PlayerSay", "SWExp::RpChatCommands", function(ply, text, bTeam)
    dprint(string.format('[Hook PlayerSay] talker=%s team=%s text=%q',
        IsValid(ply) and ply:Nick() or 'nil',
        tostring(bTeam),
        tostring(text)))

    if ProcessRpCommand(ply, text) then return "" end
end)

-- ============================================================
-- Method 2: GM.PlayerSay (fallback - called by gamemode.Call
-- when hooks did not return anything)
-- ============================================================

local _origGMPlayerSay = GM and GM.PlayerSay
function GM:PlayerSay(ply, text, bTeam)
    if ProcessRpCommand(ply, text) then return "" end
    if _origGMPlayerSay then return _origGMPlayerSay(self, ply, text, bTeam) end
    return text
end

-- ============================================================
-- Method 3: direct EasyChat.SendGlobalMessage patch
-- ============================================================

-- Полная замена EasyChat.SendGlobalMessage. Вместо того чтобы
-- полагаться на gamemode.Call("PlayerCanSeePlayersChat") внутри
-- оригинала (который, как показала отладка, не зовётся при
-- is_local=false), мы сами строим фильтр получателей по дистанции
-- и шлём пакет в EasyChat-формате только им.
local NET_BROADCAST_MSG = "EASY_CHAT_BROADCAST_MSG"

local function SWExp_SendChatMessage(ply, str, is_team, is_local)
    if not IsValid(ply) then return end

    -- Тримим текст как это делает оригинальный EasyChat
    if EasyChat and EasyChat.ExtendedStringTrim then
        str = EasyChat.ExtendedStringTrim(str)
    else
        str = string.Trim(str)
    end
    if #str == 0 then return end

    local talkerPos = ply:GetPos()
    local maxSqr    = RP_PROXIMITY * RP_PROXIMITY
    local filter    = { ply }  -- говорящий всегда видит свой текст

    for _, listener in ipairs(player.GetAll()) do
        if listener ~= ply and IsValid(listener) then
            local dist = listener:GetPos():DistToSqr(talkerPos)

            -- Командный чат не режем по дистанции
            if is_team or dist <= maxSqr then
                filter[#filter + 1] = listener
                dprint(string.format('  [Filter] %s -> %s | dist=%.0f -> ADDED',
                    ply:Nick(), listener:Nick(), math.sqrt(dist)))
            else
                dprint(string.format('  [Filter] %s -> %s | dist=%.0f > %d -> SKIPPED',
                    ply:Nick(), listener:Nick(), math.sqrt(dist), RP_PROXIMITY))
            end
        end
    end

    net.Start(NET_BROADCAST_MSG)
        net.WriteEntity(ply)
        net.WriteString(str)
        net.WriteBool(not ply:Alive())
        net.WriteBool(is_team and true or false)
        net.WriteBool(is_local and true or false)
    net.Send(filter)

    dprint(string.format('  [Filter] sent to %d players', #filter))

    if game.IsDedicated() then
        print(string.format("%s: %s", ply:Nick():gsub("<.->", ""), str))
    end
end

local function PatchEasyChat()
    if not EasyChat or not EasyChat.SendGlobalMessage then
        timer.Simple(1, PatchEasyChat)
        return
    end

    if EasyChat._SWExp_Patched then return end
    EasyChat._SWExp_Patched = true

    function EasyChat.SendGlobalMessage(ply, str, is_team, is_local)
        dprint(string.format('[EasyChat.SendGlobalMessage] talker=%s team=%s local=%s text=%q',
            IsValid(ply) and ply:Nick() or 'nil',
            tostring(is_team), tostring(is_local), tostring(str)))

        -- RP-команды (/me /do /ooc и т.д.) — обрабатываем здесь
        if ProcessRpCommand(ply, str) then return end

        -- Даём сработать стандартным PlayerSay-хукам.
        -- В этом геймоде есть SWExp::ChatName, который сам шлёт
        -- сообщение через ChatPrint с RP-ником, поэтому если он
        -- вернёт '' — мы НЕ шлём ничего сами, чтобы не дублировать.
        local result = gamemode.Call('PlayerSay', ply, str, is_team, is_local)
        dprint(string.format('  gamemode.Call(PlayerSay) returned: type=%s value=%q',
            type(result), tostring(result)))

        if result == nil then
            dprint('  -> result==nil, sending via SWExp_SendChatMessage')
            SWExp_SendChatMessage(ply, str, is_team, is_local)
        elseif type(result) == 'string' and #result > 0 then
            dprint('  -> result is non-empty string, sending modified text')
            SWExp_SendChatMessage(ply, result, is_team, is_local)
        else
            dprint('  -> result is empty string -> hook handled it (NOT dispatching)')
        end
        -- Если result == '' — сообщение уже разослано хуком
        -- (SWExp::ChatName сам делает ChatPrint), не дублируем.
    end

    dprint('EasyChat.SendGlobalMessage patched (proximity filter active).')
end

PatchEasyChat()
timer.Simple(0, PatchEasyChat)
timer.Simple(2, PatchEasyChat)

MsgC(Color(190, 252, 3), '[ SWExp ] ', color_white, 'RP chat commands loaded.\n')

-- ============================================================
-- PROXIMITY CHAT FILTER (also handles non-EasyChat path)
-- ============================================================

hook.Add('PlayerCanSeePlayersChat', 'SWExp::ProximityChat', function(text, bTeam, listener, talker, is_local)
    if not IsValid(talker) or not IsValid(listener) then return end
    if listener == talker then return true end
    if bTeam then return true end

    local distSqr = listener:GetPos():DistToSqr(talker:GetPos())
    if distSqr <= (RP_PROXIMITY * RP_PROXIMITY) then
        return true
    end
    return false
end)

-- ============================================================
-- Status report
-- ============================================================

timer.Simple(5, function()
    dprint('=== STATUS REPORT (5 sec after start) ===')
    dprint('EasyChat present: ' .. tostring(EasyChat ~= nil))
    dprint('EasyChat patched: ' .. tostring(EasyChat and EasyChat._SWExp_Patched or false))
    dprint('Players online: ' .. tostring(#player.GetAll()))
    dprint('=== END STATUS ===')
end)
