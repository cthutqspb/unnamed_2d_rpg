local M = {}
M.DATA_TYPE_ITEM = "item"
M.DATA_TYPE_UNIT = "unit" -- монстры/нпс
M.DATA_TYPE_WORLD = "world" -- объекты мира

M.mouse_x = 0
M.mouse_y = 0

local current_data = nil

function M.show(type, info, context)
    current_data = {
        type = type,     -- "item" или "world_object"
        info = info,     -- сами данные (предмет или стейт сундука)
        context = context -- откуда пришло (инвентарь, мир, магазин)
    }
end

function M.hide()
    -- Если данных и так нет, просто выходим
    if current_data == nil then return end

    current_data = nil
    -- Здесь можно добавить принт для дебага, чтобы увидеть, 
    -- что hide вызывается только один раз при уходе мыши
    -- print("Tooltip data cleared")
end

function M.get_current()
    return current_data
end

-- Тот самый метод, который мы вызываем в player.script и world.script
function M.get_inspect_info(go_id)
    -- 1. Сначала проверяем, не контейнер ли это. 
    -- Стучимся в скрипт объекта, чтобы достать его уникальный container_uid
    local ok_c, c_uid = pcall(go.get, msg.url(nil, go_id, "script"), "container_uid")
    if ok_c and c_uid then
        local data = containers.get(c_uid)
        if data then return "container", data end
    end

    -- 2. Если не сундук, проверяем, не предмет ли это на земле (loot)
    local ok_i, i_uid = pcall(go.get, msg.url(nil, go_id, "script"), "uid")
    if ok_i and i_uid then
        local data = world_items.get_item_by_uid(i_uid)
        if data then return "loot", data end
    end

    return nil, nil
end

-- Возвращает текущий тип ("item", "world_object" и т.д.)
function M.get_current_type()
    return current_data and current_data.type
end


function M.update_mouse(x, y)
    M.mouse_x = x or M.mouse_x or 0
    M.mouse_y = y or M.mouse_y or 0
end

return M
