local component = require("druid.component")
local locales = require("main.modules.data.locales.locale_manager")

-- Компоненты вкладок
local constants_ui = require("main.gui.constants_ui")
local BaseWindow = require("main.gui.components.base_window.base_window")
local CharacterStats = require("main.gui.components.character_window.CharacterStats")
local CharacterPaperdoll = require("main.gui.components.character_window.CharacterPaperdoll")
local CharacterInventory = require("main.gui.components.static_grid.StaticGrid")
local CharacterJournal = require("main.gui.components.character_window.CharacterJournal")
local CharacterTalents = require("main.gui.components.character_window.CharacterTalents")

---@class CharacterWindow : druid.component
---@field init fun(self: CharacterWindow, template_id: string, player_inventory: table)
---@field static_grid StaticGrid
---@field paperdoll CharacterPaperdoll | nil
---@field character_stats CharacterStats | nil
---@field root node
---@field body node
---@field header node
local M = component.create("CharacterWindow")

local TOTAL_WIDTH = 900
local WINDOW_HEIGHT = 600

-- Конфигурация вкладок остается прежней
local TABS_CONFIG = {
    character = {
        window_title = "character_window",
        btn_key = "btn_character",
        container_key = "page_character",
        sub_components = {
            { class = CharacterStats, template = "character_stats" },
            { class = CharacterPaperdoll, template = "character_paperdoll" },
            {
                class = CharacterInventory,
                template = "static_grid",
                config = {
                    columns = 7,
                    rows = 12,
                    item_size = 40,
                    spacing = 2,
                    on_double_click = function(index, item)
                        msg.post(".", "item_action", {
                            event = "item_transfer",
                            data = {
                                slot_index = index,
                                item_id = item.item_id
                            }
                        })
                    end
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

function M:init(template_id, player_inventory)
    self.render_order = constants_ui.LAYERS.WINDOW
    self.is_static = false

    BaseWindow.init(self, template_id, {
        on_show = function ()
            self.static_grid:refresh()
        end
    })

    self.toggle = BaseWindow.toggle
    self.is_visible = BaseWindow.is_visible
    self.set_visible = BaseWindow.set_visible
    self.close = BaseWindow.close
    self.set_title  = BaseWindow.set_title
    self.update = BaseWindow.update
    -- self.handle_input_flow = BaseWindow.handle_input_flow
    self.request_refresh = BaseWindow.request_refresh
    self.is_over_window = BaseWindow.is_over_window
    self.handle_hover = BaseWindow.handle_hover

    self.tabs = {}
    self.active_tab = nil

    -- Инициализация вкладок
    for name, cfg in pairs(TABS_CONFIG) do
        local btn_node = gui.get_node(cfg.btn_key)
        local container_node = gui.get_node(cfg.container_key)

        self.tabs[name] = {
            window_title = cfg.window_title,
            btn = btn_node,
            container = container_node,
            modules = {}
        }

        if cfg.sub_components then
            for _, sub in ipairs(cfg.sub_components) do
                local sub_config = sub.config or {}
                if sub.template == "static_grid" then
                    sub_config.data_source = player_inventory
                end

                local instance = self.druid:new(sub.class, sub.template, sub_config)
                table.insert(self.tabs[name].modules, instance)

                -- Сохраняем прямые ссылки для быстрого доступа
                if sub.template == "static_grid" then self.static_grid = instance
                elseif sub.template == "character_paperdoll" then self.paperdoll = instance
                elseif sub.template == "character_stats" then self.character_stats = instance end
            end
        elseif cfg.component then
            local instance = self.druid:new(cfg.component, cfg.template_id)
            table.insert(self.tabs[name].modules, instance)
        end

        -- Кнопка переключения вкладки
        self.druid:new_button(btn_node, function() self:switch_tab(name) end)
    end

    -- Настройка визуала
    gui.set_size(self.body, vmath.vector3(TOTAL_WIDTH, WINDOW_HEIGHT, 0))
    gui.set_size(self.header, vmath.vector3(TOTAL_WIDTH, 80, 0))

    self.modules = {
        self.static_grid,
        self.paperdoll,
        self.character_stats
    }

    self:switch_tab("character")
    self:set_visible(false)
end

function M:switch_tab(tab_name)
    local active_tab_data = self.tabs[tab_name]
    if not active_tab_data then return end

    self.set_title(self, locales.get(active_tab_data.window_title) or "No Title")

    for name, tab in pairs(self.tabs) do
        local is_active = (name == tab_name)
        gui.set_enabled(tab.container, is_active)

        for _, module in ipairs(tab.modules) do
            module:set_visible(is_active)
        end

        local color = is_active and vmath.vector4(1, 1, 0.6, 1) or vmath.vector4(0.8, 0.8, 0.8, 1)
        gui.set_color(tab.btn, color)
    end

    self.active_tab = tab_name
end

function M:refresh_all()
    if self.static_grid then
        self.static_grid:refresh()
    end

    if self.paperdoll then
       self.paperdoll:refresh()
    end

    if self.character_stats then
        self.character_stats:update_display()
    end
end

function M:update_all_displays()
    -- Проходим по всем вкладкам, которые мы создали в init
    for name, tab in pairs(self.tabs) do
        -- Проходим по всем модулям (статы, кукла, грид) внутри вкладки
        for _, module in ipairs(tab.modules) do
            -- Если у модуля есть метод обновления текста/визуала - вызываем
            if module.update_display then
                module:update_display()
            end
        end
    end
end

function M:get_slot_at_position(x, y)
    if self.static_grid and self.active_tab == "character" then
        return self.static_grid:get_slot_at_position(x, y)
    end
    return nil
end

return M
