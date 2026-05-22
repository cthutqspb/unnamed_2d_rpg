local component = require("druid.component")
local context_db = require("main.modules.data.context_menu_db")
local locales = require("main.modules.data.locales.locale_manager")

---@class ContextMenu : druid.component
local M = component.create("ContextMenu")

function M:init()
    self.druid = self:get_druid()
    self.root = gui.get_node("root")
    self.background = gui.get_node("background")
    self.action_field = gui.get_node("action_field")

    self.nodes_cache = {}
    gui.set_enabled(self.root, false)
end

function M:show(x, y, type, sub_type, flags, data)
    self:clear_cache()

    local actions = context_db.get_actions(type, sub_type, flags)
    local cfg = {
        padding = 2,
        spacing = 2,
        btn_height = 40,
        menu_width = 240
    }
    cfg.btn_width = cfg.menu_width - (cfg.padding * 2)

    -- Визуал корня
    gui.set_enabled(self.root, true)
    gui.set_position(self.root, vmath.vector3(x, y, 1))

    local total_height = (#actions * cfg.btn_height) + ((#actions - 1) * cfg.spacing) + (cfg.padding * 2)
    gui.set_size(self.background, vmath.vector3(cfg.menu_width, total_height, 0))

    -- Наполнение
    for i, action in ipairs(actions) do
        self:create_menu_button(action, i, data, cfg)
    end
end


function M:create_menu_button(action, index, data, config)
    local nodes = gui.clone_tree(self.action_field)
    local btn_node = nodes[hash("action_field")]
    local txt_node = nodes[hash("action_text")]

    gui.set_enabled(btn_node, true)
    gui.set_text(txt_node, tostring(locales.get(action.name_key)))

    -- 1. ПОЗИЦИЯ (NW Pivot): x = 2, y = -2, -44, -86...
    local x_pos = config.padding
    local y_pos = -config.padding - ((index - 1) * (config.btn_height + config.spacing))
    gui.set_position(btn_node, vmath.vector3(x_pos, y_pos, 0))
    gui.set_size(btn_node, vmath.vector3(config.btn_width, config.btn_height, 0))

    -- 2. ЛОГИКА КЛИКА
    local btn_instance = self.druid:new_button(btn_node, function()
        msg.post(data.source_url, "context_menu_action", { event = action.event, data = data })
        self:hide()
    end)

    -- 3. ЖЕСТКОЕ ОТКЛЮЧЕНИЕ СТИЛЯ (Чтобы не было анимации увеличения)
    btn_instance.style.set_color = function() end
    btn_instance.style.set_scale = function() end
    btn_instance.style.on_click_pulse = function() end
    -- btn_instance.style.on_pressed = function() end -- Если нужно убрать эффект нажатия
-- btn_instance.style.on_hover = function() end   -- Если нужно убрать наведение из стиля
    btn_instance.style.on_pressed = function() end
    btn_instance.style.set_scale()
    
    -- 2. Кастомный ховер для ЧЕРНОЙ кнопки
    btn_instance.style.on_mouse_hover = function(self_btn, node, state)
        -- Отменяем старые анимации, чтобы они не конфликтовали
        -- gui.cancel_animation(node, gui.PROP_COLOR)
        
        if state then
            -- При наведении: делаем кнопку более видимой (0.95)
            -- Можно также чуть-чуть увести из чистого черного в темно-серый
            gui.animate(node, gui.PROP_COLOR, vmath.vector4(0.15, 0.15, 0.15, 0.95), gui.EASING_OUTQUAD, 0.1)
        else
            -- Возвращаем исходный: черный (#000000) и прозрачность 0.72
            gui.animate(node, gui.PROP_COLOR, vmath.vector4(0, 0, 0, 0.72), gui.EASING_OUTQUAD, 0.2)
        end
    end

    -- Сохраняем в кэш
    table.insert(self.nodes_cache, {
        nodes = nodes,
        btn = btn_instance,
        hover = hover_instance
    })
end


function M:clear_cache()
    for _, entry in ipairs(self.nodes_cache) do
        if entry.btn then self.druid:remove(entry.btn) end
        if entry.hover then self.druid:remove(entry.hover) end -- Вот это лечит Deleted Node
        for _, node in pairs(entry.nodes) do gui.delete_node(node) end
    end
    self.nodes_cache = {}
end

function M:hide_ui()
    gui.set_enabled(self.root, false)
end

function M:hide()
    msg.post(".", "hide_menu")
end

-- В ContextMenu.lua

function M:on_input(action_id, action)
    -- Если кликнули (ЛКМ) и меню открыто
    if action_id == hash("touch") and action.pressed and gui.is_enabled(self.root, true) then
        -- Если клик НЕ попал в фон меню — закрываем его
        if not gui.pick_node(self.background, action.x, action.y) then
            self:hide()
            -- Мы НЕ возвращаем true, чтобы клик пролетел в мир или другое окно
            return false
        end
    end
    return false
end


return M

