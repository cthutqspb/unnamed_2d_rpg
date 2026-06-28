local interaction_manager = require("main.modules.logic.interaction_manager")
local item_transfer_manager = require("main.modules.item_transfer_manager")
local combat_manager = require("main.modules.system.combat_manager")
local items_db = require("main.modules.data.items_db")
local character_data = require("main.modules.character.character_data")
local unit_logic = require("main.modules.unit.logic.unit_logic")

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

        -- =========================================================================
        -- 🦾 1. КРИСТАЛЬНО ЗРЯЧЕЕ РАСПРЕДЕЛЕНИЕ МОДЕЛЕЙ (ИСПРАВЛЕНО)
        -- =========================================================================
        -- Если GUI-слой (будь то драг или даблклик) ЯВНО передал оверрайды Источника и Цели,
        -- мы берём ИХ и только их! Никаких угадываний и подмен фокусами сундуков!
        if data.source_model_override and data.target_model_override then
            source = data.source_model_override
            target = data.target_model_override
        else
            -- Фоллбек-канал для кликов, где один из оверрайдов мог потеряться
            if data.from_paperdoll then
                source = data.source_model_override
                target = data.target_model_override
            else
                source = data.source_model_override

                -- 🛡️ ГВАРД ПЕРЕВЁРТЫША (ЗАЩИТА):
                -- При луте из сундука в рюкзак, target_focus возвращает СУНДУК.
                -- Чтобы сундук не перезаписал рюкзак мага, мы берём фокус только в том случае,
                -- если мы тащим вещь ИЗ инвентаря ВО внешний сундук!
                -- А если вещь летит ИЗ внешнего сундука, целью обязан стать рюкзак мага!
                local target_focus = interaction_manager.get_focus and interaction_manager.get_focus()

                if target_focus and target_focus ~= source then
                    target = target_focus
                else
                    target = data.target_model_override
                end

                -- Авто-вычисление куклы по обратной ссылке, если цель пустая
                if not target and source and source.owner then
                    target = source.owner.paperdoll
                end
            end
        end

        -- Читаем предмет из прилетевшей бэкенд-модели источника
        local item = data.item_override or (source and source.get_item and source:get_item(data.slot_index))

        if item and item_cfg and source and target then
            local target_slot = data.target_slot -- Куда бросили мышку

            -- =========================================================================
            -- 🛡️ АБСОЛЮТНАЯ ЗАЩИТА ОТ АННИГИЛЯЦИИ (Твой оригинальный код матрешки)
            -- =========================================================================
            if target.items and item then
                local target_uid = target.uid or (target.item_data and target.item_data.uid)
                local is_same_array = (item.items and item.items == target.items)
                local is_same_uid = (item.uid and target_uid and item.uid == target_uid)

                if is_same_array or is_same_uid then
                    print("🚨 СИНГУЛЯРНОСТЬ [Dispatcher]: Заблокирована попытка засунуть бочку в себя! UID:", item.uid)
                    item_transfer_manager.finalize()
                    return
                end

                if item.items then
                    for _, sub_item in pairs(item.items) do
                        if sub_item then
                            local sub_same_array = (sub_item.items and sub_item.items == target.items)
                            local sub_same_uid = (sub_item.uid and target_uid and sub_item.uid == target_uid)
                            if sub_same_array or sub_same_uid then
                                print("🚨 СИНГУЛЯРНОСТЬ [Dispatcher]: Заблокирована попытка положить родителя во вложенную сумму!")
                                item_transfer_manager.finalize()
                                return
                            end
                        end
                    end
                end

                -- =========================================================================
                -- 🛡️ ТИТАНОВЫЙ ААА-ГВАРД ЗАПРEТA МAТРЁШEК (ИСПРАВЛЕНО НА ТИПЫ ДАННЫХ):
                -- =========================================================================
                -- 1. Мы смотрим на чистый геймдизайнерский чертеж шмотки, которую несем.
                --    Если в items_db у нее написано type = "container", это матрешка, 
                --    неважно — бочка это, кошелек или труп ["unit_loot_bag"]!
                local is_incoming_item_a_container = item_cfg and (item_cfg.type == "container")

                -- 2. Проверяем, является ли ЦEЛЬ (target) инвентарем внешнего сундука
                local is_target_a_sub_chest = target_uid and target_uid ~= "" and target_uid ~= "player"

                if is_incoming_item_a_container and is_target_a_sub_chest then
                    print("🚨 ДИСПЕТЧЕР: Дроп заблокирован по типу [container]! Нельзя класть сумки в сундуки. Цель UID: " .. tostring(target_uid))

                    item_transfer_manager.finalize()
                    return
                end
                -- =========================================================================
            end

            -- =========================================================================
            -- 🦾 ВЫЧИСЛЕНИЕ СЛОТА ДЛЯ ДАБЛКЛИКОВ ЧЕРЕЗ DUCK TYPING
            -- =========================================================================
            if not target_slot then
                if target.get_first_empty_slot then
                    -- 💼 Если у целевой таблицы есть метод поиска ячейки — это ИНВЕНТАРЬ/СУМКА!
                    target_slot = target:get_first_empty_slot()
                    if not target_slot then print("Инвентарь полон!") return end
                else
                    -- 🛡️ Если метода нет — это наша универсальная объектная КУКЛА ШМОТА (Paperdoll)!
                    target_slot = item_cfg.equip_slot
                end
            end

            -- 🛡️ ГВАРД ХАРАКТЕРИСТИК ДЛЯ ОБЪЕКТНОЙ КУКЛЫ:
            if not target.get_first_empty_slot and target.can_equip_item then
                -- Кукла благодаря owner сама тихо проверит Силу/Интеллект своего хозяина в RAM!
                if not target:can_equip_item(item, target_slot) then
                    print("💾 БЭКЕНД: Транзакция отклонена, юнит не подходит по характеристикам!")
                    item_transfer_manager.finalize()
                    return
                end
            end

            -- 3. Передаем в execute_transfer ПРАВИЛЬНЫЕ объектные модели
            item_transfer_manager.execute_transfer(
                source, data.slot_index,
                target, target_slot,
                item, item_cfg
            )
        end
    end,

    ["item_drop"] = function(data)
        -- =========================================================================
        -- 🦾 АБСОЛЮТНО СЛЕПОЙ ААА-СБРОС ПРЕДМЕТОВ (РОДНОЙ КАНОН CHARACTER_DATA)
        -- =========================================================================
        -- Никаких require("game_state")! Диспетчер чист от импортов бэкенд-стейтов.
        -- Мы зряче берем ЛИБО оверрайд из gui_script, ЛИБО нативное поле из drag_manager
        local source = data.source_model_override or data.source_model
        if not source then print("🚨 ДИСПЕТЧЕР [item_drop]: Источник транзакции не найден!") return end

        -- 🧱 ТИТАНОВЫЙ КАСКАДНЫЙ ЛОКАТОР КООРДИНАТ ИЗ ТВОЕГО РОДНОГО СИНГЛТОНА (ИСПРАВЛЕНО):
        -- 1. Если вещь выкидывает Юнит со своим рюкзаком — берем координаты из его паспорта (source.owner).
        -- 2. Если вещь выкидывают из СУНДУКА (owner == nil) — мы пуленепробиваемо вытаскиваем 
        --    живую текущую позицию мага на Meadows-карте из твоего вечного модуля character_data!
        --    Мы проверяем все возможные варианты полей (.saved_position или прямой .position),
        --    чтобы полностью защитить вектор от падения в nil!
        local player_ref = character_data and character_data.player

        local base_position = (source.owner and source.owner.saved_position)
            or (player_ref and player_ref.saved_position)
            or (player_ref and player_ref.position) -- доп-страховка на случай смены имени поля в мосту

        -- 💥 МАТЕМАТИКА ГЕЙМДИЗАЙНА: Спавним лут строго на +40 пикселей СВЕРХУ НАД НОГАМИ МАГА!
        local calculated_drop_pos = vmath.vector3(base_position.x, base_position.y + 40, 0)
        print("🎯 ДИСПЕТЧЕР: Успешный расчет точки сброса шмотки у ног Юнита:", calculated_drop_pos)

        -- Вызываем атомарный сервис спавна физического лута на Meadows-карте
        item_transfer_manager.drop_to_world(
            source,
            data.slot_index,
            source:get_item(data.slot_index),
            calculated_drop_pos
        )
    end,


    -- === СЛАЙС 2: ГЛОБАЛЬНЫЕ ДЕЙСТВИЯ В МИРЕ (context_menu_action по объектам) ===
    -- ["container_open"] = function(data)
    --     -- ВЕТКА А: Бочка стоит на земле Meadows (Есть физический ID тела)
    --     if data.target_go_id then
    --         msg.post(data.target_go_id, "click")
    --
    --     -- 🎯 ВЕТКА Б: БОЧКА В КАРМАНЕ (Твой нативный чистый msg.post):
    --     -- Если физического ID нет, но прилетел slot_index — значит, открываем Матрёшку из рюкзака!
    --     -- Шлём Си-сигнал напрямую в GUI окна контейнеров, передавая паспорт ячейки.
    --     elseif data.slot_index then
    --         msg.post("game_scene:/world#world", "prepare_pocket_container", {
    --             container_uid = data.target_uid,
    --             item_id = data.item_id,
    --             slot_index = data.slot_index,
    --             unit_uid = data.unit_uid or "player"
    --         })
    --         print("КОНТРОЛЛЕР [Dispatcher]: Запрос Бэкенду на генерацию лута в карманной бочке. Слот: " .. data.slot_index)
    --     end
    -- end,

    -- ["container_open_world"] = function(data)
    --  -- =========================================================================
    --     -- 🦾 1. ТВОЙ РОДНОЙ, ПЛОСКИЙ И КРИСТАЛЬНО ЧИСТЫЙ КОД (БЕЗ ЛАПШИ И ИМПОРТОВ!)
    --     -- =========================================================================
    --     -- Мы работаем strictly с тем, что прислал бэкенд в payload. 
    --     -- Никаких require стейтов и никаких выдуманных регистраторов контейнеров!
    --     local instance = data.instance_data
    --     local cfg = data.db_cfg
    --     if not instance then return end
    --
    --     -- Если в персистентной таблице сундука на земле лута еще нет — генерируем один раз!
    --     if not instance.items then
    --         local final_loot_id = instance.loot_table_id or "empty"
    --         if final_loot_id == "" or final_loot_id == "unknown" then
    --             final_loot_id = "empty"
    --         end
    --
    --         print("🎲 ДИСПЕТЧЕР: Первая ленивая генерация лута по таблице:", final_loot_id)
    --         -- Импорт loot_tables в диспетчере у тебя был разрешен изначально
    --         local generated_loot = loot_tables.get_loot(hash(final_loot_id)) or {}
    --         instance.items = generated_loot
    --     end
    --
    --     -- =========================================================================
    --     -- 🦾 2. ПРЯМАЯ ОТПРАВКА СЫРЫХ ДАННЫХ В GUI ЧЕРЕЗ MSG.POST
    --     -- =========================================================================
    --     -- Диспетчер вообще не создает никаких ООП-моделей! Метатаблицы все равно сотрутся.
    --     -- Он просто шлет плоский массив предметов сундука прямо в окно лута!
    --     msg.post("main:/container_window#gui", "open_container_window", {
    --         container_uid = data.uid,
    --         container_id = hash(data.id),
    --         container_name = hash(cfg and cfg.name_key or "container_common_chest_name"),
    --         entity_type = data.entity_type,
    --         columns = cfg and cfg.columns or 6,
    --         rows = cfg and cfg.rows or 4,
    --         position = data.position,
    --         player_pos = go.get_position("game_scene:/player"),
    --
    --         -- 🎯 ПЕРЕДАЕМ ЖИВОЙ МАССИВ ПРЕДМЕТОВ С ЗЕМЛИ:
    --         -- Окно лута примет этот плоский массив и само обернет его в зрячую модель!
    --         container_items = instance.items
    --     })
    -- end,

        -- Внутри actions_dispatcher.lua в таблице REDUCERS:

    -- =========================================================================
    -- 🦾 УНИВЕРСАЛЬНЫЙ ААА-РЕДЬЮСЕР ОТКРЫТИЯ ЛЮБЫХ КОНТЕЙНЕРОВ (ЗАФИКСИРОВАНО)
    -- =========================================================================
    -- Диспетчер полностью вычищен от логики генерации лута! Гварды переехали в GUI.
    -- Метод слепо и зряче прокидывает плоские данные напрямую в управляющий gui_script!
    ["container_open"] = function(data)
        -- ВЕТКА А: Кликнули по физической бочке на земле Meadows (Шлем Си-сигнал телу go)
        if data.target_go_id then
            msg.post(data.target_go_id, "click")
            return
        end

        -- 🧱 1. ЗРЯЧЕЕ ИЗВЛЕЧЕНИЕ ИНСТАНСА ИЗ ОБОИХ КОНТEКСТОВ (Твой оригинальный код!):
        local instance = data.instance_data

        if not instance and data.slot_index then
            -- ВЕТКА Б: МАТРЁШКА В КАРМАНЕ (Прилетел слот, но нет instance_data)
            -- Легально через мост character_data лезем в живой рюкзак мага в RAM 
            -- и вынимаем оттуда «Душу» нашей карманной бочки строго по слоту!
            local player_inv = character_data and character_data.player and character_data.player.inventory
            instance = player_inv and player_inv:get_item(data.slot_index)
        end

        if not instance then
            print("🚨 ДИСПЕТЧЕР [container_open]: Критическая ошибка! Данные инстанса сундука пусты!") 
            return
        end

        local cfg = data.db_cfg or items_db.get_item(data.id or data.item_id or instance.item_id)

        -- =========================================================================
        -- 🦾 2. ПРЯМАЯ ОТПРАВКА СЫРЫХ ДАННЫХ В GUI ЧЕРЕЗ MSG.POST
        -- =========================================================================
        -- Никаких go.get_position! Берем strictly сохраненную позицию из моста character_data!
        msg.post("main:/container_window#gui", "open_container_window", {
            container_uid = data.uid or data.target_uid or instance.uid,
            container_id = hash(data.id or "container"),
            container_name = hash(cfg and cfg.name_key or "container_common_chest_name"),
            entity_type = data.entity_type or "world_item",
            columns = cfg and cfg.columns or (data.columns) or 6,
            rows = cfg and cfg.rows or (data.rows) or 4,
            position = data.position,
            player_pos = character_data and character_data.player and character_data.player.saved_position,

            -- ПРОБРОС ФЛАГОВ И ССЫЛОК ИЗ PAYLOAD:
            container_items = instance.items,
            slot_index = data.slot_index,

            -- Сквозной ААА-проброс флага! Если открывали из рюкзака — тут прилетит true, 
            -- и окно лута Meadows пуленепробиваемо защитит себя от закрытия при беге!
            from_inventory = (data.from_inventory == true) or (data.slot_index ~= nil)
        })

        print("КОНТРОЛЛЕР [Dispatcher]: Окно контейнера успешно вызвано напрямую. Контекст from_inventory:", tostring(data.slot_index ~= nil))
    end,

    ["item_pickup"] = function(data)
        -- Логика подбора шмотки с земли
        if data.target_go_id then
            msg.post(data.target_go_id, "click")
        end
    end,

    -- === СЛАЙС 3: БОЕВОЙ ТАРГЕТИНГ И ПАНЕЛИ СПОСОБНОСТЕЙ ===
    ["action_bar_assign"] = function(data)
        local target_unit = character_data.player

        -- Перенаправляем чистый payload в метод мутации памяти
        unit_logic.set_action_bar_slot(
            data.target_bar_index,
            data.target_slot_index,
            data.drag_type, -- "ablity / "item" / "empty"
            data.action_id,  -- "melee_attack" / "frostbolt" / nil
            target_unit
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
            combat_manager.execute_ability("player", target_go_id, data.action_id)
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

    ["unit_attack"] = function(data)
        -- ⚔️ ЗАДЕЛ НА БУДУЩЕЕ: Сюда прилетит клик "Атаковать кабана" из меню!
        print("БЭКЕНД БОЯ: Начинаем охоту на кабана:", data.target_go_id)
    end,
}

return M

