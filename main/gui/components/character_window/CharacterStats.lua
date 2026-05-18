local component = require("druid.component")
local character_data = require("main.modules.character.character_data")

---@class CharacterStats : druid.component
---@field template_id string
local M = component.create("CharacterStats")

function M:init(template_id)
    self.template_id = template_id
    self.root = gui.get_node(template_id .. "/root")

    local function get_node(name)
        return gui.get_node(template_id .. "/" .. name)
    end

    self.nodes = {
        name = get_node("player_name_text"),
        race = get_node("player_race_text"),
        class = get_node("player_class_text"),
        level = get_node("player_level_text"),
        health = get_node("player_health_text")
    }

    -- Динамически собираем ноды статов на основе данных из модуля
    self.stat_nodes = {}
    for stat_id, _ in pairs(character_data.player.stats) do
        local path = template_id .. "/player_" .. stat_id .. "_text"
        -- Проверяем наличие ноды один раз при инициализации
        local ok, node = pcall(gui.get_node, path)
        if ok then
            self.stat_nodes[stat_id] = node
        end
    end

    self:update_display()
end

function M:update_display()
  print("STATS")
    local player = character_data.player

    gui.set_text(self.nodes.name, player.name)
    gui.set_text(self.nodes.race, player.race)
    gui.set_text(self.nodes.class, player.class)
    gui.set_text(self.nodes.level, tostring(player.level))
    gui.set_text(self.nodes.health, player.health .. " / " .. player.max_health)
    
    -- Обновляем только те статы, для которых нашлись ноды в GUI
    for stat_id, node in pairs(self.stat_nodes) do
        ---@type number, number
        local current = player.current_stats[stat_id] or 0
        local base = player.stats[stat_id] or 0
        local bonus = current - base

        if bonus > 0 then
            gui.set_text(node, current .. " (" .. base .. "+" .. bonus .. ")")
        else
            gui.set_text(node, tostring(current))
        end
    end
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:update_display()
    end
end

return M


-- local component = require("druid.component")
-- local character_data = require("main.modules.character.character_data")
-- -- local config = require("main.modules.character.character_config")
--
-- ---@class CharacterStats : druid.component
-- local M = component.create("CharacterStats")
--
-- function M:init(template_id)
--     self.template_id = template_id
--     self.root = gui.get_node(template_id .. "/root")
--
--     -- Хелпер для получения нод внутри шаблона
--     local function get_node(name)
--         return gui.get_node(template_id .. "/" .. name)
--     end
--
--     -- Основная инфо
--     self.nodes = {
--         name = get_node("player_name_text"),
--         race = get_node("player_race_text"),
--         class = get_node("player_class_text"),
--         level = get_node("player_level_text"),
--         health = get_node("player_health_text")
--     }
--
--     self:update_display()
-- end
--
-- function M:update_display()
--     local player = character_data.player
--
--     -- Обновляем базовые текстовые поля
--     gui.set_text(self.nodes.name, player.name)
--     gui.set_text(self.nodes.race, player.race)
--     gui.set_text(self.nodes.class, player.class)
--     gui.set_text(self.nodes.level, tostring(player.level))
--     gui.set_text(self.nodes.health, player.health .. " / " .. player.max_health)
--
--     -- Обновляем характеристики (сила, ловкость и т.д.)
--     for stat_id, current_value in pairs(player.current_stats) do
--         local path = self.template_id .. "/player_" .. stat_id .. "_text"
--
--         -- Используем pcall только для проверки существования ноды
--         local ok, node = pcall(gui.get_node, path)
--         if ok then
--             local base_value = player.stats[stat_id] or 0
--             local bonus = current_value - base_value
--
--             if bonus > 0 then
--                 gui.set_text(node, current_value .. " (" .. base_value .. "+" .. bonus .. ")")
--             else
--                 gui.set_text(node, tostring(current_value))
--             end
--         end
--     end
-- end
--
-- function M:set_visible(visible)
--     gui.set_enabled(self.root, visible)
--     if visible then
--         self:update_display()
--     end
-- end
--
-- return M
--
