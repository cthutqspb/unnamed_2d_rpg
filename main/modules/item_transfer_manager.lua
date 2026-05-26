local broadcast = require("main.modules.system.broadcast")

---@class ItemTransferManager
local M = {}

---Вспомогательная функция: безопасно вытягивает модель данных (Data Source) из провайдера
---@private
---@param provider table|any @Компонент окна или напрямую Lua-модель данных инвентаря
---@return table|nil @Lua-модель инвентаря/сундука/куклы
local function get_ds(provider)
    if not provider then return nil end
    -- Если у объекта есть метод get_data_source, вызываем его. Иначе считаем, что это и есть DS.
    if type(provider) == "table" and provider.get_data_source then
        return provider:get_data_source()
    end
    return provider
end

---Отменить текущий перенос и принудительно обновить исходное окно
---@param source_comp table|any @Компонент-источник драга
function M.cancel_transfer(source_comp)
    if source_comp and source_comp.request_refresh then
        source_comp:request_refresh()
    end
end

---Выбросить предмет из инвентаря в игровой мир
---@param source_comp table|any @Компонент или модель источника предметов
---@param source_slot number|string @Индекс исходного слота или тип слота куклы
---@param item table @Модель данных выбрасываемого предмета
---@param mouse_x number @Экранная координата X курсора для спавна
---@param mouse_y number @Экранная координата Y курсора для спавна
function M.drop_to_world(source_comp, source_slot, item, mouse_x, mouse_y)
    local source = get_ds(source_comp) -- Безопасное получение данных
    if not source then return end

    msg.post("game_scene:/world", "spawn_dropped_item", {
        item_uid = item.uid,
        item_id = item.item_id,
        amount = item.amount,
        mouse_x = mouse_x,
        mouse_y = mouse_y
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

    M.finalize(source_comp)
end

---Выполнить перенос предмета (Drag&Drop, быстрый лут, или экипировка шмотки)
---@param source_comp table|any @Компонент или модель источника (откуда забираем)
---@param source_slot number|string @Индекс исходного слота или тип слота куклы
---@param target_comp table|any @Компонент или модель цели (куда кладём)
---@param target_slot number|string|nil @Индекс слота назначения, либо nil для автоматического поиска
---@param item table @Модель данных переносимого предмета
---@param item_cfg table @Конфигурация предмета из items_db
function M.execute_transfer(source_comp, source_slot, target_comp, target_slot, item, item_cfg)
    -- Теперь нам плевать, открыты окна или нет
    local source = get_ds(source_comp)
    local target = get_ds(target_comp)

    if not source or not target then return end

        -- ⚡️ АВТО-ЛУТ (если не указан слот назначения)
    if target_slot == nil then
        -- 1. Пытаемся распихать по стакам (если предмет стакается)
        if item_cfg.stackable and target.try_stack_item_anywhere then
            -- Обновляем количество в самом объекте предмета
            item.amount = target:try_stack_item_anywhere(item.item_id, item.amount, item_cfg)
        end

        -- 2. Проверяем, осталось ли что-то после попытки стаканья
        if item.amount > 0 then
            local free_idx = target:get_first_empty_slot()
            if free_idx then
                -- Кладём остаток в новый пустой слот
                target:set_item(free_idx, item)
                -- И полностью удаляем из источника (т.к. всё, что было, распределилось)
                source:set_item(source_slot, nil)
            else
                -- Если места в рюкзаке нет, возвращаем остаток в исходный слот (сундук)
                source:set_item(source_slot, item)
                print("Inventory full! Item stayed in container.")
            end
        else
            -- Если после стаканья item.amount == 0, значит всё успешно «впиталось»
            source:set_item(source_slot, nil)
        end

        M.finalize(source_comp, target_comp)
        return
    end

    -- 0. ОБРАБОТКА СПЛИТА
    if item and item.source_split_slot then
        local success = target:split_stack(source, item.source_split_slot, target_slot, item.amount, item_cfg)
        if success then
            M.finalize(source_comp, target_comp)
            return
        else
            M.cancel_transfer(source_comp)
            return
        end
    end

    -- 1. ПРОВЕРКА КУКЛЫ
    if target.can_equip_item then
        if not target:can_equip_item(item, target_slot) then
            M.cancel_transfer(source_comp)
            return
        end
    end

    -- Дополнительно: проверка куклы для обратного обмена (если на кукле уже что-то висит)
    local item_b = target:get_item(target_slot)
    -- Если в цели РЕАЛЬНО что-то лежит (есть ID)
    if item_b and item_b.item_id and source.can_equip_item then
        -- Проверяем, может ли ИСТОЧНИК (кукла) принять этот предмет обратно
        if not source:can_equip_item(item_b, source_slot) then
            M.cancel_transfer(source_comp)
            return
        end
    end

    -- 2. ПОПЫТКА СТАКАНЬЯ
    local stacked = false
    if target.try_stack_items_from then
        stacked = target:try_stack_items_from(source, source_slot, target_slot, item_cfg)
    end

    -- 3. СВАП
    if not stacked then
        local item_a = source:get_item(source_slot)

        target:set_item(target_slot, item_a)
        source:set_item(source_slot, item_b)
    end

    M.finalize(source_comp, target_comp)
end

---Зафиксировать изменения данных, обновить открытые GUI-компоненты и разослать глобальное уведомление
---@param source_comp table|any @Компонент или модель источника
---@param target_comp table|any|nil @Компонент или модель цели (опционально)
function M.finalize(source_comp, target_comp)
    -- Если окна открыты — просим их обновиться
    if source_comp and type(source_comp) == "table" and source_comp.request_refresh then
        source_comp:request_refresh()
    end
    if target_comp and type(target_comp) == "table" and target_comp.request_refresh then
        target_comp:request_refresh()
    end

    -- Глобальный сигнал: все, кто слушает (даже закрытые окна при открытии), обновятся
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
end

return M
