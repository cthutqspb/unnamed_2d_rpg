local component = require("druid.component")
local static_grid = require("druid.base.static_grid")
local strings = require("main.modules.strings")
local items_db = require("main.modules.items_db")

local Inventory = component.create("Inventory")

function Inventory:init(template_id)
    self.template_id = template_id
    local d = self:get_druid()

    self.root = gui.get_node(template_id .. "/root")
    self.header = gui.get_node(template_id .. "/header")
    self.btn_close = gui.get_node(template_id .. "/icon")
    self.container = gui.get_node(template_id .. "/container")
    
    -- Шаблон для клонирования (должен быть Box с размерами 40x40)
    self.drag_template = gui.get_node(template_id .. "/drag_icon")
    self.drag_clone = nil
    
    -- Для хранения координат мыши
    self.mouse_x = 0
    self.mouse_y = 0

    local title_node = gui.get_node(template_id .. "/title")
    gui.set_text(title_node, strings.get("inventory_title"))
    
    self.columns = 6
    self.rows = 4
    self.item_size = 40
    self.spacing = 4

    self.grid = d:new(static_grid, self.container, template_id .. "/slot_prefab/root", self.columns)
    self.grid:set_item_size(self.item_size + self.spacing, self.item_size + self.spacing) 
    self.grid:set_anchor(vmath.vector3(0, 1, 0))

    self.items_data = {}
    self.dragging_index = nil
    
    self:create_slots()
    
    local screen_w = sys.get_config("display.width")
    local screen_h = sys.get_config("display.height")
    local inv_size = gui.get_size(self.root)
    local target_x = screen_w - (inv_size.x / 2) - 20
    local target_y = 60 + (inv_size.y / 2)
    gui.set_position(self.root, vmath.vector3(target_x, target_y, 0))

    self.drag = d:new_drag(self.header, function(context, dx, dy)
        local pos = gui.get_position(self.root)
        pos.x = pos.x + dx
        pos.y = pos.y + dy
        gui.set_position(self.root, pos)
    end)
    self.drag.is_touch_threshold = true 
    
    d:new_button(self.btn_close, function()
        self:set_visible(false)
    end)
    
    -- Получаем фокус ввода для мыши
    msg.post("@render:", "acquire_input_focus")
    
    -- Скрываем шаблон
    if self.drag_template then
        gui.set_enabled(self.drag_template, false)
    end

    self:set_item(1, "iron_sword", 1)
    self:set_item(2, "crystal_sword", 1)
    self:set_visible(false)
end

-- Получение координат мыши
function Inventory:on_input(action_id, action)
    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
    end
end

function Inventory:create_slots()
    self.slots = {}
    local prefab_path = self.template_id .. "/slot_prefab/root"
    
    for i = 1, self.columns * self.rows do
        local nodes = gui.clone_tree(gui.get_node(prefab_path))
        
        local root_id  = hash(self.template_id .. "/slot_prefab/root")
        local icon_id  = hash(self.template_id .. "/slot_prefab/icon")
        local count_id = hash(self.template_id .. "/slot_prefab/count")

        local slot_root  = nodes[root_id]
        local slot_icon  = nodes[icon_id]
        local slot_count = nodes[count_id]

        if slot_root then
            gui.set_enabled(slot_root, true)
            gui.set_parent(slot_root, self.container)
            
            local p = gui.get_position(slot_root)
            p.z = 0
            gui.set_position(slot_root, p)

            self.grid:add(slot_root)
            
            local d = self:get_druid()
            local btn = d:new_button(slot_root, function() self:on_slot_click(i) end)
            
            local drag = d:new_drag(slot_root, function(ctx, dx, dy)
                if self.dragging_index then
                    self:on_item_drag(self.dragging_index, dx, dy)
                end
            end)
            
            drag.is_touch_threshold = false 
            btn.click_zone = slot_root

            if drag.set_input_priority then
                drag:set_input_priority(100)
            end

            drag.on_drag_start:subscribe(function()
                self:on_item_drag_start(i)
            end)
            
            drag.on_drag_end:subscribe(function()
                self:on_item_drag_end(i)
            end)
          
            table.insert(self.slots, {
                root  = slot_root,
                icon  = nodes[icon_id],
                count = nodes[count_id],
                button = btn,
                drag = drag
            })
            
            self.items_data[i] = {item_id = nil, amount = 0}
            
            gui.set_enabled(slot_icon, false)
            gui.set_enabled(slot_count, false)
        end
    end
end

function Inventory:set_item(slot_index, item_id, amount)
    local slot = self.slots[slot_index]
    if not slot then return end

    local data = items_db.get_item(item_id)
    if data then
        self.items_data[slot_index] = {item_id = item_id, amount = amount or 1}
        
        gui.set_enabled(slot.icon, true)
        gui.set_color(slot.icon, data.color)
        
        if data.texture then
            gui.set_texture(slot.icon, data.texture)
        end
        gui.play_flipbook(slot.icon, hash(data.icon))

        if amount and amount > 1 then
            gui.set_enabled(slot.count, true)
            gui.set_text(slot.count, tostring(amount))
        else
            gui.set_enabled(slot.count, false)
        end
    end
end

function Inventory:clear_slot(slot_index)
    local slot = self.slots[slot_index]
    if slot then
        self.items_data[slot_index] = {item_id = nil, amount = 0}
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.count, false)
    end
end

function Inventory:set_visible(is_visible)
    gui.set_enabled(self.root, is_visible)
end

function Inventory:toggle()
    local current = gui.is_enabled(self.root)
    self:set_visible(not current)
end

function Inventory:on_slot_click(index)
    print("Click on slot:", index, "Item:", self.items_data[index].item_id)
end

function Inventory:on_item_drag_start(index)
    local item_data = self.items_data[index]
    if not item_data or not item_data.item_id then 
        self.dragging_index = nil
        return 
    end

    self.dragging_index = index
    local data = items_db.get_item(item_data.item_id)
    
    -- СОЗДАЕМ КЛОН
    local cloned_nodes = gui.clone_tree(self.drag_template)
    self.drag_clone = cloned_nodes[""] or cloned_nodes[hash("")]
    
    if not self.drag_clone then
        for _, node in pairs(cloned_nodes) do
            self.drag_clone = node
            break
        end
    end
    
    -- Прикрепляем к корню
    gui.set_parent(self.drag_clone, self.root)
    
    -- ВАЖНО: Пересчитываем позицию
    -- Получаем экранную позицию root
    local root_x, root_y = self:get_screen_position(self.root)
    
    -- Вычисляем относительную позицию для drag_clone
    local local_x = self.mouse_x - root_x
    local local_y = self.mouse_y - root_y
    
    -- Настраиваем внешний вид
    gui.set_texture(self.drag_clone, data.texture)
    gui.play_flipbook(self.drag_clone, hash(data.icon))
    gui.set_size(self.drag_clone, vmath.vector3(self.item_size, self.item_size, 0))
    gui.set_color(self.drag_clone, vmath.vector4(1, 1, 1, 1))
    
    -- Ставим под курсор (с учетом позиции root)
    gui.set_position(self.drag_clone, vmath.vector3(local_x, local_y, 1))
    gui.set_enabled(self.drag_clone, true)
    
    -- Скрываем оригинал
    gui.set_enabled(self.slots[index].icon, false)
    gui.set_enabled(self.slots[index].count, false)
end

function Inventory:on_item_drag(index, dx, dy)
    if not self.dragging_index or not self.drag_clone then return end
    
    -- Также пересчитываем при движении
    local root_x, root_y = self:get_screen_position(self.root)
    local local_x = self.mouse_x - root_x
    local local_y = self.mouse_y - root_y
    
    gui.set_position(self.drag_clone, vmath.vector3(local_x, local_y, 1))
end

-- Функция для получения экранной позиции
function Inventory:get_screen_position(node)
    local x, y = 0, 0
    local current = node
    
    while current do
        local pos = gui.get_position(current)
        x = x + pos.x
        y = y + pos.y
        current = gui.get_parent(current)
    end
    
    return x, y
end

function Inventory:on_item_drag_end(index)
    if not self.dragging_index then return end
    
    -- Получаем целевой слот под курсором
    local target_slot = self:get_slot_at_position(self.mouse_x, self.mouse_y)
    
    if target_slot and target_slot ~= index then
        -- Меняем предметы местами
        local source_data = self.items_data[index]
        local target_data = self.items_data[target_slot]
        
        -- Обмениваем данные
        self.items_data[index] = target_data
        self.items_data[target_slot] = source_data
        
        -- Обновляем UI
        if source_data and source_data.item_id then
            self:set_item(target_slot, source_data.item_id, source_data.amount)
        else
            self:clear_slot(target_slot)
        end
        
        if target_data and target_data.item_id then
            self:set_item(index, target_data.item_id, target_data.amount)
        else
            self:clear_slot(index)
        end
    else
        -- Возвращаем предмет на место
        local source_index = self.dragging_index
        local item_data = self.items_data[source_index]
        if item_data and item_data.item_id then
            self:set_item(source_index, item_data.item_id, item_data.amount)
        end
    end
    
    -- Удаляем клон
    if self.drag_clone then
        gui.delete_node(self.drag_clone)
        self.drag_clone = nil
    end
    
    self.dragging_index = nil
end

function Inventory:get_slot_at_position(screen_x, screen_y)
    -- Получаем экранную позицию container
    local container_screen_x, container_screen_y = self:get_screen_position(self.container)
    
    -- Переводим в локальные координаты container
    local local_x = screen_x - container_screen_x
    local local_y = screen_y - container_screen_y
    
    -- Проверяем попадание в слоты (ручная проверка вместо gui.pick_node)
    for i, slot in ipairs(self.slots) do
        local slot_pos = gui.get_position(slot.root)
        local slot_size = gui.get_size(slot.root)
        
        local left = slot_pos.x - slot_size.x/2
        local right = slot_pos.x + slot_size.x/2
        local bottom = slot_pos.y - slot_size.y/2
        local top = slot_pos.y + slot_size.y/2
        
        if local_x >= left and local_x <= right and local_y >= bottom and local_y <= top then
            return i
        end
    end
    
    return nil
end

function Inventory:get_screen_position(node)
    local x, y = 0, 0
    local current = node
    
    while current do
        local pos = gui.get_position(current)
        x = x + pos.x
        y = y + pos.y
        current = gui.get_parent(current)
    end
    
    return x, y
end

return Inventory


-- local component = require("druid.component")
-- local static_grid = require("druid.base.static_grid")
-- local strings = require("main.modules.strings")
-- local items_db = require("main.modules.items_db")
--
-- local Inventory = component.create("Inventory")
--
-- function Inventory:init(template_id)
--     self.template_id = template_id
--     local d = self:get_druid()
--
--     self.root = gui.get_node(template_id .. "/root")
--     self.header = gui.get_node(template_id .. "/header")
--     self.btn_close = gui.get_node(template_id .. "/icon")
--     self.container = gui.get_node(template_id .. "/container")
--     
--     self.drag_clone = nil
--     self.mouse_x = 0
--     self.mouse_y = 0
--
--     local title_node = gui.get_node(template_id .. "/title")
--     gui.set_text(title_node, strings.get("inventory_title"))
--     
--     self.columns = 6
--     self.rows = 4
--     self.item_size = 40
--     self.spacing = 4
--
--     self.grid = d:new(static_grid, self.container, template_id .. "/slot_prefab/root", self.columns)
--     self.grid:set_item_size(self.item_size + self.spacing, self.item_size + self.spacing) 
--     self.grid:set_anchor(vmath.vector3(0, 1, 0))
--
--     self.items_data = {}
--     self.dragging_index = nil
--     
--     self:create_slots()
--     
--     local screen_w = sys.get_config("display.width")
--     local screen_h = sys.get_config("display.height")
--     local inv_size = gui.get_size(self.root)
--     local target_x = screen_w - (inv_size.x / 2) - 20
--     local target_y = 60 + (inv_size.y / 2)
--     gui.set_position(self.root, vmath.vector3(target_x, target_y, 0))
--
--     self.drag = d:new_drag(self.header, function(context, dx, dy)
--         local pos = gui.get_position(self.root)
--         pos.x = pos.x + dx
--         pos.y = pos.y + dy
--         gui.set_position(self.root, pos)
--     end)
--     self.drag.is_touch_threshold = true 
--     
--     d:new_button(self.btn_close, function()
--         self:set_visible(false)
--     end)
--     
--     msg.post("@render:", "acquire_input_focus")
--
--     self:set_item(1, "iron_sword", 1)
--     self:set_visible(false)
-- end
--
-- function Inventory:on_input(action_id, action)
--     if action and action.x and action.y then
--         self.mouse_x = action.x
--         self.mouse_y = action.y
--     end
-- end
--
-- function Inventory:create_slots()
--     self.slots = {}
--     local prefab_path = self.template_id .. "/slot_prefab/root"
--     
--     for i = 1, self.columns * self.rows do
--         local nodes = gui.clone_tree(gui.get_node(prefab_path))
--         
--         local root_id  = hash(self.template_id .. "/slot_prefab/root")
--         local icon_id  = hash(self.template_id .. "/slot_prefab/icon")
--         local count_id = hash(self.template_id .. "/slot_prefab/count")
--
--         local slot_root  = nodes[root_id]
--         local slot_icon  = nodes[icon_id]
--         local slot_count = nodes[count_id]
--
--         if slot_root then
--             gui.set_enabled(slot_root, true)
--             gui.set_parent(slot_root, self.container)
--             
--             local p = gui.get_position(slot_root)
--             p.z = 0
--             gui.set_position(slot_root, p)
--
--             self.grid:add(slot_root)
--             
--             local d = self:get_druid()
--             local btn = d:new_button(slot_root, function() self:on_slot_click(i) end)
--             
--             local drag = d:new_drag(slot_root, function(ctx, dx, dy)
--                 if self.dragging_index then
--                     self:on_item_drag(self.dragging_index, dx, dy)
--                 end
--             end)
--             
--             drag.is_touch_threshold = false 
--             btn.click_zone = slot_root
--
--             if drag.set_input_priority then
--                 drag:set_input_priority(100)
--             end
--
--             drag.on_drag_start:subscribe(function()
--                 self:on_item_drag_start(i)
--             end)
--             
--             drag.on_drag_end:subscribe(function()
--                 self:on_item_drag_end(i)
--             end)
--           
--             table.insert(self.slots, {
--                 root  = slot_root,
--                 icon  = nodes[icon_id],
--                 count = nodes[count_id],
--                 button = btn,
--                 drag = drag
--             })
--             
--             self.items_data[i] = {item_id = nil, amount = 0}
--             
--             gui.set_enabled(slot_icon, false)
--             gui.set_enabled(slot_count, false)
--         end
--     end
-- end
--
-- function Inventory:set_item(slot_index, item_id, amount)
--     local slot = self.slots[slot_index]
--     if not slot then return end
--
--     local data = items_db.get_item(item_id)
--     if data then
--         self.items_data[slot_index] = {item_id = item_id, amount = amount or 1}
--         
--         gui.set_enabled(slot.icon, true)
--         gui.set_color(slot.icon, data.color)
--         
--         if data.texture then
--             gui.set_texture(slot.icon, data.texture)
--         end
--         gui.play_flipbook(slot.icon, hash(data.icon))
--
--         if amount and amount > 1 then
--             gui.set_enabled(slot.count, true)
--             gui.set_text(slot.count, tostring(amount))
--         else
--             gui.set_enabled(slot.count, false)
--         end
--     end
-- end
--
-- function Inventory:clear_slot(slot_index)
--     local slot = self.slots[slot_index]
--     if slot then
--         self.items_data[slot_index] = {item_id = nil, amount = 0}
--         gui.set_enabled(slot.icon, false)
--         gui.set_enabled(slot.count, false)
--     end
-- end
--
-- function Inventory:set_visible(is_visible)
--     gui.set_enabled(self.root, is_visible)
-- end
--
-- function Inventory:toggle()
--     local current = gui.is_enabled(self.root)
--     self:set_visible(not current)
-- end
--
-- function Inventory:on_slot_click(index)
--     print("Click on slot:", index, "Item:", self.items_data[index].item_id)
-- end
--
-- function Inventory:on_item_drag_start(index)
--     local item_data = self.items_data[index]
--     if not item_data or not item_data.item_id then 
--         self.dragging_index = nil
--         return 
--     end
--
--     self.dragging_index = index
--     local data = items_db.get_item(item_data.item_id)
--     
--     -- СОЗДАЕМ НОВУЮ НОДУ НА ЛЕТУ
--     self.drag_clone = gui.new_box_node(
--         vmath.vector3(self.mouse_x, self.mouse_y, 1000),
--         vmath.vector3(self.item_size, self.item_size, 0)
--     )
--     
--     -- Настраиваем внешний вид
--     if data.texture then
--         gui.set_texture(self.drag_clone, data.texture)
--     end
--     gui.play_flipbook(self.drag_clone, hash(data.icon))
--     gui.set_color(self.drag_clone, vmath.vector4(1, 1, 1, 1))
--     gui.set_enabled(self.drag_clone, true)
--     
--     -- Скрываем оригинал
--     gui.set_enabled(self.slots[index].icon, false)
--     gui.set_enabled(self.slots[index].count, false)
-- end
--
-- function Inventory:on_item_drag(index, dx, dy)
--     if not self.dragging_index or not self.drag_clone then return end
--     
--     local pos = gui.get_position(self.drag_clone)
--     gui.set_position(self.drag_clone, vmath.vector3(pos.x + dx, pos.y + dy, 1))
-- end
--
-- function Inventory:on_item_drag_end(index)
--     if not self.dragging_index then return end
--     
--     -- Удаляем временную ноду
--     if self.drag_clone then
--         gui.delete_node(self.drag_clone)
--         self.drag_clone = nil
--     end
--     
--     -- Восстанавливаем оригинал
--     local source_index = self.dragging_index
--     local item_data = self.items_data[source_index]
--     if item_data and item_data.item_id then
--         self:set_item(source_index, item_data.item_id, item_data.amount)
--     end
--     
--     self.dragging_index = nil
-- end
--
-- return Inventory
