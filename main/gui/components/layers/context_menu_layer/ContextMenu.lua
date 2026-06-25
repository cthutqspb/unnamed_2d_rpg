local component = require("druid.component")
local context_db = require("main.modules.data.context_menu_db")
local locales = require("main.modules.data.locales.locale_manager")

---@class ContextMenuCacheEntry
---@field nodes table<hash, node> Таблица склонированных нод из gui.clone_tree
---@field btn druid.button Инстанс кнопки Друида

---@class ContextMenu : druid.component
---@field druid druid.instance
---@field root node
---@field background node
---@field action_field node
---@field nodes_cache ContextMenuCacheEntry[]
local M = component.create("ContextMenu")

function M:init()
    self.druid = self:get_druid()

    self.root = gui.get_node("root")
    self.background = gui.get_node("background")
    self.action_field = gui.get_node("action_field")

    self.nodes_cache = {}
    gui.set_enabled(self.root, false)
end

---@param x number Экранная координата X курсора
---@param y number Экранная координата Y курсора
---@param type string Главный тип инспекции ("gui_item", "world_item", "world_object", "unit")
---@param sub_type string|nil Устаревший подтип (Игнорируем, теперь все рулится через data и конфиги)
---@param flags table|nil Флаги состояния (is_equipped, can_split)
---@param data table|nil Полный пейлод метаданных (item_id, slot_index, target_uid)
function M:show(x, y, type, sub_type, flags, data)
    self:clear_cache()

    -- 🎯 ЗРЯЧЕЕ AAA-ВЫЧИСЛЕНИЕ КОНФИГА:
    -- Если в пейлоде data прилетел item_id (неважно, из рюкзака или с земли Meadows),
    -- мы ОДИН РАЗ на пороге открытия меню вытаскиваем его чистый конфиг из items_db!
    local items_db = require("main.modules.data.items_db")
    local item_cfg = nil
    if data and data.item_id then
        item_cfg = items_db.get_item(data.item_id)
    end

    -- 🦾 ТИТАНОВЫЙ СИНХРОН: Кормим базу меню правильными изолированными аргументами!
    -- Передаем: тип, вытащенный конфиг, флаги и полный пейлод (где сидит slot_index)
    local actions = context_db.get_actions(type, item_cfg, flags, data)

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
    
    -- Наполнение кнопок на экране HUD
    for i, action in ipairs(actions) do
        self:create_menu_button(action, i, data, cfg)
    end
end

---Внутренний метод генерации склонированной кнопки
---@private
---@param action table Данные действия из базы меню
---@param index number Порядковый индекс кнопки для расчета Y-позиции
---@param data table Системный контекст кликнутого объекта
---@param config table Таблица размеров и отступов меню
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
        -- Создаем зрячий, объединенный payload для нашего gui_script!
        -- Мы берем исходные данные клика (data) и намертво вшиваем в них 
        -- сгенерированные базой меню контексты (item_id, slot_index, unit_uid)!
        local merged_payload = {}
        if data then
            for k, v in pairs(data) do merged_payload[k] = v end
        end
        if action.data then
            for k, v in pairs(action.data) do merged_payload[k] = v end
        end

        -- Отправляем в character_window.gui_script (или container_window) 
        -- ультимативно зрячую посылку, готовую к ААА-транзакциям!
        msg.post(data.source_url, "context_menu_action", { 
            event = action.event, 
            data = merged_payload 
        })
        
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

    -- 4. КАСТОМНЫЙ ХОВЕР (Красивое затемнение/высветление черной кнопки)
    btn_instance.style.on_mouse_hover = function(self_btn, node, state)
        -- Отменяем старые анимации, чтобы они не конфликтовали
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
        btn = btn_instance
    })
end

---Полная очистка созданных нод и регистраций кнопок Друида
function M:clear_cache()
    for _, entry in ipairs(self.nodes_cache) do
        self.druid:remove(entry.btn)

        for _, node in pairs(entry.nodes) do
            gui.delete_node(node)
        end
    end
    self.nodes_cache = {}
end

function M:hide_ui()
    gui.set_enabled(self.root, false)
end

---@diagnostic disable-next-line: unused-local
function M:hide()
    msg.post(".", "hide_menu")
end

function M.is_over_window(self, x, y)
    -- Если корневой узел скрыт — окна физически нет на экране
    if not self.root or not gui.is_enabled(self.root, true) then
        return false
    end

    if self.background and gui.pick_node(self.background, x, y) then return true end

    if self.action_field and gui.pick_node(self.action_field, x, y) then return true end

    -- Мышь находится в пустоте за пределами элементов окна
    return false
end

---Перехват кликов для закрытия меню при нажатии "в молоко"
---@param action_id hash
---@param action table
---@return boolean
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

