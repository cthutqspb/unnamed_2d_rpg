local M = {}

-- 1. СТАТИЧЕСКИЙ РЕЕСТР: Точки спавна игрока и триггеры выходов
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

-- =========================================================================
-- 🎯 2. ДИНАМИЧЕСКИЙ РЕЕСТР СУЩНОСТЕЙ WoW/BG3 (Entities: Скелеты, Сундуки, Трава)
-- =========================================================================
M.baked_entities = {
    ["meadows"] = {} -- Сюда объекты будут сами запекаться при Ctrl+B кадра!
}

---Автоматически прописать полиморфную сущность из редактора в конфиг карты (Bake)
---@param zone_id string Имя чанка/зоны ("meadows")
---@param entity_uid string Сгенерированный по координатам UID ("c_1200_750")
---@param entity_type "item" | "unit"|"container"|"interactable" Мета-тип сущности
---@param entity_data table Кастомный мешок свойств из инспектора Defold {id, level, rank}
---@param pos vector3 Мировые координаты спавна из редактора
function M.bake_entity(zone_id, entity_uid, entity_type, entity_data, pos)
    if not M.baked_entities[zone_id] then
        M.baked_entities[zone_id] = {}
    end

    -- Запекаем плоский полиморфный паспорт сущности в память бэкенда!
    table.insert(M.baked_entities[zone_id], {
        uid = entity_uid,
        type = entity_type,  -- "unit", "container"
        data = entity_data,  -- { id = "skeleton", level = 1, rank = "common" }
        pos = pos            -- Точка дома
    })

    print(string.format("💾 БЭКЕНД [Bake]: Сущность [%s] запечена в %s! Тип: %s | ID: %s Позиция %s",
        entity_uid, zone_id, entity_type, entity_data.id or "unknown", pos))
end

---Полностью очистить кэш запекания сущностей конкретной зоны при её выгрузке
---@param zone_id string
function M.clear_entity_spawns(zone_id)
    M.baked_entities[zone_id] = {}
end

return M
