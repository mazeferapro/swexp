AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')

resource.AddFile('resource/fonts/Exo2-Regular.ttf')
resource.AddFile('resource/fonts/Exo2-Bold.ttf')
resource.AddFile('resource/fonts/Exo2-SemiBold.ttf')

include('shared.lua')
include('modules/sv_trademc.lua')

DEFINE_BASECLASS('gamemode_sandbox')
GM.Sandbox = BaseClass

-- ============================================================
-- Серверная защита от спавна через консоль (gm_spawn)
-- ============================================================

local function CheckSpawnPermission(ply)
    if not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        return false
    end
    return true
end

-- Блокируем все виды спавна
hook.Add("PlayerSpawnProp", "SWExp::BlockPropSpawn", CheckSpawnPermission)
hook.Add("PlayerSpawnEffect", "SWExp::BlockEffectSpawn", CheckSpawnPermission)
hook.Add("PlayerSpawnNPC", "SWExp::BlockNPCSpawn", CheckSpawnPermission)
hook.Add("PlayerSpawnRagdoll", "SWExp::BlockRagdollSpawn", CheckSpawnPermission)
hook.Add("PlayerSpawnSENT", "SWExp::BlockEntitySpawn", CheckSpawnPermission)
hook.Add("PlayerSpawnSWEP", "SWExp::BlockWeaponSpawn", CheckSpawnPermission)
hook.Add("PlayerSpawnVehicle", "SWExp::BlockVehicleSpawn", CheckSpawnPermission)