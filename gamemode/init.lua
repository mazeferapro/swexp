AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')

resource.AddFile('resource/fonts/Exo2-Regular.ttf')
resource.AddFile('resource/fonts/Exo2-Bold.ttf')
resource.AddFile('resource/fonts/Exo2-SemiBold.ttf')

include('shared.lua')

DEFINE_BASECLASS('gamemode_sandbox')
GM.Sandbox = BaseClass