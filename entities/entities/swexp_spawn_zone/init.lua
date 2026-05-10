-- УСТАРЕЛО: заменено на swexp_mat_zone и swexp_res_zone
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
function ENT:Initialize() self:Remove() end
