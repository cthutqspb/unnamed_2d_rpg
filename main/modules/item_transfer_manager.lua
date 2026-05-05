local M = {}

-- Обработчик дропа в мир
local function world_drop_handler(item_data, mouse_x, mouse_y)
    msg.post("world", "spawn_dropped_item", {
        item_id = item_data.item_id,
        amount = item_data.amount,
        mouse_x = mouse_x,
        mouse_y = mouse_y
    })
end

-- Основной метод трансфера
function M.transfer(from_component, from_slot, to_type, to_data, mouse_x, mouse_y)
    local from_data = from_component:get_data_source()
    local item_data = from_data.items[from_slot]
    
    if not item_data or not item_data.item_id then
        return false
    end
    
    if to_type == "world" then
        -- Дроп в мир
        world_drop_handler(item_data, mouse_x, mouse_y)
        from_data.items[from_slot] = {item_id = nil, amount = 0}
        from_component:refresh()
        return true
        
    elseif to_type == "inventory" then
        -- Перемещение в другой инвентарь
        local to_data = to_data
        if not to_data.items[to_data.slot].item_id then
            to_data.items[to_data.slot] = item_data
            from_data.items[from_slot] = {item_id = nil, amount = 0}
            from_component:refresh()
            to_data.component:refresh()
            return true
        end
    end
    
    return false
end

return M
