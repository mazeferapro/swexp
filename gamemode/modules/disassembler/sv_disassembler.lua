-- ============================================================
-- Star Wars: Expedition — Дисассемблер (сервер)
-- modules/sv_disassembler.lua
--
-- Разбирает предмет из инвентаря игрока и зачисляет в
-- общий банк отряда floor(recipe.cost / 2) материалов.
-- ============================================================

if CLIENT then return end

SWExp.Disassembler = SWExp.Disassembler or {}

-- Fallback rate-limit
local function RateOk(ply, key, cd)
    if SWExp and SWExp.Net and SWExp.Net.RateCheck then
        return SWExp.Net:RateCheck(ply, key, cd)
    end
    return IsValid(ply)
end

-- ============================================================
-- Net-строки
-- ============================================================

util.AddNetworkString("SWExp::Disasm_Open")    -- сервер → клиент: открыть меню
util.AddNetworkString("SWExp::Disasm_Req")     -- клиент → сервер: разобрать предмет
util.AddNetworkString("SWExp::Disasm_Result")  -- сервер → клиент: результат

-- ============================================================
-- Построить lookup: itemID → рецепт с наибольшей стоимостью
-- (на случай если один предмет фигурирует в нескольких рецептах
--  с разным quantity — берём дорогой, т.е. выгоднее для игрока)
-- ============================================================

local function BuildRecipeLookup()
    local cfg = SWExp.AssemblerConfig
    if not cfg or not cfg.Recipes then return {} end

    local lookup = {}
    for _, recipe in ipairs(cfg.Recipes) do
        local existing = lookup[recipe.result]
        if not existing or (recipe.cost or 0) > (existing.cost or 0) then
            lookup[recipe.result] = recipe
        end
    end
    return lookup
end

-- ============================================================
-- Получить список разбираемых предметов из личного инвентаря
-- ============================================================

local function GetDisassemblableItems(ply)
    if not SWExp.Inventory then return {} end

    local charID  = SWExp.Inventory:GetCharacterID(ply)
    if not charID then return {} end

    local steamID = ply:SteamID64()
    local stor    = SWExp.Inventory.PlayerInventories[steamID]
                    and SWExp.Inventory.PlayerInventories[steamID][charID]
    if not stor then return {} end

    local lookup = BuildRecipeLookup()
    local items  = {}

    for uniqueID, item in pairs(stor.items) do
        local recipe = lookup[item.itemID]
        if recipe then
            local per = math.floor((recipe.cost or 0) / 2)
            local amt = item.amount or 1
            table.insert(items, {
                uniqueID = uniqueID,
                itemID   = item.itemID,
                amount   = amt,
                refund   = per * amt,   -- total for the whole stack/entry
            })
        end
    end

    return items
end

-- ============================================================
-- Отправить меню дисассемблера игроку
-- ============================================================

function SWExp.Disassembler.SendMenuData(ply)
    if not IsValid(ply) then return end

    local bank  = (SWExp.Assembler and SWExp.Assembler._bank) or 0
    local items = GetDisassemblableItems(ply)
    local json  = util.TableToJSON(items)

    net.Start("SWExp::Disasm_Open")
        net.WriteInt(bank,  32)
        net.WriteString(json)
    net.Send(ply)
    hook.Run("SWExp::DisassemblerMenuOpened", ply)
end

-- ============================================================
-- Обработка: РАЗОБРАТЬ предмет
-- ============================================================

net.Receive("SWExp::Disasm_Req", function(len, ply)
    if not IsValid(ply) then return end
    if not RateOk(ply, "Disasm_Req") then return end

    local uniqueID = net.ReadString()
    if not uniqueID or uniqueID == "" then return end
    if #uniqueID > 64 then return end  -- защита от длинных строк

    -- Проверяем инвентарь
    if not SWExp.Inventory then return end
    local charID  = SWExp.Inventory:GetCharacterID(ply)
    if not charID then return end

    local steamID = ply:SteamID64()
    local stor    = SWExp.Inventory.PlayerInventories[steamID]
                    and SWExp.Inventory.PlayerInventories[steamID][charID]

    local function SendFail(msg)
        local bank = (SWExp.Assembler and SWExp.Assembler._bank) or 0
        net.Start("SWExp::Disasm_Result")
            net.WriteBool(false)
            net.WriteString(msg)
            net.WriteString("")   -- uniqueID (none on fail)
            net.WriteInt(0,    16)
            net.WriteInt(bank, 32)
        net.Send(ply)
    end

    if not stor or not stor.items[uniqueID] then
        SendFail("Предмет не найден в инвентаре.")
        return
    end

    local item = stor.items[uniqueID]

    -- Ищем рецепт (наиболее дорогой для данного itemID)
    local cfg    = SWExp.AssemblerConfig
    local recipe = BuildRecipeLookup()[item.itemID]

    if not recipe then
        SendFail("Этот предмет нельзя разобрать.")
        return
    end

    local perItem   = math.floor((recipe.cost or 0) / 2)
    local itemName  = recipe.name or item.itemID
    local amount    = item.amount or 1
    local totalRefund = perItem * amount

    -- Удаляем предмет из инвентаря (весь стак по uniqueID)
    SWExp.Inventory:RemoveItem(ply, uniqueID, amount, false)

    -- Зачисляем в банк (за все штуки в стаке)
    if SWExp.Assembler then
        SWExp.Assembler._bank = (SWExp.Assembler._bank or 0) + totalRefund
        if MySQLite then
            MySQLite.query(
                "UPDATE `swexp_assembler_bank` SET `materials`=" ..
                SWExp.Assembler._bank .. " WHERE `id`=1;"
            )
        end
    end

    local newBank = (SWExp.Assembler and SWExp.Assembler._bank) or 0

    print(string.format("[SWExp|Disasm] %s разобрал «%s» ×%d → +%d мат. (банк=%d)",
        ply:Nick(), itemName, amount, totalRefund, newBank))

    -- Результат — отправителю (шлём uniqueID чтобы клиент мог убрать именно эту запись из списка без пересоздания меню)
    net.Start("SWExp::Disasm_Result")
        net.WriteBool(true)
        net.WriteString(itemName)
        net.WriteString(uniqueID)
        net.WriteInt(totalRefund, 16)
        net.WriteInt(newBank, 32)
    net.Send(ply)

    -- Обновляем банк всем онлайн (чтобы ассемблер у всех показал актуальное значение)
    net.Start("SWExp::Assembler_Update")
        net.WriteInt(newBank, 32)
    net.Broadcast()
end)

print("[SWExp] Модуль дисассемблера (сервер) загружен.")
