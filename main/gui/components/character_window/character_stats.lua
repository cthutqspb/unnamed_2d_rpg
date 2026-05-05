local component = require("druid.component")
local character_data = require("main.modules.character.character_data")
local config = require("main.modules.character.character_config")
local strings = require("main.modules.strings")

local CharacterStats = component.create("CharacterStats")

function CharacterStats:init(template_id)
    print("DEBUG: MY TEMPLATE ID IS:", template_id)
    -- Эта команда выведет в консоль список ВООБЩЕ ВСЕХ доступных нод прямо сейчас:
    -- pprint(gui.get_node(".")) 
     self.template_id = template_id
    -- Корневая нода самого компонента (обычно это root в stats.gui)
    self.root = gui.get_node(template_id .. "/root")

    -- Получаем ноды относительно шаблона
    self.player_name_node = gui.get_node(template_id .. "/player_name_text")
    self.player_race_node = gui.get_node(template_id .. "/player_race_text")
    self.player_class_node = gui.get_node(template_id .. "/player_class_text")
    self.player_level_node = gui.get_node(template_id .. "/player_level_text")

    -- Аналогично для остальных...
    
        
    self:update_display()
    print("CharacterStats initialized")
end

function CharacterStats:update_display()
    local player = character_data.player
    
    gui.set_text(self.player_name_node, player.name)
    gui.set_text(self.player_race_node, player.race)
    gui.set_text(self.player_class_node, player.class)
    gui.set_text(self.player_level_node, player.level)
    
    -- -- Характеристики
    -- for stat_id, value in pairs(player.stats) do
    --     local stat_name = strings.get(config.stats[stat_id].name_key)
    --     gui.set_text(self.root .. "/stat_" .. stat_id .. "_name", stat_name)
    --     gui.set_text(self.root .. "/stat_" .. stat_id .. "_value", tostring(value))
    -- end
end

function CharacterStats:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:update_display() -- обновляем при показе
    end
end

return CharacterStats
