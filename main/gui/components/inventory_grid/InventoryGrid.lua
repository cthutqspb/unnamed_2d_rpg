local tooltip_manager = require("main.gui.components.managers.tooltip_manager")
local drag_manager = require("main.gui.components.managers.drag_manager")
local component = require("druid.component")
local static_grid = require("druid.base.static_grid")
-- Модуль драга теперь один для всех инвентарей
local DragModule = require("main.gui.components.inventory_grid.inventory_drag")

---@class InventoryGrid : druid.component
---@field slots table
local M = component.create("InventoryGrid")

function M:init(template_id, config)
    config = config or {}
    local d = self:get_druid()

    -- Группа: Базовые настройки
    self.template_id = template_id
    self.data_source = config.data_source
    self.columns     = config.columns or 6
    self.rows        = config.rows or 4

    -- Группа: Визуал
    self.item_size   = config.item_size or 40
    self.spacing     = config.spacing or 4
    self.root        = gui.get_node(template_id .. "/root")
    self.container   = gui.get_node(template_id .. "/container")

    -- Группа: Состояние
    self.slots       = {}
    self.mouse_x     = 0
    self.mouse_y     = 0

    self.items_data  = {}
    self.drag_template = gui.get_node(template_id .. "/drag_icon")

    -- Инициализация сложных систем
    self:init_grid(d, template_id)

    DragModule.create_slots(self)
    DragModule.init(self)

    if self.drag_template then
        gui.set_enabled(self.drag_template, false)
    end
end

function M:init_grid(d, template_id)
    self.grid = d:new(static_grid, self.container, template_id .. "/slot_prefab/root", self.columns)
    self.grid:set_item_size(self.item_size + self.spacing, self.item_size + self.spacing)
    self.grid:set_anchor(vmath.vector3(0, 1, 0))
end

function M:set_data_source(data_source)
    self.data_source = data_source
    self:refresh()
end

function M:get_data_source()
    if self.data_source then
        return self.data_source
    end
    -- По умолчанию - инвентарь игрока
    return require("main.modules.player.player_inventory")
end

function M:get_slot_at_position(x, y)
    return DragModule.get_slot_at_position(self, x, y)
end

function M:on_input(action_id, action)
    -- Ловим Shift прямо внутри компонента инвентаря
    if action_id == hash("key_lshift") then
        if action.pressed then
            self.is_shift_pressed = true
        elseif action.released then
            self.is_shift_pressed = false
        end
        return false -- Возвращаем false, чтобы не блокировать инпут другим окнам
    end

    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
        -- Прокидываем в DragModule, чтобы он знал актуальные координаты
        DragModule.on_input(self, action_id, action)
    end
end

function M:refresh()
    local data_source = self:get_data_source()
    if not data_source or not data_source.items then
        print("Warning: InventoryGrid has no data_source during refresh")
        return
    end

    for i = 1, #self.slots do
        local data = data_source:get_item(i)
        if data and data.item_id then
            DragModule.update_slot_visual(self, i, data.item_id, data.amount)
        else
            -- Если предмет выкинули, мы должны попасть сюда
            DragModule.clear_slot_visual(self, i)
        end
    end
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
end

function M:on_drop(x, y)
    if not gui.is_enabled(self.root) then
        return false
    end

    -- Ищем слот через DragModule
    local slot_index = self:get_slot_at_position(x, y)

    if slot_index then
        print("InventoryGrid [" .. self.template_id .. "]: Drop into slot", slot_index)
        drag_manager.finish(self, slot_index)
        return true -- Мы обработали дроп
    end

    return false -- Мышь была не над этой сеткой
end

function M:update_hover(mx, my)
    -- 1. Жесткая проверка: готов ли компонент
    if not self.root or not gui.is_enabled(self.root, true) then
        return false
    end

    if drag_manager.is_dragging() then
        tooltip_manager.hide()
        return false
    end

    local over_any_slot = false
    -- 2. Инвентарь — это массив, используем ipairs
    for i, slot_nodes in ipairs(self.slots) do
        if gui.pick_node(slot_nodes.root, mx, my) then
            local item_data = self:get_data_source().items[i]

            -- Если слот пустой (item_id == nil), просто прячем тултип
            if item_data and item_data.item_id then
                tooltip_manager.show("item", item_data.item_id)
            else
                tooltip_manager.hide()
            end
            over_any_slot = true
            break
        end
    end
    return over_any_slot
end

return M


