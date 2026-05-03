local items_db = require("main.modules.items_db")

local M = {}

M.max_slots = 48
M.items = {} -- Таблица вида: [1] = {item_id = hash, amount = 2}, [2] = {item_id = nil, amount = 0}

function M.init()
    for i = 1, M.max_slots do
        M.items[i] = { item_id = nil, amount = 0 }
    end
end

function M.add_item(item_id, amount)
    local data = items_db.get_item(item_id)
    if not data then return false end

    local remaining = amount
    local item_hash = type(item_id) == "string" and hash(item_id) or item_id
    local max_stack = data.max_stack or 1

    -- 1. Сначала стакаем в существующие слоты
    if data.stackable then
        for i = 1, M.max_slots do
            local slot = M.items[i]
            if slot.item_id == item_hash and slot.amount < max_stack then
                local add = math.min(remaining, max_stack - slot.amount)
                slot.amount = slot.amount + add
                remaining = remaining - add
                if remaining <= 0 then return true end
            end
        end
    end

    -- 2. Ищем пустые слоты для остатка
    for i = 1, M.max_slots do
        local slot = M.items[i]
        if not slot.item_id then
            local add = math.min(remaining, max_stack)
            slot.item_id = item_hash
            slot.amount = add
            remaining = remaining - add
            if remaining <= 0 then return true end
        end
    end

    return remaining <= 0 -- Вернет false, если инвентарь забит
end

function M.swap_slots(from_idx, to_idx)
    M.items[from_idx], M.items[to_idx] = M.items[to_idx], M.items[from_idx]
end

M.init()
return M

