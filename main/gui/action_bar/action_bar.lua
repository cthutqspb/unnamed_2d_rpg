local component = require("druid.component")
local layout = require("druid.extended.layout") -- Проверь путь в Assets

local ActionBar = component.create("action_bar")

function ActionBar:init(template_id)
    self.template_id = template_id or "action_bar"
    local d = self:get_druid()
    
    local container_id = self.template_id .. "/container"
    
    -- 1. Создаем Layout (тип "horizontal" строкой, как в примере)
    self.layout = d:new(layout, container_id, "horizontal")
    self.layout.is_resize_width = true
    self.layout.is_resize_height = true
    -- 2. Настраиваем отступы (padding и margin)
    -- Согласно примеру, set_margin принимает (x, y)
    self.layout:set_padding(4, 4, 4, 4)
    self.layout:set_margin(4, 4)

    -- 3. Список кнопок
    local buttons = { "button_inventory", "button_character" }
    
    for _, id in ipairs(buttons) do
        local path = self.template_id .. "/" .. id .. "/root"
        local node = gui.get_node(path)
        
        d:new_button(node, function() 
        print("Клик: " .. id) -- Этот принт ты видишь
        
        -- ДОБАВЬ ЭТО:
        if id == "button_inventory" then
            msg.post(".", "toggle_inventory") -- "." означает "отправить скрипту этого же объекта"
        end
    end)

        -- Добавляем в Layout
        self.layout:add(node)
    end

    -- 4. ВАЖНО: Вызываем метод обновления из примера!
    if self.layout.refresh_layout then
        self.layout:refresh_layout()
    end
end

function ActionBar:visual_push(button_id)
    -- Если у нас есть ссылка на кнопку, мы можем заставить её "нажаться"
    -- Но проще всего вызвать функцию клика напрямую через сообщение
end

return ActionBar
-- local component = require("druid.component")
-- -- Подключаем класс сетки напрямую из папки base
-- local static_grid = require("druid.base.static_grid") 
--
-- local ActionBar = component.create("action_bar")
--
-- function ActionBar:init(template_id)
--     self.template_id = template_id or "action_bar"
--     local d = self:get_druid()
--     
--     local button_list = {
--         { id = "button_inventory" },
--         { id = "button_character" },
--     }
--
--     -- ПУТИ СТРОКАМИ
--     local parent_id = self.template_id .. "/container"
--     local prefab_id = self.template_id .. "/button_inventory/root"
--
--     -- ВАЖНО: Вместо d:new_static_grid (которого нет в объекте)
--     -- используем d:new() и передаем импортированный класс static_grid
--     local columns_count = #button_list
--
--     self.grid = d:new(static_grid, parent_id, prefab_id, columns_count)
--      
--     -- 1. Устанавливаем размер ячейки
--     self.grid:set_item_size(16 + 4, 20)
--     
--     -- 2. Вместо set_offset (которого нет) используем set_pivot или просто пропустим это.
--     -- В Druid Static Grid обычно есть метод set_anchor.
--     if self.grid.set_anchor then
--         self.grid:set_anchor(vmath.vector3(1, 0.5, 0)) 
--     end
--
--     -- Если нам нужно сместить кнопки, чтобы они не торчали из угла, 
--     -- лучше просто подвинуть саму ноду container в редакторе на (-12, 8).
--     
--     -- 3. Добавление кнопок
--     
--     for _, btn in ipairs(button_list) do
--         local path = self.template_id .. "/" .. btn.id .. "/root"
--         local node = gui.get_node(path)
--         
--         d:new_button(node, function() print("Клик по " .. btn.id) end)
--         self.grid:add(node)
--     end  
--
-- end
--
-- return ActionBar
