local M = {}

function M.world_to_screen(world_pos, ref_pos)
    local screen_w = sys.get_config("display.width") or 1920
    local screen_h = sys.get_config("display.height") or 1080
    
    local screen_x = (world_pos.x - ref_pos.x) + screen_w / 2
    local screen_y = (world_pos.y - ref_pos.y) + screen_h / 2
    
    return screen_x, screen_y
end

-- function M.screen_to_world(screen_x, screen_y)
--     local camera_pos = go.get_position("camera")
--     local screen_w = sys.get_config("display.width") or 1920
--     local screen_h = sys.get_config("display.height") or 1080
--     
--     local world_x = screen_x + camera_pos.x - screen_w / 2
--     local world_y = screen_y + camera_pos.y - screen_h / 2
--     
--     return vmath.vector3(world_x, world_y, 0)
-- end

function M.get_screen_position(node)
    local x, y = 0, 0
    local current = node
    
    while current do
        local pos = gui.get_position(current)
        x = x + pos.x
        y = y + pos.y
        current = gui.get_parent(current)
    end
    
    return x, y
end

function M.layout_horizontal(parent_node, button_names, spacing)
    local current_x = 0
    local max_height = 0
    
    -- Сначала определяем максимальную высоту
    for _, btn_name in ipairs(button_names) do
        local btn = gui.get_node(parent_node .. "/" .. btn_name)
        local size = gui.get_size(btn)
        if size.y > max_height then
            max_height = size.y
        end
    end
    
    -- Расставляем кнопки
    for _, btn_name in ipairs(button_names) do
        local btn = gui.get_node(parent_node .. "/" .. btn_name)
        local size = gui.get_size(btn)
        
        gui.set_position(btn, vmath.vector3(current_x, -max_height/2, 0))
        current_x = current_x + size.x + spacing
    end
end

-- Новая функция, которая принимает ноду, а не строку
function M.layout_horizontal_by_node(parent_node, button_nodes, spacing)
    local current_x = 0
    local max_height = 0
    
    for _, btn in ipairs(button_nodes) do
        local size = gui.get_size(btn)
        if size.y > max_height then
            max_height = size.y
        end
    end
    
    for _, btn in ipairs(button_nodes) do
        local size = gui.get_size(btn)
        gui.set_position(btn, vmath.vector3(current_x, -max_height/2, 0))
        current_x = current_x + size.x + spacing
    end
end

return M
