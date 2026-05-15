local gui_utils = require("main.gui.gui_utils")
local strings = require("main.modules.data.strings")
local CharacterStats = require("main.gui.components.character_window.CharacterStats")
local CharacterPaperdoll = require("main.gui.components.character_window.CharacterPaperdoll")
local CharacterInventory = require("main.gui.components.inventory_grid.InventoryGrid")
local CharacterJournal = require("main.gui.components.character_window.CharacterJournal")
local CharacterTalents = require("main.gui.components.character_window.CharacterTalents")

local M = {}
-- 1. Упрощаем конфиг. Теперь TAB_WIDTH — это ширина всего огромного окна
local TOTAL_WIDTH = 900
local WINDOW_HEIGHT = 600

local TABS = {
    character = {
        window_title = "character_window",
        btn_key = "btn_character",
        container_key = "page_character",
        -- Для сложной вкладки создадим список компонентов внутри
        sub_components = {
            { class = CharacterStats, template = "character_stats" },
            { class = CharacterPaperdoll, template = "character_paperdoll" },
            {
                class = CharacterInventory,
                template = "inventory_grid",
                config = {
                    columns = 7,
                    rows = 12,
                    item_size = 40,
                    spacing = 2,
                    data_source = require("main.modules.player.player_inventory")  -- ЯВНО ПЕРЕДАЕМ
                }
            }
        }
    },
    journal = {
        window_title = "character_journal",
        btn_key = "btn_journal",
        container_key = "page_journal",
        template_id = "character_journal",
        component = CharacterJournal
    },
    talents = {
        window_title = "character_talents",
        btn_key = "btn_talents",
        container_key = "page_talents",
        template_id = "character_talents",
        component = CharacterTalents
    }
}
-- Вспомогательная функция для сборки путей внутри модуля
local function get_path(template_id, node_id)
    if not template_id or template_id == "" then
        return node_id
    else
        return template_id .. "/" .. node_id
    end
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        -- Как только окно становится видимым — принудительно обновляем данные
        self:refresh_all()
    end
end

function M:close()
    self:set_visible(false) -- Теперь этот вызов найдет функцию выше
    print("Window closed")
end

function M:toggle()
    local current = gui.is_enabled(self.root)
    self:set_visible(not current)
end

function M:on_input(action_id, action)
    -- Передаем ввод в Druid (для кнопок окна)
    -- Но главное — передаем его в модули текущей вкладки
    local tab = self.tabs[self.active_tab]
    if tab then
        for _, module in ipairs(tab.modules) do
            if module.on_input then
                module:on_input(action_id, action)
            end
        end
    end
end

-- 2. В функции new инициализируем всё дерево
function M.new(druid, template_id, player_inventory)
     local self = {
        druid = druid,
        template_id = template_id,
        -- Используем get_path, чтобы убрать лишние слэши
        root = gui.get_node("root"),
        body = gui.get_node("body"), -- УБРАЛ "root/body", в GUI пишем просто "body"
        header = gui.get_node("header"),
        btn_close = gui.get_node("btn_close"),
        nav_bar = gui.get_node("nav_bar"),
        window_title = gui.get_node("window_title"),
        tabs = {},
        active_tab = nil
    }

    self.set_visible = M.set_visible
    self.toggle = M.toggle
    self.switch_tab = M.switch_tab
    self.refresh_all = M.refresh_all
    self.close = M.close
    self.get_slot_at_position = M.get_slot_at_position
    self.is_visible = M.is_visible -- ВОТ ЭТОЙ СТРОКИ НЕ ХВАТАЛО
    self.on_input = M.on_input

    self.drag = druid:new_drag(self.header, function(_, dx, dy)
        local pos = gui.get_position(self.root)
        local target_pos = vmath.vector3(pos.x + dx, pos.y + dy, 0)

        -- Ограничиваем target_pos по размерам ноды body
        local final_pos = gui_utils.clamp_to_screen(self.body, target_pos, 0, 40)

        gui.set_position(self.root, final_pos)
    end)
    -- Чтобы драг не конфликтовал с кнопками на хедере
    self.drag.is_touch_threshold = true

    druid:new_button(self.btn_close, function()
        self:close()
    end)

    for name, cfg in pairs(TABS) do
        local btn = gui.get_node(cfg.btn_key)
        local container = gui.get_node(cfg.container_key)
        
        self.tabs[name] = {
            window_title = cfg.window_title,
            btn = btn,
            container = container,
            modules = {} -- здесь будут лежать компоненты вкладки
        }

        -- Инициализируем компоненты (один или несколько)
        if cfg.sub_components then
            for _, sub in ipairs(cfg.sub_components) do
                local full_path = sub.template
                local sub_config = sub.config or {}

                -- Если это инвентарь - добавляем в config data_source
                if sub.template == "inventory_grid" then
                    sub_config.data_source = player_inventory
                end

                local instance = druid:new(sub.class, full_path, sub_config)
                instance.character_window = self
                table.insert(self.tabs[name].modules, instance)

                if sub.template == "inventory_grid" then
                    self.inventory_grid = instance
                elseif sub.template == "character_paperdoll" then
                    self.paperdoll = instance
                elseif sub.template == "character_stats" then -- ДОБАВЬ ЭТОТ БЛОК
                    self.character_stats = instance
                end
            end
        elseif cfg.component then
            local full_path = cfg.template_id
            local instance = druid:new(cfg.component, full_path)
            table.insert(self.tabs[name].modules, instance)
        end
        druid:new_button(btn, function() self:switch_tab(name) end)
    end

    -- Настраиваем финальный размер окна ОДИН раз
    gui.set_size(self.body, vmath.vector3(TOTAL_WIDTH, WINDOW_HEIGHT, 0))
    gui.set_size(self.header, vmath.vector3(TOTAL_WIDTH, 80, 0))
    
    if self.inventory_grid then
        self.inventory_grid:refresh()
    end
    if self.paperdoll then
        self.paperdoll:refresh()
    end

    self:switch_tab("character")
    return self
end

-- 3. Обновляем switch_tab
function M:switch_tab(tab_name)
    -- 1. Сначала находим данные активной вкладки и обновляем заголовок ОДИН раз
    local active_tab_data = self.tabs[tab_name]
    if active_tab_data then
        local localized_title = strings.get(active_tab_data.window_title) or "No Title"
        gui.set_text(self.window_title, localized_title)
    end

    -- 2. Теперь цикл для скрытия/показа нод
    for name, tab in pairs(self.tabs) do
        local is_active = (name == tab_name)
        gui.set_enabled(tab.container, is_active)
    
        for _, module in ipairs(tab.modules) do
            module:set_visible(is_active)
        end

        gui.set_color(tab.btn, is_active and vmath.vector4(1, 1, 0.6, 1) or vmath.vector4(0.8, 0.8, 0.8, 1))
    end
    
    self.active_tab = tab_name
end

function M:refresh_all()
    -- Просто вызываем рефреш у всех внутренних частей
    if self.inventory_grid then self.inventory_grid:refresh() end
    if self.paperdoll then self.paperdoll:refresh() end
    if self.character_stats then self.character_stats:update_display() end
    print("CharacterWindow: All components refreshed from data")
end

function M:get_slot_at_position(x, y)
    if self.inventory_grid then
        return self.inventory_grid:get_slot_at_position(x, y)
    end
    return nil
end

function M:is_visible()
    return gui.is_enabled(self.root)
end

return M

