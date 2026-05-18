local broadcast = require("main.modules.system.broadcast")
local M = {}

-- 1. ОТМЕНА: Просто перерисовываем источник

function M.cancel_transfer(source_comp)
    if source_comp and source_comp.request_refresh then
        source_comp:request_refresh()
    end
end

function M.drop_to_world(source_comp, source_slot, item, mouse_x, mouse_y)
    print("DROP to world")

    -- 1. Спавним именно то количество, что было на курсоре (item.amount)
    msg.post("world", "spawn_dropped_item", {
        item_id = item.item_id,
        amount = item.amount,
        mouse_x = mouse_x,
        mouse_y = mouse_y
    })
    
    local source = source_comp:get_data_source()

    -- 2. ЛОГИКА УДАЛЕНИЯ ИЗ ИНВЕНТАРЯ
    if item.source_split_slot then
        -- Если это сплит (выбрасываем часть), вычитаем из исходного слота в модели
        local original_item = source:get_item(item.source_split_slot)
        if original_item then
            original_item.amount = original_item.amount - item.amount
            if original_item.amount <= 0 then
                source:set_item(item.source_split_slot, nil)
            end
        end
    else
        -- Если обычный драг (выбрасываем всё), просто зануляем слот
        source:set_item(source_slot, nil)
    end
    
    -- 3. Обновляем визуал
    M.finalize(source_comp)
end

-- 2. ГЛАВНЫЙ МЕТОД ПЕРЕНОСА
function M.execute_transfer(source_comp, source_slot, target_comp, target_slot, item, item_cfg)
    local source = source_comp:get_data_source()
    local target = target_comp:get_data_source()
    
    print('execute_transfer', source_slot, target_slot, item, item_cfg)
    ---------------------------------------------------------------------------
    -- 0. ОБРАБОТКА СПЛИТА (Должна быть первой!)
    ---------------------------------------------------------------------------
    if item and item.source_split_slot then
        -- Вызываем метод сплита у ЦЕЛЕВОЙ модели
        local success = target:split_stack(source, item.source_split_slot, target_slot, item.amount, item_cfg)

        if success then
            M.finalize(source_comp, target_comp)
            return -- ВАЖНО: выходим, чтобы не сработал свап ниже!
        else
            -- Если сплит не удался (например, в целевом слоте чужой предмет)
            M.cancel_transfer(source_comp)
            return
        end
    end

    ---------------------------------------------------------------------------
    -- 1. ПРОВЕРКА КУКЛЫ
    ---------------------------------------------------------------------------
    if target.can_equip_item then
        if not target:can_equip_item(item.item_id, target_slot) then
            print("TRANSFER: This item doesn't fit in " .. target_slot)
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
        local item_b = target:get_item(target_slot)

        target:set_item(target_slot, item_a)
        source:set_item(source_slot, item_b)
    end

    M.finalize(source_comp, target_comp)
end

function M.transfer_to_paperdoll(source_comp, target_comp, slot_index, target_slot_type)
    print('transfer_to_paperdoll')
    local source = source_comp:get_data_source()
    local target = target_comp:get_data_source()
    print(source, target)
    if target.can_equip_item then
        if not target:can_equip_item(item.item_id, target_slot) then
            print("TRANSFER: This item doesn't fit in " .. target_slot)
            M.cancel_transfer(source_comp)
            return
        end
    end

    -- if not stacked then
    --     local item_a = source:get_item(source_slot)
    --     local item_b = target:get_item(target_slot)
    --
    --     target:set_item(target_slot, item_a)
    --     source:set_item(source_slot, item_b)
    -- end
    --
    M.finalize(source_comp, target_comp)
end


function M.finalize(source_comp, target_comp)
    -- 1. Обновляем локальный скрипт (тот, в который бросили предмет)
    -- msg.post(".", "refresh")
    -- 2. Вместо поиска URL, шлем глобальный сигнал всем окнам
    -- Все открытые GUI-скрипты должны быть подписаны на это
    print("FROM TRANSFER MANAGER REFFRESH ALL")
    if source_comp and source_comp.request_refresh then
        source_comp:request_refresh()
    end
    if target_comp and target_comp.request_refresh then
        target_comp:request_refresh()
    end
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
end

return M


-- local player_inventory = require("main.modules.player.player_inventory")
-- local player_paperdoll = require("main.modules.player.player_paperdoll")
-- local broadcast = require("main.modules.system.broadcast")
--
-- local M = {}
--
-- -- Вспомогательная функция для безопасного сброса слота инвентаря
-- local function get_empty_slot()
--     return {item_id = nil, amount = 0}
-- end
--
-- local function get_clean_id(item_id)
--     if type(item_id) == "userdata" then
--         return tostring(item_id):match("%[(.-)%]") or item_id
--     end
--     return item_id
-- end
--
-- -- Метод для отмены драга (просто рефреш источника)
-- function M.cancel_transfer(source_component)
--     if source_component then
--         pcall(function() source_component:refresh() end)
--     end
-- end
--
-- -- Метод для дропа предмета в мир
-- function M.drop_to_world(source_component, source_slot, item, mouse_x, mouse_y)
--     print("DROP to world")
--     msg.post("world", "spawn_dropped_item", {
--         item_id = item.item_id,
--         amount = item.amount,
--         mouse_x = mouse_x,
--         mouse_y = mouse_y
--     })
--     
--     -- Так как дропнуть в мир можно ТОЛЬКО из инвентаря, напрямую зануляем ячейку через его массив
--     local data_source = source_component:get_data_source()
--     if data_source and data_source.items then
--         data_source.items[source_slot] = get_empty_slot()
--     end
--     
--     pcall(function() source_component:refresh() end)
-- end
--
-- function M.execute_transfer(source_component, source_slot, target_component, target_slot, item, item_cfg)
--     local source_data = source_component:get_data_source()
--     local target_data = target_component:get_data_source()
--
--     ---------------------------------------------------------------------------
--     -- САМЫЙ ВЕРХНИЙ УРОВЕНЬ: Если это сплит-предмет, нам ПЛЕВАТЬ, разные окна или одно!
--     -- Мы сразу уводим выполнение в наш универсальный execute_split_transfer
--     ---------------------------------------------------------------------------
--     if item and item.source_split_slot then
--         M.execute_split_transfer(source_component, item.source_split_slot, target_component, target_slot, item, item_cfg)
--         return -- ОБЯЗАТЕЛЬНО выходим, чтобы код ниже не выполнялся!
--     end
--     ---------------------------------------------------------------------------
--     -- 1. СЛУЧАЙ: Перенос внутри самого инвентаря (Обычный драг)
--     if source_component == target_component then
--         if source_data.items then
--             local stacked = player_inventory.try_stack_items(source_slot, target_slot, item_cfg)
--             if not stacked then
--                 player_inventory.swap_slots(source_slot, target_slot)
--             end
--         end
--
--     -- 2. СЛУЧАЙ: Перенос между разными окнами (Обычный драг)
--     else
--         -- А. Из инвентаря на куклу
--         if source_data.items and target_data.slots then
--             local old_paperdoll_item = player_paperdoll.equip(target_slot, item)
--             if old_paperdoll_item and old_paperdoll_item.item_id then
--                 source_data.items[source_slot] = old_paperdoll_item
--             else
--                 source_data.items[source_slot] = {item_id = nil, amount = 0}
--             end
--
--         -- Б. С куклы в инвентарь
--         elseif source_data.slots and target_data.items then
--             local target_item = target_data.items[target_slot]
--             
--             -- Вариант 1: Слот в инвентаре пустой — просто снимаем
--             if not target_item or not target_item.item_id then
--                 target_data.items[target_slot] = item
--                 source_data.slots[source_slot] = {item_id = nil, amount = 0}
--             else
--                 -- Вариант 2: В инвентаре что-то лежит. 
--                 -- Просто спрашиваем Модель куклы: "А мы можем ВМЕСТО этой шмотки надеть ВОТ ЭТУ?"
--                 -- Мы передаем ID предмета из инвентаря, а кукла сама проверит его тип
--                 if player_paperdoll.can_equip(target_item.item_id, source_slot) then
--                     local old_inventory_item = target_data.items[target_slot]
--                     target_data.items[target_slot] = item
--                     source_data.slots[source_slot] = old_inventory_item
--                 else
--                     print("Unequip blocked: invalid swap type")
--                     M.cancel_transfer(source_component)
--                     return
--                 end
--             end           
--         -- В. Перенос между разными контейнерами .items (Инвентарь <-> Сундук)
--         elseif source_data.items and target_data.items then
--             local stacked = player_inventory.try_stack_items(source_slot, target_slot, item_cfg)
--             if not stacked then
--                 local old_target_item = target_data.items[target_slot]
--                 target_data.items[target_slot] = item
--                 if old_target_item and old_target_item.item_id then
--                     source_data.items[source_slot] = old_target_item
--                 else
--                     source_data.items[source_slot] = {item_id = nil, amount = 0}
--                 end
--             end
--         end
--     end
--
--     -- Визуальный рефреш окон для ОБЫЧНОГО драга
--     pcall(function() source_component:refresh() end)
--     if source_component ~= target_component then
--         pcall(function() target_component:refresh() end)
--         broadcast.send("inventory_events", { message_id = hash("data_updated") })
--     end
-- end
--
-- function M.execute_split_transfer(source_component, source_slot, target_component, target_slot, item, item_cfg)
--     local source_data = source_component:get_data_source()
--     local target_data = target_component:get_data_source()
--     
--     -- Проверяем, что у обоих окон есть таблицы предметов (.items)
--     if not source_data.items or not target_data.items then return end
--
--     local source_items = source_data.items
--     local target_items = target_data.items
--
--     local from_item = source_items[source_slot]
--     
--     -- Гарантируем, что целевой слот инициализирован хотя бы как пустышка
--     target_items[target_slot] = target_items[target_slot] or {item_id = nil, amount = 0}
--     local to_item = target_items[target_slot]
--
--     if not from_item or not from_item.item_id then return end
--
--     local new_amount = item.amount -- сколько выбрали в сплиттере (например, 3)
--
--     ---------------------------------------------------------------------------
--     -- СЦЕНАРИЙ 1: Бросаем в абсолютно пустую ячейку целевого окна
--     ---------------------------------------------------------------------------
--     if not to_item.item_id or to_item.amount <= 0 then
--         -- Записываем отщипнутый кусок в цель (в сундук или другую сумку)
--         to_item.item_id = from_item.item_id
--         to_item.amount = new_amount
--
--         -- Вычитаем из исходного слота (в инвентаре)
--         from_item.amount = from_item.amount - new_amount
--         if from_item.amount <= 0 then
--             source_items[source_slot] = {item_id = nil, amount = 0}
--         end
--
--     ---------------------------------------------------------------------------
--     -- СЦЕНАРИЙ 2: Бросаем на ТАКОЙ ЖЕ предмет в целевом окне (Слияние)
--     ---------------------------------------------------------------------------
--     elseif get_clean_id(from_item.item_id) == get_clean_id(to_item.item_id) and item_cfg and item_cfg.stackable then
--         local max_stack = item_cfg.max_stack or 64
--         local space_left = max_stack - to_item.amount
--
--         if space_left > 0 then
--             local to_add = math.min(new_amount, space_left)
--
--             to_item.amount = to_item.amount + to_add
--             from_item.amount = from_item.amount - to_add
--
--             if from_item.amount <= 0 then
--                 source_items[source_slot] = {item_id = nil, amount = 0}
--             end
--         end
--     ---------------------------------------------------------------------------
--     -- СЦЕНАРИЙ 3: Бросаем на ЧУЖОЙ предмет (Блокировка и отмена)
--     ---------------------------------------------------------------------------
--     else
--         print("SPLIT TRANSFER BLOCKED: Invalid target item. Resetting.")
--         -- Ничего не меняем, при рефреше исходный стак просто склеится обратно
--     end
--
--     -- Визуально обновляем оба окна, теперь данные железно синхронизированы!
--     pcall(function() source_component:refresh() end)
--     if source_component ~= target_component then
--         pcall(function() target_component:refresh() end)
--         
--         -- Шлем сигнал, если сплитали между разными окнами (на случай, если это как-то заденет статы)
--         print('FROM item_transfer_manager.lua: split data_updated')
--         broadcast.send("inventory_events", { message_id = hash("data_updated") })
--     end
-- end
--
-- return M
