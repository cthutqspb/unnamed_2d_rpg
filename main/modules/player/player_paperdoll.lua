local items_db = require("main.modules.data.items_db")
local item_requirements_manager = require("main.modules.logic.item_requirements_manager")
local character_data = require("main.modules.character.character_data")


local M = {}

M.slots = {
    HEAD = {item_id = nil, amount = 0},
    CHEST = {item_id = nil, amount = 0},
    LEGS = {item_id = nil, amount = 0},
    MAIN_HAND = {item_id = nil, amount = 0},
    SHIELD = {item_id = nil, amount = 0}
}

-- ИНТЕРФЕЙСНЫЕ МЕТОДЫ (для MVC)

function M:get_item(slot_type)
    return self.slots[slot_type]
end

function M:set_item(slot_type, item_data)
    -- Если передали nil, создаем пустышку
    self.slots[slot_type] = item_data or {item_id = nil, amount = 0}
end

-- ВАЛИДАЦИЯ
function M:can_equip_item(item_id, slot_type)
    local cfg = items_db.get_item(item_id)
    if not cfg then return false end

    -- 1. Сверяем тип слота (как и было)
    if cfg.equip_slot ~= slot_type then
        return false
    end

    -- 2. Сверяем требования (наш новый блок)
    local check = item_requirements_manager.check(cfg, character_data.player)
    if not check.is_ok then
        print("REQUIREMENTS FAILED: Cannot equip " .. item_id)
        -- Можно здесь кинуть broadcast, чтобы показать надпись игроку
        return false
    end

    return true
end

-- СИСТЕМНЫЕ МЕТОДЫ
function M.get_save_data()
    return M.slots
end

function M.load_save_data(data)
    if data then M.slots = data end
end

function M.clear()
    for slot_type, _ in pairs(M.slots) do
        M.slots[slot_type] = { item_id = nil, amount = 0 }
    end
end

return M


-- local items_db = require("main.modules.data.items_db");
--
-- local M = {}
--
-- M.slots = {
--     HEAD = {item_id = nil, amount = 0},
--     CHEST = {item_id = nil, amount = 0},
--     LEGS = {item_id = nil, amount = 0},
--     WEAPON = {item_id = nil, amount = 0},
--     SHIELD = {item_id = nil, amount = 0}
-- }
--
-- function M.can_equip(item_type, slot_type)
--     if slot_type == "WEAPON" and item_type == "WEAPON" then return true end
--     if slot_type == "HEAD" and item_type == "HEAD" then return true end
--     return false
-- end
--
-- function M.can_equip_id(item_id, slot_type)
--     local cfg = items_db.get_item(item_id)
--     if not cfg then return false end
--     return M.can_equip(cfg.type, slot_type)
-- end
--
-- -- Экипировать
-- function M.equip(slot_type, item_data)
--     local old_item = M.slots[slot_type]
--     M.slots[slot_type] = item_data
--     return old_item -- возвращаем старую шмотку, чтобы положить её обратно в инвентарь
-- end
--
-- function M.get_save_data()
--     return M.slots
-- end
--
-- function M.load_save_data(data)
--     M.slots = data or {}
-- end
--
-- function M.clear()
--     for slot_type, _ in pairs(M.slots) do
--         M.slots[slot_type] = { item_id = nil, amount = 0 }
--     end
-- end
--
-- return M
