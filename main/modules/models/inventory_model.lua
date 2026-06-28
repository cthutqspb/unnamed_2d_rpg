-- main/modules/models/inventory_model.lua
local items_db = require("main.modules.data.items_db")
local interactions = require("main.modules.interactions")

---@class Item
---@field is_looted boolean|nil       🎯 ДИНАМИЧЕСКИЙ ФЛАГ: Был ли контейнер уже обчищен игроком
---@field items table<number, Item>|nil 💥 РЕКУРСИВНАЯ МАТРЕШКА: Внутри ячейки этого предмета (бочки) может лежать массив точно таких же предметов Item!
---@field loot_table_id string|nil
---@field action_type string|nil

---@class InventoryInstance
---@field uid string|nil
---@field max_slots number
---@field items Item[]
---@field owner table|nil 🦾 ОБРАТНАЯ ССЫЛКА: RAM-паспорт владельца инвентаря
local M = {}
M.__index = M

---🦾 AAA-КОНСТРУКТОР: Родить независимую сумку/контейнер в RAM
---@param owner table|nil Живой RAM-паспорт существа (мага, скелета, сундука)
---@param custom_slots number|nil Опциональный размер сетки, дефолт 49
---@return InventoryInstance
function M.new(owner, custom_slots)
    local instance = setmetatable({}, M)

    instance.owner = owner
    instance.max_slots = custom_slots or 49
    instance.items = {}

    -- Инициализируем пустые ячейки-заглушки для этого конкретного инстанса
    for i = 1, instance.max_slots do
        instance.items[i] = { item_id = nil, amount = 0, uid = nil }
    end

    return instance
end

---@param item_id any
---@return string|any
local function get_clean_id(item_id)
    if type(item_id) == "userdata" then
        return interactions.clean_id(item_id)
    end
    return item_id
end

-- Вспомогательный локальный хелпер для сброса слотов в ноль
---@return Item
local function empty_slot()
    return { item_id = nil, amount = 0, uid = nil }
end

-- =========================================================================
-- 🦾 ИНТЕРФЕЙСНЫЕ ОБЪЕКТНЫЕ МЕТОДЫ (РАБОТАЮТ НА СEЛФ 'self')
-- =========================================================================

---@param idx number
---@return Item
function M:get_item(idx)
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
---@param sub_items table|nil Внутренний лут бочки (если подобрали с земли)
---@param is_looted boolean|nil Статус обыска бочки
---@return boolean
function M:add_item(item_id, amount, uid, sub_items, is_looted, loot_table_id) -- 🎯 ИСПРАВЛЕНО: Теперь метод вызывается через двоеточие!
    local data = items_db.get_item(item_id)
    if not data then return false end

    local remaining = amount
    local item_hash = type(item_id) == "string" and hash(item_id) or item_id
    local max_stack = data.max_stack or 1

    -- 1. ЛОГИКА ДЛЯ СТАКАЕМЫХ (Читаем и пишем strictly в self.items!)
    if data.stackable then
        for i = 1, self.max_slots do
            local slot = self.items[i]
            if slot and slot.item_id == item_hash and slot.amount < max_stack then
                local add = math.min(remaining, max_stack - slot.amount)
                slot.amount = slot.amount + add
                remaining = remaining - add
                if remaining <= 0 then return true end
            end
        end
    end

    -- 2. ЛОГИКА ДЛЯ НОВЫХ СЛОТОВ
    for i = 1, self.max_slots do
        local slot = self.items[i]

        if not slot or not slot.item_id then
            local add = math.min(remaining, max_stack)
            print("IS LOOTED FROM INVENTORY MODEL", is_looted, loot_table_id)
            local new_item = {
                item_id = item_hash,
                amount = add,
                uid = uid,
                items = sub_items or nil,
                is_looted = is_looted or nil,
                loot_table_id = loot_table_id
            }

            if not new_item.uid and data.action_type == "container_item" then
                local s_id = interactions.clean_id(item_id) or "container"
                new_item.uid = string.format("%s_%d_%d", s_id, os.time(), math.random(1000, 9999))
            end

            self.items[i] = new_item

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
    return true
end

---@param _item Item
function M:equip_item(_item)
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

-- =========================================================================
-- 🦾 УНИВЕРСАЛЬНЫЕ МЕТОДЫ СВАПА И МЕЖ-КОНТЕЙНЕРНОГО СТАКАНИЯ
-- =========================================================================

---Поменять ячейки местами внутри этой сумки
---@param from_idx number
---@param to_idx number
function M:swap_slots(from_idx, to_idx)
    self.items[from_idx], self.items[to_idx] = self.items[to_idx], self.items[from_idx]
end

---Попытаться стакнуть два предмета внутри одной этой сумки
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
    to_item.amount = to_item.amount + to_add
    from_item.amount = from_item.amount - to_add

    if from_item.amount <= 0 then
        self.items[from_index] = empty_slot()
    end

    return true
end

---Попытаться стакнуть предмет, прилетевший из СОВЕРШЕННО ДРУГОГО внешнего инвентаря/сундука
---@param other_model InventoryInstance 🎯 ИСПРАВЛЕНО: Строгий тип универсального инстанса для Neovim!
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

    if not item_cfg or not item_cfg.stackable then return false end

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

---Попытаться автоматически найти такой же стак в рюкзаке и досыпать туда предметы
---@param item_id hash|string
---@param amount number
---@param item_cfg table
---@return number @Возвращает остаток (0 если всё стакнулось)
function M:try_stack_item_anywhere(item_id, amount, item_cfg)
    local remaining = amount
    local target_id = type(item_id) == "string" and hash(item_id) or item_id

    for i = 1, self.max_slots do
        local slot = self.items[i]

        -- Наш железный гвард от nil значений для глушения Neovim
        if slot and slot.item_id == target_id then
            local max_stack = item_cfg.max_stack or 64
            local space = max_stack - slot.amount

            if space > 0 then
                local to_add = math.min(remaining, space)
                slot.amount = slot.amount + to_add
                remaining = remaining - to_add
            end
        end

        if remaining <= 0 then return 0 end
    end
    return remaining
end

-- =========================================================================
-- 🦾 ЛОГИКА СПЛИТА СТАКОВ И СИСТЕМНЫЕ МЕТОДЫ СЕРИАЛИЗАЦИИ
-- =========================================================================

---Разделить стак предметов, отщипнув часть на курсор или в целевой слот
---@param other_model InventoryInstance 🎯 ИСПРАВЛЕНО: Строгий тип универсального инстанса для Neovim!
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
            amount = new_amount,
            uid = from_item.uid
        }
        self:set_item(to_idx, new_item)

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

---Полностью очистить все ячейки конкретного инвентаря
function M:clear() -- 🎯 ИСПРАВЛЕНО: Теперь объектный метод инстанса через двоеточие!
    for i = 1, self.max_slots do
        self.items[i] = { item_id = nil, amount = 0, uid = nil }
    end
end

---Собрать слепок данных инвентаря под сохранение в JSON (Матрёшка)
---@return table
function M:get_save_data() -- 🎯 ИСПРАВЛЕНО: Объектный метод через двоеточие!
    local data = {}
    for i = 1, self.max_slots do
        local item = self.items[i]
        if item and item.item_id then
            local id_str = interactions.clean_id(item.item_id)

            data[i] = {
                id = id_str,
                amount = item.amount,
                uid = item.uid,
                loot_table_id = item.loot_table_id or nil
            }

            if item.is_looted then
                data[i].is_looted = item.is_looted
            end

            if item.items then
                data[i].items = {}
                for sub_idx, sub_item in pairs(item.items) do
                    if sub_item then
                        data[i].items[sub_idx] = {
                            id = interactions.clean_id(sub_item.item_id),
                            amount = sub_item.amount,
                            uid = sub_item.uid,
                            is_looted = sub_item.is_looted or nil,
                            loot_table_id = sub_item.loot_table_id or nil
                        }
                    end
                end
            end
        else
            data[i] = { id = nil, amount = 0, uid = nil }
        end
    end
    return data
end

---Восстановить содержимое сумки/сундука из таблицы сохранения JSON
---@param data table
function M:load_save_data(data) -- 🎯 ИСПРАВЛЕНО: Объектный метод через двоеточие!
    self:clear()
    if not data then return end
    for index, saved in pairs(data) do
        local i = tonumber(index)
        if i and saved and saved.id then
            local restored_item = {
                item_id = hash(saved.id),
                amount = saved.amount,
                uid = saved.uid,
                is_looted = saved.is_looted or nil,
                loot_table_id = saved.loot_table_id or nil
            }

            if saved.items then
                restored_item.items = {}
                for sub_idx, sub_saved in pairs(saved.items) do
                    local idx = tonumber(sub_idx)
                    if idx and sub_saved and sub_saved.id then
                        restored_item.items[idx] = {
                            item_id = hash(sub_saved.id),
                            amount = sub_saved.amount,
                            uid = sub_saved.uid,
                            is_looted = sub_saved.is_looted or nil,
                            loot_table_id = sub_saved.loot_table_id or nil
                        }
                    end
                end
            end

            self.items[i] = restored_item
        end
    end
end

return M
