-- ============================================================
-- Star Wars: Expedition — Контроль фонарика (сервер)
-- modules/sv_flashlight.lua
-- ============================================================

if CLIENT then return end

util.AddNetworkString("SWExp::FlashlightToggle")

local function HasFlashlightItem(pPlayer)
    if not IsValid(pPlayer) then return false end
    if not SWExp.Inventory then return false end

    local steamID = pPlayer:SteamID64()
    local charID  = SWExp.Inventory:GetCharacterID(pPlayer)
    if not charID then return false end

    local equip = SWExp.Inventory.PlayerEquipment
    if not equip[steamID] then return false end
    if not equip[steamID][charID] then return false end

    local specialSlots = equip[steamID][charID]["special"]
    if not specialSlots then return false end

    for _, item in pairs(specialSlots) do
        if item and item.itemID == "tool_flashlight" then
            return true
        end
    end

    return false
end

-- Переопределяем метод геймода — именно он отвечает за разрешение фонарика
function GM:PlayerSwitchFlashlight(pPlayer, enabled)
    if not enabled then return true end  -- выключать всегда можно
    return HasFlashlightItem(pPlayer)
end

-- Получаем запрос от клиента и переключаем фонарик
net.Receive("SWExp::FlashlightToggle", function(len, pPlayer)
    if not IsValid(pPlayer) then return end
    if not HasFlashlightItem(pPlayer) then return end
    pPlayer:Flashlight(not pPlayer:FlashlightIsOn())
end)

-- При снятии фонарика из слота — гасим
hook.Add("SWExp::ItemUnequipping", "SWExp::FlashlightUnequip", function(pPlayer, slotType, slotIndex, itemID)
    if slotType == "special" and itemID == "tool_flashlight" then
        timer.Simple(0.1, function()
            if IsValid(pPlayer) and pPlayer:FlashlightIsOn() and not HasFlashlightItem(pPlayer) then
                pPlayer:Flashlight(false)
            end
        end)
    end
end)

print("[SWExp] Модуль контроля фонарика загружен.")
