local component = require("druid.component")
local context_db = require("main.modules.data.context_menu_db")
local strings = require("main.modules.data.strings")

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

function M:show(x, y, type, data)
    -- Очистка старого
    for _, nodes in ipairs(self.nodes_cache) do
        for _, node in pairs(nodes) do gui.delete_node(node) end
    end
    self.nodes_cache = {}
    
    -- Наполнение
    local actions = context_db.get_actions(type)
    gui.set_enabled(self.root, true)
    gui.set_position(self.root, vmath.vector3(x, y, 0))
    
    -- Подгоняем фон (высота кнопки 40)
    gui.set_size(self.background, vmath.vector3(240, #actions * 24, 0))

    for i, action in ipairs(actions) do
        local nodes = gui.clone_tree(self.action_field)
        local btn = nodes[hash("action_field")]
        local txt = nodes[hash("action_text")]
        
        gui.set_enabled(btn, true)
        gui.set_text(txt, strings.get(action.name_key))
        gui.set_position(btn, vmath.vector3(0, -(i-1) * 40, 0))
        
        self.druid:new_button(btn, function()
            -- Шлем сигнал тому, кто вызвал (например, в world.script)
            msg.post("/gui_manager#hud", "context_action", { event = action.event, data = data })
            self:hide()
        end)
        
        table.insert(self.nodes_cache, nodes)
    end
end

function M:hide()
    gui.set_enabled(self.root, false)
end

return M

