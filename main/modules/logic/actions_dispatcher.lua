local interaction_manager = require("main.modules.logic.interaction_manager")
local item_transfer_manager = require("main.modules.item_transfer_manager")
local combat_manager = require("main.modules.system.combat_manager")
local items_db = require("main.modules.data.items_db")
local loot_tables = require("main.modules.data.loot_tables")
local character_data = require("main.modules.character.character_data")
local character_logic = require("main.modules.character.character_logic")

---@class ActionPayload
---@field slot_index number|string|nil Индекс слота (число для сумки, строка для куклы)
---@field item_id string|nil Строковый ID предмета ("sword", "potion")
---@field from_paperdoll boolean|nil Прилетело ли действие с куклы персонажа
---@field target_slot number|string|nil Целевой слот при перетаскивании (Drag & Drop)
---@field target_go_id hash|nil Физический ID игрового объекта в мире (бочки, лут, кабаны)
---@field target_uid string|nil Уникальный строковый UID из реестра сохранений

---@class ActionsDispatcher
local M = {}

-- 🎯 ТАБЛИЦА СТРАТЕГИЙ (НАШИ СЛАЙСЫ)
M.REDUCERS = {
    -- === СЛАЙС 1: ДЕЙСТВИЯ С ПРЕДМЕТАМИ В ИНВЕНТАРЕ (item_action) ===
    ["item_transfer"] = function(data)
        local item_cfg = items_db.get_item(data.item_id)
        local source, target

        -- 1. Определяем модели данных источника и цели
        if data.source_model_override and data.target_model_override then
            source = data.source_model_override
            target = data.target_model_override
        else
            if data.from_paperdoll then
                source = interaction_manager.get_player_paperdoll()
                target = interaction_manager.get_player_inventory()
            else
                source = interaction_manager.get_player_inventory()
                local target_focus = interaction_manager.get_focus()
                target = target_focus or interaction_manager.get_player_paperdoll()
            end
        end

        -- 2. 🎯 ГЛАВНЫЙ АРХИТЕКТУРНЫЙ ФИКС:
        -- Если предмет передан напрямую в payload (из drag_manager), мы берем ЕГО! 
        -- Ведь при сплите на курсоре летит специальный split_item, содержащий метку .source_split_slot.
        -- А если предмета в payload нет (был даблклик ЛКМ или контекстное меню), 
        -- тогда честно читаем его из бэкенд-модели по индексу слота.
        local item = data.item_override or source:get_item(data.slot_index)

        if item and item_cfg then
            local target_slot = data.target_slot -- куда бросили мышку
            -- =========================================================================
            -- 🛡️ АБСОЛЮТНАЯ ЗАЩИТА ОТ АННИГИЛЯЦИИ (Версия 4.0 — Финал)
            -- =========================================================================
            if target and target.items and item then
                -- Капкан А: Если совпали физические ссылки на массивы предметов (наша RAM-магия)
                local is_same_array = (item.items and item.items == target.items)
                
                -- Капкан Б: Проверяем UID. Если у перетаскиваемого предмета совпал UID 
                -- с UID целевой модели (если ты прокинул его в gui_script)
                local target_uid = target.uid or (target.item_data and target.item_data.uid)
                local is_same_uid = (item.uid and target_uid and item.uid == target_uid)

                -- 💥 ЕСЛИ СРАБОТАЛ ХОТЬ ОДИН КАПКАН — ОТМЕНЯЕМ СИНГУЛЯРНОСТЬ!
                if is_same_array or is_same_uid then
                    print("🚨 СИНГУЛЯРНОСТЬ [Dispatcher]: Заблокирована попытка засунуть бочку в себя! UID:", item.uid)
                    item_transfer_manager.finalize() -- Сбрасываем визуал драга, возвращая иконку на место
                    return -- Наглухо выходим, спасая рантайм
                end

                -- Рекурсивный гвард (Матрёшка): проверяем, не суем ли мы родителя в ребенка,
                -- который лежит у него же в кармане
                if item.items then
                    for _, sub_item in pairs(item.items) do
                        if sub_item then
                            local sub_same_array = (sub_item.items and sub_item.items == target.items)
                            local sub_same_uid = (sub_item.uid and target_uid and sub_item.uid == target_uid)
                            
                            if sub_same_array or sub_same_uid then
                                print("🚨 СИНГУЛЯРНОСТЬ [Dispatcher]: Заблокирована попытка положить родителя во вложенную сумку!")
                                item_transfer_manager.finalize()
                                return
                            end
                        end
                    end
                end
            end
            -- Вычисляем целевой слот для даблкликов, если его нет
            if not target_slot then
                if target == interaction_manager.get_player_paperdoll() then
                    target_slot = item_cfg.equip_slot
                elseif target == interaction_manager.get_player_inventory() then
                    target_slot = target:get_first_empty_slot()
                    if not target_slot then print("Инвентарь полон!") return end
                end
            end

            -- 3. Передаем в execute_transfer ПРАВИЛЬНЫЙ предмет (со всеми метками сплита)
            item_transfer_manager.execute_transfer(
                source, data.slot_index,
                target, target_slot,
                item, item_cfg
            )
        end
    end,

    ["item_drop"] = function(data)
        local player_position = character_data.player.last_position
        local source = data.source_model or interaction_manager.get_player_inventory()

        local calculated_drop_pos = vmath.vector3(player_position.x, player_position.y + 40, 0)
        print("calculated_drop_pos", calculated_drop_pos)
        item_transfer_manager.drop_to_world(
            source,
            data.slot_index,
            source:get_item(data.slot_index),
            calculated_drop_pos
        )
    end,

    -- === СЛАЙС 2: ГЛОБАЛЬНЫЕ ДЕЙСТВИЯ В МИРЕ (context_menu_action по объектам) ===
    ["container_open"] = function(data)
        -- ВЕТКА А: Бочка стоит на земле Meadows (Есть физический ID тела)
        if data.target_go_id then
            msg.post(data.target_go_id, "click")

        -- 🎯 ВЕТКА Б: БОЧКА В КАРМАНЕ (Твой нативный чистый msg.post):
        -- Если физического ID нет, но прилетел slot_index — значит, открываем Матрёшку из рюкзака!
        -- Шлём Си-сигнал напрямую в GUI окна контейнеров, передавая паспорт ячейки.
        elseif data.slot_index then
            msg.post("game_scene:/world#world", "prepare_pocket_container", {
                container_uid = data.target_uid,
                item_id = data.item_id,
                slot_index = data.slot_index
            })
            print("КОНТРОЛЛЕР [Dispatcher]: Запрос Бэкенду на генерацию лута в карманной бочке. Слот: " .. data.slot_index)
        end
    end,

    ["container_open_world"] = function(data)
        -- Передаем из скриптов: 
        -- data.uid (self.uid)
        -- data.id (self.creature_id или self.item_id)
        -- data.db_cfg (базовый конфиг из базы существ или предметов)
        -- data.instance_data (живая Lua-таблица из creatures_state или world_items_state)
        -- data.position (go.get_position())

        local instance = data.instance_data
        local cfg = data.db_cfg
        if not instance then return end

        -- 1. 🎯 ТВОЯ РОДНАЯ ЛЕНИВАЯ ГЕНЕРАЦИЯ (Крутится прямо внутри переданной таблицы по ссылке!)
        if not instance.items then
            local final_loot_id = instance.loot_table_id or "empty"
            if final_loot_id == "" or final_loot_id == "unknown" then
                final_loot_id = "empty"
            end

            print("🎲 ДИСПЕТЧЕР: Первая ленивая генерация лута по таблице:", final_loot_id)
            -- Импорт базы дропа loot_tables в диспетчере ПОЛНОСТЬЮ разрешен!
            local generated_loot = loot_tables.get_loot(hash(final_loot_id)) or {}
            instance.items = generated_loot
        end

        -- 2. 💥 МОНОЛИТНАЯ ОТПРАВКА В GUI
        msg.post("main:/container_window#gui", "open_container_window", {
            container_uid = data.uid,
            container_id = hash(data.id),
            container_name = hash(cfg and cfg.name_key or "container_common_chest_name"),
            entity_type = data.entity_type,
            columns = cfg and cfg.columns or 6,
            rows = cfg and cfg.rows or 4,
            position = data.position,
            player_pos = go.get_position("game_scene:/player")
        })
    end,

    ["item_pickup"] = function(data)
        -- Логика подбора шмотки с земли
        if data.target_go_id then
            msg.post(data.target_go_id, "click")
        end
    end,

    -- === СЛАЙС 3: БОЕВОЙ ТАРГЕТИНГ И ПАНЕЛИ СПОСОБНОСТЕЙ ===
    ["action_bar_assign"] = function(data)
        -- Перенаправляем чистый payload в метод мутации памяти
        character_logic.set_action_bar_slot(
            data.target_bar_index,
            data.target_slot_index,
            data.drag_type, -- "ablity / "item" / "empty"
            data.action_id  -- "melee_attack" / "frostbolt" / nil
        )
    end,

    ["action_bar_use"] = function(data)
        -- 1. Если прожали шмотку (банку маны) — отправляем в обработку предметов
        if data.drag_type == "item" then
            -- Сюда потом вставишь логику использования расходников из рюкзака
            print("БЭКЕНД: Игрок прожал банку из панели слотов")
            return
        end

        -- 2. Если прожали способность — отдаем управление в CombatManager!
        if data.drag_type == "ability" then
            -- Забираем чистый Си-хэш текущего таргета из твоего геттера
            local target_go_id = interaction_manager.get_current_target and interaction_manager.get_current_target()
            
            -- Пинаем комбат менеджер выполнить автоатаку или спелл
            combat_manager.execute_ability(data.action_id, target_go_id)
        end
    end,

    -- ["action_bar_use"] = function(data)
    --     -- 1. Вытаскиваем, какую способность или предмет активировали
    --     local action_id = data.action_id      -- Например, "melee_attack"
    --     local drag_type = data.drag_type      -- "ability" или "item"
    --
    --     -- 2. Достаем текущую цель (выделенный таргет)
    --     -- Подставь свой метод, которым ты забираешь ID выделенного монстра
    --     local target_id = interaction_manager.get_current_target and interaction_manager.get_current_target()
    --
    --     print("--- ОТЛАДКА БОЯ ---")
    --     print("Активирован слот панели! Тип:", tostring(drag_type), "| ID:", tostring(action_id))
    --     print("Текущая цель в таргете (ID):", tostring(target_id))
    --
    --     -- 3. Если цель выделена — считаем расстояние между векторами
    --     if target_id then
    --         local player_pos = go.get_position("game_scene:/player") -- Путь к твоему плееру
    --         local target_pos = go.get_position(target_id)
    --
    --         -- Вычисляем длину вектора разницы между игроком и целью
    --         local distance = vmath.length(player_pos - target_pos)
    --         
    --         print(string.format("Дистанция до цели: %.2f пикселей", distance))
    --     else
    --         print("Расстояние посчитать нельзя: цель отсутствует.")
    --     end
    --     print("-------------------")
    -- end,

    ["creature_attack"] = function(data)
        -- ⚔️ ЗАДЕЛ НА БУДУЩЕЕ: Сюда прилетит клик "Атаковать кабана" из меню!
        print("БЭКЕНД БОЯ: Начинаем охоту на кабана:", data.target_go_id)
    end,
}

return M

