local broadcast = require("main.modules.system.broadcast")

---@class ItemTransferManager
local M = {}

---Выбросить предмет из модели данных в игровой мир
---@param source table @Чистая Lua-модель источника предметов (например, player_inventory)
---@param source_slot number|string @Индекс исходного слота или тип слота куклы
---@param item table @Данные выбрасываемого предмета
---@param position vector3 @Координата спавна X
function M.drop_to_world(source, source_slot, item, position)
    msg.post("game_scene:/world", "spawn_world_item", {
        source = "player",
        item_uid = item.uid,
        item_id = item.item_id,
        amount = item.amount,
        position = position,
        items = item.items or nil,         -- 🎯 Передаем шмотки из бочки обратно в мир!
        is_looted = item.is_looted or nil  -- 🎯 Передаем статус обыска!
    })

    if item.source_split_slot then
        local original_item = source:get_item(item.source_split_slot)
        if original_item then
            original_item.amount = original_item.amount - item.amount
            if original_item.amount <= 0 then
                source:set_item(item.source_split_slot, nil)
            end
        end
    else
        source:set_item(source_slot, nil)
    end

    M.finalize()
end

---Выполнить перенос предмета строго между моделями данных
---@param source table @Модель-источник (откуда забираем)
---@param source_slot number|string @Слот-источник
---@param target table @Модель-цель (куда кладём)
---@param target_slot number|string|nil @Слот назначения (или nil для авто-лута)
---@param item table @Данные предмета
---@param item_cfg table @Конфиг предмета из БД
function M.execute_transfer(source, source_slot, target, target_slot, item, item_cfg)
    -- Проверяем, что все критические данные для трансфера доехали успешно
    if not source or not target or not item or not item_cfg then
        print("🚨 СЕРВИС [Transfer]: Критическая ошибка! Переданы пустые данные (nil) в execute_transfer!")
        M.finalize()
        return
    end
    -- ЛОГИКА АВТО-ЛУТА (если не указан конкретный слот назначения)
    if target_slot == nil then
        if item_cfg.stackable and target.try_stack_item_anywhere then
            item.amount = target:try_stack_item_anywhere(item.item_id, item.amount, item_cfg)
        end

        if item.amount > 0 then
            local free_idx = target:get_first_empty_slot()
            if free_idx then
                target:set_item(free_idx, item)
                source:set_item(source_slot, nil)
            else
                source:set_item(source_slot, item)
                print("Inventory full!")
            end
        else
            source:set_item(source_slot, nil)
        end

        M.finalize()
        return
    end

    -- ЛОГИКА ОБРАБОТКИ СПЛИТА
    if item and item.source_split_slot then
        local success = target:split_stack(source, item.source_split_slot, target_slot, item.amount, item_cfg)
        if success then
            M.finalize()
            return
        else
            M.finalize()
            return
        end
    end

    -- ПРОВЕРКА ВОЗМОЖНОСТИ ЭКИПИРОВКИ НА КУКЛУ
    if target.can_equip_item then
        if not target:can_equip_item(item, target_slot) then
            M.finalize()
            return
        end
    end

    local item_b = target:get_item(target_slot)
    if item_b and item_b.item_id and source.can_equip_item then
        if not source:can_equip_item(item_b, source_slot) then
            M.finalize()
            return
        end
    end

    -- ЛОГИКА СТАКАНЬЯ В ВЫБРАННЫЙ СЛОТ
    local stacked = false
    if target.try_stack_items_from then
        stacked = target:try_stack_items_from(source, source_slot, target_slot, item_cfg)
    end

    -- ЛОГИКА ОБЫЧНОГО ОБМЕНА МЕСТАМИ (СВАП)
    if not stacked then
        local item_a = source:get_item(source_slot)
        target:set_item(target_slot, item_a)
        source:set_item(source_slot, item_b)
    end

    M.finalize()
end

---Глобальное оповещение всех представлений (Views) об изменении данных
function M.finalize()
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
end

return M
