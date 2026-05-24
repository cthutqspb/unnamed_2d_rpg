local gui_utils = require("main.gui.gui_utils")
local window_manager = require("main.gui.components.managers.window_manager")
local drag_manager = require("main.gui.components.managers.drag_manager")
local tooltip_manager = require("main.gui.components.managers.tooltip_manager")

local M = {}

function M.init(self, template_id, callbacks)
    self.callbacks = callbacks or {}
    self.druid = self:get_druid()

    -- Если template_id не передан или это пустая строка, префикс должен быть ПУСТЫМ
    local prefix = ""
    if template_id and template_id ~= "" then
        prefix = template_id .. "/"
    end

    self.root = gui.get_node(prefix .. "root")
    self.body = gui.get_node(prefix .. "body")
    self.header = gui.get_node(prefix .. "header")
    self.btn_close = gui.get_node(prefix .. "btn_close")
    self.window_title = gui.get_node(prefix .. "window_title")
    self._dirty = false

    -- Только через pcall, чтобы не упасть без кнопок
    local ok_bc, node_bc = pcall(gui.get_node, prefix .. "btn_close")
    self.btn_close = ok_bc and node_bc or nil

    local ok_wt, node_wt = pcall(gui.get_node, prefix .. "window_title")
    self.window_title = ok_wt and node_wt or nil

    self.drag = self.druid:new_drag(self.header, function(_, dx, dy)
        local pos = gui.get_position(self.root)
        local target_pos = vmath.vector3(pos.x + dx, pos.y + dy, 0)
        -- Используем body для вычисления границ, а двигаем root
        local final_pos = gui_utils.clamp_to_screen(self.body, target_pos, 0, 40)
        gui.set_position(self.root, final_pos)
    end)

    -- Чтобы драг не мешал кнопкам на хедере (если они там будут)
    self.drag.is_touch_threshold = true

    -- Авто-кнопка закрытия
    if self.btn_close then
        self.druid:new_button(self.btn_close, function()
            M.close(self)
        end)
    end

    -- 1. Устанавливаем визуальный Z-слой
    -- self.render_order должен быть задан в gui_script до вызова M.init
    if not self.render_order then
        self.render_order = 5
        print("WARNING: render_order not set, using default 10 for", msg.url())
    end
    gui.set_render_order(self.render_order)
    --
    -- -- 2. Если это статика (HUD, Портрет, Экшен-бар), сразу пушим в менеджер.
    -- -- Они будут в стеке всегда, но на нижних Z-слоях.
    if self.is_static then
        window_manager.push(self, msg.url(), self.render_order)
    end
end

function M.request_refresh(self)
    self._dirty = true
end

function M.update(self, dt, mx, my)
    -- Проверяем видимость и нахождение мыши над телом окна
    local is_over = false
    if M.is_visible(self) then
        is_over = gui.pick_node(self.body, mx, my)
    end
    
    -- Сообщаем менеджеру актуальный статус
    -- Это безопасно, так как вызывается из GUI контекста
    window_manager.set_hover_status(msg.url(), is_over)

    if self._dirty then
        if self.refresh_all then self:refresh_all() end
        self._dirty = false
    end
end

-- В BaseWindow.lua
function M.is_over_window(self, x, y)
    -- Если root выключен, окно ВООБЩЕ не должно существовать для логики
    if not self.root or not gui.is_enabled(self.root, true) then
        return false
    end
    -- Только если включено, проверяем координаты
    return gui.pick_node(self.body, x, y)
end


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
                    if data then return data end
                end
            end
        end
    end
    return nil
end

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



function M.set_visible(self, visible)
    gui.set_enabled(self.root, visible)

    -- Если окно скрывается, оно ДОЛЖНО обнулить свой статус ховера
    if not visible then
        window_manager.set_hover_status(msg.url(), false)

        if tooltip_manager.get_current_type() == "item" then
            tooltip_manager.hide()
        end
    end

    if visible and self.callbacks.on_show then
        self.callbacks.on_show()
    elseif not visible and self.callbacks.on_hide then
        self.callbacks.on_hide()
    end
    -- Если надо будет то переопределим в character_window, пока без этого работает
    -- if visible then self:refresh_all() end
end

function M.is_visible(self)
    return gui.is_enabled(self.root)
end

function M.close(self)
    -- 1. Скрываем
    M.set_visible(self, false)

    -- 2. Убираем из стека
    window_manager.pop(msg.url())

    msg.post(".", "release_input_focus")
    window_manager.reorder_focus()
end


function M.set_title(self, text)
    if self.window_title then
        gui.set_text(self.window_title, text)
    end
end

return M
