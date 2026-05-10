--[[--
    SWExp: Тировый портальный триггер (swexp_tiered_door)
    Основан на helios_door из аддона "The Circular Portals".

    Отличия от оригинала:
    - Телепортирует только одного игрока, после чего закрывает оба портала
    - Пропсы не телепортирует (только игроки)
    - Ключ у игрока остаётся после телепортации
    - Связан с системой тиров через родительский swexp_tiered_gateway
]]--

AddCSLuaFile()

if SERVER then
    util.AddNetworkString("SWEXP_TIERED_FLASH")
end

DEFINE_BASECLASS("base_entity")

ENT.Type         = "anim"
ENT.PrintName    = "SWExp Tiered Portal Door"
ENT.Category     = "SWExp Entities"
ENT.Spawnable    = false
ENT.AdminOnly    = true
ENT.Model        = Model("models/hunter/blocks/cube1x2x025.mdl")
ENT.RenderGroup  = RENDERGROUP_BOTH

-- ============================================================================
-- УТИЛИТЫ
-- ============================================================================

local function InFront(posA, posB, normal)
    local Vec1 = (posB - posA):GetNormalized()
    return (normal:Dot(Vec1) >= 0)
end

-- ============================================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ============================================================================

function ENT:SetupDataTables()
    self:NetworkVar("Bool",   0, "Enabled")
    self:NetworkVar("Vector", 0, "TempColor")
    self:NetworkVar("Vector", 1, "RealColor")
    self:NetworkVar("Entity", 0, "Other")
    self:NetworkVar("Float",  0, "AnimStart")

    if SERVER then
        self:NetworkVarNotify("TempColor", function(ent, name, old, new)
            local color = HSVToColor(new.x, new.y, new.z)
            local r = (color.r * 2) / 255
            local g = (color.g * 2) / 255
            local b = (color.b * 2) / 255
            self:SetRealColor(Vector(r, g, b))
        end)
    end
end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

if SERVER then

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetSolid(SOLID_VPHYSICS)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMaterial("vgui/black")
        self:DrawShadow(false)
        self:SetTrigger(true)
        self:SetEnabled(false)
        self:SetUseType(SIMPLE_USE)
        self:SetCollisionGroup(COLLISION_GROUP_WORLD)
        self:SetCustomCollisionCheck(true)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Enable()
        if self:GetEnabled() then return end
        self:SetEnabled(true)
        self:EmitSound("Witcher.PortalOpen")

        if not self.ambient then
            local filter = RecipientFilter()
            filter:AddAllPlayers()
            self.ambient = CreateSound(self, "portal/portal_ambient.wav", filter)
        end
        self.ambient:Play()
        self:SetAnimStart(CurTime())
    end

    function ENT:Disable()
        if not self:GetEnabled() then return end
        self:SetEnabled(false)
        self:EmitSound("Witcher.PortalClose")
        if self.ambient then self.ambient:Stop() end
        self:SetAnimStart(CurTime())
    end

    function ENT:SetColour(color)
        local h, s, v = ColorToHSV(color)
        self:SetTempColor(Vector(h, s, v))
        if IsValid(self:GetOther()) then
            self:GetOther():SetTempColor(Vector(h, s, v))
        end
    end

    function ENT:OnRemove()
        if self.ambient then self.ambient:Stop() end
    end

    -- ========================================================================
    -- МАТЕМАТИКА ТЕЛЕПОРТАЦИИ (идентично helios_door)
    -- ========================================================================

    function ENT:TransformOffset(v, a1, a2)
        return (v:Dot(a1:Right()) * a2:Right() + v:Dot(a1:Up()) * (-a2:Up()) - v:Dot(a1:Forward()) * a2:Forward())
    end

    function ENT:GetFloorOffset(pos1, height)
        local offset = Vector(0, 0, 0)
        local pos = Vector(0, 0, 0)
        pos:Set(pos1)
        pos = self:GetOther():WorldToLocal(pos)
        pos.y = pos.y + height
        pos.z = pos.z + 10

        for i = 0, 30 do
            local openspace = util.IsInWorld(self:GetOther():LocalToWorld(pos - Vector(0, i, 0)))
            if openspace then
                offset.z = i
                break
            end
        end
        return offset
    end

    function ENT:GetOffsets(portal, ent)
        local pos
        if ent:IsPlayer() then
            pos = ent:EyePos()
        else
            pos = ent:GetPos()
        end

        local offset = self:WorldToLocal(pos)
        offset.x = -offset.x
        local output = portal:LocalToWorld(offset)

        if ent:IsPlayer() then
            return output + self:GetFloorOffset(output, (ent:EyePos() - ent:GetPos()).z)
        else
            return output
        end
    end

    function ENT:GetPortalAngleOffsets(portal, ent)
        local angles  = ent:GetAngles()
        local normal  = self:GetAngles():Up()
        local forward = -angles:Forward()
        local up      = angles:Up()

        local dot = forward:Dot(normal)
        forward = forward + (-2 * dot) * normal

        dot = up:Dot(normal)
        up = up + (-2 * dot) * normal

        angles = math.VectorAngles(forward, up)
        local LocalAngles = self:WorldToLocalAngles(angles)
        LocalAngles.x = -LocalAngles.x
        LocalAngles.y = -LocalAngles.y
        return portal:LocalToWorldAngles(LocalAngles)
    end

    -- ========================================================================
    -- ЗАКРЫТИЕ ПОРТАЛА ПОСЛЕ ИСПОЛЬЗОВАНИЯ
    -- ========================================================================

    function ENT:NotifyGatewayAfterTeleport()
        -- Сообщаем родительскому gateway что игрок прошёл.
        -- Gateway закрывает анимацию/двери, но НЕ трогает постоянную связь (LinkedTo).
        local gateway = self:GetParent()
        if IsValid(gateway) and gateway:GetClass() == "swexp_tiered_gateway" then
            gateway:OnPlayerTeleported()
        end
    end

    -- ========================================================================
    -- ТРИГГЕР ТЕЛЕПОРТАЦИИ
    -- ========================================================================

    function ENT:StartTouch(ent) end

    function ENT:GravGunPickupAllowed() return false end

    function ENT:Touch(ent)
        if not IsValid(ent) then return end
        if ent:GetClass() == "swexp_tiered_gateway" then return end
        if ent:GetClass() == "swexp_tiered_door" then return end

        -- Пропускаем только игроков
        if not ent:IsPlayer() then return end

        if not (IsValid(self:GetOther()) and self:GetEnabled()) then return end

        local faceNormal = self:GetAngles():Up()
        if InFront(ent:GetPos(), self:GetPos() - faceNormal * 2.8, faceNormal) then return end

        if not ent.lastPort then ent.lastPort = 0 end
        if CurTime() < (ent.lastPort + 0.4) then return end

        -- Телепортация игрока
        local color    = self:GetRealColor()
        local vel      = ent:GetVelocity()
        local other    = self:GetOther()

        local newPos    = self:GetOffsets(other, ent)
        local newVel    = self:TransformOffset(vel, self:GetAngles(), other:GetAngles())
        local newAngles = self:GetPortalAngleOffsets(other, ent)
        newAngles.z = 0

        -- Коррекция приседания
        newPos.z = newPos.z - (ent:EyePos() - ent:GetPos()).z

        local otherNormal = other:GetAngles():Up()
        local checkDist = DistanceToPlane(newPos, other:GetPos(), otherNormal)
        if checkDist < 0 then otherNormal = -otherNormal end

        if other:GetAngles().z > -60 then
            newPos = newPos + otherNormal * 50
        end

        local offset = Vector()
        for i = 0, 20 do
            local openspace = util.IsInWorld(newPos + Vector(0, 0, i))
            if openspace then offset.z = i break end
        end

        newPos = newPos + offset + otherNormal * 3

        local planeDist = DistanceToPlane(newPos, other:GetPos(), otherNormal)
        if planeDist <= 16 then
            newPos = newPos + otherNormal * (16 - planeDist)
        end

        local up = otherNormal
        local nearestPoint = other:NearestPoint(newPos)
        local nearNormal = (newPos - nearestPoint):GetNormalized()
        local foundSpot = false
        local trace

        for i = 0, 30 do
            trace = util.TraceEntity({
                start  = nearestPoint + up * 32 + nearNormal * 5 + other:GetRight() * i,
                endpos = newPos + up + other:GetRight() * i,
                filter = function(traceEnt)
                    if traceEnt == other then return false end
                    if IsValid(other:GetParent()) and traceEnt == other:GetParent() then return false end
                    return true
                end
            }, ent)
            if not trace.AllSolid then foundSpot = true break end
        end

        if not foundSpot then return end

        ent:SetPos(trace.HitPos + up * 2)
        ent:SetLocalVelocity(newVel)
        ent:SetEyeAngles(newAngles)
        ent.lastPort = CurTime()

        sound.Play("portal/portal_teleport.wav", self:WorldSpaceCenter())
        sound.Play("portal/portal_teleport.wav", other:WorldSpaceCenter())

        ent:ScreenFade(SCREENFADE.IN, color_black, 0.2, 0.03)

        -- Уведомляем систему врагов: игрок прошёл через портал.
        -- Передаём тир исходного и целевого gateway, чтобы менеджер
        -- определил направление (вперёд = зона+1, назад = зона портала).
        local srcGateway  = self:GetParent()
        local destDoor    = self:GetOther()
        local destGateway = IsValid(destDoor) and destDoor:GetParent() or nil
        local srcTier  = (IsValid(srcGateway)  and srcGateway:GetClass()  == "swexp_tiered_gateway") and srcGateway:GetTier()  or 1
        local destTier = (IsValid(destGateway) and destGateway:GetClass() == "swexp_tiered_gateway") and destGateway:GetTier() or 1
        hook.Run("SWExp::PlayerPassedPortal", ent, srcTier, destTier)

        -- Уведомить gateway что игрок прошёл → закрыть анимацию, сохранить связь
        -- Небольшая задержка чтобы screenfade успел начаться
        timer.Simple(0.1, function()
            if IsValid(self) then
                self:NotifyGatewayAfterTeleport()
            end
        end)
    end

elseif CLIENT then

    -- ========================================================================
    -- КЛИЕНТСКИЙ РЕНДЕРИНГ (идентично helios_door)
    -- ========================================================================

    local mat = CreateMaterial("swexpTieredGlow", "UnlitGeneric", {
        ["$basetexture"]          = "sprites/light_glow02",
        ["$additive"]             = 1,
        ["$translucent"]          = 1,
        ["$vertexcolor"]          = 1,
        ["$vertexalpha"]          = 1,
        ["$ignorez"]              = 1
    })

    local tempcolor   = Color(0, 0, 0, 0)
    local unit_vector = Vector(1, 1, 0.01)
    local green       = Color(0, 255, 0, 1)

    function ENT:Initialize()
        self.PixVis = util.GetPixelVisibleHandle()
        local matrix = Matrix()
        matrix:Scale(Vector(1, 1, 0.01))
        local offset = 1.8

        local effectData = EffectData()
        effectData:SetEntity(self)
        effectData:SetOrigin(self:GetPos())
        util.Effect("portal_inhale", effectData)

        self:SetSolid(SOLID_VPHYSICS)

        self.hole = ClientsideModel("models/helios/effects/portal_top_inside.mdl", RENDERGROUP_BOTH)
        self.hole:SetPos(self:GetPos() - self:GetUp() * (0 + offset))
        self.hole:SetAngles(self:GetAngles())
        self.hole:SetParent(self)
        self.hole:SetNoDraw(true)
        self.hole:EnableMatrix("RenderMultiply", matrix)

        self.top = ClientsideModel("models/helios/effects/portal_side_inside.mdl", RENDERGROUP_BOTH)
        self.top:SetMaterial("portal/border3")
        self.top:SetPos(self:GetPos() + self:GetRight() * -0 - self:GetUp() * (0 + offset))
        self.top:SetParent(self)
        self.top:SetLocalAngles(Angle(0, 0, 0))
        self.top:SetNoDraw(true)

        self.back = ClientsideModel("models/hunter/plates/plate3x3.mdl", RENDERGROUP_BOTH)
        self.back:SetMaterial("vgui/black")
        self.back:SetPos(self:GetPos() - self:GetUp() * 42)
        self.back:SetParent(self)
        self.back:SetLocalAngles(angle_zero)
        self.back:SetNoDraw(true)

        self.h, self.s, self.l = 0, 1, 1
    end

    function ENT:OnRemove()
        if IsValid(self.top)  then self.top:Remove()  end
        if IsValid(self.hole) then self.hole:Remove() end
        if IsValid(self.back) then self.back:Remove() end
    end

    function ENT:Draw() end

    function ENT:Think()
        if self:GetEnabled() then
            local light = DynamicLight(self:EntIndex())
            if light then
                local vecCol = self:GetRealColor()
                light.pos        = self:WorldSpaceCenter() + self:GetUp() * 15
                light.Size       = 300
                light.style      = 5
                light.Decay      = 600
                light.brightness = 1
                light.r          = (vecCol.x / 2) * 255
                light.g          = (vecCol.y / 2) * 255
                light.b          = (vecCol.z / 2) * 255
                light.DieTime    = CurTime() + 0.1
            end
        end

        if IsValid(self.hole) then self.hole:SetParent(self) end
        if IsValid(self.top)  then self.top:SetParent(self)  end
        if IsValid(self.back) then self.back:SetParent(self) end
    end

    local function DefineClipBuffer(ref)
        render.ClearStencil()
        render.SetStencilEnable(true)
        render.SetStencilCompareFunction(STENCIL_ALWAYS)
        render.SetStencilPassOperation(STENCIL_REPLACE)
        render.SetStencilFailOperation(STENCIL_KEEP)
        render.SetStencilZFailOperation(STENCIL_KEEP)
        render.SetStencilWriteMask(254)
        render.SetStencilTestMask(254)
        render.SetStencilReferenceValue(ref or 44)
    end

    local function DrawToBuffer()
        render.SetStencilCompareFunction(STENCIL_EQUAL)
    end

    local function EndClipBuffer()
        render.SetStencilEnable(false)
        render.ClearStencil()
    end

    function ENT:DrawTranslucent()
        debugoverlay.BoxAngles(self:GetPos(), unit_vector * -60, unit_vector * 60, self:GetAngles(), 0.1, green)

        if InFront(LocalPlayer():EyePos(), self:GetPos() - self:GetUp() * 1.8, self:GetUp()) then return end

        local bEnabled = self:GetEnabled()
        local color    = self:GetRealColor()
        local elapsed  = CurTime() - self:GetAnimStart()
        local frac     = math.Clamp(elapsed / (bEnabled and 0.5 or 0.1), 0, 1)

        if frac <= 1 then
            tempcolor:SetUnpacked((color.x / 2) * 255, (color.y / 2) * 255, (color.z / 2) * 255, 255)
            self.h, self.s, self.l = ColorToHSL(tempcolor)
            self.l = Lerp(frac, self.l or 1, bEnabled and 0 or 1)
            self.col = HSLToColor(self.h, self.s, self.l)
        end

        if bEnabled then
            self.lerpr = Lerp(frac, self.lerpr or 255, self.col.r)
            self.lerpg = Lerp(frac, self.lerpg or 255, self.col.g)
            self.lerpb = Lerp(frac, self.lerpb or 255, self.col.b)
        else
            self.lerpr = Lerp(frac, self.lerpr or 0, self.col.r)
            self.lerpg = Lerp(frac, self.lerpg or 0, self.col.g)
            self.lerpb = Lerp(frac, self.lerpb or 0, self.col.b)
        end

        self.top:SetNoDraw(true)
        DefineClipBuffer()

        if (bEnabled and frac > 0) or (not bEnabled and frac < 1) then
            self.hole:DrawModel()
        end

        DrawToBuffer()
        render.ClearBuffersObeyStencil(self.lerpr, self.lerpg, self.lerpb, 0, bEnabled)

        if bEnabled and frac >= 0.1 then
            if frac >= 1 then self.back:DrawModel() end
            render.SetColorModulation(color.x * 3, color.y * 3, color.z * 3)
            self.top:DrawModel()
            render.SetColorModulation(1, 1, 1)
        end

        EndClipBuffer()

        if not bEnabled then return end

        local norm     = self:GetUp()
        local viewNorm = (self:GetPos() - EyePos()):GetNormalized()
        local dot      = viewNorm:Dot(norm * -1)

        if dot >= 0 then
            render.SetColorModulation(1, 1, 1)
            local visible = util.PixelVisible(self:GetPos() + self:GetUp() * 3, 20, self.PixVis)
            if not visible then return end

            local alpha = math.Clamp((EyePos():Distance(self:GetPos()) / 10) * dot * visible, 0, 30)
            tempcolor:SetUnpacked(color.x, color.y, color.z, alpha)
            render.SetMaterial(mat)
            render.DrawSprite(self:GetPos() + self:GetUp() * 2, 600, 600, tempcolor, visible * dot)
        end
    end

end
