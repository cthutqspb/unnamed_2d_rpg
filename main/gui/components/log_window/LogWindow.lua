local locales = require("main.modules.data.locales.locale_manager")
local component = require("druid.component")
local BaseWindow = require("main.gui.components.base_window.base_window")

local CHAT_COLORS = {
    ["combat_damage"] = vmath.vector4(1, 1, 1, 1),      -- Белый урон
    ["combat_crit"]   = vmath.vector4(1, 0.8, 0, 1),    -- Желтый крит
    ["loot"]          = vmath.vector4(0, 1, 0, 1),      -- Зеленый лут (Вы получили: [Ткань])
    ["npc_dialog"]    = vmath.vector4(1, 0.5, 0, 1),    -- Оранжевый текст разговора
    ["system"]        = vmath.vector4(1, 0.2, 0.2, 1),  -- Красный системный (Сервер перезагружается!)
}

---@class LogWindow : druid.component
local M = component.create('LogWindow')

---@param template_id string
function M:init(template_id)
    BaseWindow.init(self, template_id)

    self.scroll_view = gui.get_node("scroll_view") -- Твоя маска-бокс (Pivot: NW!)
    self.log_line_text = gui.get_node("log_line_text") -- Префаб строки (Pivot: NW!)
    gui.set_enabled(self.log_line_text, false)

    self.lines_registry = {}
    self.max_lines = 128

    -- 🎯 ОСТАВЛЯЕМ ДРУИДУ ТОЛЬКО СКРОЛЛ (Колесико мыши, инерция, маски)
    self.scroll = self.druid:new_scroll("scroll_view", "scroll_content")
    self.scroll.on_scroll:subscribe(self.on_scroll)

    -- =========================================================================
    -- 🎛️ ИНИЦИАЛИЗАЦИЯ СЛАЙДЕРА ДЛЯ СКРОЛЛБАРA
    -- =========================================================================
    -- 1. Вычисляем высоту трека ( slider_back ), чтобы понять, на сколько пикселей вниз может уехать ползунок.
    -- (Убедись, что нода "slider_back" заведена в твоем .gui и имеет нормальные размеры, например H: 200)
    local back_node = gui.get_node("slider_back")
    local back_height = gui.get_size(back_node).y

    local pin_node = gui.get_node("slider_pin")
    local pin_height = gui.get_size(pin_node).y

     -- 1. Сдвигаем стартовую позицию ползунка вниз на половину его высоты (-12),
    -- чтобы верхний край каретки идеально коснулся отметки 0 подложки
    local start_y = -(pin_height / 2)
    gui.set_position(pin_node, vmath.vector3(0, start_y, 0))

    -- 2. Считаем конечную точку пути. 
    -- Нижний край каретки должен коснуться отметки -back_height, 
    -- значит её центр должен остановиться на координате -(back_height - 12)
    local end_y = -(back_height - (pin_height / 2))
    local slider_end_pos = vmath.vector3(0, end_y, 0)

    -- 3. Создаем слайдер. Теперь его рельсы жестко зажаты от -12 до -(back_height - 12)!
    -- Координата X строго 0, чтобы траектория была вертикальной.
    self.slider = self.druid:new_slider("slider_pin", slider_end_pos, self.on_slider) --[[@as druid.slider]]
    self.slider:set_input_node("slider_back")

    self.druid:new_hover("slider_back", nil, self.on_slider_back_hover)
    self.scroll:set_extra_stretch_size(40)

    self.current_y = 0
end

function M:on_scroll()
	local scroll_percent = self.scroll:get_percent()
	self.slider:set(1 - scroll_percent.y, true)
end


function M:on_slider(value)
	self.scroll:scroll_to_percent(vmath.vector3(0, 1 - value, 0), true)
end

---@param params any
---@param button druid.button
function M:on_button_click(params, button)
	local node = button.node
	self.scroll:scroll_to(gui.get_position(node))
end


function M:on_slider_back_hover(is_hover)
	local node = self:get_node("slider_pin")
	gui.animate(node, "color.w", is_hover and 1.5 or 1, gui.EASING_OUTSINE, 0.2)
end

---Отрендерить новую строку чата с динамическим сдвигом (WoW-канон)
---@param data table Пакет данных { channel, text }
function M:render_log_line(data)
    if not data or not data.text or not data.channel then return end

    -- 1. ЛИМИТ СТРОК (Оставляем твой код)
    if #self.lines_registry >= self.max_lines then
        local old_line = table.remove(self.lines_registry, 1)
        if old_line and old_line.node then
            gui.delete_node(old_line.node)
        end
    end

    -- 2. КЛОНИРУЕМ ПРЕФАБ ПРАВИЛЬНО:
    local new_line_node = gui.clone(self.log_line_text)

    -- Сразу усыновляем её нашему двигающемуся холсту скролла Друида (scroll_content)
    local scroll_content = gui.get_node("scroll_content")
    gui.set_parent(new_line_node, scroll_content)
    gui.set_enabled(new_line_node, true)

    -- 3. ФИКС ЗАПАЗДЫВАНИЯ: Мы пишем текст ПРЯМО В КЛОН (new_line_node)!
    local timestamp = os.date("[%H:%M:%S] ")
    local final_text = timestamp .. locales.get(data.text)

    gui.set_text(new_line_node, final_text)
    gui.set_color(new_line_node, CHAT_COLORS[data.channel] or vmath.vector4(1, 1, 1, 1))

    -- =========================================================================
    -- 📐 ВЫЧИСЛЕНИЕ ДИНАМИЧЕСКОЙ ВЫСОТЫ СТРОКИ ЧАТА (По новому клону)
    -- =========================================================================
    local font = gui.get_font(new_line_node)
    local scroll_view_size = gui.get_size(self.scroll_view)
    local max_w = scroll_view_size.x

    -- Замеряем метрики по новой ноде
    local metrics = gui.get_text_metrics(font, final_text, max_w, true)
    local text_h = metrics.height * gui.get_scale(new_line_node).y
    local row_h = math.max(16, text_h)

    gui.set_size(new_line_node, vmath.vector3(max_w, row_h, 0))

    -- Позиционируем клон на холсте
    gui.set_position(new_line_node, vmath.vector3(5, self.current_y, 0))

    -- Сдвигаем маркер вниз для будущего сообщения
    self.current_y = self.current_y - row_h
    -- =========================================================================

    -- =========================================================================
    -- 4. ИНТЕГРАЦИЯ СО СКРОЛЛОМ ДРУИДА (Чистый размер без вычитания строки)
    -- =========================================================================
    local total_content_height = math.abs(self.current_y)
    self.scroll:set_size(vmath.vector3(scroll_view_size.x, total_content_height - row_h, 0))

    -- Запоминаем строку
    table.insert(self.lines_registry, { node = new_line_node, height = row_h })

    -- =========================================================================
    -- 🎛️ ДИНАМИЧЕСКИЙ СТАТУС, РАЗМЕР И БАРЬЕРЫ СЛАЙДЕРА (WoW-канон)
    -- =========================================================================
    local view_h = scroll_view_size.y
    local track_node = gui.get_node("slider_back")
    local caret_node = gui.get_node("slider_pin")

    if total_content_height > view_h then
        gui.set_enabled(track_node, true)
        gui.set_enabled(caret_node, true)

        -- Используем семафор блокировки, чтобы ручная установка слайдера не воевала со скроллом
        self._lock_update = true

        -- 🎯 WoW-Канон: Мягко докручиваем скролл в самый низ (y = 0 в координатах Друида)
        -- Передаем true для плавной инерционной докрутки без прыжков каретки
        self.scroll:scroll_to_percent(vmath.vector3(0, 0, 0), true)

        -- Ставим ползунок в нижнюю точку
        self.slider:set(1.0, true)

        self._lock_update = false
    else
        gui.set_enabled(track_node, false)
        gui.set_enabled(caret_node, false)

        self._lock_update = true
        self.slider:set(0.0, true)
        self._lock_update = false
    end
end

---Полностью очистить историю чата при старте новой игры (WoW-канон)
function M:log_clear()
    print("🎛️ ООП-ЧАТ [clear_log]: Запущена тотальная зачистка истории чата...")

    -- 1. Физически удаляем все склонированные текстовые ноды с экрана Meadows
    if self.lines_registry then
        for i = 1, #self.lines_registry do
            local line_data = self.lines_registry[i]
            -- line_data.node — это хэш-ссылка на Си-клон ноды
            if line_data and line_data.node then
                gui.delete_node(line_data.node)
            end
        end
    end

    -- 2. Сбрасываем таблицы памяти бэкенда окна чата в девственно чистое состояние
    self.lines_registry = {}

    -- 3. СБРАСЫВАЕМ МАРКЕРЫ СДВИГА: Возвращаем Y-координату в нулевую точку (самый верх)
    self.current_y = 0

    -- 4. СИНХРОНИЗИРУЕМ СКРОЛЛ ДРУИДА:
    -- Говорим Друиду, что размер холста теперь официально равен 0 пикселей.
    -- Он моментально сбросит все границы, выключит ползунки и заблокирует колесо мыши!
    if self.scroll then
        local view_size = gui.get_size(self.scroll_view)
        self.scroll:set_size(vmath.vector3(view_size.x, 0, 0))

        -- Мягко возвращаем скролл в базовую верхнюю точку
        self.scroll:scroll_to_percent(vmath.vector3(0, 1, 0), true)
    end

    -- 5. Прячем ползунки обратно, так как чат снова пустой
    local track_node = gui.get_node("slider_back")
    local pin_node = gui.get_node("slider_pin")
    gui.set_enabled(track_node, false)
    gui.set_enabled(pin_node, false)

    if self.slider then
        self.slider:set(0.0)
    end
end

return M
