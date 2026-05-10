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
    self.player_health_node = gui.get_node(template_id .. "/player_health_text")
    -- Аналогично для остальных...
    self.player_strength_node = gui.get_node(template_id .. "/player_strength_text")
        
    self:update_display()
    print("CharacterStats initialized")
end

function CharacterStats:update_display()
  print("DEBUG: CharacterStats updating visual!")
    local player = character_data.player
    
    gui.set_text(self.player_name_node, player.name)
    gui.set_text(self.player_race_node, player.race)
    gui.set_text(self.player_class_node, player.class)
    gui.set_text(self.player_level_node, player.level)
    gui.set_text(self.player_health_node, player.health)

    gui.set_text(self.player_health_node, player.health .. " / " .. player.max_health)
    -- -- Характеристики
    
     for stat_id, value in pairs(player.current_stats) do
        local path = self.template_id .. "/player_" .. stat_id .. "_text"
        print("DEBUG STAT:", stat_id, "VALUE:", value, "PATH:", path)
        
        -- Попытаемся получить ноду через pcall, чтобы увидеть ошибку, если она есть
        local ok, node = pcall(gui.get_node, path)
        if ok then
            print("NODE FOUND!")
            local base = player.stats[stat_id] or 0
            local bonus = value - base
            if bonus > 0 then
                gui.set_text(node, value .. " (" .. base .. "+" .. bonus .. ")")
            else
                gui.set_text(node, tostring(value))
            end
        else
            print("NODE NOT FOUND:", path)
        end
    end    
end

function CharacterStats:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:update_display() -- обновляем при показе
    end
end

return CharacterStats
