local Layout = require("main.gui.components.static_grid.static_grid_layout")
local Interactions = require("main.gui.components.static_grid.static_grid_interactions")
local component = require("druid.component")
local static_grid = require("druid.base.static_grid")
local drag_manager = require("main.gui.components.managers.drag_manager")
local interaction_manager = require("main.modules.logic.interaction_manager")

---@class StaticGridConfigTable
---@field data_source table|nil Модель данных инвентаря/сундука
---@field columns number|nil Количество колонок в сетке (дефолт: 6)
---@field rows number|nil Количество строк в сетке (дефолт: 4)
---@field item_size number|nil Размер ячейки в пикселях (дефолт: 40)
---@field spacing number|nil Расстояние между ячейками (дефолт: 2)
---@field on_double_click function|nil Коллбэк при быстром двойном клике по слоту

---@class StaticGridSlotVisual
---@field root node Корневой узел прехаба слота
---@field icon node Узел спрайта иконки предмета
---@field amount node Узел текстовой этикетки количества

---@class StaticGrid : druid.component
---@field druid druid.instance
---@field template_id string Префикс путей нод GUI-шаблона
---@field data_source table|nil Активная модель данных
---@field columns number
---@field rows number
---@field item_size number
---@field spacing number
---@field container node Контейнер-держатель сетки Друида
---@field root node Главный корень компонента
---@field is_shift_pressed boolean Системный флаг зажатия Shift
---@field on_double_click_handler function|nil
---@field grid table 🚩 ФИКС ТИПА: Меняем на универсальный table, чтобы убрать assign-type-mismatch
---@field slots StaticGridSlotVisual[] Массив сгенерированных слотов сетки
---@field _dirty boolean Флаг отложенного обновления кадра (Dirty Flag)
local M = component.create("StaticGrid")

---Инициализация универсальной сетки слотов
---@param template_id string Строковый ID шаблона
---@param config StaticGridConfigTable Таблица параметров конфигурации ячеек
function M:init(template_id, config)
    self.druid = self:get_druid()
    self.template_id = template_id
    self.data_source = config.data_source
    self.columns = config.columns or 6
    self.rows = config.rows or 4

    self.item_size = config.item_size or 40
    self.spacing = config.spacing or 2
    self.container = gui.get_node(template_id .. "/container")
    self.root = gui.get_node(template_id .. "/root")

    self.is_shift_pressed = false
    self.on_double_click_handler = config.on_double_click

    -- Регистрируем каноничную статическую сетку в Друиде
    self.grid = self.druid:new(static_grid, self.container, template_id .. "/slot_prefab/root", self.columns)
    self.grid:set_item_size(self.item_size + self.spacing, self.item_size + self.spacing)

    self.slots = {}

    -- ГЕНЕРАЦИЯ МАКЕТА: Отрисовка пустых Box-нод ячеек
    Layout.create_slots(self)

    -- НАСТРОЙКА ИНПУТОВ: Вешаем кнопки Друида на каждый созданный слот
    Interactions.setup(self)

    self._dirty = false
end

-- 🚩 УБРАЛИ ХОЛОСТЫЕ ---@param self StaticGrid ИЗ ВСЕХ ПОСЛЕДУЮЩИХ ОПП-МЕТОДОВ С ":"!

---Системный инпут-слушатель сетки слотов
---@param action_id hash|nil
---@param action table
---@return boolean
function M:on_input(action_id, action)
    if drag_manager.is_dragging() then
        return false
    end

    -- 1. Логика системного Shift (для быстрого сплита или переноса шмоток)
    if action_id == hash("key_lshift") then
        if action.pressed then
            self.is_shift_pressed = true
        elseif action.released then
            self.is_shift_pressed = false
        end
        return false
    end

    -- 2. Ручной перехват ПКМ (так как базовый Друид из коробки его игнорирует)
    if action_id == hash("mouse_right") and action.released then
        local index = self:get_slot_at_position(action.x, action.y)
        if index then
            Interactions.handle_right_click(self, index, action.x, action.y)
            return true
        end
    end

    -- 3. Отдаем ЛКМ Друиду (он сам обработает слоты через Interactions.setup клики)
    return false
end

---@param dt number
function M:update(dt)
    if self._dirty then
        self:refresh()
        self._dirty = false
    end
end

---Взвести флаг отложенной перерисовки содержимого инвентаря
function M:request_refresh()
    self._dirty = true
end

---Полная перерисовка иконок и цифр количества предметов на основе Модели данных
function M:refresh()
    local ds = self:get_data_source()
    if not ds or not ds.items then return end

    for i = 1, #self.slots do
        local item = ds:get_item(i)
        if item and item.item_id then
            Layout.draw_slot(self, i, item.item_id, item.amount)
        else
            Layout.clear_slot_visual(self, i)
        end
    end
end

---Дефолтный триггер клика по заполненому слоту (например, для сплита стака)
---@param index number Числовой индекс нажатого слота
function M:on_slot_click(index)
    local item_data = self:get_data_source():get_item(index)
    if item_data and item_data.amount > 1 then
        print('SPLIT ON SLOT CLICK')
        msg.post("main:/split_window#gui", "open_split_window", {
            item_data = item_data,
            slot_index = index
        })
    end
end

---Сменить активную модель данных (например, когда открыли совершенно другую бочку)
---@param data_source table Чистая Lua-модель данных инвентаря
function M:set_data_source(data_source)
    self.data_source = data_source
    self:refresh()
end

---Получить текущую модель данных (если не задана — по умолчанию отдает рюкзак игрока)
---@return table
function M:get_data_source()
    return self.data_source or interaction_manager.get_player_inventory()
end

-- 🚩 УБРАЛИ ВТОРОЙ ДУБЛИКАТ ЭТОГО МЕТОДА СНИЗУ! ОСТАЛСЯ СТРОГО ОДИН!
---Посчитать пиксели ячеек на экране и вернуть индекс слота под курсором мыши
---@param x number Экранная координата X мыши
---@param y number Экранная координата Y мыши
---@return number|nil index Порядковый индекс слота (от 1 до макс) или nil, если промахнулись
function M:get_slot_at_position(x, y)
    for i, slot in ipairs(self.slots) do
        if gui.pick_node(slot.root, x, y) then
            return i
        end
    end
    return nil
end

---Обновить цифру количества предметов в конкретной ячейке макета
---@param index number
---@param amount number
function M:set_slot_amount_visual(index, amount)
    Layout.set_slot_amount_visual(self, index, amount)
end

---Проверить, отпустили ли мышку над валидным слотом в момент завершения драга
---@param x number Экранная координата X мыши
---@param y number Экранная координата Y мыши
---@return boolean true если предмет успешно сброшен в ячейку
function M:on_drop(x, y)
    -- Если сетка или окно скрыты — полный игнор
    if not gui.is_enabled(self.root, true) then return false end

    -- Ищем, над каким конкретно числовым индексом слота отпустили мышь
    local index = self:get_slot_at_position(x, y)

    if index then
        -- 🎯 ФИКС ПРИЛИПАНИЯ: Вызываем деструктор драга!
        -- Передаем самого себя (self) и индекс слота.
        -- Менеджер драга увидит метод :get_data_source(), достанет чистую модель инвентаря
        -- и вещь мгновенно отлипнет от курсора, уйдя в item_transfer_manager!
        drag_manager.finish(self, index)
        return true
    end

    return false
end

---Запрос данных предмета под мышкой для системы тултипов (Hover статус)
---@param mx number
---@param my number
---@return table|nil Структура данных ховера {type="item", item=data} или nil
function M:get_hover_data(mx, my)
    local index = self:get_slot_at_position(mx, my)
    if index then
        local item = self:get_data_source():get_item(index)
        if item and item.item_id then
            return {
                type = "gui_item",
                item = item
            }
        end
    end
    return nil
end

---Установить видимость всей сетки слотов
---@param visible boolean
function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:request_refresh()
    end
end

return M
