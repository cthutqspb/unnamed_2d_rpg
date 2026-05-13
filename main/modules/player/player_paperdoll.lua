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

-- function M.clear()
--     print('Сбросили папердолл')
-- end

-- function M.get_save_data()
--     local data = {}
--     -- Используем pairs для словаря (HEAD, CHEST...)
--     for slot_name, item in pairs(M.slots) do
--         if item.item_id then
--             data[slot_name] = {
--                 id = tostring(item.item_id), -- хеш "[hash: sword]" -> "sword" (если это был hash("sword"))
--                 amount = item.amount
--             }
--         else
--             data[slot_name] = { id = nil, amount = 0 }
--         end
--     end
--     return data
-- end
--
-- function M.load_save_data(data)
--     -- Важно: чистим текущие слоты перед загрузкой
--     for slot_name, _ in pairs(M.slots) do
--         local saved_item = data[slot_name]
--         if saved_item and saved_item.id then
--             M.slots[slot_name] = {
--                 item_id = hash(saved_item.id),
--                 amount = saved_item.amount
--             }
--         else
--             M.slots[slot_name] = { item_id = nil, amount = 0 }
--         end
--     end
-- end

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
