local items_db = require("main.modules.data.items_db")
local interactions = require("main.modules.interactions")

---@class Inventory
local M = {}

M.max_slots = 49
---@type Item[]
M.items = {}

---@param item_id any
---@return string|any
local function get_clean_id(item_id)
    if type(item_id) == "userdata" then
        return interactions.clean_id(item_id)
    end
    return item_id
end

-- Вспомогательная функция для пустой ячейки
---@return Item
local function empty_slot()
    return { item_id = nil, amount = 0, uid = nil } -- Добавь uid = nil
end

function M.init()
    for i = 1, M.max_slots do
        M.items[i] = empty_slot()
    end
end

-- ИНТЕРФЕЙСНЫЕ МЕТОДЫ (для StaticGrid и TransferManager)
---@param idx number
---@return Item
function M:get_item(idx)
    -- Добавляем fallback на пустой слот, чтобы убрать "return-type-mismatch"
    return self.items[idx] or empty_slot()
end

---@param idx number
---@param data Item|nil
function M:set_item(idx, data)
    self.items[idx] = data or empty_slot()
end

---@param item_id hash|string
---@param amount number
---@param uid string|nil
---@param items table|nil Внутренний лут бочки (если подобрали с земли)
---@param is_looted boolean|nil Статус обыска бочки
---@return boolean
function M.add_item(item_id, amount, uid, items, is_looted)
    local item = items_db.get_item(item_id)
    if not item then return false end

    local remaining = amount
    local item_hash = type(item_id) == "string" and hash(item_id) or item_id
    local max_stack = item.properties.max_stack or 1

    -- 1. ЛОГИКА ДЛЯ СТАКАЕМЫХ (Зелья, стрелы)
    if item.properties.stackable then
        for i = 1, M.max_slots do
            local slot = M.items[i]
            if slot and slot.item_id == item_hash and slot.amount < max_stack then
                local add = math.min(remaining, max_stack - slot.amount)
                slot.amount = slot.amount + add
                remaining = remaining - add
                if remaining <= 0 then return true end
            end
        end
    end

    -- 2. ЛОГИКА ДЛЯ НОВЫХ СЛОТОВ (Каноничный поиск свободного места)
    for i = 1, M.max_slots do
        local slot = M.items[i]

        -- ИСПРАВЛЕНИЕ: Слот считается пустым, если таблицы нет (nil) ИЛИ если это пустая заглушка без ID
        if not slot or not slot.item_id then
            local add = math.min(remaining, max_stack)

            -- Рождаем полноценный объект предмета со всеми его паспортами и Душой!
            local new_item = {
                item_id = item_hash,
                amount = add,
                uid = uid,                    -- 🦾 ТИТАНОВЫЙ ФИКС: Паспорт теперь в кармане!
                items = items or nil,         -- Переносим сгенерированный на земле лут
                is_looted = is_looted or nil
            }

            -- 🎯 СТРАХОВКА: Если бочка поднята из редактора (без UID), генерируем паспорт прямо на лету!
            if not new_item.uid and item.action_type == "container_item" then
                local s_id = interactions.clean_id(item_id) or "container"
                new_item.uid = string.format("%s_%d_%d", s_id, os.time(), math.random(1000, 9999))
            end

            -- Записываем готовый предмет в массив инвентаря
            M.items[i] = new_item

            remaining = remaining - add
            if remaining <= 0 then return true end
        end
    end
    return remaining <= 0
end


---@param _item Item
---@param _slot_idx number
---@return boolean
function M:can_equip_item(_item, _slot_idx)
    -- Инвентарю плевать, что в него кладут. Всегда true.
    return true
end

---@param _item Item
function M.equip_item(_item)
    -- Будущая логика контекстного меню
end

---@return number|nil
function M:get_first_empty_slot()
    for i = 1, self.max_slots do
        if not self.items[i] or not self.items[i].item_id then
            return i
        end
    end
    return nil
end


-- УНИВЕРСАЛЬНЫЕ МЕТОДЫ (теперь через self.items)
---@param from_idx number
---@param to_idx number
function M:swap_slots(from_idx, to_idx)
    self.items[from_idx], self.items[to_idx] = self.items[to_idx], self.items[from_idx]
end

---@param from_index number
---@param to_index number
---@param item_cfg table
---@return boolean
function M:try_stack_items(from_index, to_index, item_cfg)
    local from_item = self.items[from_index]
    local to_item = self.items[to_index]

    if not from_item or not from_item.item_id or not to_item or not to_item.item_id then
        return false
    end

    if not item_cfg or not item_cfg.stackable then
        return false
    end

    if get_clean_id(from_item.item_id) ~= get_clean_id(to_item.item_id) then
        return false
    end

    local max_stack = item_cfg.max_stack or 64
    local space_left = max_stack - to_item.amount

    if space_left <= 0 then return false end

    local to_add = math.min(from_item.amount, space_left)
    ---@diagnostic disable-next-line: assign-type-mismatch
    to_item.amount = to_item.amount + to_add
    ---@diagnostic disable-next-line: assign-type-mismatch
    from_item.amount = from_item.amount - to_add

    if from_item.amount <= 0 then
        self.items[from_index] = empty_slot()
    end

    return true
end

---@param other_model Inventory
---@param from_idx number
---@param to_idx number
---@param item_cfg table
---@return boolean
function M:try_stack_items_from(other_model, from_idx, to_idx, item_cfg)
    local from_item = other_model:get_item(from_idx)
    local to_item = self:get_item(to_idx)

    if not from_item or not from_item.item_id or not to_item or not to_item.item_id then
        return false
    end

    -- Твоя логика проверки ID и stackable
    if not item_cfg or not item_cfg.stackable then return false end

    -- Сравниваем ID (используй свою функцию get_clean_id)
    if get_clean_id(from_item.item_id) ~= get_clean_id(to_item.item_id) then
        return false
    end

    local max_stack = item_cfg.max_stack or 64
    local space_left = max_stack - to_item.amount
    if space_left <= 0 then return false end

    local to_add = math.min(from_item.amount, space_left)
    ---@diagnostic disable-next-line: assign-type-mismatch
    to_item.amount = to_item.amount + to_add
    ---@diagnostic disable-next-line: assign-type-mismatch
    from_item.amount = from_item.amount - to_add

    -- Если в источнике ничего не осталось — зануляем его там
    if from_item.amount <= 0 then
        other_model:set_item(from_idx, nil)
    end

    return true
end

---@param item_id hash|string
---@param amount number
---@param item_cfg table
---@return number @Возвращает остаток (0 если всё стакнулось)
function M:try_stack_item_anywhere(item_id, amount, item_cfg)
    local remaining = amount
    local target_id = type(item_id) == "string" and hash(item_id) or item_id

    for i = 1, self.max_slots do
        local slot = self.items[i]

        -- 🚩 ВОТ ЭТА СТРОКА УБИРАЕТ ВСЕ ОШИБКИ ЛИНТЕРА НИЖЕ
        if slot and slot.item_id == target_id then
            local max_stack = item_cfg.max_stack or 64
            local space = max_stack - slot.amount

            if space > 0 then
                local to_add = math.min(remaining, space)
                -- Теперь тут не будет "slot may be nil"
                ---@diagnostic disable-next-line: assign-type-mismatch
                slot.amount = slot.amount + to_add
                remaining = remaining - to_add
            end
        end

        if remaining <= 0 then return 0 end
    end
    return remaining
end

---@param other_model Inventory
---@param from_idx number
---@param to_idx number
---@param new_amount number
---@param item_cfg table
---@return boolean
function M:split_stack(other_model, from_idx, to_idx, new_amount, item_cfg)
    local from_item = other_model:get_item(from_idx) -- Берем из ИСТОЧНИКА
    local to_item = self:get_item(to_idx)           -- Кладем в СЕБЯ (цель)

    if not from_item or not from_item.item_id then return false end

    -- 1. СЦЕНАРИЙ: В пустой слот
    if not to_item or not to_item.item_id or to_item.amount <= 0 then
        ---@type Item
        local new_item = {
            item_id = from_item.item_id,
            ---@diagnostic disable-next-line: assign-type-mismatch
            amount = new_amount,
            uid = from_item.uid
        }
        self:set_item(to_idx, new_item)

        -- Вычитаем из источника
        ---@diagnostic disable-next-line: assign-type-mismatch
        from_item.amount = from_item.amount - new_amount
        if from_item.amount <= 0 then
            other_model:set_item(from_idx, nil)
        end
        return true
    end

    -- 2. СЦЕНАРИЙ: Слияние (бросаем сплит в существующий такой же стак)
    local id1 = get_clean_id(from_item.item_id)
    local id2 = get_clean_id(to_item.item_id)

    if id1 == id2 and item_cfg and item_cfg.stackable then
        local max_stack = item_cfg.max_stack or 64
        local space_left = max_stack - to_item.amount

        if space_left > 0 then
            local to_add = math.min(new_amount, space_left)

            ---@diagnostic disable-next-line: assign-type-mismatch
            to_item.amount = to_item.amount + to_add
            ---@diagnostic disable-next-line: assign-type-mismatch
            from_item.amount = from_item.amount - to_add

            if from_item.amount <= 0 then
                other_model:set_item(from_idx, nil)
            end
            return true
        end
    end

    return false
end

-- СИСТЕМНЫЕ МЕТОДЫ
function M.clear()
    -- Просто вызываем уже готовую логику создания пустых слотов
    M.init()
end

---@return table flat_save_snapshot
function M.get_save_data()
    local saved_data = {}
    for i = 1, M.max_slots do
        local item = M.items[i]
        if item and item.item_id then
            local id_str = interactions.clean_id(item.item_id)

            -- 🚀 ЧИСТЫЙ ФЛЭТ ЛОСК: Сохраняем strictly только плоский паспорт ячейки!
            saved_data[i] = {
                item_id = id_str, -- Перевыровнено на чистый ААА-нейминг без легаси .id!
                amount  = item.amount or 1,
                uid     = item.uid
            }

            -- Если это матрешка (сундук/бочка в сумке), забираем её статус обыска и кишки лута!
            if item.is_looted then saved_data[i].is_looted = item.is_looted end
            if item.loot_table_id then saved_data[i].loot_table_id = item.loot_table_id end

            if item.items then
                saved_data[i].items = {}
                for sub_item_idx, sub_item in pairs(item.items) do
                    if sub_item then
                        saved_data[i].items[sub_item_idx] = {
                            item_id = interactions.clean_id(sub_item.item_id),
                            amount  = sub_item.amount or 1,
                            uid     = sub_item.uid
                        }
                    end
                end
            end
        else
            -- Пустой слот запекается стерильной дефолтной заглушкой пустоты
            saved_data[i] = { item_id = nil, amount = 0, uid = nil }
        end
    end
    return saved_data
end

---Восстановить содержимое сумки/сундука из таблицы сохранения JSON
---@param saved_data table
function M:load_save_data(saved_data)
    self:clear() -- Всплываем девственно чистой сеткой слотов
    if not saved_data then return end

    for index, saved_item in pairs(saved_data) do
        local i = tonumber(index)

        -- Читаем имя шмотки strictly по нашему новому породистому ключу item_id!
        local raw_id = saved_item and saved_item.item_id

        if i and saved_item and raw_id and raw_id ~= "" and raw_id ~= "null" then
            -- 🚀 ООП-РЕАНИМАЦИЯ ЯЧЕЙКИ: Переводим строки JSON обратно в Си-хэши Defold!
            local restored_item = {
                item_id       = hash(raw_id),
                amount        = saved_item.amount or 1,
                uid           = saved_item.uid,
                is_looted     = (saved_item.is_looted == true),
                loot_table_id = saved_item.loot_table_id or nil
            }

            -- Накат вложенных матрешек (сумка в сумке)
            if saved_item.items then
                restored_item.items = {}
                for sub_item_idx, sub_saved_item in pairs(saved_item.items) do
                    local idx = tonumber(sub_item_idx)
                    local sub_item_raw_id = sub_saved_item and sub_saved_item.item_id
                    if idx and sub_saved_item and sub_item_raw_id then
                        restored_item.items[idx] = {
                            item_id       = hash(sub_item_raw_id),
                            amount        = sub_saved_item.amount or 1,
                            uid           = sub_saved_item.uid,
                            is_looted     = (sub_saved_item.is_looted == true),
                            loot_table_id = sub_saved_item.loot_table_id or nil
                        }
                    end
                end
            end

            -- Записываем живой, зрячий ООП-предмет в массив ячейки рантайма!
            self.items[i] = restored_item
        end
    end
end

M.init()
return M

