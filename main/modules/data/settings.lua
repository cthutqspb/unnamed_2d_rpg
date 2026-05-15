local M = {}

-- Настройки по умолчанию
M.resolution = {
    width = 1920,
    height = 1080
}

M.world_bounds = {
    left = 32,
    right = 1920 - 32,
    bottom = 32,
    top = 1080 - 32
}

M.world_center = {
    x = 0,
    y = 0
}

-- TODO: Добавить выбор разрешения через GUI
-- TODO: Добавить полноэкранный режим
-- TODO: Добавить настройки качества графики

function M.get_center()
    return M.resolution.width / 2, M.resolution.height / 2
end

function M.get_resolution()
    return M.resolution
end

function M.get_world_center()
    return M.world_center.x, M.world_center.y
end

return M
