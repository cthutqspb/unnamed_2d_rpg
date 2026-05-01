local component = require("druid.component")
local character_data = require("main.modules.character_data")
local config = require("main.modules.character_config")
local strings = require("main.modules.strings")

local CharacterJournal = component.create("CharacterJournal")

function CharacterJournal:init(template_id)
    self.template_id = template_id
    -- Корневая нода самого компонента (обычно это root в stats.gui)
    self.root = gui.get_node(template_id .. "/root")
        
    self:update_display()
    print("CharacterJournal initialized")
end

function CharacterJournal:update_display()
    
end

function CharacterJournal:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:update_display() -- обновляем при показе
    end
end

return CharacterJournal

