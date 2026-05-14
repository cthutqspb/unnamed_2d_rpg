local items_db = require("main.modules.data.items_db")

local M = {}

M.max_slots = 48
M.items = {} -- Таблица вида: [1] = {item_id = hash, amount = 2}, [2] = {item_id = nil, amount = 0}

local function get_clean_id(item_id)
    if type(item_id) == "userdata" then
        return tostring(item_id):match("%[(.-)%]") or item_id
    end
    return item_id
end

function M.init()
    for i = 1, M.max_slots do
        M.items[i] = { item_id = nil, amount = 0 }
    end
end

function M.add_item(item_id, amount)
    local data = items_db.get_item(item_id)
    if not data then return false end

    local remaining = amount
    local item_hash = type(item_id) == "string" and hash(item_id) or item_id
    local max_stack = data.max_stack or 1

    -- 1. Сначала стакаем в существующие слоты
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

    -- 2. Ищем пустые слоты для остатка
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

    return remaining <= 0 -- Вернет false, если инвентарь забит
end

function M.swap_slots(from_idx, to_idx)
    M.items[from_idx], M.items[to_idx] = M.items[to_idx], M.items[from_idx]
end

function M.try_stack_items(from_index, to_index, item_cfg)
    local from_item = M.items[from_index]
    local to_item = M.items[to_index]

    -- Если исходный слот пуст или в целевом слоте ничего нет — стакать нечего
    if not from_item or not from_item.item_id or not to_item or not to_item.item_id then
        return false
    end

    -- Если предмет в принципе нельзя стакать по базе данных
    if not item_cfg or not item_cfg.stackable then
        return false
    end

    -- Сравниваем чистые ID предметов
    local id1 = get_clean_id(from_item.item_id)
    local id2 = get_clean_id(to_item.item_id)

    if id1 ~= id2 then
        return false -- Разные предметы, стакать нельзя
    end

    -- Считаем лимиты стака
    local max_stack = item_cfg.max_stack or 64
    local space_left = max_stack - to_item.amount

    -- Если целевой стак уже забит до упора
    if space_left <= 0 then
        return false
    end

    -- Вычисляем сколько реально можем досыпать
    local to_add = math.min(from_item.amount, space_left)

    -- Меняем цифры в памяти
    to_item.amount = to_item.amount + to_add
    from_item.amount = from_item.amount - to_add

    -- Если исходный стак полностью улетел в целевой, зануляем его правильной пустышкой
    if from_item.amount <= 0 then
        M.items[from_index] = {item_id = nil, amount = 0}
    end

    return true -- Успешно стакнули!
end

function M.split_stack(from_idx, to_idx, new_amount, item_cfg)
    local from_item = M.items[from_idx]
    local to_item = M.items[to_idx]

    -- Защита: если исходный слот пустой, сплитать нечего
    if not from_item or not from_item.item_id then
        return false
    end

    -- Гарантируем, что целевой слот инициализирован (хотя бы как пустышка)
    M.items[to_idx] = M.items[to_idx] or {item_id = nil, amount = 0}
    to_item = M.items[to_idx]

    ---------------------------------------------------------------------------
    -- СЦЕНАРИЙ 1: Бросаем в абсолютно пустой слот
    ---------------------------------------------------------------------------
    if not to_item.item_id or to_item.amount <= 0 then
        local item_id = from_item.item_id
        local remainder = from_item.amount - new_amount

        -- Записываем отщипнутый кусок в цель
        to_item.item_id = item_id
        to_item.amount = new_amount

        -- Уменьшаем исходный слот
        from_item.amount = remainder
        if remainder <= 0 then
            M.items[from_idx] = {item_id = nil, amount = 0}
        end
        return true
    end

     ---------------------------------------------------------------------------
    -- СЦЕНАРИЙ 2: Бросаем на ТОЧНО ТАКОЙ ЖЕ предмет (Слияние стаков при сплите)
    ---------------------------------------------------------------------------
    local id1 = get_clean_id(from_item.item_id)
    local id2 = get_clean_id(to_item.item_id)

    if id1 == id2 and item_cfg and item_cfg.stackable then
        local max_stack = item_cfg.max_stack or 64
        local space_left = max_stack - to_item.amount

        -- Если в целевом стаке есть место, досыпаем
        if space_left > 0 then
            -- Досыпаем сколько влезет, но не больше, чем мы принесли на курсоре (new_amount)
            local to_add = math.min(new_amount, space_left)

            -- Прибавляем к целевому слоту
            to_item.amount = to_item.amount + to_add
            
            -- Вычитаем ИЗ ИСХОДНОГО слота в памяти (там лежало полное количество, например 10)
            from_item.amount = from_item.amount - to_add

            -- Если исходный стак полностью исчерпан, зануляем его пустышкой
            if from_item.amount <= 0 then
                M.items[from_idx] = {item_id = nil, amount = 0}
            end
            
            print("SPLIT SUCCESS: Merged " .. tostring(to_add) .. " items into existing stack.")
            return true
        end
    end

    ---------------------------------------------------------------------------
    -- СЦЕНАРИЙ 3: Бросаем на ЧУЖОЙ предмет или стак забит (Блокировка и Отмена)
    ---------------------------------------------------------------------------
    print("SPLIT BLOCKED: Invalid target item or stack is full. Resetting.")
    return false -- Возвращаем false дирижёру, чтобы он знал, что операция отменена
end

function M.clear()
    print('Сбросили инвентарь')
    M.init()
end

function M.get_save_data()
    local data = {}
    for i = 1, M.max_slots do
        local item = M.items[i]
        if item and item.item_id then
            -- Очищаем строку от "hash: [...]"
            local id_str = tostring(item.item_id)
            id_str = id_str:match("%[(.-)%]") or id_str

            data[i] = {
                id = id_str,
                amount = item.amount
            }
        else
            data[i] = { id = nil, amount = 0 }
        end
    end
    return data
end

function M.load_save_data(data)
    M.init() -- Сначала очищаем всё
    if not data then return end

    for index, saved in pairs(data) do
        local i = tonumber(index) -- Гарантируем, что индекс — число
        if i and saved and saved.id then
            M.items[i] = {
                item_id = hash(saved.id), -- Теперь тут чистая строка, хеш будет верным
                amount = saved.amount
            }
        end
    end
end

M.init()
return M

