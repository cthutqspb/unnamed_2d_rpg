local component = require("druid.component")
local strings = require("main.modules.strings")
local InventoryGrid = require("main.gui.components.inventory.inventory_grid")

local Inventory = component.create("Inventory")

function Inventory:init(template_id, config)
    self.template_id = template_id
    config = config or {}
    local d = self:get_druid()

    self.root = gui.get_node(template_id .. "/root")
    self.header = gui.get_node(template_id .. "/header")
    self.btn_close = gui.get_node(template_id .. "/btn_close")
    self.container = gui.get_node(template_id .. "/container")  -- пустой контейнер

    self.inventory_grid = d:new(InventoryGrid, template_id .. "/inventory_grid", {
        data_source = config.data_source,
        columns = config.columns or 6,
        rows = config.rows or 4,
        item_size = config.item_size or 40,
        spacing = config.spacing or 2
    })

    local title_node = gui.get_node(template_id .. "/title")
    gui.set_text(title_node, strings.get("inventory_title"))
    
    local screen_w = sys.get_config("display.width")
    local screen_h = sys.get_config("display.height")
    local inv_size = gui.get_size(self.root)
    local target_x = screen_w - (inv_size.x / 2) - 20
    local target_y = 60 + (inv_size.y / 2)
      
    if config.bg_color then
        local bg_node = gui.get_node(self.template_id .. "/background") -- нода для фона
        if bg_node then
            gui.set_color(bg_node, config.bg_color)
        end
    end

    gui.set_position(self.root, vmath.vector3(target_x, target_y, 0))
        
    self.drag = d:new_drag(self.header, function(context, dx, dy)
        local pos = gui.get_position(self.root)
        pos.x = pos.x + dx
        pos.y = pos.y + dy
        gui.set_position(self.root, pos)
    end)
    self.drag.is_touch_threshold = true 
    
    d:new_button(self.btn_close, function()
        self:set_visible(false)
    end)
    self:refresh()
    msg.post("@render:", "acquire_input_focus")
end

function Inventory:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible and self.inventory_grid then
        self.inventory_grid:refresh()
    end
end

function Inventory:toggle()
    self:set_visible(not gui.is_enabled(self.root))
end

function Inventory:refresh()
    print("=== InventoryGrid:refresh called ===")
    if self.inventory_grid then
        self.inventory_grid:refresh()
    end
end

function Inventory:on_input(action_id, action)
    if self.inventory_grid then
        self.inventory_grid:on_input(action_id, action)
    end
end

function Inventory:get_slot_at_position(x, y)
    if self.inventory_grid then
        return self.inventory_grid:get_slot_at_position(x, y)
    end
    return nil
end

function Inventory:is_visible()
    return gui.is_enabled(self.root)
end

return Inventory
