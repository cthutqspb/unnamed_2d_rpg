local M = {}

-- Хранилище экипировки
M.slots = {
    HEAD = nil,   -- тут будет лежать {item_id = hash("leather_helmet"), weight = 1.0}
    CHEST = nil,
    LEGS = nil,
    WEAPON = nil,
    SHIELD = nil
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
