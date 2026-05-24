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
    local slot = self.slots[slot_type]
    -- Если в слоте нет ID, возвращаем nil, чтобы было удобно писать:
    -- if paperdoll:get_item("head") then ...
    if not slot or not slot.item_id then
        return nil
    end
    return slot
end


function M:set_item(slot_type, item_data)
    if not item_data or not item_data.item_id then
        -- Если снимаем предмет, зачищаем слот полностью
        self.slots[slot_type] = { item_id = nil, amount = 0, uid = nil }
    else
        -- Если надеваем, копируем только нужные поля
        self.slots[slot_type] = {
            item_id = item_data.item_id,
            amount = item_data.amount or 1,
            uid = item_data.uid -- Передаем паспорт предмета в куклу
        }
    end
end

-- ВАЛИДАЦИЯ
function M:can_equip_item(item, slot_type)
    -- item — это { item_id = hash("..."), amount = 1, uid = "..." }
    if not item or not item.item_id then return false end

    local cfg = items_db.get_item(item.item_id)
    if not cfg then return false end

    -- 1. Проверка соответствия слота (из БД)
    if cfg.equip_slot ~= slot_type then
        return false
    end

    -- 2. Проверка требований (передаем item целиком на будущее)
    -- Даже если сейчас там только item_id, завтра ты добавишь проверку прочности по uid
    local check = item_requirements_manager.check(cfg, character_data.player, item)
    
    if not check.is_ok then
        -- Выводим причину, если нужно (например, в HUD)
        print("CANNOT EQUIP: " .. (check.reason or "low stats"))
        return false
    end

    return true
end

-- СИСТЕМНЫЕ МЕТОДЫ
function M.get_save_data()
    return M.slots
end

function M.load_save_data(data)
    if not data then return end
    
    -- Вместо прямой замены M.slots = data, лучше обновить значения, 
    -- чтобы не потерять мета-таблицы или ссылки, если они есть.
    for slot_type, slot_data in pairs(data) do
        if M.slots[slot_type] then
            M.slots[slot_type].item_id = slot_data.item_id
            M.slots[slot_type].amount = slot_data.amount or 0
            M.slots[slot_type].uid = slot_data.uid -- Восстанавливаем паспорт
        end
    end
end

function M.clear()
    for slot_type, _ in pairs(M.slots) do
        -- Обнуляем всё, включая UID
        M.slots[slot_type] = { item_id = nil, amount = 0, uid = nil }
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
