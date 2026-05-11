local gui_utils = require("main.gui.gui_utils")
local InventoryGrid = require("main.gui.components.inventory_grid.inventory_grid")
local containers_state = require("main.modules.game_state.containers_state")

local M = {}

local function get_id(template_id, node_name)
    if not template_id or template_id == "" then 
        return node_name 
    end
    return template_id .. "/" .. node_name
end

function M.new(druid, template_id, config)

    local self = {
        druid = druid,
        template_id = template_id, -- Сохраняем для истории
        -- Передаем template_id в get_id
        root = gui.get_node(get_id(template_id, "root")),
        body = gui.get_node(get_id(template_id, "body")),
        header = gui.get_node(get_id(template_id, "header")),
        btn_close = gui.get_node(get_id(template_id, "btn_close")),
        title = gui.get_node(get_id(template_id, "title")),
        btn_take_all = gui.get_node(get_id(template_id, "btn_take_all")),
    }
    
    -- Создаём грид
    -- local container_data = containers_state.get(config.container_id)
    
    self.inventory_grid = druid:new(InventoryGrid, get_id(template_id, "inventory_grid"), {
        columns = config.columns,
        rows = config.rows,
        item_size = config.item_size,
        spacing = config.spacing
    })
     -- Заголовок для драга (header должен иметь Manual size и покрывать всю верхнюю часть)
    self.drag = druid:new_drag(self.header, function(_, dx, dy)
        local pos = gui.get_position(self.root)
        local target_pos = vmath.vector3(pos.x + dx, pos.y + dy, 0)
        -- Ограничиваем target_pos по размерам ноды body
        local final_pos = gui_utils.clamp_to_screen(self.body, target_pos, 0, 20)
        gui.set_position(self.root, final_pos)    
    end)
    -- Чтобы драг не конфликтовал с кнопками на хедере
    self.drag.is_touch_threshold = true
    
    self.open = M.open
    self.close = M.close
    self.take_all = M.take_all
    self.set_data_source = M.set_data_source
    self.set_position = M.set_position
    self.get_slot_at_position = M.get_slot_at_position
    self.is_visible = M.is_visible
    self.set_visible = M.set_visible

    -- Заголовок
    gui.set_text(self.title, config.title or "Container")
    
    -- Кнопка закрытия
    druid:new_button(self.btn_close, function()
        self:close()
    end)
    
    -- Кнопка "Забрать всё"
    druid:new_button(self.btn_take_all, function()
        self:take_all()
    end)
    
    -- Позиция
    if config.position then
        gui.set_position(self.root, config.position)
    end
    
    gui.set_enabled(self.root, true)
        
    return self
end

function M:open(container_id, columns, rows, world_pos, player_pos)
    local container_data = containers_state.get(container_id)
    if not container_data then
        print("ERROR: Container state not found")
        return
    end
    -- 1. Устанавливаем данные
    self:set_data_source({
        items = container_data.items,
        max_slots = columns * rows
    })
    
    -- 2. Вычисляем позицию
    local screen_x, screen_y = gui_utils.world_to_screen(world_pos, player_pos)
    local window_w = columns * (48 + 4) - 4
    local window_h = rows * (48 + 4) - 4
    
    local offset_x = 50
    local offset_y = 50
    local final_x = screen_x + offset_x
    local final_y = screen_y + offset_y
    
    if final_x + window_w > 1920 then
        final_x = screen_x - window_w - offset_x
    end
    if final_y + window_h > 1080 then
        final_y = screen_y - window_h - offset_y
    end
    
    -- 3. Устанавливаем позицию и показываем
    print("Setting container position to:", final_x, final_y)

    self:set_position(vmath.vector3(final_x, final_y, 0))
    self:set_visible(true)
end

function M:close()
    self:set_visible(false)
end

function M:take_all()
  -- логика "забрать всё"
end

function M:set_data_source(data_source)
    self.inventory_grid:set_data_source(data_source)
    self.inventory_grid:refresh()
end

function M:set_position(position)
    gui.set_position(self.root, position)
end 

function M:get_slot_at_position(x, y)
    if self.inventory_grid then
        return self.inventory_grid:get_slot_at_position(x, y)
    end
    return nil
end

function M:is_visible()
    return gui.is_enabled(self.root)
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible and self.inventory_grid then
        self.inventory_grid:refresh()
    end
end

return M
