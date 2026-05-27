local items_db = require("main.modules.data.items_db")
local interaction = require("main.modules.interaction")

---@class Inventory
local M = {}

M.max_slots = 48
---@type Item[]
M.items = {}

---@param item_id any
---@return string|any
local function get_clean_id(item_id)
    if type(item_id) == "userdata" then
        return interaction.clean_id(item_id)
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
---@return boolean
function M.add_item(item_id, amount, uid) -- Добавили uid
    local data = items_db.get_item(item_id)
    if not data then return false end

    local remaining = amount
    local item_hash = type(item_id) == "string" and hash(item_id) or item_id
    local max_stack = data.max_stack or 1

    -- 1. ЛОГИКА ДЛЯ СТАКАЕМЫХ (Зелья, стрелы)
    if data.stackable then
        for i = 1, M.max_slots do
            local slot = M.items[i]
            if slot and slot.item_id == item_hash and slot.amount < max_stack then
                local add = math.min(remaining, max_stack - slot.amount)
                ---@diagnostic disable-next-line: assign-type-mismatch
                slot.amount = slot.amount + add
                remaining = remaining - add
                -- При стаке UID не сохраняем, т.к. это "расходник"
                if remaining <= 0 then return true end
            end
        end
    end

    -- 2. ЛОГИКА ДЛЯ НОВЫХ СЛОТОВ (Мечи, броня или остатки стака)
    for i = 1, M.max_slots do
        local slot = M.items[i]
        if slot and not slot.item_id then
            local add = math.min(remaining, max_stack)
            slot.item_id = item_hash
            ---@diagnostic disable-next-line: assign-type-mismatch
            slot.amount = add
            -- ВАЖНО: сохраняем UID только если это первый предмет в слоте
            -- и если это не стакаемый хлам (либо стак из 1 предмета)
            slot.uid = uid

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

---@return table
function M.get_save_data()
    local data = {}
    for i = 1, M.max_slots do
        local item = M.items[i]
        if item and item.item_id then
            local id_str = interaction.clean_id(item.item_id)
            data[i] = {
                id = id_str,
                amount = item.amount,
                uid = item.uid -- СОХРАНЯЕМ UID
            }
        else
            data[i] = { id = nil, amount = 0, uid = nil }
        end
    end
    return data
end

---@param data table
function M.load_save_data(data)
    M.init()
    if not data then return end
    for index, saved in pairs(data) do
        local i = tonumber(index)
        if i and saved and saved.id then
            M.items[i] = {
                item_id = hash(saved.id),
                amount = saved.amount,
                uid = saved.uid -- ВОССТАНАВЛИВАЕМ UID
            }
        end
    end
end

M.init()
return M

