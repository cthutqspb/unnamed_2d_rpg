local settings = require("main.modules.data.settings")

local M = {}

function M.world_to_screen(world_pos, ref_pos)
    local screen_w, screen_h = settings.get_center()

    local screen_x = (world_pos.x - ref_pos.x) + screen_w
    local screen_y = (world_pos.y - ref_pos.y) + screen_h

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
        x = x + math.floor(pos.x)
        y = y + math.floor(pos.y)
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
            max_height = math.floor(size.y)
        end
    end

    -- Расставляем кнопки
    for _, btn_name in ipairs(button_names) do
        local btn = gui.get_node(parent_node .. "/" .. btn_name)
        local size = gui.get_size(btn)

        gui.set_position(btn, vmath.vector3(current_x, -max_height/2, 0))
        current_x = current_x + math.floor(size.x) + spacing
    end
end

-- Новая функция, которая принимает ноду, а не строку
function M.layout_horizontal_by_node(parent_node, button_nodes, spacing)
    local current_x = 0
    local max_height = 0

    for _, btn in ipairs(button_nodes) do
        local size = gui.get_size(btn)
        if size.y > max_height then
            max_height = math.floor(size.y)
        end
    end

    for _, btn in ipairs(button_nodes) do
        local size = gui.get_size(btn)
        gui.set_position(btn, vmath.vector3(current_x, -max_height/2, 0))
        current_x = current_x + math.floor(size.x) + spacing
    end
end

function M.clamp_to_screen(node, new_pos, margin_x, margin_y)
    -- Если передали только margin_x, используем его для всех сторон
    margin_x = margin_x or 0
    margin_y = margin_y or margin_x

    local sw = gui.get_width()
    local sh = gui.get_height()

    local size = gui.get_size(node)
    local scale = gui.get_scale(node)

    local w = size.x * scale.x
    local h = size.y * scale.y

    -- Для Pivot: Center
    local hw = w / 2
    local hh = h / 2

    -- Ограничение по горизонтали (X)
    if new_pos.x - hw < margin_x then
        new_pos.x = hw + margin_x
    elseif new_pos.x + hw > sw - margin_x then
        new_pos.x = sw - hw - margin_x
    end

    -- Ограничение по вертикали (Y)
    if new_pos.y - hh < margin_y then
        new_pos.y = hh + margin_y
    elseif new_pos.y + hh > sh - margin_y then
        new_pos.y = sh - hh - margin_y
    end

    return new_pos
end

function M.is_input_over_window(window_root, action_id, action)
    if not action.x or not action.y then return false end
    if not gui.is_enabled(window_root, true) then return false end
    
    if gui.pick_node(window_root, action.x, action.y) then
        -- Если это просто движение мыши, не блокируем (для тултипов)
        if not action_id then return false end
        return true
    end
    return false
end

-- Внутри main/gui/gui_utils.lua

---Перевести экранные координаты мыши в точные мировые координаты пространства игры.
---Идеально работает на 2K, FullHD и при экстремальном тайлинге Hyprland (например, 200x1000).
---@param mx number Физическая координата мыши X (экран)
---@param my number Физическая координата мыши Y (экран)
---@param player_pos vector3 Текущая позиция игрока
---@return vector3 Идеальный вектор мировых координат для рейкаста
function M.get_world_mouse_pos(mx, my, player_pos)
    local window_w, window_h = window.get_size()
    
    -- Логическая высота твоего проекта из настроек (1080)
    local target_h = 1080

    -- 1. Вычисляем коэффициент масштабирования строго по ВЫСОТЕ окна.
    -- В стандартном Fixed Fit рендере Defold высота всегда диктует масштаб, 
    -- а ширина просто обрезается или расширяется!
    local zoom = window_h / target_h
    if zoom <= 0 then zoom = 1 end

    -- 2. Находим текущий физический центр окна операционной системы прямо сейчас
    local window_cx = window_w / 2
    local window_cy = window_h / 2

    -- 3. Считаем смещение курсора мыши относительно физического центра окна
    local screen_offset_x = mx - window_cx
    local screen_offset_y = my - window_cy

    -- 4. Переводим это смещение в логические пиксели игрового мира, разделив на zoom
    local world_offset_x = screen_offset_x / zoom
    local world_offset_y = screen_offset_y / zoom

    -- 5. Прибавляем смещение к текущей позиции игрока (так как камера центрирована на нём)
    local world_x = player_pos.x + world_offset_x
    local world_y = player_pos.y + world_offset_y

    return vmath.vector3(world_x, world_y, 0)
end




return M
