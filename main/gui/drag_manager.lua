-- main/gui/drag_manager.lua
local gui_utils = require("main.gui.gui_utils")

local M = {}

local active_drag = nil
local is_over_any_gui = false

local function get_items_table(component)
    local ds = component:get_data_source()
    return ds.slots or ds.items
end

function M.start(source, slot, item, texture, anim)
    active_drag = {
        source = source,
        slot = slot,
        item = item,
        texture = texture, -- строка (атлас)
        anim = anim,       -- хеш (анимация)
        x = 0, y = 0
    }
    print("Drag started")
end

function M.update(x, y)
    if not active_drag then return end
    active_drag.x = x
    active_drag.y = y
    is_over_any_gui = false
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

function M.set_over_gui(value)
    is_over_any_gui = value
end

function M.finish(target_component, target_slot)
    if not active_drag then return end

    local d = active_drag 
    active_drag = nil 

    local source = d.source
    local source_slot = d.slot
    local item = d.item
    local source_items = get_items_table(source)

    -- 1. СЛУЧАЙ: ОТМЕНА (Над GUI, но не в слоте)
    if not target_component and is_over_any_gui then
        print("Cancel drag: mouse over GUI but no slot")
        -- Просто обновляем источник, чтобы иконка вернулась на место
        pcall(function() source:refresh() end)

    -- 2. СЛУЧАЙ: СВАП (Внутри того же окна/инвентаря)
    elseif source == target_component then
        local temp = source_items[source_slot]
        source_items[source_slot] = source_items[target_slot]
        source_items[target_slot] = temp
        pcall(function() source:refresh() end)
        
    -- 3. СЛУЧАЙ: ПЕРЕНОС (Между разными окнами: Инвентарь <-> Кукла <-> Сундук)
    elseif target_component then
        local target_items = get_items_table(target_component)
        local old_target_item = target_items[target_slot]
        
        target_items[target_slot] = item
        
        -- Рокировка: если в слоте что-то было, возвращаем это в источник
        if old_target_item and old_target_item.item_id then
            source_items[source_slot] = old_target_item
        else
            source_items[source_slot] = {item_id = nil, amount = 0}
        end
        
        pcall(function() source:refresh() end)
        pcall(function() target_component:refresh() end)
        
    -- 4. СЛУЧАЙ: ДРОП В МИР (Не над GUI вообще)
    else
        print("DROP to world")
        msg.post("world", "spawn_dropped_item", {
            item_id = item.item_id,
            amount = item.amount,
            mouse_x = d.x,
            mouse_y = d.y
        })
        source_items[source_slot] = {item_id = nil, amount = 0}
        pcall(function() source:refresh() end)
    end

    -- СБРОС ФЛАГА
    is_over_any_gui = false

    -- Глобальное обновление (визуал)
    msg.post("/gui_manager#hud", "refresh_inventories")
    msg.post("main:/character_window#gui", "refresh")
    msg.post("main:/container_window#gui", "refresh") 
end

return M
