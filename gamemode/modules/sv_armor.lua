-- modules/armor/sv_armor.lua
-- Броня = статический процент снижения урона (Armor() / 100).
-- Armor(50) → урон умножается на 0.5
-- Броня НЕ снижается от урона.
-- Чем выше броня — тем медленнее игрок.

if CLIENT then return end

-- Базовые скорости
local BASE_WALK      = 250
local BASE_RUN       = 400
local BASE_SLOW_WALK = 150

-- ============================================================
-- Применение скорости с учётом брони
-- ============================================================

local function ApplyArmorSpeed(pPlayer)
    local armor   = pPlayer:Armor()
    local penalty = armor / 100
    local mult    = 1 - (penalty * 0.4)   -- броня 100% → ×0.6

    pPlayer:SetWalkSpeed(math.floor(BASE_WALK      * mult))
    pPlayer:SetRunSpeed(math.floor(BASE_RUN        * mult))
    pPlayer:SetSlowWalkSpeed(math.floor(BASE_SLOW_WALK * mult))
end

-- ============================================================
-- Поглощение урона + защита от стандартного снижения GMod
-- ============================================================

hook.Add('HandlePlayerArmorReduction', 'SWExp::ArmorReduction', function(pPlayer, dmginfo)
    if pPlayer:Armor() <= 0 then return end

    if bit.band(dmginfo:GetDamageType(), DMG_FALL + DMG_DROWN + DMG_POISON + DMG_RADIATION) ~= 0 then return end

    -- Запоминаем броню ДО того как GMod её снизит
    pPlayer._SWExp_Armor = pPlayer:Armor()

    local reduction = pPlayer:Armor() / 100
    local newDmg = math.max(1, math.floor(dmginfo:GetDamage() * (1 - reduction)))
    dmginfo:SetDamage(newDmg)
end)

-- GMod после обработки урона сам снижает Armor() — восстанавливаем его
hook.Add('PostEntityTakeDamage', 'SWExp::ArmorRestore', function(pPlayer, dmginfo, bTookDamage)
    if not pPlayer:IsPlayer() then return end
    if not pPlayer._SWExp_Armor then return end

    pPlayer:SetArmor(pPlayer._SWExp_Armor)
    pPlayer._SWExp_Armor = nil
end)

-- ============================================================
-- Консольные команды
-- ============================================================

concommand.Add('swexp_setarmor', function(pCaller, _, args)
    if IsValid(pCaller) and not pCaller:IsSuperAdmin() then return end

    local targetName = args[1]
    local armorValue = tonumber(args[2])

    if not targetName or not armorValue then
        MsgC(Color(255, 80, 80), 'Использование: swexp_setarmor <имя/SteamID> <0-100>\n')
        return
    end

    armorValue = math.Clamp(armorValue, 0, 100)

    local target
    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), string.lower(targetName), 1, true)
        or ply:SteamID() == targetName then
            target = ply
            break
        end
    end

    if not IsValid(target) then
        MsgC(Color(255, 80, 80), '[SWExp.Armor] Игрок "', targetName, '" не найден.\n')
        return
    end

    target:SetMaxArmor(100)
    target:SetArmor(armorValue)
    ApplyArmorSpeed(target)

    local callerName = IsValid(pCaller) and pCaller:Nick() or 'Console'
    MsgC(Color(190, 252, 3), '[SWExp.Armor] ', color_white,
        callerName, ' → ', target:Nick(),
        ': броня ', armorValue, '% | walk ', target:GetWalkSpeed(), ' run ', target:GetRunSpeed(), '\n')
end)

concommand.Add('swexp_getarmor', function(pCaller, _, args)
    if IsValid(pCaller) and not pCaller:IsAdmin() then return end

    local targetName = args[1]
    if not targetName then
        for _, ply in ipairs(player.GetAll()) do
            MsgC(Color(190, 252, 3), ply:Nick(), color_white,
                ' → ', ply:Armor(), '% | walk ', ply:GetWalkSpeed(), ' run ', ply:GetRunSpeed(), '\n')
        end
        return
    end

    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), string.lower(targetName), 1, true)
        or ply:SteamID() == targetName then
            MsgC(Color(190, 252, 3), ply:Nick(), color_white,
                ' → ', ply:Armor(), '% | walk ', ply:GetWalkSpeed(), ' run ', ply:GetRunSpeed(), '\n')
            return
        end
    end

    MsgC(Color(255, 80, 80), '[SWExp.Armor] Игрок "', targetName, '" не найден.\n')
end)

concommand.Add('swexp_resetarmor', function(pCaller, _, args)
    if IsValid(pCaller) and not pCaller:IsSuperAdmin() then return end

    local targetName = args[1]
    if not targetName then
        MsgC(Color(255, 80, 80), 'Использование: swexp_resetarmor <имя/SteamID>\n')
        return
    end

    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), string.lower(targetName), 1, true)
        or ply:SteamID() == targetName then
            ply:SetArmor(0)
            ApplyArmorSpeed(ply)
            MsgC(Color(190, 252, 3), '[SWExp.Armor] ', color_white, ply:Nick(), ': броня сброшена.\n')
            return
        end
    end

    MsgC(Color(255, 80, 80), '[SWExp.Armor] Игрок "', targetName, '" не найден.\n')
end)

MsgC(Color(190, 252, 3), '[ SWExp ]', color_white, ' Модуль брони загружен.\n')