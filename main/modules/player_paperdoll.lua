local M = {}


M.slots = {
    HEAD = {item_id = nil, amount = 0},
    CHEST = {item_id = nil, amount = 0},
    LEGS = {item_id = nil, amount = 0},
    WEAPON = {item_id = nil, amount = 0},
    SHIELD = {item_id = nil, amount = 0}
}

-- Проверка: можно ли этот предмет надеть в этот слот?
function M.can_equip(item_type, slot_type)
    -- Например, оружие можно только в руку
    if slot_type == "WEAPON" and item_type == "WEAPON" then return true end
    if slot_type == "HEAD" and item_type == "HEAD" then return true end
    -- ... и так далее
    return false
end

-- Экипировать
function M.equip(slot_type, item_data)
    local old_item = M.slots[slot_type]
    M.slots[slot_type] = item_data
    return old_item -- возвращаем старую шмотку, чтобы положить её обратно в инвентарь
end

return M
