local locales = require("main.modules.data.locales.locale_manager")
local component = require("druid.component")
local constants_ui = require("main.gui.constants_ui")
local BaseWindow = require("main.gui.components.base_window.base_window")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")
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

    self.render_order = constants_ui.LAYERS.LOOT
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
                event = "item_loot",
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

---@param container_model table Готовая обернутая модель InventoryModel
---@param container_name hash Ключ имени для локализации
---@param world_pos vector3|nil Координаты контейнера
---@param player_pos vector3|nil Координаты игрока
function M:open(container_model, container_name, world_pos, player_pos)
    -- 1. Привязываем источник данных к нашей вложенной сетке StaticGrid
    self:set_data_source(container_model)
    self.set_title(self, locales.get(container_name))

    -- 2. 🦾 ЗРЯЧЕЕ AAA-ВЫЧИСЛЕНИЕ ГЕОМЕТРИИ (ИСПРАВЛЕНО):
    -- Вместо чтения из «голой» таблицы данных, мы берем размеры колонок и строк,
    -- которые нам пуленепробиваемо рассчитал world.script на основе типа бочки/сундука!
    -- Если в модели их нет — каскадный фоллбек нативно выставит стандартную сетку 6x4!
    local cols = container_model.columns or (self.static_grid and self.static_grid.columns) or 6
    local rows = container_model.rows or (self.static_grid and self.static_grid.rows) or 4

    -- 3. Вычисляем позицию на экране HUD (Твой оригинальный расчет)
    local screen_x, screen_y = 640, 360
    if world_pos and player_pos then
        screen_x, screen_y = gui_utils.world_to_screen(world_pos, player_pos)
    end

    local window_w = cols * (48 + 4) - 4
    local window_h = rows * (48 + 4) - 4

    local offset_x, offset_y = 50, 50
    local final_x = screen_x + offset_x
    local final_y = screen_y + offset_y

    if final_x + window_w > 1920 then
        final_x = math.floor(screen_x - window_w - offset_x)
    end
    if final_y + window_h > 1080 then
        final_y = math.floor(screen_y - window_h - offset_y)
    end

    gui.set_position(self.root, vmath.vector3(final_x, final_y, 0))
end

-- main/gui/components/container_window/ContainerWindow.lua

function M:take_all()
    print("Take all logic for:", self.template_id)
    
    -- 🦾 ЗРЯЧИЙ ААА-ПРОБРОС ИСТОЧНИКА ДЛЯ LOOT ALL (ИСПРАВЛЕНО):
    -- Вытаскиваем живой объектный инстанс модели сундука/бочки из нашей сетки StaticGrid
    local current_source_model = self.static_grid and self.static_grid:get_data_source()

    msg.post(".", "item_action", {
        event = "item_loot_all",
        data = {
            slot_index = nil,
            item_id = nil,
            all = true,
            
            -- 🎯 НАМЕРТВО ИНЖЕКТИРУЕМ МОДEЛЬ СУНДУКА В PAYLOAD:
            -- Теперь container_window.gui_script при поимке этого сообщения сразу увидит 
            -- правильный source_model_override, подставит рюкзак мага, и цикл заберет все вещи!
            source_model_override = current_source_model
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
