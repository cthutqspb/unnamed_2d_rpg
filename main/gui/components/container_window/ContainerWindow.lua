local component = require("druid.component")
local constants_ui = require("main.gui.constants_ui")
local BaseWindow = require("main.gui.components.base_window.base_window")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")
local InventoryModel = require("main.modules.inventory_model")
local containers_state = require("main.modules.game_state.containers_state")
local interaction_manager = require("main.modules.logic.interaction_manager")
local gui_utils = require("main.gui.gui_utils")

---@class ContainerWindow : druid.component
---@field root node
---@field body node
---@field window_title node
local M = component.create("ContainerWindow")

local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

function M:init(template_id, config)
    self.template_id = template_id
    local d = self:get_druid()
    

    self.render_order = constants_ui.LAYERS.LOOT -- 30
    self.is_static = false

    -- Создаём вложенный грид инвентаря
    self.static_grid = d:new(StaticGrid, get_id(template_id, "static_grid"), {
        columns = config.columns or 6,
        rows = config.rows or 4,
        item_size = config.item_size or 48,
        spacing = config.spacing or 4,
        on_double_click = function(index, item)
            -- Мы находимся в контексте CharacterWindow
            -- Просто шлем сообщение самому себе (в скрипт, где лежит CharacterWindow)
            msg.post(".", "item_action", {
                event = "loot_item",
                data = {
                    slot_index = index,
                    item_id = item.item_id
                }
            })
        end
    })

    BaseWindow.init(self, template_id, {
        on_show = function ()
            self.static_grid:refresh()
            interaction_manager.set_focus(self.static_grid:get_data_source())
        end,
        on_hide = function ()
            interaction_manager.clear_focus()
        end
    })

    -- Инициализация нод
    self.btn_take_all = gui.get_node("btn_take_all")

    self.toggle = BaseWindow.toggle
    self.is_visible = BaseWindow.is_visible
    self.set_visible = BaseWindow.set_visible
    self.close = BaseWindow.close
    self.set_title  = BaseWindow.set_title
    self.update = BaseWindow.update
    self.request_refresh = BaseWindow.request_refresh
    self.is_over_window = BaseWindow.is_over_window
    self.handle_hover = BaseWindow.handle_hover
    -- self.take_all = M.take_all

    -- Кнопк
    -- d:new_button(self.btn_close, self.close)
    d:new_button(self.btn_take_all, self:take_all())

    -- Начальные настройки
    -- gui.set_text(self.title, config.title or "Container")
    self.set_title(self, config.title or "Container")

    self.modules = {
        self.static_grid
    }

    self:set_visible(false)
end

function M:open(container_uid, container_id, columns, rows, world_pos, player_pos)
    self.uid = container_uid
    local container_data = containers_state.get(container_uid)
    if not container_data then
        print("ERROR: Container state not found")
        return
    end

    -- 1. Устанавливаем данные
    local model = InventoryModel.wrap(container_data)

    model.max_slots = columns * rows
    self:set_data_source(model)

    -- 2. Вычисляем позицию
    local screen_x, screen_y = gui_utils.world_to_screen(world_pos, player_pos)
    local window_w = columns * (48 + 4) - 4
    local window_h = rows * (48 + 4) - 4

    local offset_x, offset_y = 50, 50
    local final_x = screen_x + offset_x
    local final_y = screen_y + offset_y

    -- Проверка границ экрана (1920x1080)
    if final_x + window_w > 1920 then
        final_x = math.floor(screen_x - window_w - offset_x)
    end
    if final_y + window_h > 1080 then
        final_y = math.floor(screen_y - window_h - offset_y)
    end

    -- 3. Показываем
    gui.set_position(self.root, vmath.vector3(final_x, final_y, 0))
end

function M:take_all()
    print("Take all logic for:", self.template_id) -- Используем self
    -- Тут будет логика
end

function M:set_data_source(data_source)
    self.static_grid:set_data_source(data_source)
end

function M:get_slot_at_position(x, y)
    return self.static_grid:get_slot_at_position(x, y)
end

function M:refresh_all()
    self.static_grid:refresh()
end

return M
