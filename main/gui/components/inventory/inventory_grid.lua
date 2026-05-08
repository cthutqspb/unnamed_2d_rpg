local items_db = require("main.modules.items_db")
local component = require("druid.component")
local static_grid = require("druid.base.static_grid")
-- Модуль драга теперь один для всех инвентарей
local DragModule = require("main.gui.components.inventory.inventory_drag")

local InventoryGrid = component.create("InventoryGrid")

function InventoryGrid:init(template_id, config)
    self.template_id = template_id
    config = config or {}
    local d = self:get_druid()
      
    self.data_source = config.data_source
    -- Ищем стандартные ноды внутри любого переданного шаблона
    self.root = gui.get_node(template_id .. "/root")
    self.container = gui.get_node(template_id .. "/container")
    self.drag_template = gui.get_node(template_id .. "/drag_icon")
    
    -- Конфигурация сетки
    self.columns = config.columns or 6
    self.rows = config.rows or 4
    self.item_size = config.item_size or 40
    self.spacing = config.spacing or 4

    -- Инициализация Druid Grid
    -- Использует слот-префаб, который ДОЛЖЕН быть в каждом .gui файле инвентаря
    self.grid = d:new(static_grid, self.container, template_id .. "/slot_prefab/root", self.columns)
    self.grid:set_item_size(self.item_size + self.spacing, self.item_size + self.spacing)
    self.grid:set_anchor(vmath.vector3(0, 1, 0))

    self.items_data = {}
    self.mouse_x = 0
    self.mouse_y = 0

    -- Оживляем слоты через твой DragModule
    -- Мы передаем "self", чтобы модуль знал, в какой именно инвентарь (этот или сундука) мы кликаем
    DragModule.create_slots(self)
    DragModule.init(self, d)

    if self.drag_template then
        gui.set_enabled(self.drag_template, false)
    end

end

function InventoryGrid:set_data_source(data_source)
    self.data_source = data_source
    self:refresh()
end

function InventoryGrid:get_data_source()
    if self.data_source then
        return self.data_source
    end
    -- По умолчанию - инвентарь игрока
    return require("main.modules.player_inventory")
end

function InventoryGrid:get_slot_at_position(x, y)
    return DragModule.get_slot_at_position(self, x, y)
end

function InventoryGrid:on_input(action_id, action)
    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
        -- Прокидываем в DragModule, чтобы он знал актуальные координаты
        DragModule.on_input(self, action_id, action)
    end
end

function InventoryGrid:is_mouse_over_any_gui(x, y)
    return DragModule.is_mouse_over_any_gui(self, x, y)
end

function InventoryGrid:refresh()
    local data_source = self.data_source
    
    for i = 1, #self.slots do
        local data = data_source.items[i]
        if data and data.item_id then
            DragModule.update_slot_visual(self, i, data.item_id, data.amount)
        else
            -- Если предмет выкинули, мы должны попасть сюда
            DragModule.clear_slot_visual(self, i)
        end
    end 
end

function InventoryGrid:set_visible(visible)
    gui.set_enabled(self.root, visible)
end

function InventoryGrid:on_drop(x, y)
    -- Ищем слот через DragModule
    local slot_index = self:get_slot_at_position(x, y)
    
    if slot_index then
        local drag_manager = require("main.gui.drag_manager")
        print("InventoryGrid [" .. self.template_id .. "]: Drop into slot", slot_index)
        drag_manager.finish(self, slot_index)
        return true -- Мы обработали дроп
    end
    
    return false -- Мышь была не над этой сеткой
end

return InventoryGrid


