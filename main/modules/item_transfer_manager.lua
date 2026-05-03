-- main.modules.item_transfer_manager.lua
local M = {}

-- Сервис для безопасного перемещения предметов между контейнерами
local function transfer_item(from_container, from_slot, to_container, to_slot)
    local item = from_container:get_item(from_slot)
    if not item or not item.item_id then return false end
    
    -- Проверяем, можно ли положить в целевой слот
    if to_container:can_accept_item(to_slot, item) then
        -- Забираем предмет
        local taken_item = from_container:take_item(from_slot)
        -- Кладем в новый слот
        local success = to_container:place_item(to_slot, taken_item)
        
        if not success then
            -- Если не удалось положить, возвращаем на место
            from_container:place_item(from_slot, taken_item)
            return false
        end
        
        return true
    end
    
    return false
end

-- Создает коллбэк для дропа, который обрабатывает передачу
function M.create_drop_handler(from_container, from_slot)
    return function(to_container, to_slot)
        return transfer_item(from_container, from_slot, to_container, to_slot)
    end
end

return M
