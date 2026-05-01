local component = require("druid.component")
local CharacterPaperdoll = component.create("CharacterPaperdoll")

function CharacterPaperdoll:init(template_id)
     -- template_id — это строка "character_window/character_equipment"
    self.template_id = template_id 
    
    -- Получаем саму ноду. 
    -- Замени "/root" на ID самой верхней ноды в твоем character_equipment.gui
    self.root = gui.get_node(template_id .. "/root") 
    
    print("CharacterPaperdoll initialized")
end

function CharacterPaperdoll:set_visible(visible)
    gui.set_enabled(self.root, visible)
    
    if visible and self.update_display then
        self:update_display()
    end   
end

return CharacterPaperdoll
