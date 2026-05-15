local items_db = require("main.modules.data.items_db");

local M = {}

M.slots = {
    HEAD = {item_id = nil, amount = 0},
    CHEST = {item_id = nil, amount = 0},
    LEGS = {item_id = nil, amount = 0},
    WEAPON = {item_id = nil, amount = 0},
    SHIELD = {item_id = nil, amount = 0}
}

function M.can_equip(item_type, slot_type)
    if slot_type == "WEAPON" and item_type == "WEAPON" then return true end
    if slot_type == "HEAD" and item_type == "HEAD" then return true end
    return false
end

function M.can_equip_id(item_id, slot_type)
    local cfg = items_db.get_item(item_id)
    if not cfg then return false end
    return M.can_equip(cfg.type, slot_type)
end

-- Экипировать
function M.equip(slot_type, item_data)
    local old_item = M.slots[slot_type]
    M.slots[slot_type] = item_data
    return old_item -- возвращаем старую шмотку, чтобы положить её обратно в инвентарь
end

function M.get_save_data()
    return M.slots
end

function M.load_save_data(data)
    M.slots = data or {}
end

function M.clear()
    for slot_type, _ in pairs(M.slots) do
        M.slots[slot_type] = { item_id = nil, amount = 0 }
    end
end

return M
