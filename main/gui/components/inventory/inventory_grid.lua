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

function InventoryGrid:on_input(action_id, action)
    -- Прокидываем координаты мыши в DragModule
    DragModule.on_input(self, action_id, action)
    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
    end
end

function InventoryGrid:refresh()
    local player_inv = require("main.modules.player_inventory")
    print("InventoryGrid:refresh called. Slots in this instance:", #self.slots)
    
    for i = 1, #self.slots do
        local data = player_inv.items[i]
        if data and data.item_id then
            print("Slot", i, "updating visual with:", data.item_id)
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

return InventoryGrid


