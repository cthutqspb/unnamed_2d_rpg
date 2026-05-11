local druid = require("druid.druid")
local player_inv = require("main.modules.player.player_inventory")
local gui_utils = require("main.gui.gui_utils")
local items_db = require("main.modules.data.items_db")
local ItemTransfer = require("main.modules.item_transfer_manager")
local drag_manager = require("main.gui.components.managers.drag_manager")
local tooltip_manager = require("main.gui.components.managers.tooltip_manager")

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
              
            -- d:new_hover(slot_root, 
            --     -- Функция 1: МЫШЬ ЗАШЛА (OnEnter)
            --     function()
            --         print("ENTERED SLOT:")
            --         local item_data = self:get_data_source().items[i]
            --         if item_data and item_data.item_id and not drag_manager.is_dragging() then
            --             print("TOOLTIP: SHOW for slot", i)
            --             tooltip_manager.show("item", item_data.item_id)
            --         end
            --     end,
            --     -- Функция 2: МЫШЬ УШЛА (OnLeave)
            --     function() 
            --         print("TOOLTIP: HIDE for slot", i)
            --         tooltip_manager.hide()
            --     end
            -- )

            local drag = d:new_drag(slot_root, function(ctx, dx, dy)
          
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
    -- 1. Получаем данные предмета
    local item_data = self:get_data_source().items[index]
    if not item_data or not item_data.item_id then return end
    
    local data = items_db.get_item(item_data.item_id)

    -- 2. Просто уведомляем менеджер, ЧТО мы тащим
    -- Нам не нужно создавать ноды, менеджер скажет drag_layer.gui, что отрисовать
    print('DRAG START', data.texture, data.animation)
    drag_manager.start(self, index, item_data, data.texture, hash(data.animation))

    -- 3. Скрываем оригинал в слоте
    gui.set_enabled(self.slots[index].icon, false)
    gui.set_enabled(self.slots[index].count, false)
    
    -- НИКАКИХ gui.clone_tree, gui.set_parent и gui.set_render_order здесь больше не нужно!
end
--
-- function M.on_item_drag_start(self, index)
--     gui.set_render_order(15)
--     local item_data = self:get_data_source().items[index]
--     if not item_data or not item_data.item_id then return end
--     
--     local data = items_db.get_item(item_data.item_id)
--     -- Создаём клон
--     local template_id = gui.get_id(self.drag_template) -- Получаем ID оригинала (уже хэшированный)
--     local cloned_nodes = gui.clone_tree(self.drag_template)
--     local drag_clone = cloned_nodes[template_id] 
--     
--     if not drag_clone then
--         for _, node in pairs(cloned_nodes) do
--             drag_clone = node
--             break
--         end
--     end
--     
--     self.current_drag_clone = drag_clone
--     gui.set_parent(drag_clone, self.root)
--     
--     local root_x, root_y = gui_utils.get_screen_position(self.root)
--     gui.set_texture(drag_clone, data.texture)
--     gui.play_flipbook(drag_clone, hash(data.animation))
--     gui.set_size(drag_clone, vmath.vector3(self.item_size, self.item_size, 0))
--     gui.set_color(drag_clone, vmath.vector4(1, 1, 1, 1))
--     gui.set_position(drag_clone, vmath.vector3(self.mouse_x - root_x, self.mouse_y - root_y, 1))
--     gui.set_enabled(drag_clone, true)
--     
--     -- Запускаем драг в менеджере
--     -- drag_manager.start(self, index, item_data, drag_clone, self.root)
--     drag_manager.start(self, index, item_data, data.texture, hash(data.animation))
--
--     -- Скрываем оригинал
--     gui.set_enabled(self.slots[index].icon, false)
--     gui.set_enabled(self.slots[index].count, false)
-- end

function M.on_item_drag(self, index, dx, dy)
    print("on_item_drag called", dx, dy)
    self.mouse_x = self.mouse_x + dx
    self.mouse_y = self.mouse_y + dy
    drag_manager.update(self.mouse_x, self.mouse_y)
end

function M.on_item_drag_end(self, index)
    msg.post("world", "drag_end")
    self.dragging_index = nil
    -- Драг завершится в hud.gui_script
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
    local items = self:get_data_source().items
    local item = items[index]
    if item and item.item_id then
        print("Click on slot:", index, "Item:", item.item_id)
    else
        print("Click on empty slot:", index)
    end
end

function M.get_slot_at_position(self, screen_x, screen_y)
    
    local container_screen_x, container_screen_y = gui_utils.get_screen_position(self.container)
    
    local local_x = screen_x - container_screen_x
    local local_y = screen_y - container_screen_y
    
    for i, slot in ipairs(self.slots) do
        local slot_pos = gui.get_position(slot.root)
        local slot_size = gui.get_size(slot.root)
        
        local left = slot_pos.x - slot_size.x/2
        local right = slot_pos.x + slot_size.x/2
        local bottom = slot_pos.y - slot_size.y/2
        local top = slot_pos.y + slot_size.y/2
        
        
        if local_x >= left and local_x <= right and local_y >= bottom and local_y <= top then
            print("HIT slot", i)
            return i
        end
    end
    
    return nil
end

function M.is_mouse_over_any_gui(self, mouse_x, mouse_y)
    local ui_windows = {
        "character_window/root",
        "container_window/root",
        "inventory/root",
        "action_bar/root"
    }

    for _, path in ipairs(ui_windows) do
        local ok, node = pcall(gui.get_node, path)
        if ok and node and gui.is_enabled(node) and gui.pick_node(node, mouse_x, mouse_y) then
            return true
        end
    end
    return false
end

return M
