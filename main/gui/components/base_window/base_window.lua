local gui_utils = require("main.gui.gui_utils")
local window_manager = require("main.gui.components.managers.window_manager")
local drag_manager = require("main.gui.components.managers.drag_manager")
local tooltip_manager = require("main.gui.components.managers.tooltip_manager")
local CustomCursor = require("main.gui.components.cursor.CustomCursor")

---@class WindowCallbacks
---@field on_show function|nil Коллбэк, вызываемый при открытии окна
---@field on_hide function|nil Коллбэк, вызываемый при закрытии окна

---@class BaseWindow
local M = {}

---Инициализация базовой разметки и системных кнопок окна
---@param self table|any Контекст наследующего Druid-компонента окна (CharacterWindow, ContainerWindow)
---@param template_id string Строковый ID GUI-шаблона (префикс путей нод)
---@param callbacks WindowCallbacks|nil Таблица кастомных жизненных коллбэков
function M.init(self, template_id, callbacks)
    self.callbacks = callbacks or {}
    self.druid = self:get_druid()

    -- Если template_id не передан или это пустая строка, префикс должен быть ПУСТЫМ
    local prefix = ""
    if template_id and template_id ~= "" then
        prefix = template_id .. "/"
    end

    -- =========================================================================
    -- 🧱 КРИТИЧЕСКИЙ БAЗОВЫЙ СТЕК (Обязательные ноды — если их нет, игра ДОЛЖНА упасть)
    -- =========================================================================
    self.root = gui.get_node(prefix .. "root")
    self.body = gui.get_node(prefix .. "body")
    self.header = gui.get_node(prefix .. "header")
    self.footer = gui.get_node(prefix .. "footer")
    self._dirty = false

    -- =========================================================================
    -- 🛡️ ОПЦИОНАЛЬНЫЙ ДЕКОР (Только через pcall, спасает от краша окна без кнопок)
    -- =========================================================================
    local ok_bc, node_bc = pcall(gui.get_node, prefix .. "btn_close")
    self.btn_close = ok_bc and node_bc or nil

    local ok_wt, node_wt = pcall(gui.get_node, prefix .. "window_title")
    self.window_title = ok_wt and node_wt or nil
    -- =========================================================================

    -- Драг-система хедера (Оставляем твой оригинальный математический расчет clamp_to_screen)
    self.drag = self.druid:new_drag(self.header, function(_, dx, dy)
        local pos = gui.get_position(self.root)
        local _, sf_x, sf_y = gui_utils.clamp_to_screen(self.root, self.body, pos)
        local target_pos = vmath.vector3(pos.x + (dx * sf_x), pos.y + (dy * sf_y), 0)
        local final_pos = gui_utils.clamp_to_screen(self.root, self.body, target_pos, 30, 30)
        gui.set_position(self.root, final_pos)
    end)

    -- Чтобы драг не мешал кнопкам на хедере
    self.drag.is_touch_threshold = true

    -- Авто-кнопка закрытия (Сработает ТОЛЬКО если нода физически существует в шаблоне)
    if self.btn_close then
        self.druid:new_button(self.btn_close, function()
            M.close(self)
        end)
    end

    -- Настройка рендер-слоев (Твоя оригинальная логика)
    if not self.render_order then
        self.render_order = 5
        print("WARNING: render_order not set, using default 5 for", msg.url())
    end
    gui.set_render_order(self.render_order)

    if self.is_static then
        window_manager.push(self, msg.url(), self.render_order)
    end
end

---Поставить флаг отложенного обновления интерфейса (Dirty Flag)
---@param self table|any
function M.request_refresh(self)
    self._dirty = true
end

---Системный апдейт ховера и логики отрисовки
---@param self table|any
---@param dt number Дельта времени кадра
---@param mx number Текущая координата X мыши
---@param my number Текущая координата Y мыши
function M.update(self, dt, mx, my)
    -- Проверяем видимость и нахождение мыши над телом окна
    local is_over = false
    if M.is_visible(self) then
        is_over = M.is_over_window(self, mx, my)
    end

    -- Сообщаем менеджеру актуальный статус
    -- Это безопасно, так как вызывается из GUI контекста
    window_manager.set_hover_status(msg.url(), is_over)

    if self._dirty then
        if self.refresh_all then
            self:refresh_all()
        end
        self._dirty = false
    end
end

---Проверить, находится ли курсор мыши над реальными элементами макета окна
---@param self table|any Экземпляр окна
---@param x number Координата мыши X
---@param y number Координата мыши Y
---@return boolean true -- если мышь находится над осязаемой частью интерфейса
function M.is_over_window(self, x, y)
    -- Если корневой узел скрыт — окна физически нет на экране
    if not self.root or not gui.is_enabled(self.root, true) then
        return false
    end

    -- 1. Проверяем шапку (заголовок, крестик закрытия)
    if self.header and gui.pick_node(self.header, x, y) then return true end

    -- 2. Проверяем главное тело окна (контент, табы, слоты)
    if self.body and gui.pick_node(self.body, x, y) then return true end

    -- 3. Проверяем подвал (системные кнопки вроде "Принять / Закрыть")
    if self.footer and gui.pick_node(self.footer, x, y) then return true end

    -- Мышь находится в пустоте за пределами элементов окна
    return false
end

---Обработать ховер мыши над дочерними интерактивными модулями окна (слоты, кукла)
---@param self table|any
---@param mx number Координата мыши X
---@param my number Координата мыши Y
---@return table|nil Возвращает структуру данных ховера (например, {type="item", item=data}) или nil
function M.handle_hover(self, mx, my)
    -- 1. Сначала проверяем координаты (защита от nil и 0)
    if not mx or not my or mx == 0 or my == 0 then return nil end

    if drag_manager.is_dragging() then return nil end

    if window_manager.is_context_menu_open() then return nil end

    -- 2. Проверяем, что нода вообще СУЩЕСТВУЕТ, прежде чем вызывать gui.is_enabled
    -- Если self.root будет nil, gui.is_enabled уронит игру с нечитаемой ошибкой
    if not self.root or not gui.is_enabled(self.root, true) then
        return nil
    end

    -- 3. Опрос модулей
    if self.modules then
        for _, module in ipairs(self.modules) do
            -- 2. ГЛАВНЫЙ ФИКС: Проверяем, включен ли корень модуля (сетки, куклы и т.д.)
            -- Если вкладка скрыта, то module.root будет disabled, и мы его пропустим
            if module and module.root and gui.is_enabled(module.root, true) then
                if module.get_hover_data then
                    local data = module:get_hover_data(mx, my)
                    if data then
                        return data
                    end
                end
            end
        end
    end
    return nil
end

---Переключить состояние видимости окна (открыть/закрыть) с перестройкой стека фокуса
---@param self table|any
---@return boolean Новое состояние видимости окна (true - открыто, false - закрыто)
function M.toggle(self)
    local is_visible = M.is_visible(self)
    local new_visible = not is_visible

    M.set_visible(self, new_visible)

    if new_visible then
        -- 1. Регистрируем в стеке с Z
        window_manager.push(self, msg.url(), self.render_order)
        -- 2. ГЛАВНЫЙ ФИКС: Перестраиваем очередь ввода по слоям
        window_manager.reorder_focus()
    else
        window_manager.pop(msg.url())
        msg.post(".", "release_input_focus")
        -- После закрытия обновляем фокус для тех, кто остался
        window_manager.reorder_focus()
    end

    return new_visible
end

---Прямо установить видимость окна на экране и вызвать соответствующие коллбэки
---@param self table|any
---@param visible boolean Флаг видимости
function M.set_visible(self, visible)
    gui.set_enabled(self.root, visible)

    -- Если окно скрывается, оно ДОЛЖНО обнулить свой статус ховера
    if not visible then
        window_manager.set_hover_status(msg.url(), false)

        if tooltip_manager.get_current_type() == "item" then
            tooltip_manager.hide_gui_tooltips()
        end
    end

    if visible and self.callbacks.on_show then
        self.callbacks.on_show()
    elseif not visible and self.callbacks.on_hide then
        self.callbacks.on_hide()
    end
end

---@param self table|any
---@return boolean true
function M.is_visible(self)
    return gui.is_enabled(self.root)
end

---@param self table|any
function M.close(self)
    -- 1. Скрываем
    M.set_visible(self, false)

    -- 2. Убираем из стека
    window_manager.pop(msg.url())

    msg.post(".", "release_input_focus")
    window_manager.reorder_focus()
end

---@param self table|any
---@param text string
function M.set_title(self, text)
    if self.window_title then
        gui.set_text(self.window_title, text)
    end
end

---Установить визуальное состояние фокуса/активности окна
---@param self table|any
---@param is_active boolean true, если окно стало главным для игрока
function M.set_focus_visual(self, is_active)
    if self.body then
        local alpha = is_active and 0.9 or 0.72
        local current_color = gui.get_color(self.body)
        current_color.w = alpha
        gui.set_color(self.body, current_color)
    end
end

return M
