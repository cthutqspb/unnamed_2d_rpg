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
        ["inventory_title"] = "Инвентарь",
        ["character_window"] = "Окно персонажа",
        ["character_journal"] = "Журнал",
        ["character_talents"] = "Таланты",

        --Character
        ["race_human"] = "Человек",
        ["race_elf"] = "Эльф",
        ["race_dwarf"] = "Дворф",
        ["class_warrior"] = "Воин",
        ["class_mage"] = "Маг",
        ["class_rogue"] = "Разбойник",
        ["stat_strength"] = "Сила",
        ["stat_agility"] = "Ловкость",
        ["stat_intellect"] = "Интеллект",
        ["stat_stamina"] = "Выносливость",
    },
    ["en"] = {
        ["item_iron_sword_name"] = "Iron Sword",
        ["item_iron_sword_desc"] = "A simple steel blade. Good for training.",
        ["item_crystal_sword_name"] = "Crystal Sword",
        ["item_crystal_sword_desc"] = "Everything looks funnier through it. Who even thought of making a sword out of glass?.",

        ["item_lesser_mana_potion_name"] = "Lesser mana potion" ,
        ["item_lesser_mana_potion_desk"] = "This potion restores some mana.",



        ["item_potion_name"] = "Health Potion",
        ["inventory_title"] = "Inventory",
        ["character_window"] = "Character window",
        ["character_journal"] = "Journal",
        ["character_talents"] = "Talents",

        --Character
        ["race_human"] = "Human",
        ["race_elf"] = "Elf",
        ["race_dwarf"] = "Dwarf",
        ["class_warrior"] = "Warrior",
        ["class_mage"] = "Mage",
        ["class_rogue"] = "Rogue",
        ["stat_strength"] = "Strength",
        ["stat_agility"] = "Aglitity",
        ["stat_intellect"] = "Intellect",
        ["stat_stamina"] = "Stamina",
    }
}

function M.get(key)
    local lang_data = M.data[M.LANG] or M.data["en"]
    return lang_data[key] or key -- Возвращает ключ, если перевод не найден
end

return M
