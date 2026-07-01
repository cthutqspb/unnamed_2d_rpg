local M = {}

M.RELATIONS = {
    ["neutral_humanoid"] = { -- Фракция твоего мага
        ["neutral_humanoid"] = "FRIENDLY",
        ["undead"]           = "HOSTILE",
        ["beast_neutral"]    = "NEUTRAL",   -- Желтый кабан: мирно пасётся
        ["beast_aggressive"] = "HOSTILE",   -- Красный кабан: сожрёт на месте
        ["green_dragon"]     = "NEUTRAL"
    },
    ["undead"] = {
        ["neutral_humanoid"] = "HOSTILE",
        ["undead"]           = "FRIENDLY",
        ["beast_neutral"]    = "NEUTRAL",   -- Скелеты не трогают мирных кабанов
        ["beast_aggressive"] = "NEUTRAL",   -- И диких кабанов тоже пока не бьют
        ["green_dragon"]     = "NEUTRAL"
    },
    -- =========================================================================
    -- 🐗 ПОЛИМОРФНЫЕ ВЕТКИ КАБАНОВ ( behavior вшит прямо в матрицу!):
    -- =========================================================================
    ["beast_neutral"] = {
        ["neutral_humanoid"] = "NEUTRAL",   -- Игрока сам не трогает!
        ["undead"]           = "NEUTRAL",
        ["beast_neutral"]    = "FRIENDLY",
        ["beast_aggressive"] = "NEUTRAL"
    },
    ["beast_aggressive"] = {
        ["neutral_humanoid"] = "HOSTILE",   -- Увидит мага — побежит ломать лицо!
        ["undead"]           = "NEUTRAL",   -- Скелетов игнорирует
        ["beast_neutral"]    = "NEUTRAL",
        ["beast_aggressive"] = "FRIENDLY"
    },
    -- =========================================================================
    ["green_dragon"] = {
        ["neutral_humanoid"] = "NEUTRAL",
        ["undead"]           = "NEUTRAL",
        ["green_dragon"]     = "FRIENDLY"
    }
}

function M.is_hostile(source_unit_faction, target_unit_faction)
    if not source_unit_faction or not target_unit_faction then return false end
    if not M.RELATIONS[source_unit_faction] then return false end
    return M.RELATIONS[source_unit_faction][target_unit_faction] == "HOSTILE"
end

return M

