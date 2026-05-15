local M = {}

M.LANG = "ru" -- Текущий язык (потом можно менять)

M.data = {
    ["ru"] = {
        --items
        ["item_iron_sword_name"] = "Железный меч",
        ["item_iron_sword_desc"] = "Обычный стальной клинок. Подойдет для тренировок.",
        ["item_crystal_sword_name"] = "Кристальный меч",
        ["item_crystal_sword_desc"] = "Сквозь него все выглядит смешнее. Кому вообще взбрело в голову делать меч из стекла? .",

        ["item_leather_helmet_name"] = "Кожаный шлем",

        ["item_lesser_mana_potion_name"] = "Малое зелье маны",
        ["item_lesser_mana_potion_desk"] = "Это зелье восстанавливает немного маны.",

        ["item_potion_name"] = "Зелье здоровья",

        --world containers
        ["container_common_chest_name"] = "Простой сундук",
        ["container_status_empty"] = "Пусто",


        --gui
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

        -- Menu
        ["btn_main_menu"] = "Главное меню",
        ["btn_new_game"] = "Новая игра",
        ["btn_continue_game"] = "Продолжить игру",
        ["btn_save_game"] = "Сохранить игру",
        ["btn_load_game"] = "Загрузить игру",
        ["btn_exit_game"] = "Выйти из игры",
    },
    ["en"] = {
        ["item_iron_sword_name"] = "Iron Sword",
        ["item_iron_sword_desc"] = "A simple steel blade. Good for training.",
        ["item_crystal_sword_name"] = "Crystal Sword",
        ["item_crystal_sword_desc"] = "Everything looks funnier through it. Who even thought of making a sword out of glass?.",


        ["item_leather_helmet_name"] = "Leather helmet",
        ["item_lesser_mana_potion_name"] = "Lesser mana potion" ,
        ["item_lesser_mana_potion_desk"] = "This potion restores some mana.",

        ["item_potion_name"] = "Health Potion",

        --world containers
        ["container_common_chest_name"] = "Common chest",
        ["container_status_empty"] = "Empty",


        --gui

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

        -- Menu
        ["btn_main_menu"] = "Main menu",
        ["btn_new_game"] = "New game",
        ["btn_continue_game"] = "Continie game",
        ["btn_save_game"] = "Save game",
        ["btn_load_game"] = "Load game",
        ["btn_exit_game"] = "Exit game",
    }
}

-- Внутренняя таблица для быстрого поиска по хешам
local hash_map = {}

-- Функция наполнения карты (вызываем один раз)
function M.rebuild()
    for key, value in pairs(M.data) do
        hash_map[hash(key)] = value
    end
end

local current_lang = "ru"
local hash_to_string_map = {}

-- Функция, которая строит карту хешей ДЛЯ ТЕКУЩЕГО ЯЗЫКА
function M.rebuild_cache()
    hash_to_string_map = {}
    local lang_data = M.data[current_lang]
    if lang_data then
        for key, value in pairs(lang_data) do
            hash_to_string_map[hash(key)] = value
        end
    end
end

-- Инициализация при старте
M.rebuild_cache()

function M.get(key)
    if not key then return "" end

    -- 1. Если пришла строка (из кода)
    if type(key) == "string" then
        return M.data[current_lang][key] or key
    end

    -- 2. Если пришел ХЕШ (из go.property)
    if type(key) == "userdata" then
        local value = hash_to_string_map[key]
        if value then
            return value
        end
        
        -- Если не нашли (хот-релод), пробуем обновить кэш
        M.rebuild_cache()
        return hash_to_string_map[key] or tostring(key)
    end

    return tostring(key)
end

-- Метод для смены языка (например, из настроек)
function M.set_language(lang)
    if M.data[lang] then
        current_lang = lang
        M.rebuild_cache()
        -- Тут можно кинуть бродкаст, чтобы все UI обновились, но это позже
    end
end

return M
