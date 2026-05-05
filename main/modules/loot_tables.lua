local M = {}

M.tables = {
    [hash("chest_common")] = {
        {item_id = hash("lesser_mana_potion"), amount = {1, 3}, chance = 1},
        {item_id = hash("crystal_sword"), amount = 1, chance = 0.5}
    }
    -- -- Кухонный ящик
    -- kitchen_crate = {
    --     {item_id = hash("apple"), amount = {1, 3}, chance = 0.8},
    --     {item_id = hash("bread"), amount = {1, 2}, chance = 0.5},
    --     {item_id = hash("cheese"), amount = 1, chance = 0.3},
    -- },
    -- -- Книжный шкаф
    -- bookshelf = {
    --     {item_id = hash("scroll_blank"), amount = {1, 2}, chance = 0.7},
    --     {item_id = hash("book_common"), amount = 1, chance = 0.4},
    --     {item_id = hash("scroll_fireball"), amount = 1, chance = 0.05},
    -- },
    -- -- Скелет
    -- skeleton = {
    --     {item_id = hash("bone"), amount = {1, 3}, chance = 0.9},
    --     {item_id = hash("gold"), amount = {5, 15}, chance = 0.6},
    --     {item_id = hash("rusty_sword"), amount = 1, chance = 0.1},
    -- },
    -- -- Редкий сундук
    -- chest_rare = {
    --     {item_id = hash("gold"), amount = {50, 200}, chance = 1.0},
    --     {item_id = hash("health_potion"), amount = {2, 5}, chance = 0.8},
    --     {item_id = hash("crystal_sword"), amount = 1, chance = 0.2},
    -- }
}

function M.get_loot(table_id)
    local items = {}
    local table_data = M.tables[table_id]
    if not table_data then return items end
    
    for _, entry in ipairs(table_data) do
        if math.random() <= entry.chance then
            local amount = entry.amount
            if type(amount) == "table" then
                amount = math.random(amount[1], amount[2])
            end
            table.insert(items, {item_id = entry.item_id, amount = amount})
        end
    end
    
    return items
end

return M
