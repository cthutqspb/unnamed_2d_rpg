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
---@field bar_index number|nil
---@field grid_type "inventory"|"action_bar"|nil Тип сетки (дефолт: "inventory")
---@field item_size number|nil Размер ячейки в пикселях (дефолт: 40)
---@field spacing number|nil Расстояние между ячейками (дефолт: 2)
---@field on_double_click function|nil Коллбэк при быстром двойном клике по слоту

---@class StaticGridSlotVisual
---@field root node Корневой узел прехаба слота
---@field icon node Узел спрайта иконки предмета
---@field amount node Узел текстовой этикетки количества
---@field bind node|nil 🎯
---@field gcd_overlay node
---@field button table

---@class StaticGrid : druid.component
---@field druid druid.instance
---@field template_id string Префикс путей нод GUI-шаблона
---@field data_source table|nil Активная модель данных
---@field columns number
---@field rows number
---@field bar_index number|nil
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

    self.grid_type = config.grid_type or "inventory"
    self.bar_index = config.bar_index or nil

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

---Абсолютно полиморфный рефреш всей сетки (Работает строго на готовом Payload)
function M:refresh()
    local ds = self:get_data_source()
    if not ds then return end

    -- РEЖИМ А: ЭКШEН-БAР
    if self.grid_type == "action_bar" then
        for i = 1, #self.slots do
            -- Просто слепо швыряем структуру {action_type, action_id} в Layout!
            Layout.draw_slot(self, i, ds[i] or {})
        end
        return
    end

    -- РEЖИМ Б: ИНВEНТAРЬ
    if not ds.items then return end
    for i = 1, #self.slots do
        -- Просто слепо швыряем твой чистый item {item_id, amount} в Layout!
        Layout.draw_slot(self, i, ds:get_item(i) or {})
    end
end

-- ---Полная перерисовка иконок и цифр количества предметов на основе Модели данных
-- function M:refresh()
--     local ds = self:get_data_source()
--     if not ds or not ds.items then return end
--
--     for i = 1, #self.slots do
--         local item = ds:get_item(i)
--         if item and item.item_id then
--             Layout.draw_slot(self, i, item.item_id, item.amount)
--         else
--             Layout.clear_slot_visual(self, i)
--         end
--     end
-- end

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

---Получить текущую модель данных с жесткой защитой доменов (WoW-канон)
---@return table|nil
function M:get_data_source()
    -- Если сорс явно задан в self.data_source — отдаем его без разговоров
    if self.data_source then
        return self.data_source
    end

    -- 🧱 ТИТАНОВАЯ ЗАЩИТА ОТ ЛOЖНOГO ДРAГA ПРEДМEТOВ:
     -- Если это боевая панель способностей и у неё взведен индекс (1, 2 или 3),
    -- она САМА идёт в interaction_manager и забирает нужный массив!
    if self.grid_type == "action_bar" and self.bar_index then
        return interaction_manager.get_player_action_bar(self.bar_index)
    end

    if self.grid_type == "action_bar" then
        return nil
    end

    -- Только если это чистокровная сумка инвентаря, возвращаем рюкзак по умолчанию
    return nil
end

---Универсальный геттер сырых данных ячейки (Инвентарь vs Экшен-бар)
---@param index number Числовой индекс слота
---@return table|nil
function M:get_slot_data(index)
    local ds = self:get_data_source()
    if not ds then return nil end

    -- Если у сорса есть метод get_item (это рюкзак или сундук) — вызываем его
    if ds.get_item then
        return ds:get_item(index)
    end

    -- Во всех остальных случаях (это экшен-бар) — читаем плоскую таблицу матрицы
    return ds[index]
end

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
                item = item,
                action_type = item.action_type
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

---Запустить сочную WoW-анимацию шторок ГКД по всем подходящим ячейкам сетки
---@param duration number Длительность ГКД (1.5 сек)
function M:trigger_gcd(duration)
    if not self.slots then return end

    for index, slot in pairs(self.slots) do
        local slot_data = self:get_slot_data(index)

        -- Достаем Си-ноду оверлея напрямую из нашего свежего, сочного кэша!
        local gcd_node = slot.gcd_overlay

        if gcd_node and slot_data then
            -- 🧠 ЧИТАЕМ СТЕРИЛЬНЫЙ DUCK TYPING (БЕЗ ЛEВЫХ ИМПOРТOВ):
            -- Модель инвентаря/экшен-бара сама знает, запускает ли эта шмотка ГКД!
            if slot_data.triggers_gcd then
                gui.cancel_animations(gcd_node, "size.y")
                
                gui.set_fill_angle(gcd_node, 360)
                print("duration", duration)
                gui.animate(gcd_node, gui.PROP_FILL_ANGLE, 0, gui.EASING_LINEAR, duration)
            end
        end
    end
end



return M
