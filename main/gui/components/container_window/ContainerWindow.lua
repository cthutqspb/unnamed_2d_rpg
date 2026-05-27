local locales = require("main.modules.data.locales.locale_manager")
local component = require("druid.component")
local constants_ui = require("main.gui.constants_ui")
local BaseWindow = require("main.gui.components.base_window.base_window")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")
local InventoryModel = require("main.modules.inventory_model")
local containers_state = require("main.modules.game_state.containers_state")
local interaction_manager = require("main.modules.logic.interaction_manager")
local gui_utils = require("main.gui.gui_utils")

---@class ContainerWindow : druid.component
---@field template_id string
---@field static_grid StaticGrid
---@field btn_take_all node
---@field btn_take_all_text_node node 
---@field uid string|nil
---@field root node   --- ДОБАВЛЯЕМ СЮДА, чтобы убрать ошибку в M:open
---@field body node   --- До кучи, если используешь в проверках координат
local M = component.create("ContainerWindow")

---@private
---@param template_id string
---@param node_name string
---@return string
local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

---@param template_id string
---@param config table
function M:init(template_id, config)
    self.template_id = template_id
    local d = self:get_druid()

    self.render_order = constants_ui.LAYERS.LOOT -- 30
    self.is_static = false

    -- Создаём вложенный грид инвентаря
    self.static_grid = d:new(StaticGrid, get_id(template_id, "static_grid"), {
        columns = config.columns or 6,
        rows = config.rows or 4,
        item_size = config.item_size or 40,
        spacing = config.spacing or 2,
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
    self.btn_take_all_text_node = gui.get_node("btn_take_all_text")
    gui.set_text(self.btn_take_all_text_node, locales.get("btn_take_all"))

    -- Привязываем методы базового окна
    self.toggle = BaseWindow.toggle
    self.is_visible = BaseWindow.is_visible
    self.set_visible = BaseWindow.set_visible
    self.close = BaseWindow.close
    self.set_title  = BaseWindow.set_title
    self.update = BaseWindow.update
    self.request_refresh = BaseWindow.request_refresh
    self.is_over_window = BaseWindow.is_over_window
    self.handle_hover = BaseWindow.handle_hover
    self.set_focus_visual = BaseWindow.set_focus_visual

    -- d:new_button(self.btn_close, self.close)
    d:new_button(self.btn_take_all, function ()
        self:take_all()
        self:close()
    end)

    
    -- Начальные настройки
    -- gui.set_text(self.title, config.title or "Container")
    self.set_title(self, config.title or "Container")

    self.modules = {
        self.static_grid
    }

    self:set_visible(false)
end

---@param container_uid string Уникальный UID конкретной бочки в мире
---@param container_id string|hash Шаблонный ID типа контейнера
---@param container_name string Ключ локализации заголовка (например, "prop_barrel")
---@param columns number Количество колонок сетки
---@param rows number Количество строк сетки
---@param world_pos vector3 Мировые координаты сундука
---@param player_pos vector3 Мировые координаты игрока
function M:open(container_uid, container_id, container_name, columns, rows, world_pos, player_pos)
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
    self.set_title(self, locales.get(container_name))
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
    msg.post(".", "item_action", {
        event = "loot_item_all",
        data = {
            slot_index = nil,
            item_id = nil,
            all = true
        }
    })
end

---@param data_source table
function M:set_data_source(data_source)
    self.static_grid:set_data_source(data_source)
end

---@param x number
---@param y number
---@return number|nil
function M:get_slot_at_position(x, y)
    return self.static_grid:get_slot_at_position(x, y)
end

function M:refresh_all()
    self.static_grid:refresh()
end

return M
