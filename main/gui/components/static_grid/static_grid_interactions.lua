local interaction = require("main.modules.interaction")
local drag_manager = require("main.gui.components.managers.drag_manager")
local items_db = require("main.modules.data.items_db")
local abilities_db = require("main.modules.data.abilities_db")

---@class StaticGridInteractionsModule
local M = {}

---Настроить интерактивность для всех сгенерированных ячеек сетки (Друид кнопки и Драг)
---@param self StaticGrid Ссылка на родительский компонент универсальной сетки слотов
function M.setup(self)
    for i, slot in ipairs(self.slots) do
        -- Регистрируем стандартную Друид-кнопку (она поймает только ЛКМ)
        local btn = self.druid:new_button(slot.root, function(ctx, action_id, action)
            M.handle_slot_click(self, i, action_id, action)
        end)

        slot.button = btn

        -- 🚩 УЛЬТИМАТИВНЫЙ ФИКС ТИПОВ:
        -- Принудительно кастуем возвращаемое значение в тип 'any'.
        -- Это намертво затыкает любые проверки 'inject-field' и 'undefined-field',
        -- так как для 'any' разрешено чтение и запись любых свойств, а рантайм Defold будет летать!
        ---@type any
        local d = self.druid:new_drag(slot.root)

        d.drag_threshold = 4
        d.on_drag_start:subscribe(function()
            M.handle_drag_start(self, i)
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

    if not self.on_double_click_handler then
        return false -- Сигнал пролетает дальше к обычному клику Друида! [🔍]
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
    local data_source = self:get_data_source()
    if not data_source then return end

    local item = data_source:get_item(index)
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

---Коллбэк Друида на старт физического перетаскивания предмета/способности мышкой
---@param self StaticGrid
---@param index number
function M.handle_drag_start(self, index)
    local slot_data = self:get_slot_data(index)
    if not slot_data then return end

    -- 🎯 ЧИСТЫЙ DATA-DRIVEN (Без посредников и угадываний):
    -- Если в данных ячейки есть поле action_type (это панель) — берем его. 
    -- Если поля нет (это инвентарь/кукла) — оператор 'or' выставит дефолтный "item"!
    local current_type = slot_data.action_type or "item"

    -- Вытаскиваем целевой ID (или item_id для сумок, или action_id для панели)
    local target_id = slot_data.action_id or slot_data.item_id

    -- Прямой, моментальный хэш-запрос в нужную базу за 1 такт процессора!
    local cfg = nil
    if current_type == "ability" then
        cfg = abilities_db.get_ability(target_id)
    else
        cfg = items_db.get_item(target_id)
    end

    -- Железная Си-страховка рантайма Defold
    if not cfg then return end

    -- 🧱 УЛЬТИМАТИВНЫЙ СЛEПOЙ ЗАПУСК ДРАГА:
    -- Мы убрали 5-й аргумент! Менеджер драга сам прочитает зашитый тип внутри cfg.action_type!
    drag_manager.start(self, index, slot_data, cfg)

    -- Мгновенно гасим визуал ячейки на HUD
    local slot = self.slots[index]
    if slot then
        if slot.icon then gui.set_enabled(slot.icon, false) end
        if slot.amount then gui.set_enabled(slot.amount, false) end
    end
end

return M
