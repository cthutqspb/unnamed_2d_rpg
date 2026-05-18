local M = {}
M.DATA_TYPE_ITEM = "item"
M.DATA_TYPE_UNIT = "unit" -- монстры/нпс
M.DATA_TYPE_WORLD = "world" -- объекты мира

M.mouse_x = 0
M.mouse_y = 0

local current_data = nil

function M.show(type, id, extra_data)
    current_data = { type = type, id = id, extra = extra_data }
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

function M.update_mouse(x, y)
    M.mouse_x = x or M.mouse_x or 0
    M.mouse_y = y or M.mouse_y or 0
end

return M
