local interaction = require("main.modules.interaction")
local drag_manager = require("main.gui.components.managers.drag_manager")
local items_db = require("main.modules.data.items_db")

---@class StaticGridInteractionsModule
local M = {}

---Настроить интерактивность для всех сгенерированных ячеек сетки (Друид кнопки и Драг)
---@param self StaticGrid Ссылка на родительский компонент универсальной сетки слотов
function M.setup(self)
    for i, slot in ipairs(self.slots) do
        -- Регистрируем стандартную Друид-кнопку (она поймает только ЛКМ)
        self.druid:new_button(slot.root, function(ctx, action_id, action)
            M.handle_slot_click(self, i, action_id, action)
        end)

        -- 🚩 УЛЬТИМАТИВНЫЙ ФИКС ТИПОВ:
        -- Принудительно кастуем возвращаемое значение в тип 'any'.
        -- Это намертво затыкает любые проверки 'inject-field' и 'undefined-field',
        -- так как для 'any' разрешено чтение и запись любых свойств, а рантайм Defold будет летать!
        ---@type any
        local d = self.druid:new_drag(slot.root)
        
        d.drag_threshold = 4
        d.on_drag_start:subscribe(function() 
            M.on_item_drag_start(self, i) 
        end)
    end
end

---Обработать ЛКМ клик по конкретной ячейке инвентаря
---@param self StaticGrid
---@param index number Порядковый индекс ячейки
---@param action_id hash|nil Идентификатор действия (например, touch)
---@param action table Таблица системного инпута Defold
---@return boolean is_handled Флаг полной обработки клика (возвращаем ОДНО значение!)
function M.handle_slot_click(self, index, action_id, action)
    -- 1. Проверяем Shift (Быстрый сплит или автоперенос)
    local is_shift = self.is_shift_pressed 
    if is_shift then
        self:on_slot_click(index)
        return true
    end

    -- 🚩 ФИКС "ЕСЛИ": Полностью изолировали комментарий, чтобы линтер его не парсил
    -- [LOGIC] Если предмет зелье — можно активировать/выпить по даблклику

    -- 2. Логика ДАБЛКЛИКА через универсальный модуль
    local click_id = self.template_id .. "_" .. index

    if interaction.is_double_click(click_id) then
        M.handle_double_click(self, index)
        return true
    end

    return false
end

---Внутренний обработчик подтвержденного двойного клика по вещи
---@param self StaticGrid
---@param index number
function M.handle_double_click(self, index)
    local ds = self:get_data_source()
    local item = ds:get_item(index)
    if not item or not item.item_id then return end

    if self.on_double_click_handler then
        self.on_double_click_handler(index, item)
    else
        print("GRID: Нет обработчика double-click для этой сетки")
    end
end

---Внешний перехват ПКМ из on_input скрипта окна (для вызова контекстного меню)
---@param self StaticGrid
---@param index number Индекс кликнутой ячейки
---@param x number Экранная координата X клика
---@param y number Экранная координата Y клика
function M.handle_right_click(self, index, x, y)
    local item_data = self:get_data_source():get_item(index)

    if not item_data or not item_data.item_id then
        print("RIGHT CLICK: Слот пустой")
        return
    end

    local item_cfg = items_db.get_item(item_data.item_id)
    if not item_cfg then return end

    local can_split = item_data.amount and item_data.amount >= 2

    msg.post("main:/context_menu_layer#gui", "show_menu", {
        x = x, 
        y = y,
        type = "gui_item",
        sub_type = item_cfg.type,
        flags = {
            can_split = can_split, 
        },
        data = {
            slot_index = index,
            item_id = item_data.item_id,
            source_url = msg.url()
        }
    })
end

---Коллбэк Друида на старт физического перетаскивания предмета мышкой
---@param self StaticGrid
---@param index number
function M.on_item_drag_start(self, index)
    local item_data = self:get_data_source():get_item(index)
    if item_data and item_data.item_id then
        local cfg = items_db.get_item(item_data.item_id)
        if not cfg then return end
        
        drag_manager.start(self, index, item_data, cfg)
        
        if self.slots[index] then
            gui.set_enabled(self.slots[index].icon, false)
            gui.set_enabled(self.slots[index].amount, false)
        end
    end
end

return M


-- local interaction = require("main.modules.interaction")
-- local drag_manager = require("main.gui.components.managers.drag_manager")
-- local items_db = require("main.modules.data.items_db")
-- local M = {}
--
-- function M.setup(self)
--     for i, slot in ipairs(self.slots) do
--         -- Регистрируем стандартную Друид-кнопку (она поймает только ЛКМ)
--         self.druid:new_button(slot.root, function(ctx, action_id, action)
--             M.handle_slot_click(self, i, action_id, action)
--         end)
--
--         -- Регистрируем Драг
--         local d = self.druid:new_drag(slot.root)
--         d.drag_threshold = 4
--         d.on_drag_start:subscribe(function() M.on_item_drag_start(self, i) end)
--     end
-- end
--
-- function M.handle_slot_click(self, index, action_id, action)
--     -- 1. Сначала проверяем Shift (Сплит)
--     local is_shift = self.is_shift_pressed -- Берем из самого компонента
--     if is_shift then
--         self:on_slot_click(index)
--         return true
--     end
--
--     --если зелье то можно бы выпить по даблклику
--
--     -- 2. Логика ДАБЛКЛИКА через универсальный модуль
--     -- Мы передаем уникальный ID (комбинация шаблона и индекса), 
--     -- чтобы даблклик в одном окне не конфликтовал с другим.
--     local click_id = self.template_id .. "_" .. index
--
--     if interaction.is_double_click(click_id) then
--         M.handle_double_click(self, index)
--         return true
--     end
--
--     -- 3. Обычный клик (выделение и т.д.)
--     return false
-- end
--
--
-- function M.handle_double_click(self, index)
--     local ds = self:get_data_source()
--     local item = ds:get_item(index)
--     if not item or not item.item_id then return end
--
--     -- Если нам дали инструкцию при создании — выполняем её
--     if self.on_double_click_handler then
--         self.on_double_click_handler(index, item)
--     else
--         print("GRID: No double-click handler defined for this grid")
--     end
-- end
--
-- function M.handle_right_click(self, index, x, y)
--     local item_data = self:get_data_source():get_item(index)
--
--     if not item_data or not item_data.item_id then
--         print("RIGHT CLICK: Slot is empty")
--         return
--     end
--
--     local item_cfg = items_db.get_item(item_data.item_id)
--
--     -- Проверяем, можно ли разделить этот конкретный стак
--     local can_split = item_data.amount and item_data.amount >= 2
--
--     msg.post("main:/context_menu_layer#gui", "show_menu", {
--         x = x, y = y,
--         type = "item",
--         sub_type = item_cfg.type,
--         flags = {
--             can_split = can_split, -- Передаем флаг в меню
--         },
--         data = {
--             slot_index = index,
--             item_id = item_data.item_id,
--             source_url = msg.url()
--         }
--     })
-- end
--
-- function M.on_item_drag_start(self, index)
--     local item_data = self:get_data_source():get_item(index)
--     if item_data and item_data.item_id then
--         local cfg = items_db.get_item(item_data.item_id)
--         drag_manager.start(self, index, item_data, cfg)
--         -- Скрываем иконку на время драга
--         gui.set_enabled(self.slots[index].icon, false)
--         gui.set_enabled(self.slots[index].amount, false)
--     end
-- end
--
-- return M



