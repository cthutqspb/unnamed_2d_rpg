-- main.gui.components.managers.drag_manager.lua
local item_transfer_manager = require("main.modules.item_transfer_manager")

local M = {}

local active_drag = nil
local is_over_any_gui = false

function M.start(source, slot, item, item_cfg)
    local animation_name = item_cfg.animation or item_cfg.icon

    active_drag = {
        source = source,
        slot = slot,
        item = item,
        item_cfg = item_cfg,
        texture = item_cfg.texture,
        animation = hash(animation_name),
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

-- В drag_manager.lua

function M.finish(target_component, target_slot)
    if not active_drag then return end

    local d = active_drag
    active_drag = nil

    local source = d.source
    local source_slot = d.slot
    local item = d.item 
    local item_cfg = d.item_cfg

    -- 1. СЛУЧАЙ: ОТМЕНА (Над GUI, но мимо слотов)
    if not target_component and is_over_any_gui then
        print("Cancel drag: mouse over GUI but no slot")
        item_transfer_manager.cancel_transfer(source)

    -- 2. СЛУЧАЙ: ПЕРЕМЕЩЕНИЕ (Внутри одного окна или между разными)
    elseif target_component then
        item_transfer_manager.execute_transfer(source, source_slot, target_component, target_slot, item, item_cfg)

    -- 3. СЛУЧАЙ: ДРОП В МИР (Бросили на землю)
    else
        item_transfer_manager.drop_to_world(source, source_slot, item, d.x, d.y)
    end

    -- СБРОС СИСТЕМНЫХ ФЛАГОВ И ГЛОБАЛЬНЫЙ ВИЗУАЛЬНЫЙ ОБНОВИТЕЛЬ
    is_over_any_gui = false

    item_transfer_manager.finalize(source_comp, target_comp)
end

return M
