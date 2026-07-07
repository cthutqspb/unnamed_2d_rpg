---@class ItemIdentity
---@field name_key string                  Локализационный ключ имени вещи
---@field desc_key string                  Локализационный ключ описания вещи
---@field type "weapon"|"armor"|"potion"|"container"|"quest"|"trash"
---@field quality "common"|"uncommon"|"rare"|"epic"|"legendary"
---@field price number                     Стоимость предмета у торговцев
---@field weight number                    Физический вес одной шмотки в рюкзаке
---@field durability number|nil            Прочность (опционально)
---@field loot_table_id string|nil

---@class ItemVisuals
---@field animation string                 Имя флипбука в Defold атласе
---@field texture string                   Имя графического атласа
---@field tile_index number                Индекс тайла для генераторов
---@field color vector4|nil                Цвет свечения рамки редкости (vmath.vector4)

---@class ItemProperties
---@field equip_slot string|nil            Слот куклы капсом ("HEAD", "MAIN_HAND")
---@field weapon_type string|nil           Подтип оружия ("one_hand_sword", "staff")
---@field armor_type string|nil            Подтип брони ("cloth", "leather", "plate")
---@field stackable boolean                Можно ли собирать в пачки в рюкзаке
---@field max_stack number                 Максимальный размер стака
---@field triggers_gcd boolean             Запускает ли ГКД при использовании
---@field columns number|nil               Для контейнеров: ширина сетки лута
---@field rows number|nil                  Для контейнеров: высота сетки лута

---@class ItemDamageConfig
---@field min number                       Минимальный базовый урон
---@field max number                       Максимальный базовый урон
---@field type string                      Тип школы урона ("physical", "magic")

---@class ItemBonusDamageConfig
---@field min number
---@field max number
---@field type string                      Школа доп урона ("arcane", "fire", "frost")

---@class ItemPassiveEffect
---@field aura_id string                   ID скрытой пассивной ауры в боевой системе
---@field value number                     Сила или процент прока эффекта
---@field chance number|nil                Шанс срабатывания в % (0..100)

---@class ItemUseEffect
---@field ability_id string                Ссылка на ID спелла из abilities_db
---@field value {min: number, max: number} Диапазон силы применения предмета
---@field cooldown number                  Кулдаун прожима предмета в секундах

---@class ItemCombatStats
---@field attributes UnitAttributes        -- 🚀 ТОТАЛЬНЫЙ СИНХРОН: Переиспользуем класс UnitAttributes из БД юнитов!
---@field damage ItemDamageConfig|nil
---@field bonus_damage ItemBonusDamageConfig[]|nil
---@field resists table<string, number>|nil
---@field armor_rating number|nil          Показатель физической брони шмотки

---@class ItemConfig
---@field action_type "item"|"container_item"
---@field identity ItemIdentity            🆔 Паспортные метаданные предмета
---@field visuals ItemVisuals              🎨 Слой графического представления
---@field properties ItemProperties        🎒 Физика поведения в сумках и на кукле
---@field requirements table<string, number>|nil 🛡️ Требования к статам для надевания
---@field combat_stats ItemCombatStats|nil 📊 Весь боевой импакт в одной коробке!
---@field effects ItemPassiveEffect[]|nil  🦠 Массив скрытых пассивных аур
---@field use_effects ItemUseEffect[]|nil  🧪 Активные прожимаемые тринкеты/зелья
---@field id string|nil                    Строковый ID вещи ("crystal_sword")
local M = {}

---@type table<string, any>
M.items_raw = {
     -- =========================================================================
    -- 📦 1. АРХЕТИП: КОНТEЙНEР-МAТРЁШКA (ЛУТAEМЫЙ OБЪEКТ)
    -- =========================================================================
    ["unit_loot_bag"] = {
        action_type = "container_item",

        identity = {
            name_key   = "container_chest_common_name",
            desc_key   = "container_chest_common_desc",
            type       = "container",
            quality    = "common",
            price      = 8,
            weight     = 10,
            durability = 150,
        },

        visuals = {
            animation  = "unit_loot_bag",
            texture    = "project_utumno",
            tile_index = 3408,
            color      = nil,
        },

        properties = {
            stackable    = false,
            max_stack    = 1,
            columns      = 6, -- Сетка мешка: 24 слота лута!
            rows         = 4,
            equip_slot   = nil,
            weapon_type  = nil,
            armor_type   = nil,
            triggers_gcd = false,
        },
    },
    ["wooden_barrel"] = {
        action_type = "container_item", -- Системный экшен-токен для GUI/Курсоров

        identity = {
            name_key = "container_wooden_barrel_name",
            desc_key = "container_wooden_barrel_desk",
            type     = "container",
            quality  = "common",
            price    = 8,
            weight   = 12.5,
            durability = 125,
        },

        visuals = {
            animation  = "wooden_barrel",
            texture    = "project_utumno",
            tile_index = 8,
            color      = nil, -- У обычной бочки нет рамки свечения качества
        },

        properties = {
            stackable    = false,
            max_stack    = 1,
            columns      = 6, -- Геометрия внутренней сетки бочки: 12 слотов лута!
            rows         = 2,
            equip_slot   = nil,
            weapon_type  = nil,
            armor_type   = nil,
            triggers_gcd = false,
        },
        -- Никаких требований, боевых стат и магии на корне! Чистая экономия памяти.
    },
    ["chest_common"] = {
        action_type = "container_item",

        identity = {
            name_key   = "container_chest_common_name",
            desc_key   = "container_chest_common_desc",
            type       = "container",
            quality    = "common",
            price      = 8,
            weight     = 25,
            durability = 275,
        },

        visuals = {
            animation  = "chest_common",
            texture    = "project_utumno",
            tile_index = 7,
            color      = nil,
        },

        properties = {
            stackable    = false,
            max_stack    = 1,
            columns      = 6, -- Сетка сундука: 24 слота лута!
            rows         = 4,
            equip_slot   = nil,
            weapon_type  = nil,
            armor_type   = nil,
            triggers_gcd = false,
        },
    },
    -- =========================================================================
    -- ⚔️ 2. АРХЕТИП: ОРУЖИЕ
    -- =========================================================================
    ["iron_sword"] = {
        action_type = "item", -- Системный экшен-токен для GUI/Курсоров

        identity = {
            name_key   = "item_iron_sword_name",
            desc_key   = "item_iron_sword_desc",
            type       = "weapon",
            quality    = "common",
            price      = 25,
            weight     = 2.4,
            durability = 100, -- Задел под прочность
        },

        visuals = {
            animation  = "iron_sword",
            texture    = "project_utumno",
            tile_index = 2976,
            color      = vmath.vector4(0.8, 0.8, 1, 1),
        },

        properties = {
            equip_slot   = "MAIN_HAND",
            weapon_type  = "one_hand_sword",
            armor_type   = nil,
            stackable    = false,
            max_stack    = 1,
            triggers_gcd = false,
        },

        requirements = {
            level    = 1,
            strength = 6,
        },

        -- 📊 МОНОЛИТНЫЙ БОЕВОЙ ПАСПОРТ: 0% дублирования, 100% сквозной контракт!
        combat_stats = {
            -- 🧬 ТОТАЛЬНЫЙ СИНХРОН: Сила ушла во вселенские attributes!
            attributes   = { strength = 3, intellect = 0, agility = 0, stamina = 0 },

            damage       = { min = 3, max = 7, type = "physical" },
            bonus_damage = nil, -- У обычного меча нет магии магов
            resists      = {},
            armor_rating = 0,
        },
    },
    ["crystal_sword"] = {
        action_type = "item",

        identity = {
            name_key = "item_crystal_sword_name",
            desc_key = "item_crystal_sword_desc",
            type     = "weapon",
            quality  = "rare",
            price    = 75,
            weight   = 2.4,
            durability = 100, -- Задел под прочность
        },

        visuals = {
            animation  = "crystal_sword",
            texture    = "project_utumno",
            tile_index = 3013,
            color      = vmath.vector4(0.8, 0.8, 1, 1),
        },

        properties = {
            equip_slot   = "MAIN_HAND",
            weapon_type  = "one_hand_sword",
            armor_type   = nil,
            stackable    = false,
            max_stack    = 1,
            triggers_gcd = false,
        },

        requirements = {
            level     = 3,
            intellect = 10,
        },

        -- 📊 МОНОЛИТНЫЙ БОЕВОЙ ПАСПОРТ: Всё, что шмотка накидывает на тушу моба/игрока
        combat_stats = {
            -- 🧬 ТОТАЛЬНЫЙ СИНХРОН: Атрибуты перевыровнены строго под контракт юнитов!
            attributes = { strength = 3, intellect = 2, agility = 0, stamina = 0 },

            damage       = { min = 4, max = 8, type = "physical" },
            bonus_damage = { { min = 2, max = 3, type = "arcane" } },
            resists      = { arcane = 15 },
            armor_rating = 0,
        },

        effects = {
            {
                aura_id = "mana_leech_on_hit",
                value   = 1.0,
                chance  = 100
            }
        },

        use_effects = {
            {
                ability_id = "restore_mana",
                value      = { min = 10, max = 10 },
                cooldown   = 300
            }
        },
    },

    -- =========================================================================
    -- 👕 3. АРХЕТИП: БРOНЯ (ОДEЖДA С ХАРАКТЕРИСТИКАМИ)
    -- =========================================================================
    ["leather_helmet"] = {
        action_type = "item",

        identity = {
            name_key = "item_leather_helmet_name",
            desc_key = "item_leather_helmet_desc",
            type     = "armor",
            quality  = "common",
            price    = 15,
            weight   = 1.0,
            durability = 200,
        },

        visuals = {
            animation  = "leather_helmet",
            texture    = "project_utumno",
            tile_index = 2345,
            color      = vmath.vector4(0.8, 0.8, 1, 1),
        },

        properties = {
            equip_slot   = "HEAD",
            weapon_type  = nil,
            armor_type   = "leather",
            stackable    = false,
            max_stack    = 1,
            triggers_gcd = false,
        },

        requirements = {
            level = 2,
        },

        combat_stats = {
            attributes   = { strength = 0, intellect = 0, agility = 2, stamina = 5 },
            damage       = nil,
            bonus_damage = nil,
            resists      = {},
            armor_rating = 27, -- Чистая физическая броня шлема
        },

        effects = {
            {
                aura_id = "increase_max_health",
                value   = 20
            }
        },
    },
     ["clown_hat"] = {
        action_type = "item",

        identity = {
            name_key   = "item_clown_hat_name",
            desc_key   = "item_clown_hat_desc",
            type       = "armor",
            quality    = "uncommon",
            price      = 40,
            weight     = 1.2,
            durability = 100,
        },

        visuals = {
            animation  = "clown_hat",
            texture    = "project_utumno",
            tile_index = 2347,
            color      = vmath.vector4(0.8, 0.8, 1, 1),
        },

        properties = {
            equip_slot   = "HEAD",
            weapon_type  = nil,
            armor_type   = "leather",
            stackable    = false,
            max_stack    = 1,
            triggers_gcd = false,
        },

        requirements = {
            level     = 2,
            agility   = 12,
            intellect = 8,
        },

        combat_stats = {
            -- 🧬 ЗEРКAЛЬНЫЙ АAА-СИНХРOH: Твой сочный дебаф на стамину (-2) сел идеально!
            attributes   = { strength = 0, intellect = 5, agility = 3, stamina = -2 },
            damage       = nil,
            bonus_damage = nil,
            resists      = {},
            armor_rating = 15,
        },

        effects = {
            {
                aura_id = "chance_to_critical_hit",
                value   = 2.5
            }
        },
    },
    -- =========================================================================
    -- 🧪 4. АРХЕТИП: РAСХOДНИК (СТAКAЮЩEEСЯ ЗEЛЬE)
    -- =========================================================================
    ["lesser_mana_potion"] = {
        action_type = "item",

        identity = {
            name_key = "item_lesser_mana_potion_name",
            desc_key = "item_lesser_mana_potion_desc",
            type     = "potion",
            quality  = "common",
            price    = 5,
            weight   = 0.1, -- Твой бэкенд сумок умножит это на текущий saved.amount!
        },

        visuals = {
            animation  = "lesser_mana_potion",
            texture    = "project_utumno",
            tile_index = 2683,
            color      = vmath.vector4(0.8, 0.8, 1, 1),
        },

        properties = {
            equip_slot   = nil,
            weapon_type  = nil,
            armor_type   = nil,
            stackable    = true,  -- Физика рюкзака: разрешаем собирать в пачки!
            max_stack    = 20,
            triggers_gcd = true,  -- Зелье запускает ГКД на панели способностей!
        },

        requirements = {
            level    = 1,
            resource = "mana" -- Зелье может выпить только юнит с полоской маны
        },

        use_effects = {
            {
                ability_id = "restore_mana",
                value      = { min = 20, max = 40 }, -- Рандомный Си-бросок кубиков регена!
                cooldown   = 25                      -- Кулдаун категории зелий в секундах
            }
        },
    },
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
