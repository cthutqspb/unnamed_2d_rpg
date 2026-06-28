---@class ColorsDatabaseModule
local M = {}

---@type table<string, vector4>
M.QUALITY_COLORS = {
    common    = vmath.vector4(1, 1, 1, 1),
    uncommon  = vmath.vector4(0.12, 1, 0, 1),
    rare      = vmath.vector4(0, 0.44, 1, 1),
    epic      = vmath.vector4(0.64, 0.21, 0.93, 1),
    legendary = vmath.vector4(1, 0.5, 0, 1),
}

---@type table<string, vector4>
M.UNIT_RANK_COLORS = {
    pure      = vmath.vector4(0.12, 1, 0.5, 1),   -- Лаймово-зелёный (мирный/союзник)
    common    = vmath.vector4(1, 1, 1, 1),         -- Чистый белый (обычный моб)
    uncommon  = vmath.vector4(0.2, 0.8, 0.2, 1),   -- Плотный зелёный (крепкий моб)
    rare      = vmath.vector4(0, 0.44, 1, 1),      -- Яркий синий (редкий именной)
    elite     = vmath.vector4(0.64, 0.21, 0.93, 1),-- Пурпурный/Фиолетовый (элита)
    boss      = vmath.vector4(1, 0.2, 0.2, 1),     -- Кроваво-красный (босс)
}

---@type vector4
M.STATS_COLOR = vmath.vector4(0.7, 0.7, 0.7, 1)

return M
