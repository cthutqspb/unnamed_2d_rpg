local settings = require("main.modules.data.settings")
local camera = require "orthographic.camera"

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


function M.clamp_to_screen(root_node, body_node, target_pos, offset_top, offset_bottom)
    offset_top = offset_top or 0
    offset_bottom = offset_bottom or 0

    -- 1. Размеры текущего окна и настройки проекта
    local window_w, window_h = window.get_size()
    local project_w = sys.get_config_int("display.width")
    local project_h = sys.get_config_int("display.height")

    -- 2. Считаем пропорции экрана и коэффициенты растяжения
    local project_aspect = project_w / project_h
    local current_aspect = window_w / window_h

    local stretch_factor_x = 1
    local stretch_factor_y = 1

    local screen_min_x = 0
    local screen_max_x = project_w
    local screen_min_y = 0
    local screen_max_y = project_h

    if current_aspect > project_aspect then
        -- Экран шире проекта (например, 21:9)
        stretch_factor_x = current_aspect / project_aspect
        local visual_w = project_w * stretch_factor_x
        local offset_x = (visual_w - project_w) / 2
        screen_min_x = -offset_x
        screen_max_x = project_w + offset_x
    else
        -- Экран уже проекта (4:5)
        stretch_factor_y = project_aspect / current_aspect
        local visual_h = project_h * stretch_factor_y
        local offset_y = (visual_h - project_h) / 2
        screen_min_y = -offset_y
        screen_max_y = project_h + offset_y
    end

    -- Применяем твои отступы к вертикальным границам экрана
    screen_min_y = screen_min_y + offset_bottom
    screen_max_y = screen_max_y - offset_top

    -- 3. Вычисляем физический размер тела окна (body)
    local body_size = gui.get_size(body_node)
    local body_scale = gui.get_scale(body_node)
    local win_w = body_size.x * body_scale.x
    local win_h = body_size.y * body_scale.y

    -- 4. Считаем границы с учетом Pivot (по умолчанию Center для root)
    local half_w = win_w / 2
    local half_h = win_h / 2

    local min_x = screen_min_x + half_w
    local max_x = screen_max_x - half_w
    local min_y = screen_min_y + half_h
    local max_y = screen_max_y - half_h

    -- ВАЖНО: Если у твоих окон Pivot у root всегда Corner/SouthWest, 
    -- раскомментируй эти 4 строки ниже, а 4 строки выше — удали:
    -- local min_x = screen_min_x
    -- local max_x = screen_max_x - win_w
    -- local min_y = screen_min_y
    -- local max_y = screen_max_y - win_h

    -- 5. Возвращаем заклампленный вектор позиции
    local final_pos = vmath.vector3(target_pos)
    final_pos.x = math.max(min_x, math.min(final_pos.x, max_x))
    final_pos.y = math.max(min_y, math.min(final_pos.y, max_y))

    return final_pos, stretch_factor_x, stretch_factor_y
end


-- function M.clamp_to_screen(node, new_pos, margin_x, margin_y)
--     -- Если передали только margin_x, используем его для всех сторон
--     margin_x = margin_x or 0
--     margin_y = margin_y or margin_x
--
--     local sw = gui.get_width()
--     local sh = gui.get_height()
--
--     local size = gui.get_size(node)
--     local scale = gui.get_scale(node)
--
--     local w = size.x * scale.x
--     local h = size.y * scale.y
--
--     -- Для Pivot: Center
--     local hw = w / 2
--     local hh = h / 2
--
--     -- Ограничение по горизонтали (X)
--     if new_pos.x - hw < margin_x then
--         new_pos.x = hw + margin_x
--     elseif new_pos.x + hw > sw - margin_x then
--         new_pos.x = sw - hw - margin_x
--     end
--
--     -- Ограничение по вертикали (Y)
--     if new_pos.y - hh < margin_y then
--         new_pos.y = hh + margin_y
--     elseif new_pos.y + hh > sh - margin_y then
--         new_pos.y = sh - hh - margin_y
--     end
--
--     return new_pos
-- end

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

-- Внутри main/modules/interaction.lua

---Перевести физические координаты клика мыши из on_input в точные мировые координаты пространства игры
---@param action table Таблица инпута из on_input (содержит action.x и action.y)
---@param player_pos vector3 Текущая позиция игрока go.get_position("player")
---@return vector3 Идеальный вектор мировых координат для рейкаста, устойчивый к 2K и тайлингу
function M.get_world_mouse_pos(action, player_pos)
    -- 1. Получаем РЕАЛЬНЫЙ физический размер окна в пикселях на мониторе прямо сейчас
    local window_w, window_h = window.get_size()
    
    -- 2. Жесткие логические размеры твоего проекта (из game.project / settings)
    local target_w = 1920
    local target_h = 1080

    -- 3. Считаем коэффициенты масштабирования (пропорции сжатия/растяжения)
    local scale_x = target_w / window_w
    local scale_y = target_h / window_h

    -- 4. Переводим физический клик мыши в логические пиксели игры пространства 1920x1080
    local logic_mouse_x = action.x * scale_x
    local logic_mouse_y = action.y * scale_y

    -- 5. Находим логический центр игрового экрана
    local cx = target_w / 2
    local cy = target_h / 2

    -- 6. Считаем финальный вектор относительно позиции игрока
    local world_x = player_pos.x + (logic_mouse_x - cx)
    local world_y = player_pos.y + (logic_mouse_y - cy)

    return vmath.vector3(world_x, world_y, 0)
end

--- Трансформирует экранные координаты клика/мыши под нужды GUI и игрового мира.
---@param action table Таблица action из on_input
---@param camera_id hash ID вашей камеры (например, hash("/camera"))
---@return vmath.vector3 gui_pos Координаты, скорректированные под сетку проекта (X и Y)
---@return vmath.vector3 world_pos Точные мировые координаты для рейкастов
function M.transform_coordinates(action, camera_id)
    -- 1. Защита, если это инпут без координат экрана
    if not action.screen_x then
        return vmath.vector3(0, 0, 0), vmath.vector3(0, 0, 0)
    end

    -- 2. Получаем размеры
    local window_w, window_h = window.get_size()
    local project_w = sys.get_config_int("display.width")
    local project_h = sys.get_config_int("display.height")

    -- 3. Расчет для GUI
    local scale_x = window_w / project_w
    local scale_y = window_h / project_h
    local gui_pos = vmath.vector3(action.screen_x / scale_x, action.screen_y / scale_y, 0)

    -- 4. Расчет для игрового мира
    local view = camera.get_view(camera_id)
    local projection = camera.get_projection(camera_id)
    local inv = vmath.inv(projection * view)
    
    local norm_x = (action.screen_x / window_w) * 2 - 1
    local norm_y = (action.screen_y / window_h) * 2 - 1
    
    local vec = inv * vmath.vector4(norm_x, norm_y, 0, 1)
    local world_pos = vmath.vector3(vec.x / vec.w, vec.y / vec.w, 0)

    return gui_pos, world_pos
end

return M
