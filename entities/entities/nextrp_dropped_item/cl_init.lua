--[[--
    SWExp: Выброшенный предмет — клиентская часть
    Entity: nextrp_dropped_item
]]--

include("shared.lua")

local GLOW_COLOR = Color(0, 184, 255)

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawTranslucent()
    -- Ничего
end

-- Рендерим иконку / название над предметом
hook.Add("PostDrawOpaqueRenderables", "SWExp::DrawDroppedItemLabels", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    for _, ent in ipairs(ents.FindByClass("nextrp_dropped_item")) do
        if not IsValid(ent) then continue end

        local dist = lp:GetPos():Distance(ent:GetPos())
        local maxDist = 200

        if dist > maxDist then continue end

        local itemID   = ent:GetNWString("SWExp_ItemID", "")
        local amount   = ent:GetNWInt("SWExp_Amount", 1)
        local itemData = SWExp and SWExp.Inventory and SWExp.Inventory:GetItemData(itemID)
        local name     = itemData and itemData.name or itemID
        local rarity   = itemData and itemData.rarity or "common"

        local rarityColors = {
            common    = Color(168, 204, 220),
            uncommon  = Color(0, 238, 119),
            rare      = Color(0, 184, 255),
            epic      = Color(163, 53, 238),
            legendary = Color(255, 136, 0),
        }
        local col = rarityColors[rarity] or rarityColors.common

        -- Прозрачность при приближении
        local alpha = math.Clamp(1 - (dist / maxDist), 0.3, 1)

        local pos = ent:GetPos() + Vector(0, 0, 8)
        local ang = (lp:GetPos() - pos):Angle()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Right(), 90)

        cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), 0.08)
            -- Фон
            draw.RoundedBox(8, -130, -22, 260, 44,
                Color(6, 12, 18, math.Round(200 * alpha)))

            -- Цветная рамка (редкость)
            surface.SetDrawColor(col.r, col.g, col.b, math.Round(180 * alpha))
            surface.DrawOutlinedRect(-130, -22, 260, 44, 2)

            -- Название
            draw.SimpleText(
                string.upper(name),
                "DermaDefault",
                0, -6,
                Color(col.r, col.g, col.b, math.Round(255 * alpha)),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            -- Количество
            if amount and amount > 1 then
                draw.SimpleText(
                    "×" .. amount,
                    "DermaDefault",
                    0, 10,
                    Color(200, 200, 200, math.Round(200 * alpha)),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end

            -- Подсказка
            local pickupAlpha = math.Clamp((100 - dist) / 100, 0, 1)
            if pickupAlpha > 0 then
                draw.SimpleText(
                    "[E] Подобрать",
                    "DermaDefault",
                    0, 30,
                    Color(255, 255, 255, math.Round(200 * pickupAlpha)),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        cam.End3D2D()
    end
end)
