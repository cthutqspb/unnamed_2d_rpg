local M = {}

-- Живой реестр активных точек спавна в загруженных чанках
local active_points = {}

function M.register_spawn_point(id, data)
    active_points[id] = data
end

function M.unregister_spawn_point(id)
    active_points[id] = nil
end

function M.get_spawn_point(id)
    return active_points[id]
end

return M

