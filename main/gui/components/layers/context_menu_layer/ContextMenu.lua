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

function M:show(x, y, type, sub_type, can_split, data)
    print('SHOW', type, sub_type, can_split, data)
    -- 1. ПРАВИЛЬНАЯ ОЧИСТКА
    for _, entry in ipairs(self.nodes_cache) do
        -- Удаляем компонент из Друида, чтобы он перестал слушать инпут
        self.druid:remove(entry.btn) 
        -- Теперь удаляем ноды
        for _, node in pairs(entry.nodes) do 
            gui.delete_node(node) 
        end
    end
    self.nodes_cache = {}

    self.current_data = data
    
    local actions = context_db.get_actions(type, sub_type, can_split)
    gui.set_enabled(self.root, true)
    gui.set_position(self.root, vmath.vector3(x, y, 1)) -- Z на 1, чтобы быть выше
    
    -- Исправляем размер фона (шаг 40)
    gui.set_size(self.background, vmath.vector3(240, #actions * 40 + 10, 0))

    for i, action in ipairs(actions) do
        local nodes = gui.clone_tree(self.action_field)
        local btn_node = nodes[hash("action_field")]
        local txt_node = nodes[hash("action_text")]
        
        gui.set_enabled(btn_node, true)
        gui.set_text(txt_node, strings.get(action.name_key))
        gui.set_position(btn_node, vmath.vector3(0, -(i-1) * 40, 0))
        
         -- ЗАХВАТ ДАННЫХ: создаем локальную копию для колбэка
        local current_action_event = action.event
        local current_item_data = data 
        local source_url = data.source_url -- Тот самый URL, который мы передали из инвентаря
        -- Создаем кнопку и сохраняем ссылку на инстанс
        local btn_instance = self.druid:new_button(btn_node, function()
            print('CLICK CONTEXT', source_url)
            msg.post(source_url, "context_menu_action", { event = action.event, data = data })
            self:hide()
        end)
        
        -- Кэшируем всё вместе для последующего удаления
        table.insert(self.nodes_cache, { nodes = nodes, btn = btn_instance })
    end
end


function M:hide()
    gui.set_enabled(self.root, false)
end

-- В ContextMenu.lua

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

