-- ============================================================
-- Star Wars: Expedition — Зона исследований (клиент)
-- entities/swexp_res_zone/cl_init.lua
--
-- Использует тот же ConVar swexp_zones_visible что и mat_zone.
-- IMesh рендер — один draw-call на зону.
-- ============================================================

include("shared.lua")

-- Тот же конвар — создаём только если ещё не существует
if not ConVarExists("swexp_zones_visible") then
    CreateClientConVar("swexp_zones_visible", "1", true, false,
        "Показывать зоны SWExp администраторам (0/1)")
end
local cv_visible = GetConVar("swexp_zones_visible")

local _meshCache  = {}
local _pulseAlpha = {}
local _pulseTimer = 0

local RING_SEGS = 28
local PAR_SEGS  = 20
local MER_SEGS  = 10
local MERIDIANS = 6
local PARALLELS = 3
local MAX_DIST  = 3500

local _mat = Material("effects/laser1")

local function BuildMesh(r, cr, cg, cb)
    local verts = {}

    local function addLine(x1,y1,z1, x2,y2,z2, alpha)
        local col = Color(cr, cg, cb, alpha)
        verts[#verts+1] = { pos = Vector(x1,y1,z1), color = col }
        verts[#verts+1] = { pos = Vector(x2,y2,z2), color = col }
    end

    local step = (math.pi * 2) / RING_SEGS
    for i = 0, RING_SEGS - 1 do
        local a1, a2 = i*step, (i+1)*step
        addLine(math.cos(a1)*r, math.sin(a1)*r, 0,
                math.cos(a2)*r, math.sin(a2)*r, 0, 160)
    end

    step = (math.pi * 2) / PAR_SEGS
    for p = 1, PARALLELS do
        local el = (math.pi * 0.5) * (p / (PARALLELS + 1))
        local rh = math.cos(el) * r
        local h  = math.sin(el) * r
        local a  = math.Round(160 * (1 - p / (PARALLELS + 1)))
        for i = 0, PAR_SEGS - 1 do
            local a1, a2 = i*step, (i+1)*step
            addLine(math.cos(a1)*rh, math.sin(a1)*rh, h,
                    math.cos(a2)*rh, math.sin(a2)*rh, h, a)
        end
    end

    local mstep = (math.pi * 0.5) / MER_SEGS
    for m = 0, MERIDIANS - 1 do
        local yaw = (math.pi * 2) * (m / MERIDIANS)
        local cy, sy = math.cos(yaw), math.sin(yaw)
        for i = 0, MER_SEGS - 1 do
            local el1, el2 = i*mstep, (i+1)*mstep
            local r1, r2   = math.cos(el1)*r, math.cos(el2)*r
            addLine(cy*r1, sy*r1, math.sin(el1)*r,
                    cy*r2, sy*r2, math.sin(el2)*r, 100)
        end
    end

    local m = Mesh()
    mesh.Begin(m, MATERIAL_LINES, #verts / 2)
    for _, v in ipairs(verts) do
        mesh.Position(v.pos)
        mesh.Color(v.color.r, v.color.g, v.color.b, v.color.a)
        mesh.AdvanceVertex()
    end
    mesh.End()

    return m
end

local function GetMesh(ent)
    local idx = ent:EntIndex()
    local r   = ent:GetNWInt("SWExp_ZoneRadius", 600)
    local cr  = ent:GetNWInt("SWExp_ColorR", 80)
    local cg  = ent:GetNWInt("SWExp_ColorG", 160)
    local cb  = ent:GetNWInt("SWExp_ColorB", 255)
    local c   = _meshCache[idx]
    if not c or c.radius ~= r or c.cr ~= cr or c.cg ~= cg or c.cb ~= cb then
        if c and c.mesh then c.mesh:Destroy() end
        _meshCache[idx] = { radius=r, cr=cr, cg=cg, cb=cb, mesh=BuildMesh(r,cr,cg,cb) }
    end
    return _meshCache[idx].mesh
end

-- ── Рендер модели ────────────────────────────────────────────

function ENT:Draw()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if cv_visible:GetBool() and (lp:IsAdmin() or lp:IsSuperAdmin()) then
        self:DrawModel()
    end
end

-- ── Полусфера ────────────────────────────────────────────────

hook.Add("PostDrawTranslucentRenderables", "SWExp::ResZoneDraw", function()
    if not cv_visible:GetBool() then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not (lp:IsAdmin() or lp:IsSuperAdmin()) then return end

    local now = CurTime()
    if now - _pulseTimer > 0.1 then
        _pulseTimer = now
        for _, ent in ipairs(ents.FindByClass("swexp_res_zone")) do
            if IsValid(ent) then
                _pulseAlpha[ent:EntIndex()] = math.abs(math.sin(now + 1.5)) * 0.45 + 0.45
            end
        end
    end

    local lpPos = lp:GetPos()
    render.SetMaterial(_mat)

    for _, ent in ipairs(ents.FindByClass("swexp_res_zone")) do
        if not IsValid(ent) then continue end

        local pos  = ent:GetPos()
        local dist = lpPos:Distance(pos)
        if dist > MAX_DIST then continue end

        local pulse    = _pulseAlpha[ent:EntIndex()] or 0.7
        local distFade = 1 - math.Clamp((dist - 1200) / 2300, 0, 1)
        local alpha    = pulse * distFade

        if alpha < 0.05 then continue end

        render.SetColorModulation(1, 1, 1)
        render.SetBlend(alpha)

        local mat = Matrix()
        mat:Translate(pos)
        cam.PushModelMatrix(mat)
            GetMesh(ent):Draw()
        cam.PopModelMatrix()

        render.SetBlend(1)
    end
end)

-- ── 3D-метка ─────────────────────────────────────────────────

hook.Add("PostDrawOpaqueRenderables", "SWExp::ResZoneLabel", function()
    if not cv_visible:GetBool() then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not (lp:IsAdmin() or lp:IsSuperAdmin()) then return end

    local eyeY  = EyeAngles().y
    local lpPos = lp:GetPos()

    for _, ent in ipairs(ents.FindByClass("swexp_res_zone")) do
        if not IsValid(ent) then continue end

        local dist = lpPos:Distance(ent:GetPos())
        if dist > 2500 then continue end

        local fade = math.Clamp(1 - (dist - 600) / 1900, 0, 1)
        if fade < 0.02 then continue end

        local tier    = ent:GetNWInt("SWExp_ZoneTier",    1)
        local radius  = ent:GetNWInt("SWExp_ZoneRadius",  600)
        local respawn = ent:GetNWInt("SWExp_ZoneRespawn", 90)
        local cr      = ent:GetNWInt("SWExp_ColorR", 80)
        local cg      = ent:GetNWInt("SWExp_ColorG", 160)
        local cb      = ent:GetNWInt("SWExp_ColorB", 255)

        local a255 = math.Round(255 * fade)
        local a200 = math.Round(200 * fade)
        local a150 = math.Round(150 * fade)
        local a120 = math.Round(120 * fade)

        cam.Start3D2D(ent:GetPos() + Vector(0,0,40), Angle(0, eyeY-90, 90), 0.10)
            local bw, bh = 260, 74
            local bx, by = -bw/2, -bh/2
            draw.RoundedBox(6, bx, by, bw, bh, Color(6, 11, 18, math.Round(220*fade)))
            draw.RoundedBox(3, bx+3, by+8, 3, bh-16, Color(cr, cg, cb, a255))
            surface.SetDrawColor(cr, cg, cb, a120)
            surface.DrawOutlinedRect(bx, by, bw, bh, 2)
            draw.SimpleText("ЗОНА ИССЛЕДОВАНИЙ  ТИР "..tier, "SWUI.Small",
                0, by+10, Color(cr,cg,cb,a255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("R=%d   Респавн=%dс   [E] Настройки", radius, respawn),
                "SWUI.Tiny", 0, by+36, Color(160,185,210,a200), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("#%d", ent:EntIndex()),
                "SWUI.Tiny", bx+bw-8, by+56, Color(100,130,160,a150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        cam.End3D2D()
    end
end)

-- ── Чистим меши ──────────────────────────────────────────────

hook.Add("EntityRemoved", "SWExp::ResZoneCacheClean", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "swexp_res_zone" then return end
    local idx = ent:EntIndex()
    if _meshCache[idx] and _meshCache[idx].mesh then
        _meshCache[idx].mesh:Destroy()
    end
    _meshCache[idx]  = nil
    _pulseAlpha[idx] = nil
end)

print("[SWExp] swexp_res_zone (клиент) загружен.")
