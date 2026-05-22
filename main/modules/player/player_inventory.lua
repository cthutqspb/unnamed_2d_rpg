local items_db = require("main.modules.data.items_db")

local M = {}

M.max_slots = 48
M.items = {} 

local function get_clean_id(item_id)
    if type(item_id) == "userdata" then
        return tostring(item_id):match("%[(.-)%]") or item_id
    end
    return item_id
end

-- Вспомогательная функция для пустой ячейки
local function empty_slot()
    return { item_id = nil, amount = 0 }
end

function M.init()
    for i = 1, M.max_slots do
        M.items[i] = empty_slot()
    end
end

-- ИНТЕРФЕЙСНЫЕ МЕТОДЫ (для StaticGrid и TransferManager)
function M:get_item(idx)
    return self.items[idx]
end

function M:set_item(idx, data)
    self.items[idx] = data or empty_slot()
end

function M.add_item(item_id, amount)
    -- Оставляем старую логику добавления (использует M.items напрямую для игрока)
    local data = items_db.get_item(item_id)
    if not data then return false end

    local remaining = amount
    local item_hash = type(item_id) == "string" and hash(item_id) or item_id
    local max_stack = data.max_stack or 1

    if data.stackable then
        for i = 1, M.max_slots do
            local slot = M.items[i]
            if slot.item_id == item_hash and slot.amount < max_stack then
                local add = math.min(remaining, max_stack - slot.amount)
                slot.amount = slot.amount + add
                remaining = remaining - add
                if remaining <= 0 then return true end
            end
        end
    end

    for i = 1, M.max_slots do
        local slot = M.items[i]
        if not slot.item_id then
            local add = math.min(remaining, max_stack)
            slot.item_id = item_hash
            slot.amount = add
            remaining = remaining - add
            if remaining <= 0 then return true end
        end
    end
    return remaining <= 0
end

-- Методы контекстного меню
function M.equip_item(item)
    
end

-- В player_inventory.lua
function M:get_first_empty_slot()
    for i = 1, self.max_slots do
        if not self.items[i] or not self.items[i].item_id then
            return i
        end
    end
    return nil
end


-- УНИВЕРСАЛЬНЫЕ МЕТОДЫ (теперь через self.items)
function M:swap_slots(from_idx, to_idx)
    self.items[from_idx], self.items[to_idx] = self.items[to_idx], self.items[from_idx]
end

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
    to_item.amount = to_item.amount + to_add
    from_item.amount = from_item.amount - to_add

    if from_item.amount <= 0 then
        self.items[from_index] = empty_slot()
    end

    return true
end

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
    to_item.amount = to_item.amount + to_add
    from_item.amount = from_item.amount - to_add

    -- Если в источнике ничего не осталось — зануляем его там
    if from_item.amount <= 0 then
        other_model:set_item(from_idx, nil)
    end

    return true
end

-- В player_inventory.lua

function M:split_stack(other_model, from_idx, to_idx, new_amount, item_cfg)
    local from_item = other_model:get_item(from_idx) -- Берем из ИСТОЧНИКА
    local to_item = self:get_item(to_idx)           -- Кладем в СЕБЯ (цель)

    if not from_item or not from_item.item_id then return false end

    -- 1. СЦЕНАРИЙ: В пустой слот
    if not to_item or not to_item.item_id or to_item.amount <= 0 then
        self:set_item(to_idx, {
            item_id = from_item.item_id,
            amount = new_amount
        })
        
        -- Вычитаем из источника
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
            
            to_item.amount = to_item.amount + to_add
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
    M.init()
end

function M.get_save_data()
    local data = {}
    for i = 1, M.max_slots do
        local item = M.items[i]
        if item and item.item_id then
            local id_str = tostring(item.item_id):match("%[(.-)%]") or tostring(item.item_id)
            data[i] = { id = id_str, amount = item.amount }
        else
            data[i] = { id = nil, amount = 0 }
        end
    end
    return data
end

function M.load_save_data(data)
    M.init()
    if not data then return end
    for index, saved in pairs(data) do
        local i = tonumber(index)
        if i and saved and saved.id then
            M.items[i] = { item_id = hash(saved.id), amount = saved.amount }
        end
    end
end

M.init()
return M

