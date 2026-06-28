local component = require("druid.component")
local locales = require("main.modules.data.locales.locale_manager")

---@class CharacterJournal : druid.component
---@field template_id string
local M = component.create("CharacterJournal")

function M:init(template_id)
    self.template_id = template_id
    -- Корневая нода самого компонента (обычно это root в stats.gui)
    self.root = gui.get_node(template_id .. "/root")
        
    self:update_display()
    print("CharacterJournal initialized")
end

function M:update_display()
    
end

function M:set_visible(visible)
    gui.set_enabled(self.root, visible)
    if visible then
        self:update_display() -- обновляем при показе
    end
end

return M

