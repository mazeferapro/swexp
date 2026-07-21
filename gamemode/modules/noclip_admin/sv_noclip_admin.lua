-- ============================================================
-- Star Wars: Expedition — Admin Noclip Cloak + ESP
-- modules/noclip_admin/sv_noclip_admin.lua
--
-- SAM включает noclip через SetMoveType() напрямую, поэтому
-- хук PlayerNoClip не срабатывает. Вместо него используем
-- таймер, который отслеживает изменение movetype у каждого
-- игрока-админа и реагирует на переход.
-- ============================================================

if not SERVER then return end

util.AddNetworkString("SWExp::AdminESP_Toggle")

-- ============================================================
-- Состояние: [steamid64] = bool (был ли в noclip на прошлом тике)
-- ============================================================

local wasNoclip = {}

-- ============================================================
-- Утилита: применить / снять клоак
-- ============================================================

local function ApplyCloak(ply, state)
    if not IsValid(ply) then return end
    ply:SetNoDraw(state)
    if state then
        ply:AddFlags(FL_NOTARGET)                          -- NPC перестают видеть игрока
        ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)  -- не толкает игроков
    else
        ply:RemoveFlags(FL_NOTARGET)                       -- NPC снова могут атаковать
        ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)      -- стандартная коллизия
    end
    net.Start("SWExp::AdminESP_Toggle")
        net.WriteBool(state)
    net.Send(ply)
end

local function IsAdminPly(ply)
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

-- ============================================================
-- Таймер: проверяет movetype каждые 0.1 сек
-- Срабатывает на изменение WALK→NOCLIP и обратно
-- ============================================================

timer.Create("SWExp::NoclipAdminWatch", 0.1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not IsAdminPly(ply) then continue end

        local sid      = ply:SteamID64()
        -- InVehicle() — страховка: некоторые транспортные средства
        -- ставят игроку MOVETYPE_NOCLIP пока тот за рулём,
        -- что ложно срабатывало как вход в noclip-режим.
        local inNoclip = ply:GetMoveType() == MOVETYPE_NOCLIP and not ply:InVehicle()
        local was      = wasNoclip[sid]

        if inNoclip and not was then
            -- Вошёл в noclip
            wasNoclip[sid] = true
            ApplyCloak(ply, true)

        elseif not inNoclip and was then
            -- Вышел из noclip
            wasNoclip[sid] = false
            ApplyCloak(ply, false)
        end
    end
end)

-- ============================================================
-- Чистка при дисконнекте / смерти
-- ============================================================

hook.Add("PlayerDisconnected", "SWExp::NoclipAdminCloak_DC", function(ply)
    if not IsValid(ply) then return end
    wasNoclip[ply:SteamID64()] = nil
    ApplyCloak(ply, false)
end)

hook.Add("PlayerDeath", "SWExp::NoclipAdminCloak_Death", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if wasNoclip[sid] then
        wasNoclip[sid] = false
        ApplyCloak(ply, false)
    end
end)

print("[SWExp] sv_noclip_admin loaded.")
