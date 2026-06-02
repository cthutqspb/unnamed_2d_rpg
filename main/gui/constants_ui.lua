local M = {}

M.LAYERS = {
    HUD = 2,        -- Панели ХП, скиллы (всегда снизу)
    WINDOW = 5,     -- Обычные окна (инвентарь, статы)
    LOOT = 7,
    POPUP = 9,      -- Подтверждения (Выйти из игры?)
    CONTEXT = 10,
    TOOLTIP = 12,    -- Всегда сверху всех
    DRAG = 14,
    CURSOR = 15
}

return M
