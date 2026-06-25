---@class ItemRequiredStats
---@field level number|nil Требуемый уровень персонажа
---@field strength number|nil Требуемая сила
---@field agility number|nil Требуемая ловкость
---@field intellect number|nil Требуемый интеллект

---@class ItemBonusStats
---@field strength number|nil Бонус к силе
---@field agility number|nil Бонус к ловкости
---@field intellect number|nil Бонус к интеллекту
---@field stamina number|nil Бонус к выносливости

---@class ItemDamageConfig
---@field min number Минимальный урон
---@field max number Максимальный урон
---@field type string Тип урона ("physical", "magic")

---@class ItemBonusDamageConfig
---@field min number Минимальный доп. урон
---@field max number Максимальный доп. урон
---@field type string Школа магии доп. урона ("arcane", "fire")

---@class ItemPassiveEffectsConfig
---@field aura_id string ID скрытой пассивной ауры в боевой системе ("mana_leech_on_hit")
---@field value number Сила или процент срабатывания эффекта
---@field chance number Шанс прока в процентах (0..100)

---@class ItemEffectValue
---@field min number Минимальное значение силы эффекта (лечения/мана-регена)
---@field max number Максимальное значение силы эффекта

---@class ItemUseEffectsConfig
---@field ability_id string Ссылка на ID заклинания из базы способностей abilities_db ("restore_mana")
---@field value ItemEffectValue Диапазон силы применения предмета
---@field cooldown number Кулдаун категории предметов в секундах (например, 300)

---@class ItemConfig
---@field action_type string
---@field name_key string Локализационный ключ имени шмотки
---@field desc_key string Локализационный ключ описания шмотки
---@field animation string Имя анимации флипбука в атласе
---@field tile_index number Индекс тайла для генераторов карт
---@field color vector4 Цвет ноды качества/редкости (vmath.vector4)
---@field texture string Имя графического атласа Defold
---@field type string Тип предмета ("weapon", "armor", "quest", "potion")
---@field equip_slot string Слот куклы капсом ("MAIN_HAND", "CHEST", "HEAD")
---@field stackable boolean Можно ли складывать в один стак
---@field max_stack number Максимальный размер стака предметов
---@field quality string Качество вещи ("common", "rare", "epic")
---@field weapon_type string|nil Подтип оружия ("one_hand_sword", "staff")
---@field required ItemRequiredStats Структура требований к характеристикам
---@field stats ItemBonusStats Структура добавляемых статов при экипировке
---@field effects ItemPassiveEffectsConfig[]|nil Массив пассивных аур предмета
---@field use_effects ItemUseEffectsConfig[]|nil Массив активных прожимаемых эффектов (зелья/тринкеты)
---@field damage ItemDamageConfig|nil Параметры боевого урона для оружия
---@field bonus_damage ItemBonusDamageConfig[]|nil
---@field price number Стоимость предмета у торговцев
---@field weight number Физический вес шмотки в рюкзаке
---@field durability number|nil
---@field loot_table_id string|nil
---@field columns number|nil
---@field rows number|nil
---@field id? string Строковый ID ("iron_sword"), пропишем при инициализации для редьюсеров
local M = {}

---@type table<string, any>
M.items_raw = {
    ["unit_loot_bag"] = {
        action_type = "container_item",
        name_key = "container_chest_common_name",
        desc_key = "container_chest_common_desc",
        animation = "unit_loot_bag",
        tile_index = 3408,
        texture = "project_utumno",
        type = "container",
        columns = 6,
        rows = 4,
        quality = "common",
        stackable = false,
        max_stack = 1,
        price = 8,
        weight = 10,
        durability = 150
    },
    ["chest_common"] = {
        action_type = "container_item",
        name_key = "container_chest_common_name",
        desc_key = "container_chest_common_desc",
        animation = "chest_common",
        tile_index = 7,
        texture = "project_utumno",
        type = "container",
        columns = 6,
        rows = 4,
        quality = "common",
        stackable = false,
        max_stack = 1,
        price = 8,
        weight = 25,
        durability = 275
    },
    ["wooden_barrel"] = {
        action_type = "container_item",
        name_key = "container_wooden_barrel_name",
        desc_key = "container_wooden_barrel_desk",
        animation = "wooden_barrel",
        tile_index = 8,
        texture = "project_utumno",
        type = "container",
        columns = 6,
        rows = 2,
        quality = "common",
        stackable = false,
        max_stack = 1,
        price = 8,
        weight = 12.5,
        durability = 125,
    },
    ["iron_sword"] = {
        action_type = "item",
        name_key = "item_iron_sword_name",
        desc_key = "item_iron_sword_desc",
        animation = "iron_sword",
        tile_index = 2976,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "project_utumno",
        type = "weapon",
        equip_slot = "MAIN_HAND",
        stackable = false,
        max_stack = 1,
        quality = "common",
        weapon_type = "one_hand_sword",
        required = {
            level = 1,
            strength = 6
        },
        stats = {
            strength = 3
        },
        damage = {
            min = 3,
            max = 7,
            type = "physical"
        },
        price = 25,
        weight = 2.4

        -- scale = 0.5,
        -- drop_distance = 20,    -- на сколько пикселей перед игроком
        -- rotation = 0,          -- угол поворота на земле
    },
    ["crystal_sword"] = {
        action_type = "item",
        name_key = "item_crystal_sword_name",
        desc_key = "item_crystal_sword_desc",
        animation = "crystal_sword",
        tile_index = 3013,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "project_utumno",
        type = "weapon",
        equip_slot = "MAIN_HAND",
        stackable = false,
        max_stack = 1,
        quality = "rare",
        weapon_type = "one_hand_sword",
        required = {
            level = 3,
            intellect = 10
        },
        stats = {
            strength = 3,
            intellect = 2
        },
        effects = {
            {
                aura_id = "mana_leech_on_hit",
                value = 1.0,
                chance = 100
            }
        },
        use_effects = {
            {
                ability_id = "restore_mana",
                value = { min = 10, max = 10},
                cooldown = 300
            }
        },
        damage = {
            min = 4,
            max = 8,
            type = "physical"
        },
        bonus_damage = {
            {
                min = 2,
                max = 3,
                type = "arcane"
            }
        },
        resists = {
            arcane = 15
        },
        price = 75,
        weight = 2.4
    },
    ["leather_helmet"] = {
        action_type = "item",
        name_key = "item_leather_helmet_name",
        desc_key = "item_leather_helmet_desc",
        animation = "leather_helmet",
        color = vmath.vector4(0.8, 0.8, 1, 1),
        tile_index = 2345,
        texture = "project_utumno",
        type = "armor",
        equip_slot = "HEAD",
        stackable = false,
        max_stack = 1,
        quality = "common",
        armor_type = "leather",
        required = {
            level = 2,
        },
        stats = {
            stamina = 5,
            agility = 2
        },
        effects = {
            {
                aura_id = "increase_max_health",
                value = 20
            }
        },
        armor_rating = 27,
        price = 15,
        weight = 1.0,
    },
    ["clown_hat"] = {
        action_type = "item",
        name_key = "item_clown_hat_name",
        desc_key = "item_clown_hat_desc",
        animation = "clown_hat",
        color = vmath.vector4(0.8, 0.8, 1, 1),
        tile_index = 2347,
        texture = "project_utumno",
        type = "armor",
        equip_slot = "HEAD",
        stackable = false,
        max_stack = 1,
        quality = "uncommon",
        armor_type = "leather",
        required = {
            level = 2,
            agility = 12,
            intellect = 8
        },
        stats = {
            stamina = -2,
            agility = 3,
            intellect = 5
        },
        effects = {
            {
                aura_id = "chance_to_critical_hit",
                value = 2.5
            }
        },
        armor_rating = 15,
        price = 40,
        weight = 1.2
    },
    ["lesser_mana_potion"] = {
        action_type = "item",
        name_key = "item_lesser_mana_potion_name",
        desc_key = "item_lesser_mana_potion_desc",
        animation = "lesser_mana_potion",
        type = "potion",
        tile_index = 2683,
        color = vmath.vector4(0.8, 0.8, 1, 1),
        texture = "project_utumno",
        stackable = true,
        max_stack = 20,
        quality = "common",
        required = {
            level = 1,
            resource = "mana"
        },
        use_effects = {
            {
                ability_id = "restore_mana",
                value = {
                    min = 20,
                    max = 40
                },
                cooldown = 1
            }
        },
        price = 5,
        weight = 0.1 -- нужно учитывать при стаках
    }
    -- ... остальные предметы
}


-- Быстрый кэш хэшированных ключей для мгновенного поиска из голых свойств Defold (go.property)
---@type table<hash, ItemConfig>
local items_by_hash = {}

for id_str, data in pairs(M.items_raw) do
    -- 🎯 ПРОМЫШЛЕННЫЙ ЗАДЕЛ: Автоматически вшиваем строковый ID в сам конфиг,
    -- чтобы редьюсер item_transfer мог безопасно читать его одной строчкой item_cfg.id!
    data.id = id_str
    items_by_hash[hash(id_str)] = data
end

---Универсальная быстрая функция получения статического конфига предмета
---@param id any Идентификатор предмета (хэш Defold или чистая Lua-строка)
---@return ItemConfig|nil data
function M.get_item(id)
    local cfg = items_by_hash[id] or M.items_raw[id]
    
    -- 🎯 ААА-ИНЖЕКЦИЯ МЕТА-ТИПА:
    -- Если предмет найден в базе, мы прямо в оперативной памяти вклеиваем ему 
    -- системное поле action_type = "item". В самом файле базы этого поля НЕТ, 
    -- оно не мусорит, но любой скрипт в игре теперь видит его автоматически!
    if cfg and not cfg.action_type then
        cfg.action_type = "item"
    end
    
    return cfg
end

return M
