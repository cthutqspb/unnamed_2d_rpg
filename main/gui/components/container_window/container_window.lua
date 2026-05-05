local ContainerWindow = {}
local gui_utils = require("main.gui.gui_utils")
local InventoryGrid = require("main.gui.components.inventory.inventory_grid")
local containers_state = require("main.modules.game_state.containers_state")

function ContainerWindow.new(druid, template_id, config)
    local self = {
        druid = druid,
        root = gui.get_node(template_id .. "/root"),
        grid = nil
    }
    
    -- Создаём грид
    -- local container_data = containers_state.get(config.container_id)
    
    self.grid = druid:new(InventoryGrid, template_id .. "/inventory_grid", {
        columns = config.columns,
        rows = config.rows,
        item_size = 48,
        spacing = 4
    })
    -- self.grid:refresh()
    -- Заголовок
    local title_node = gui.get_node(template_id .. "/title")
    gui.set_text(title_node, config.title or "Container")
    
    -- Кнопка закрытия
    local btn_close = gui.get_node(template_id .. "/btn_close")
    druid:new_button(btn_close, function()
        self:close()
    end)
    
    -- Кнопка "Забрать всё"
    local btn_take_all = gui.get_node(template_id .. "/btn_take_all")
    druid:new_button(btn_take_all, function()
        self:take_all()
    end)
    
    -- Позиция
    if config.position then
        gui.set_position(self.root, config.position)
    end
    
    gui.set_enabled(self.root, true)
    
    function self:set_visible(visible)
        gui.set_enabled(self.root, visible)
        if visible and self.grid then
            self.grid:refresh()
        end
    end

    function self:open(container_id, columns, rows, world_pos, player_pos)
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
        self:set_position(vmath.vector3(final_x, final_y, 0))
        self:set_visible(true)
    end
    
    function self:close()
        self:set_visible(false)
        msg.post("/gui_manager", "close_container_window")
    end
    
    function self:take_all()
        -- логика "забрать всё"
    end
    
    function self:set_data_source(data_source)
        self.grid:set_data_source(data_source)
        self.grid:refresh()
    end

    function self:set_position(position)
        gui.set_position(self.root, position)
    end
    
    return self
end

return ContainerWindow
