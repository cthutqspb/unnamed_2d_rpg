-- main/gui/drag_manager.lua
local gui_utils = require("main.gui.gui_utils")

local M = {}

local active_drag = nil

function M.start(source, slot, item, clone, root_node)
    active_drag = {
        source = source,
        slot = slot,
        item = item,
        clone = clone,
        root = root_node,
        x = 0,
        y = 0
    }
    print("Drag started")
end

function M.update(x, y)
    if not active_drag then return end
    active_drag.x = x
    active_drag.y = y
    
    if active_drag.clone and active_drag.root then
        local root_x, root_y = gui_utils.get_screen_position(active_drag.root)
        local local_x = x - root_x
        local local_y = y - root_y
        gui.set_position(active_drag.clone, vmath.vector3(local_x, local_y, 1))
    else
        print("No clone or root", active_drag.clone, active_drag.root)
    end
end

function M.get_active()
    return active_drag
end

function M.is_dragging()
    return active_drag ~= nil
end

function M.get_source()
    if not active_drag then return nil, nil, nil end
    return active_drag.source, active_drag.slot, active_drag.item
end

function M.finish(target_component, target_slot)
    if not active_drag then 
        print("No active drag")
        return 
    end
    
    local source = active_drag.source
    local source_slot = active_drag.slot
    local item = active_drag.item
    
    print("finish: source_slot=", source_slot, "target_slot=", target_slot)
    print("source == target_component?", source == target_component)
    
    if source == target_component then
        -- Свап внутри одного компонента
        print("SWAP inside same component")
        local data = source:get_data_source()
        local temp = data.items[source_slot]
        data.items[source_slot] = data.items[target_slot]
        data.items[target_slot] = temp
        source:refresh()
        
    elseif target_component then
        -- Перемещение между разными компонентами
        print("MOVE to different component")
        local source_data = source:get_data_source()
        local target_data = target_component:get_data_source()
        
        target_data.items[target_slot] = item
        source_data.items[source_slot] = {item_id = nil, amount = 0}
        
        source:refresh()
        target_component:refresh()
        
    else
        -- Дроп в мир
        print("DROP to world")
        msg.post("world", "spawn_dropped_item", {
            item_id = item.item_id,
            amount = item.amount,
            mouse_x = active_drag.x,
            mouse_y = active_drag.y
        })
        local source_data = source:get_data_source()
        source_data.items[source_slot] = {item_id = nil, amount = 0}
        source:refresh()
    end
    
    if active_drag.clone then
        gui.delete_node(active_drag.clone)
    end
    active_drag = nil
    msg.post("/gui_manager", "refresh_inventories")
    print("Drag finished")
end

return M
