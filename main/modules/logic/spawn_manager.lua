local map_config = require("main.modules.data.map_config")
local creatures_state = require("main.modules.game_state.creatures_state")
local world_items_state = require("main.modules.game_state.world_items_state")

---@class SpawnManagerModule
local M = {}

---Кэш живых Си-адресов существ на сцене [go_id] = uid
---@type table<hash, string>
local active_bodies = {}

---Кэш живых Си-адресов предметов на сцене [go_id] = uid
---@type table<hash, string>
local active_items = {}

-- =========================================================================
-- СЛУЖЕБНЫЕ МЕТОДЫ (Внутренняя логика модуля)
-- =========================================================================

---Внутренний метод материализации физического тела существа на сцене
---@param uid string Уникальный строковый UID монстра
---@param creature_instance_data table Паспортные данные существа из RAM-реестра
local function materialize_creature(uid, creature_instance_data)
    -- Гвард: если существо уже мертво или полностью зачищено (разлутано) — игнорируем спавн
    if creature_instance_data.is_dead or creature_instance_data.is_collected then
        return
    end

    -- 🛡️ ЗАЩИТА ОТ ДУБЛИРОВАНИЯ ТЕЛ:
    -- Проверяем, не существует ли уже этот конкретный UID физически на Meadows-карте
    local has_physical_body = false
    if creatures_state.instances then
        for registered_game_object_id, registered_unique_id in pairs(creatures_state.instances) do
            if registered_unique_id == uid and go.exists(registered_game_object_id) then
                has_physical_body = true
                active_bodies[registered_game_object_id] = uid
                break
            end
        end
    end

    -- Если тела в мире нет — со спокойной душой спавним его из фабрики
    if not has_physical_body then
        -- Берём чистокровный вектор координат из переданных паспортных данных
        local final_position = creature_instance_data.saved_position

        local factory_url = "game_scene:/world_controller#creature_factory"
        local game_object_id = factory.create(factory_url, final_position, nil, {
            uid = hash(uid),
            creature_id = hash(creature_instance_data.creature_id),
            creature_level = creature_instance_data.level or 1,
            creature_rank = hash(creature_instance_data.rank or "common"),
            is_from_factory = true,
        })

        if game_object_id then
            active_bodies[game_object_id] = uid
            creatures_state.instances[game_object_id] = uid
        end
    end
end

-- =========================================================================
-- ГЛАВНЫЙ ИНТЕРФЕЙС УПРАВЛЕНИЯ СПАВНОМ (Публичные методы)
-- =========================================================================

---Метод А: Материализовать существ чанка строго по чертежам редактора (Новая Игра)
---@param zone_name string Имя активного чанка ("meadows")
function M.spawn_zone(zone_name)
    -- 🛡️ ИНВЕРСИЯ СПАВНА: Если игра загружена из сейва, мы ВООБЩЕ игнорируем map_config!
    -- Мы спавним мир по чистокровным паспортам RAM, полностью исключая гонку потоков.
    if creatures_state.is_loaded_from_save then
        for unique_identifier, creature_instance_data in pairs(creatures_state.get_all()) do
            -- Вызываем наш единый вынесенный метод материализации
            materialize_creature(unique_identifier, creature_instance_data)
        end
        return
    end

    -- ВЕТКА НОВОЙ ИГРЫ: Читаем дефолтную разметку дизайнера из конфигуратора карты
    local entity_list = map_config.baked_entities[zone_name]
    if not entity_list or #entity_list == 0 then return end

    print("БЭКЕНД [SpawnManager]: Материализуем мобов чанка по чертежам редактора для " .. zone_name)

    for _, entity_node in ipairs(entity_list) do
        local uid = entity_node.uid

        if entity_node.type == "creature" then
            -- Вытаскиваем паспорт, созданный в Фазе 1 встроенным мобом
            local creature_instance_data = creatures_state.get(uid)
            if creature_instance_data then
                -- Вызываем этот же самый метод! Дублирование полностью устранено.
                materialize_creature(uid, creature_instance_data)
            end
        end
    end
end

---МЕТОД Б (BG3 Монолит): Двухсторонний стриминг ПРЕДМЕТОВ по площади экрана
---@param current_zone string Текущая активная локация мага ("overworld", "necropolis")
---@param x_min number Левая граница экрана
---@param x_max number Правая граница экрана
---@param y_min number Нижняя граница экрана
---@param y_max number Верхняя граница экрана
function M.spawn_world_items(current_zone, x_min, x_max, y_min, y_max)
    if not world_items_state or not world_items_state.get_all then return end

    local registry = world_items_state.get_all()
    local factory_url = "game_scene:/world_controller#item_factory"

    -- =========================================================================
    -- 🦾 ПОТОК 1: ЕДИНЫЙ СПАВН ПРЕДМЕТОВ ИЗ ОБЛАСТИ ВИДИМОСТИ (И Сейвы, и Дроп)
    -- =========================================================================
    for uid, data in pairs(registry) do
        if not data.is_collected and data.saved_position then
            -- СИ-ЗАМОК ДАНЖЕЙ: Предмет спавнится только в своей родной зоне
            local item_zone = data.zone_id or "overworld"

            if item_zone == current_zone then
                local item_x = data.saved_position.x
                local item_y = data.saved_position.y

                -- ИСПРАВЛЕНО: Кристально чистая математика экранных границ
                local is_inside_view = item_x >= x_min and item_x <= x_max and
                                       item_y >= y_min and item_y <= y_max

                if is_inside_view then
                    local already_spawned = false
                    for registered_go_id, registered_uid in pairs(active_items) do
                        if registered_uid == uid and go.exists(registered_go_id) then
                            already_spawned = true
                            break
                        end
                    end

                    -- УЛЬТИМАТИВНЫЙ БЕЗБАЖНЫЙ СПАВН:
                    if not already_spawned then
                        local position = vmath.vector3(item_x, item_y, data.saved_position.z or 1.0)
                        local item_go = factory.create(factory_url, position, nil, { is_from_factory = true })

                        if item_go then
                            active_items[item_go] = uid
                            world_items_state.register(item_go, uid)

                            msg.post(item_go, "set_item_id", {
                                item_id = data.item_id, 
                                amount = data.amount,
                                uid = uid
                            })
                        end
                    end
                end
            end
        end
    end

    -- =========================================================================
    -- 🦾 ПОТОК 2: АВТО-КЛИНИНГ ЗА ЭКРАНОМ
    -- =========================================================================
    local survivors = {}
    for item_go, item_uid in pairs(active_items) do
        if go.exists(item_go) then
            local item_data = world_items_state.get_item_by_uid(item_uid)
            if item_data and item_data.saved_position then
                local item_x = item_data.saved_position.x
                local item_y = item_data.saved_position.y
                local item_zone = item_data.zone_id or "overworld"

                local is_inside_view = item_x >= x_min and item_x <= x_max and
                                       item_y >= y_min and item_y <= y_max

                if item_zone == current_zone and is_inside_view and not item_data.is_collected then
                    survivors[item_go] = item_uid
                else
                    go.delete(item_go)
                end
            else
                go.delete(item_go)
            end
        end
    end
    active_items = survivors
end


-- ---МЕТОД Б (BG3 Монолит): Двухсторонний стриминг ПРЕДМЕТОВ по площади экрана
-- ---@param current_zone string Текущая активная локация мага ("overworld", "necropolis")
-- ---@param x_min number Левая граница экрана
-- ---@param x_max number Правая граница экрана
-- ---@param y_min number Нижняя граница экрана
-- ---@param y_max number Верхняя граница экрана
-- function M.spawn_world_items(current_zone, x_min, x_max, y_min, y_max)
--     if not world_items_state or not world_items_state.get_all then return end
--
--     local registry = world_items_state.get_all()
--     local factory_url = "game_scene:/world_controller#item_factory"
--
--     -- 🦾 ПОТОК 1: СПАВН ИЗ ОБЛАСТИ ВИДИМОСТИ
--     for uid, data in pairs(registry) do
--         if not data.is_collected then
--             -- 🎯 СИ-ЗАМОК ДАНЖЕЙ: Меч спавнится, только если его зона совпадает с комнатой мага!
--             local item_zone = data.zone_id or "overworld"
--
--             if item_zone == current_zone then
--                 local item_x = data.saved_position.x
--                 local item_y = data.saved_position.y
--
--                 local is_inside_view = item_x >= x_min and item_x <= x_max and
--                                        item_y >= y_min and item_y <= y_max
--
--                 if is_inside_view then
--                     local already_spawned = false
--                     for registered_go_id, registered_uid in pairs(active_items) do
--                         if registered_uid == uid and go.exists(registered_go_id) then
--                             already_spawned = true
--                             break
--                         end
--                     end
--
--                     -- 🦾 УЛЬТИМАТИВНЫЙ БЕЗБАЖНЫЙ СПАВН:
--                     -- Мы полностью убрали отсюда зависимость от items_db! Фабрика штампует 
--                     -- прехаб world_item.go СЛЕПО, потому что он сам внутри своего on_message
--                     -- натянет визуал по своей внутренней логике хэшей!
--                     if not already_spawned then
--                         local position = vmath.vector3(item_x, item_y, data.saved_position.z or 1.0)
--                         local item_go = factory.create(factory_url, position, nil, { is_from_factory = true })
--
--                         if item_go then
--                             active_items[item_go] = uid
--                             world_items_state.register(item_go, uid)
--
--                             msg.post(item_go, "set_item_id", {
--                                 item_id = data.item_id, -- Шлем строку/хэш "as is"
--                                 amount = data.amount,
--                                 uid = uid
--                             })
--                         end
--                     end
--                 end
--             end
--         end
--     end
--
--     -- 🦾 ПОТОК 2: АВТО-КЛИНИНГ ЗА ЭКРАНОМ
--     local survivors = {}
--     for item_go, item_uid in pairs(active_items) do
--         if go.exists(item_go) then
--             local item_data = world_items_state.get_item_by_uid(item_uid)
--             if item_data then
--                 local item_x = item_data.saved_position.x
--                 local item_y = item_data.saved_position.y
--                 local item_zone = item_data.zone_id or "overworld"
--
--                 local is_inside_view = item_x >= x_min and item_x <= x_max and
--                                        item_y >= y_min and item_y <= y_max
--
--                 if item_zone == current_zone and is_inside_view and not item_data.is_collected then
--                     survivors[item_go] = item_uid
--                 else
--                     go.delete(item_go)
--                 end
--             else
--                 go.delete(item_go)
--             end
--         end
--     end
--     active_items = survivors
-- end

---Умная выгрузка тел существ при уходе игрока из чанка земли
---@param zone_name string Имя покидаемого чанка
function M.clear_all_bodies(zone_name)
    print("БЭКЕНД: Умная выгрузка тел для зоны " .. zone_name)

    local survivors = {}
    for creature_go, creature_uid in pairs(active_bodies) do
        if go.exists(creature_go) then
            if creatures_state.is_creature_in_combat and creatures_state.is_creature_in_combat(creature_uid) then
                survivors[creature_go] = creature_uid
            else
                go.delete(creature_go)
            end
        end
    end
    active_bodies = survivors

    if map_config.clear_entity_spawns then
        map_config.clear_entity_spawns(zone_name)
    end
end

return M

