local player_inv = require("main.modules.player_inventory")
local DragModule = require("main.gui.components.inventory.inventory_drag")
local items_db = require("main.modules.items_db")

local M = {}

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
            local btn = d:new_button(slot_root, function() self:on_slot_click(i) end)
            
            local drag = d:new_drag(slot_root, function(ctx, dx, dy)
                if self.dragging_index then
                    DragModule.on_item_drag(self, self.dragging_index, dx, dy)
                end
            end)
            
            drag.is_touch_threshold = false 
            btn.click_zone = slot_root

            if drag.set_input_priority then
                drag:set_input_priority(100)
            end

            drag.on_drag_start:subscribe(function()
                DragModule.on_item_drag_start(self, i)
            end)
            
            drag.on_drag_end:subscribe(function()
                DragModule.on_item_drag_end(self, i)
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

function M.set_item(self, slot_index, item_id, amount)
    local slot = self.slots[slot_index]
    if not slot then return end
    
    player_inv.items[slot_index] = { item_id = item_id, amount = amount or 1}
    local data = items_db.get_item(item_id)

    if data then        
        gui.set_enabled(slot.icon, true)
        gui.set_color(slot.icon, data.color)
        
        if data.texture then
            gui.set_texture(slot.icon, data.texture)
        end
        gui.play_flipbook(slot.icon, hash(data.animation))

        if amount and amount > 1 then
            gui.set_enabled(slot.count, true)
            gui.set_text(slot.count, tostring(amount))
        else
            gui.set_enabled(slot.count, false)
        end
    end
end

-- Функция ТОЛЬКО для отрисовки (не меняет данные в модуле)
function M.update_slot_visual(self, slot_index, item_id, amount)
    local slot = self.slots[slot_index]
    if not slot then return end
    
    local data = items_db.get_item(item_id)
    if data then        
        gui.set_enabled(slot.icon, true)
        -- ... весь твой код с текстурами и цветами ...
        if amount and amount > 1 then
            gui.set_enabled(slot.count, true)
            gui.set_text(slot.count, tostring(amount))
        else
            gui.set_enabled(slot.count, false)
        end
    end
end

-- Функция для очистки ТОЛЬКО визуала
function M.clear_slot_visual(self, slot_index)
    local slot = self.slots[slot_index]
    if slot then
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.count, false)
    end
end

return M
