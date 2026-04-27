local M = {}

M.LANG = "ru" -- Текущий язык (потом можно менять)

M.data = {
    ["ru"] = {
        ["item_iron_sword_name"] = "Железный меч",
        ["item_iron_sword_desc"] = "Обычный стальной клинок. Подойдет для тренировок.",
        ["item_crystal_sword_name"] = "Кристальный меч",
        ["item_crystal_sword_desc"] = "Сквозь него все выглядит смешнее. Кому вообще взбрело в голову делать меч из стекла? .",

        ["item_lesser_mana_potion_name"] = "Малое зелье маны",
        ["item_lesser_mana_potion_desk"] = "Это зелье восстанавливает немного маны.",


        ["item_potion_name"] = "Зелье здоровья",
        ["inventory_title"] = "ИНВЕНТАРЬ",
    },
    ["en"] = {
        ["item_iron_sword_name"] = "Iron Sword",
        ["item_iron_sword_desc"] = "A simple steel blade. Good for training.",
        ["item_crystal_sword_name"] = "Crystal Sword",
        ["item_crystal_sword_desc"] = "Everything looks funnier through it. Who even thought of making a sword out of glass?.",

        ["item_lesser_mana_potion_name"] = "Lesser mana potion" ,
        ["item_lesser_mana_potion_desk"] = "This potion restores some mana.",



        ["item_potion_name"] = "Health Potion",
        ["inventory_title"] = "INVENTORY",
    }
}

function M.get(key)
    local lang_data = M.data[M.LANG] or M.data["en"]
    return lang_data[key] or key -- Возвращает ключ, если перевод не найден
end

return M
