local strings = require("main.modules.strings")
local M = {}

M.items = {
    ["iron_sword"] = {
        name_key = "item_iron_sword_name",
        desc_key = "item_iron_sword_desc",
        animation = "iron_sword",
        tile_index = 2976,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "items_project_utumno",
        scale = 0.5,
        drop_distance = 20,    -- на сколько пикселей перед игроком
        rotation = 0,          -- угол поворота на земле
    },
    ["crystal_sword"] = {
        name_key = "item_crystal_sword_name",
        desc_key = "item_crystal_sword_desc",
        animation = "crystal_sword",
        tile_index = 3013,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "items_project_utumno"
    },
    -- ... остальные предметы
}

function M.get_item(id)
    local item = M.items[id]
    if item then
        -- На лету подтягиваем переведенные строки
        item.name = strings.get(item.name_key)
        item.description = strings.get(item.desc_key)
        item.icon = tostring(item.tile_index) -- для gui.play_flipbook
    end
    return item
end

return M
