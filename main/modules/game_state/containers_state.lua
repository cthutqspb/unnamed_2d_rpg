local M = {}

local containers = {}

function M.init(id, data)
    containers[id] = data
end

function M.get(id)
    return containers[id]
end

function M.remove(id)
    containers[id] = nil
end

function M.clear()
    containers = {}
end

return M
