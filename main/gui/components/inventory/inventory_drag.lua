local player_inv = require("main.modules.player_inventory")
local gui_utils = require("main.gui.gui_utils")
local items_db = require("main.modules.items_db")
local ItemTransfer = require("main.modules.item_transfer_manager")

local M = {}

function M.init(self, d)
    self.dragging_index = nil
    self.mouse_x = 0
    self.mouse_y = 0
    
    -- msg.post("@render:", "acquire_input_focus")
end

function M.create_slots(self)
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
            local btn = d:new_button(slot_root, function() M.on_slot_click(self, i) end)
            
            local drag = d:new_drag(slot_root, function(ctx, dx, dy)
                if self.dragging_index then
                    M.on_item_drag(self, self.dragging_index, dx, dy)
                end
            end)
            
            drag.is_touch_threshold = false 
            btn.click_zone = slot_root

            if drag.set_input_priority then
                drag:set_input_priority(100)
            end

            drag.on_drag_start:subscribe(function()
                M.on_item_drag_start(self, i)
            end)
            
            drag.on_drag_end:subscribe(function()
                M.on_item_drag_end(self, i)
            end)
          
            table.insert(self.slots, {
                root  = slot_root,
                icon  = nodes[icon_id],
                count = nodes[count_id],
                button = btn,
                drag = drag
            })
            
            gui.set_enabled(slot_icon, false)
            gui.set_enabled(slot_count, false)
        end
    end
end

function M.update_slot_visual(self, slot_index, item_id, amount)
    local slot = self.slots[slot_index]
    if not slot then return end

    local data = items_db.get_item(item_id)
    if data then
        gui.set_enabled(slot.icon, true)
        gui.set_color(slot.icon, data.color)
        if data.texture then gui.set_texture(slot.icon, data.texture) end
        gui.play_flipbook(slot.icon, hash(data.animation))

        if amount and amount > 1 then
            gui.set_enabled(slot.count, true)
            gui.set_text(slot.count, tostring(amount))
        else
            gui.set_enabled(slot.count, false)
        end
    end
end

function M.on_input(self, action_id, action)
    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
    end
end

function M.on_item_drag_start(self, index)
    msg.post("world", "drag_start")
    local item_data = self:get_data_source().items[index]
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
    local root_x, root_y = gui_utils.get_screen_position(self.root)
    
    -- Вычисляем относительную позицию для drag_clone
    local local_x = self.mouse_x - root_x
    local local_y = self.mouse_y - root_y
    
    -- Настраиваем внешний вид
    gui.set_texture(self.drag_clone, data.texture)
    gui.play_flipbook(self.drag_clone, hash(data.animation))
    gui.set_size(self.drag_clone, vmath.vector3(self.item_size, self.item_size, 0))
    gui.set_color(self.drag_clone, vmath.vector4(1, 1, 1, 1))
    
    -- Ставим под курсор (с учетом позиции root)
    gui.set_position(self.drag_clone, vmath.vector3(local_x, local_y, 1))
    gui.set_enabled(self.drag_clone, true)
    
    -- Скрываем оригинал
    gui.set_enabled(self.slots[index].icon, false)
    gui.set_enabled(self.slots[index].count, false)
end

function M.on_item_drag(self, index, dx, dy)
    if not self.dragging_index or not self.drag_clone then return end
    
    -- Также пересчитываем при движении
    local root_x, root_y = gui_utils.get_screen_position(self.root)
    local local_x = self.mouse_x - root_x
    local local_y = self.mouse_y - root_y
    
    gui.set_position(self.drag_clone, vmath.vector3(local_x, local_y, 1))
    -- msg.post("/gui_manager", "refresh_inventories")
end

function M.on_item_drag_end(self, index)
    msg.post("world", "drag_end")
    if not self.dragging_index then return end
    
    local target = M.get_slot_at_position(self, self.mouse_x, self.mouse_y)
    local is_over_world = not M.is_mouse_over_any_gui(self)
    
    if is_over_world then
        -- Выброс в мир
        ItemTransfer.transfer(self, self.dragging_index, "world", nil, self.mouse_x, self.mouse_y)
        self:refresh()
        
    elseif target and target.slot ~= index then
        -- Попали в слот
        if target.component ~= self then
            -- Перетаскивание между разными инвентарями
            ItemTransfer.transfer(
                self,
                self.dragging_index,
                "inventory",
                {
                    items = target.component:get_data_source().items,
                    slot = target.slot,
                    component = target.component
                },
                nil, nil
            )
        else
            -- Свап внутри одного инвентаря
            local data_source = self:get_data_source()
            if data_source.swap_slots then
                data_source.swap_slots(self.dragging_index, target.slot)
            else
                -- Простой обмен, если нет метода swap_slots
                local temp = data_source.items[self.dragging_index]
                data_source.items[self.dragging_index] = data_source.items[target.slot]
                data_source.items[target.slot] = temp
            end
            self:refresh()
        end
    else
        -- Возврат на место (ничего не делаем, просто обновляем визуал)
        self:refresh()
    end
    
    -- Удаляем клон иконки
    if self.drag_clone then
        gui.delete_node(self.drag_clone)
        self.drag_clone = nil
    end
    msg.post("/gui_manager", "refresh_inventories")
    self.dragging_index = nil
end

-- ОЧИСТИТЬ ВИЗУАЛ СЛОТА
function M.clear_slot_visual(self, slot_index)
    local slot = self.slots[slot_index]
    if slot then
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.count, false)
    end
end

function M.on_slot_click(self, index)
    print("Click on slot:", index, "Item:", self:get_data_source().items[index].item_id)
end

function M.get_slot_at_position(self, screen_x, screen_y)
    -- Получаем экранную позицию container
    local container_screen_x, container_screen_y = gui_utils.get_screen_position(self.container)
    
    -- Переводим в локальные координаты container
    local local_x = screen_x - container_screen_x
    local local_y = screen_y - container_screen_y
    
    -- Проверяем попадание в слоты
    for i, slot in ipairs(self.slots) do
        local slot_pos = gui.get_position(slot.root)
        local slot_size = gui.get_size(slot.root)
        
        local left = slot_pos.x - slot_size.x/2
        local right = slot_pos.x + slot_size.x/2
        local bottom = slot_pos.y - slot_size.y/2
        local top = slot_pos.y + slot_size.y/2
        
        if local_x >= left and local_x <= right and local_y >= bottom and local_y <= top then
            return { component = self, slot = i }
        end
    end
    
    return nil
end

function M.is_mouse_over_any_gui(self)
    -- Список нод, которые реально являются окнами или панелями
    local ui_windows = {
        "character_window/root", -- Фон окна персонажа
        "container_window/root",
        "inventory/root",         -- Фон сумки
        "action_bar/root"         -- Твоя панель навыков     
    }

    for _, path in ipairs(ui_windows) do
        local ok, node = pcall(gui.get_node, path)
        -- Проверяем: окно открыто (enabled) и мышь над ним
        if ok and gui.is_enabled(node) and gui.pick_node(node, self.mouse_x, self.mouse_y) then
            return true -- Не выкидываем!
        end
    end

    return false -- Если мышь не над окнами — выкидываем в мир
end

return M
