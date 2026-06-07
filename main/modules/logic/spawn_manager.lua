local map_config = require("main.modules.data.map_config")
local creatures_state = require("main.modules.game_state.creatures_state")

local M = {}

local active_bodies = {}

function M.spawn_zone(zone_name)
    local entity_list = map_config.baked_entities[zone_name]
    if not entity_list or #entity_list == 0 then return end

    print("БЭКЕНД: Проверяем необходимость материализации тушек для " .. zone_name)

    for i, entity_node in ipairs(entity_list) do
        local uid = entity_node.uid
        local entity_type = entity_node.type
        local entity_data = entity_node.data
        local base_pos = entity_node.pos

        -- 🎯 ТИТАНОВЫЙ СИ-ЗАМОК (WoW-канон):
        -- Мы проверяем, привязано ли уже какое-то живое тело к этому UID в стейте?
        -- Посмотри, как у тебя в creatures_state называется таблица инстансов.
        -- Если у тебя есть метод получения go_id по uid, или таблица обратного поиска, 
        -- мы можем напрямую проверить, существует ли физический объект на сцене.
        local has_physical_body = false
        
        -- Сканируем реестр creatures_state.instances, чтобы узнать, 
        -- зарегистрировал ли себя уже оригинальный Скелет из редактора?
        if creatures_state.instances then
            for registered_go_id, registered_uid in pairs(creatures_state.instances) do
                if registered_uid == uid and go.exists(registered_go_id) then
                    has_physical_body = true
                    -- 🧱 Кэшируем оригинального Скелета из редактора в наш активный список, 
                    -- чтобы спавнер знал о нем и смог стерильно удалить его тело при уходе из чанка!
                    active_bodies[registered_go_id] = uid
                    break
                end
            end
        end

        -- Если тело в мире уже зарегистрировано (моб из редактора стоит на траве) — фабрика ОТДЫХАЕТ!
        if not has_physical_body then
            local is_alive = true
            if creatures_state.exists and not creatures_state.exists(uid) then
                is_alive = false
            end

            if is_alive then
                local final_pos = base_pos
                local saved_data = creatures_state.get(uid)
                if saved_data and saved_data.saved_position then
                    final_pos = saved_data.saved_position
                end

                local factory_url = "game_scene:/world_controller#creature_factory"

                -- Спавним через фабрику ТОЛЬКО при повторном возвращении в чанк!
                local go_id = factory.create(factory_url, final_pos, nil, {
                    uid = hash(uid),
                    creature_id = hash(entity_data.id),
                    creature_level = entity_data.level or 1,
                    creature_rank = hash(entity_data.rank or "common"),
                    is_from_factory = true
                })

                if go_id then
                    active_bodies[go_id] = uid
                end
            end
        end
    end
end

function M.clear_all_bodies(zone_name)
    print("БЭКЕНД: Умная выгрузка тел для зоны " .. zone_name)
    
    local survivors = {}

    for go_id, uid in pairs(active_bodies) do
        if go.exists(go_id) then
            
            if creatures_state.is_creature_in_combat(uid) then
                -- Скелет кайтится за магом, его тело легально живет в мире!
                survivors[go_id] = uid
                print("⚔️ БЭКЕНД: Скелет " .. uid .. " в бою! Блокируем удаление из памяти.")
            else
                -- Скелет мирно стоял дома — стерильно удаляем его тело, спасая FPS
                go.delete(go_id)
            end
        end
    end
    
    -- Обновляем кэш активных тел на экране
    active_bodies = survivors
    -- 
    -- -- Предметы с земли выгружаем без изменений
    -- for item_go, item_uid in pairs(active_items) do
    --     if go.exists(item_go) then go.delete(item_go) end
    -- end
    -- active_items = {}
    -- 
    -- if map_config.clear_entity_spawns then
    --     map_config.clear_entity_spawns(zone_name)
    -- end
end

return M

