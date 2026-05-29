local interaction_manager = require("main.modules.logic.interaction_manager")
local item_transfer_manager = require("main.modules.item_transfer_manager")
local items_db = require("main.modules.data.items_db")
local character_data = require("main.modules.character.character_data")

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
        local player_pos = character_data.player.last_pos
        local source = interaction_manager.get_player_inventory()
        item_transfer_manager.drop_to_world(
            source,
            data.slot_index,
            source:get_item(data.slot_index),
            player_pos.x,
            player_pos.y + 50
        )
    end,

    -- === СЛАЙС 2: ГЛОБАЛЬНЫЕ ДЕЙСТВИЯ В МИРЕ (context_menu_action по объектам) ===
    ["container_open"] = function(data)
        -- Логика вскрытия бочки (проксируем обычный клик объекту мира)
        if data.target_go_id then
            msg.post(data.target_go_id, "click")
        end
    end,

    ["item_loot_pickup"] = function(data)
        -- Логика подбора шмотки с земли
        if data.target_go_id then
            msg.post(data.target_go_id, "click")
        end
    end,

    ["creature_attack"] = function(data)
        -- ⚔️ ЗАДЕЛ НА БУДУЩЕЕ: Сюда прилетит клик "Атаковать кабана" из меню!
        print("БЭКЕНД БОЯ: Начинаем охоту на кабана:", data.target_go_id)
    end
}

return M

