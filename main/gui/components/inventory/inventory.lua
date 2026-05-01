local player_inv = require("main.modules.player_inventory")
local component = require("druid.component")
local static_grid = require("druid.base.static_grid")
local strings = require("main.modules.strings")
local items_db = require("main.modules.items_db")
local DragModule = require("main.gui.components.inventory.inventory_drag")

local Inventory = component.create("Inventory")

function Inventory:init(template_id)
    self.template_id = template_id
    local d = self:get_druid()

    self.root = gui.get_node(template_id .. "/root")
    self.header = gui.get_node(template_id .. "/header")
    self.btn_close = gui.get_node(template_id .. "/btn_close")
    self.container = gui.get_node(template_id .. "/container")
    
    -- Шаблон для клонирования (должен быть Box с размерами 40x40)
    self.drag_template = gui.get_node(template_id .. "/drag_icon")
    self.drag_clone = nil
    
    -- Для хранения координат мыши
    self.mouse_x = 0
    self.mouse_y = 0

    local title_node = gui.get_node(template_id .. "/title")
    gui.set_text(title_node, strings.get("inventory_title"))
    
    self.columns = 6
    self.rows = 4
    self.item_size = 40
    self.spacing = 4

    self.grid = d:new(static_grid, self.container, template_id .. "/slot_prefab/root", self.columns)
    self.grid:set_item_size(self.item_size + self.spacing, self.item_size + self.spacing) 
    self.grid:set_anchor(vmath.vector3(0, 1, 0))

    -- self.items_data = {}
    self.dragging_index = nil
    
    DragModule.create_slots(self)
    
    local screen_w = sys.get_config("display.width")
    local screen_h = sys.get_config("display.height")
    local inv_size = gui.get_size(self.root)
    local target_x = screen_w - (inv_size.x / 2) - 20
    local target_y = 60 + (inv_size.y / 2)
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
    
    -- Получаем фокус ввода для мыши
    msg.post("@render:", "acquire_input_focus")
    
    -- Скрываем шаблон
    if self.drag_template then
        gui.set_enabled(self.drag_template, false)
    end    
    
    self:refresh()
    DragModule.init(self, d)
end

-- Получение координат мыши
function Inventory:on_input(action_id, action)
    DragModule.on_input(self, action_id, action)
    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
    end
end

function Inventory:set_visible(is_visible)
    gui.set_enabled(self.root, is_visible)
end

function Inventory:toggle()
    local current = gui.is_enabled(self.root)
    self:set_visible(not current)
end

function Inventory:refresh()
    -- Если ты не хочешь переписывать всё на InventoryGrid, 
    -- просто вызови обновление визуалов для этого компонента
    for i = 1, #self.slots do
        local data = player_inv.items[i]
        if data and data.item_id then
            DragModule.update_slot_visual(self, i, data.item_id, data.amount)
        else
            DragModule.clear_slot_visual(self, i)
        end
    end
end

return Inventory

