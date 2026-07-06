local broadcast = require("main.modules.system.broadcast")
local utils = require("main.modules.utils")
local units_db = require("main.modules.data.units_db")
local paperdoll_model = require("main.modules.models.paperdoll_model")
local inventory_model = require("main.modules.models.inventory_model")

-- =========================================================================
-- 🧪 СЛОЙ РАСШИРЕНИЯ МУТАБЕЛЬНЫХ ДАННЫХ (НАСЛЕДОВАНИЕ WOW/BG3 КАНОН):
-- =========================================================================

---@class UnitResourceState : UnitResource
---@field current number                  Текущее мутабельное значение маны/ярости прямо сейчас в бою

---@class UnitParametersState : UnitParameters
---@field current_speed number
---@field max_health number

---@class UnitHealthResourceState         (Текущее и Потолок бафов)
---@field current number                  Текущее живое ХП существа в этот кадр рантайма (health_resource.current)
---@field max number                      Динамический потолок полоски HUD с учетом временных бафов и аур!

---@class UnitCombatState
---@field is_in_combat boolean            Флаг нахождения в бою (активирует боевой реген)
---@field is_dead boolean                 Флаг смерти существа
---@field is_invulnerable boolean         Флаг полной неуязвимости (вместо nil-ХП)
---@field combat_start_time number|nil    Таймстамп старта комбата в секундах
---@field last_attacker_uid string|nil    UID последнего существа, нанесшего урон в RAM
---@field combat_target_uid string|nil    UID текущей боевой жертвы (кого юнит покадрово лупит)

---@class UnitCastState
---@field ability_id string|nil           Строковый ID кастуемой способности из БД ("frostbolt")
---@field duration number|nil             Полное эталонное время каста из базы (1.7)
---@field time number|nil                 Текущее покадрово тикающее время каста в секундах
---@field gcd_current number              Текущий таймер глобального кулдауна в RAM

-- =========================================================================
-- 👑 ГЛАВНЫЙ СТEРИЛЬНЫЙ КOНТРAКТ ЖИВОЙ ДУШИ СУЩЕСТВА В RAM:
-- =========================================================================
---@class UnitInstance : UnitConfig       🚀 НАСЛЕДУЕМ ВСЮ СТАТИКУ (identity, visuals, progression, ai, abilities) ИЗ БД!
---@field go_id hash                      Идентификатор игрового объекта на сцене Defold
---@field name string|nil
---@field uid string                      Уникальный строковый UID конкретной туши на карте
---@field unit_id string                  Строковый ID вида ("skeleton_mage")
---@field is_player boolean               Флаг: является ли инстанс живым игроком
---@field level number
---@field expirience number
---@field saved_position vector3          Физические координаты существа со сцены
---@field base_attributes UnitAttributes  🧬 СТАТИКА: Базовые голые статы из БД (Никогда не меняются)
---@field attributes UnitAttributes       ⚔️ МУТАБЕЛЬНО: Текущие статы с учетом бафов и шмота в ОЗУ
---@field parameters UnitParametersState  📊 МУТАБЕЛЬНО: Текущие боевые параметры (базовое и макс ХП, скорость, хитбокс, loot_table_id)
---@field health_resource UnitHealthResourceState 🩸 МУТАБЕЛЬНО: Святая Троица ХП (Текущее и Потолок бафов!)
---@field resource UnitResourceState      🧪 МУТАБЕЛЬНО: Динамические полоски ХП/Маны/Ярости с полем current!
---@field combat UnitCombatState          💥 БОЁВКА: Флаги боя, агро-цели, вендетта и смерть существа
---@field cast UnitCastState        🔮 МАГИЯ: Состояние кастбаров и ГКД на этом кадре
---@field auras table                     🦠 АУРЫ: Таблица активных бафов, дебафов и стаков заморозки
---@field paperdoll PaperdollInstance     👕 КУКЛА: Объект экипированного шмота
---@field inventory InventoryInstance     🎒 СУМКИ: Объект инвентаря существа
---@field action_bars table<number, ActionSlot>|nil 🌟 Панели способностей (Матрица слотов)
---@field is_collected boolean            Флаг залутанности/сбора туши

---@class ActionSlot
---@field action_type "ability"|"item"|"empty" Тип действия в слоте
---@field action_id string|nil            Строковый ID из базы способностей или предметов

---@class RankModifiers
---@field health_multiplier number       Множитель максимального здоровья
---@field damage_multiplier number       Множитель базового урона
---@field resists table<string, number>  Задел под резисты к стихиям (fire, frost и т.д.)
---@field bonus_abilities string[]       Список дополнительных способностей, открываемых рангом

---@class UnitState
---@field registry table<string, UnitInstance>
---@field instances table<hash, string>
---@field is_loaded_from_save boolean
local M = {}

-- Главный реестр живых монстров в оперативной памяти [uid] = UnitInstance
---@type table<string, UnitInstance>
M.registry = {}

-- Быстрая телефонная книга связи физического go_id с бэкенд-уидом [go_id] = uid
---@type table<hash, string>
M.instances = {}

M.is_loaded_from_save = false

---Вычислить все геймплейные модификаторы и бонусы на основе ранга существа
---@param rank string Ранг сложности ("common", "rare", "elite", "boss")
---@return RankModifiers
local function compute_rank_modifiers(rank)
    -- Базовые дефолтные модификаторы для обычного моба (common)
    ---@type RankModifiers
    local modifiers = {
        health_multiplier = 1.0,
        damage_multiplier = 1.0,
        resists = { fire = 0, frost = 0, shadow = 0 },
        bonus_abilities = {}
    }

    if rank == "rare" then
        modifiers.health_multiplier = 1.5
        modifiers.damage_multiplier = 1.2
        -- Редкий моб получает легкую защиту
        modifiers.resists.fire = 10
        modifiers.resists.frost = 10
        -- table.insert(modifiers.bonus_abilities, "enrage") -- задел на будущее!

    elseif rank == "elite" then
        modifiers.health_multiplier = 3.0
        modifiers.damage_multiplier = 1.5
        modifiers.resists.fire = 25
        modifiers.resists.frost = 25
        modifiers.resists.shadow = 25
        -- table.insert(modifiers.bonus_abilities, "shield_slam")

    elseif rank == "boss" then
        modifiers.health_multiplier = 5.0
        modifiers.damage_multiplier = 2.0
        -- Босс ультимативно защищен от магии
        modifiers.resists.fire = 50
        modifiers.resists.frost = 50
        modifiers.resists.shadow = 50
        -- table.insert(modifiers.bonus_abilities, "aoe_fireball")
    end

    return modifiers
end

-- =========================================================================
-- СИСТЕМНЫЕ ФУНКЦИИ УПРАВЛЕНИЯ РЕЕСТРОМ (Зеркало world_items_state)
-- =========================================================================

-- Внутри units_state.lua (АБСОЛЮТНО УНИВЕРСАЛЬНЫЙ КОНСТРУКТОР ДУШ):

function M.add(uid, props)
    if M.registry and M.registry[uid] then
        return M.registry[uid]
    end

    assert(props and props.unit_id, "Critical Error: Попытка спавна без unit_id!")

    -- 🚀 ПОРОДИСТОЕ ААА-ОБЪЯВЛЕНИЕ БАЗЫ ДАННЫХ (ИСПРАВЛЕНО НАМЕРТВО):
    -- Вытаскиваем статический конфиг существа из базы данных на самом верху метода,
    -- чтобы вся цепочка вычислений ниже видела его паспорт из units_db!
    local unit_cfg = (not props.is_player and uid ~= "player") and units_db.get_unit(props.unit_id) or nil

    local calculated_max_health = props.max_health or props.health or 100
    local source_attributes = props.attributes or props.attributes or {
        strength = 10,
        agility = 10,
        intellect = 10,
        stamina = 10
    }
    local source_abilities = props.abilities or { "melee_attack" }

    -- Если это фабричный монстр, прогоняем его через динамическое левел-скалирование ХП
    if unit_cfg then
        source_attributes = props.attributes or unit_cfg.attributes or source_attributes
        source_abilities = props.abilities or unit_cfg.abilities or source_abilities

        local level_modifier = math.pow(unit_cfg.progression.health_growth or 1, (props.level or 1) - 1)
        calculated_max_health = math.floor((unit_cfg.parameters.base_health or 40) * level_modifier)

        if compute_rank_modifiers then
            local rank_mods = compute_rank_modifiers(props.rank or unit_cfg.identity.default_rank)
            calculated_max_health = math.floor(calculated_max_health * rank_mods.health_multiplier)
        end
        local db_resource = unit_cfg.resource
        if db_resource then
            calculated_max_mana = db_resource.max or calculated_max_mana
        end
    end

    local base_attributes = utils.deepcopy(source_attributes)
    local attributes = utils.deepcopy(source_attributes)
    local abilities = utils.deepcopy(source_abilities)

    local raw_bars = props.action_bars or {}

    -- =========================================================================
    -- 🛡️ ЗРЯЧИЕ АAА-ГВAРДЫ ВХOДЯЩIХ СЛOEВ (ЗАЩИТА ОТ NIL И СЛИЯНИЕ СЕЙВОВ):
    -- =========================================================================
    -- Извлекаем вложенные объекты из props, если они есть (загрузка игрока / сейва).
    -- Если их нет (спавн обычного волка), даем пустую скобку {}, и ифы шёлково уйдут в базу данных!
    local props_identity   = props.identity or {}
    local props_parameters = props.parameters or {}
    local props_health_resource = props.health_resource or {}
    local props_resource   = props.resource or {}
    local props_ai         = props.ai or {}

    -- Сборка монолитной Души существа в RAM-реестре:
    local unit_instance = {
        go_id       = props.go_id or (props.is_player and hash("/player") or msg.url().path),
        uid         = uid,
        unit_id     = props.unit_id,
        name        = props.name or props_identity.name or nil,
        is_player   = (props.is_player == true or uid == "player"),
        level       = props.level or 1,
        experience  = props.experience or 0,

        -- 🎒 СИСТЕМЫ ИНВЕНТАРЯ И ОДЕЖДЫ:
        paperdoll = paperdoll_model.new(),
        inventory = inventory_model.new(),
        action_bars = {
            [1] = raw_bars[1] or {},
            [2] = raw_bars[2] or {},
            [3] = raw_bars[3] or {},
        },

        -- 🧪 МУТАБЕЛЬНЫЕ ВТОРИЧНЫЕ ПАРАМЕТРЫ (РЕФАКТОРИНГ НАМЕРТВО СИНХРОНИЗИРОВАН):
        parameters = {
            -- Базовое ХП левела берется либо из сейва, либо рассчитывается фабрикой
            base_health  = props_parameters.base_health or calculated_max_health,
            max_health   = props_parameters.max_health or calculated_max_health,

            -- Скорость: смотрим сначала в сейв игрока (props_parameters.base_speed), 
            -- если там пусто — лезем в базу данных моба (monster_cfg.parameters.base_speed),
            -- и только на крайний случай ставим жесткий дефолт (220 игроку / 90 волку)!
            base_speed   = props_parameters.base_speed or (unit_cfg and unit_cfg.parameters.base_speed) or (props.is_player and 220 or 90),

            -- ТЕКУЩАЯ ЖИВАЯ СКОРОСТЬ СИММЕТРИЧНО (ИСПРАВЛЕНО):
            current_speed = props_parameters.current_speed or (unit_cfg and unit_cfg.parameters.base_speed) or (props.is_player and 220 or 90),

            hitbox_size  = props_parameters.hitbox_size or (unit_cfg and unit_cfg.parameters.hitbox_size) or 64,
        },

        -- 🧪 МУТАБЕЛЬНЫЕ ЖИВЫЕ РЕСУРСЫ:
        health_resource = {
            current = props_health_resource.current or props.health or calculated_max_health, -- Поддержка и старых сейвов, и новых!
            max     = props_health_resource.max or calculated_max_health
        },

        resource = {
            type    = props_resource.type or (unit_cfg and unit_cfg.resource and unit_cfg.resource.type) or "mana",
            current = props_resource.current or ((props_resource.type == "rage") and 0 or calculated_max_mana),
            max     = props_resource.max or calculated_max_mana,
        },

        -- 💥 БОЕВОЙ СИСТЕМНЫЙ БЛОК:
        combat = {
            is_in_combat      = false,
            is_dead           = (props.is_dead == true),
            is_invulnerable   = (props.is_invulnerable == true),
            combat_start_time = nil,
            last_attacker_uid = props.last_attacker_uid or nil,
            combat_target_uid = props.combat_target_uid or nil,
        },

        -- 🔮 МАГИЧЕСКИЙ СИСТЕМНЫЙ БЛОК (КАСТБАРЫ И ГКД):
        cast = {
            ability_id  = nil,
            duration    = 0,
            time        = 0,
            gcd_current = 0,
        },

        auras = {},

        -- 🦾 ПЕРЕИСПОЛЬЗОВАНИЕ ДАННЫХ ИЗ БАЗЫ:
        identity    = unit_cfg and unit_cfg.identity or props.identity,
        visuals     = unit_cfg and unit_cfg.visuals or props.visuals,
        progression = unit_cfg and unit_cfg.progression or props.progression,
        ai          = unit_cfg and unit_cfg.ai or props.ai,

        base_attributes    = props.base_attributes and utils.deepcopy(props.base_attributes) or base_attributes,
        attributes         = attributes,
        abilities          = abilities,

        loot_table_id   = props.loot_table_id or (unit_cfg and unit_cfg.identity.loot_table_id) or "empty",
        is_collected    = (props.is_collected == true),
        saved_position  = props.saved_position or vmath.vector3(0, 0, 1.0)
    }

    -- Вытаскиваем сохраненный JSON-слепок сумок и куклы, который выжил в реестре
    local saved_inventory  = props.inventory
    local saved_paperdoll = props.paperdoll

    if saved_inventory and unit_instance.inventory then
        -- Наш объектный метод гарантированно СУЩЕСТВУЕТ в RAM по вечному адресу!
        -- Он с потрохами сожрет плоскую JSON-карту и наполнит слоты шмотом!
        unit_instance.inventory:load_save_data(saved_inventory)
    end

    if saved_paperdoll and unit_instance.paperdoll then
        -- Восстанавливаем куклу шмота
        unit_instance.paperdoll:load_save_data(saved_paperdoll)
    end

    -- Намертво цементируем ссылки обратной связи owner
    if unit_instance.paperdoll then unit_instance.paperdoll.owner = unit_instance end
    if unit_instance.inventory then unit_instance.inventory.owner = unit_instance end
    -- =========================================================================

    -- Записываем готовую Душу Юнита в реестр RAM
    M.registry[uid] = unit_instance
    return unit_instance
end


---Связать физический Си-хэш go_id с бэкенд-уидом (MVC-Инкапсуляция!)
---@param go_id hash Движковый хэш объекта
---@param uid string Чистая строковая переменная UID
function M.register(go_id, uid)
    M.instances[go_id] = uid

    local unit = M.registry[uid]
    if unit then
        unit.go_id = go_id

        --print(string.format("🔗 БЭКЕНД [Register]: Си-адрес %s пуленепробиваемо вшит в RAM-паспорт юнита [%s]!", tostring(go_id), uid))
    end
end

---Разорвать связь между физическим объектом и реестром инстансов
---@param go_id hash
function M.unregister(go_id)
    M.instances[go_id] = nil
end

---Лутаем САМО ТЕЛО (WoW/BG3 канон)
---@param uid string Чистая строка UID
function M.remove(uid)
    if M.registry and M.registry[uid] then
        -- 🎯 ФИКС: Душа вечно живет в памяти, но получает метку сбора!
        M.registry[uid].is_collected = true
        print("💾 БЭКЕНД: Душа существа [" .. uid .. "] запечатана флагом is_collected!")
    else
        print("🚨 БЭКЕНД: Ошибка удаления! Ключ [" .. tostring(uid) .. "] не найден в registry!")
    end
end


---@param uid string Уникальный строковый идентификатор ("player" или "c_X_Y")
---@return UnitInstance|nil Возвращает таблицу живого паспорта юнита из RAM
function M.get_unit_by_uid(uid)
    if M.registry and M.registry[uid] then
        return M.registry[uid]
    end
    return nil
end

---Проверить, существует ли Душа монстра в глобальной памяти бэкенда
---@param uid string
---@return boolean
function M.exists(uid)
    return M.registry[uid] ~= nil
end

---Дополнительный быстрый метод-вопрос для скриптов
---@param uid string
---@return boolean
function M.is_unit_collected(uid)
    if M.registry and M.registry[uid] then
        return M.registry[uid].is_collected == true
    end
    return false
end

---Получить динамические данные монстра по его UID
---@param uid string
---@return UnitInstance|nil
function M.get(uid)
    return M.registry[uid]
end

---Получить весь реестр живых монстров (для сохранения игры)
---@return table<string, UnitInstance>
function M.get_all()
    return M.registry
end

---🚨 ДОМЕННЫЙ ААА-МУТАТОР: Выдать предмет в инвентарь конкретного существа в RAM
---@param uid string Уникальный UID существа ("player", "c_X_Y")
---@param item_id string|hash Строковый или хэш ID предмета из базы данных
---@param amount number Количество предметов
---@param item_uid string|nil Уникальный Си-ИНН инстанса предмета
---@param sub_items table|nil Внутренние шмотки бочки/контейнера
---@param is_looted boolean|nil Флаг обыска
---@param loot_table_id string|nil ID таблицы лута
---@return boolean @Успешность операции (хватило ли места в сумках)
function M.unit_item_add(uid, item_id, amount, item_uid, sub_items, is_looted, loot_table_id)
    if not M.registry or not M.registry[uid] then return false end

    local unit = M.registry[uid]
    -- Гвард защиты: проверяем, что у существа физически существует объект рюкзака в памяти
    if not unit or not unit.inventory then
        print("🚨 БЭКЕНД [UnitsState]: Не удалось выдать предмет, инвентарь отсутствует у UID:", uid)
        return false
    end

    -- 🦾 ЧЕСТНЫЙ, ЗРЯЧИЙ НАЛИВ ЧЕРЕЗ ДВOЕTOЧIЕ:
    -- Вызываем метод прямо на живом ООП-инстансе рюкзака из глобального реестра RAM!
    local success = unit.inventory:add_item(
        item_id,
        amount,
        item_uid,
        sub_items,
        is_looted,
        loot_table_id
    )

    -- Если шмотка шёлково легла в ячейку, и это был ИГРОК — взрываем шину реактивности!
    if success and (unit.is_player or uid == "player") then
        broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    end

    return success
end

---🚨 ЗРЯЧИЙ БЭКЕНД-МУТАТОР СЛОТОВ ПАНЕЛИ (WoW Канон):
---Напрямую изменяет плоский массив экшен-бара существа внутри глобального реестра RAM.
---@param uid string UID существа ("player")
---@param bar_index number Номер панели (1, 2 или 3)
---@param slot_index number Порядковый номер ячейки (1..12)
---@param action_type "ability"|"item"|"empty" Тип действия
---@param action_id string|nil Идентификатор ("frostbolt", "iron_sword", nil)
function M.set_action_bar_slot(uid, bar_index, slot_index, action_type, action_id)
    if not M.registry or not M.registry[uid] then return end

    local unit = M.registry[uid]
    if not unit or not unit.action_bars then return end

    -- Находим нужную плоскую таблицу панели внутри глобального RAM-паспорта Души
    local current_bar = unit.action_bars[bar_index]
    if not current_bar then
        -- 🚀 ЧИСТЫЙ АAА-МАССИВНЫЙ МОСТ (ИСПРАВЛЕНО НАМЕРТВО):
        -- Сначала заявляем локальную пустую таблицу
        ---@type ActionSlot[]
        local new_bar = {}

        -- Всаживаем её в экшен-бары юнита. Линтер сожрет это с потрохами, 
        -- потому что типы new_bar и unit.action_bars[bar_index] совпадают байт-в-байт!
        unit.action_bars[bar_index] = new_bar
        current_bar = unit.action_bars[bar_index]
    end

    -- 🦾 АТОМАРНАЯ СИ-МУТАЦИЯ (СТРУКТУРА ПОЛНОСТЬЮ ВЫРОВНЕНА ПОД СЕТКУ):
    -- Вместо nil пишем честную заглушку { action_type = "empty" }, чтобы не рвать массив!
    if action_type == "empty" or not action_id or action_id == "" then
        current_bar[slot_index] = { action_type = "empty" }
    else
        current_bar[slot_index] = {
            action_type = action_type,
            action_id = action_id
        }
    end

    print(string.format("💾 БЭКЕНД [UnitsState]: Изменена Глобальная Панель %d, Слот %d для Юнита [%s] -> [%s: %s]",
        bar_index, slot_index, uid, action_type, tostring(action_id)))

    -- Реактивно пинаем HUD бродкастами, strictly только если изменился ИГРОК
    if unit.is_player or uid == "player" then
        broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
        broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    end
end

---Собрать стерильный, чистокровный АAА-слепок всего реестра юнитов для JSON-сохранения (БЕЗ ДИПКОПИ И БЕЗ БРЕДЯТИНЫ)
---@return table<string, table> flat_registry_snapshot
function M.get_save_snapshot()
    local registry_snapshot = {}
    if not M.registry then return registry_snapshot end

    -- 🚀 УЛЬТИМАТИВНЫЙ ПОЛИМОРФНЫЙ ШЭЛЛОУ-КОНВЕЙЕР:
    for uid, live_unit in pairs(M.registry) do
        if live_unit then
            -- 1. За 1 такт CPU делаем плоский слепок карточки юнита (копируем все поля оптом!)
            -- Этот цикл никогда не вызовет stack overflow, так как он не лезет в рекурсию!
            local flat_unit = {}
            for field_name, field_value in pairs(live_unit) do
                flat_unit[field_name] = field_value
            end

            -- 2. 🦾 ПЕРЕЗАПИСЫВАЕМ СТРОГО ПОЛЯ-МОДЕЛИ (ИСПРАВЛЕНО НАМЕРТВО):
            -- Вызываем объектные методы сохранения сумок и куклы шмота у живых моделей в ОЗУ.
            -- Они сочно переведут Си-хэши в строки и вернут плоские таблицы без owner-линков!
            flat_unit.inventory = (live_unit.inventory and live_unit.inventory.get_save_data) and live_unit.inventory:get_save_data() or {}
            flat_unit.paperdoll = (live_unit.paperdoll and live_unit.paperdoll.get_save_data) and live_unit.paperdoll:get_save_data() or {}

            -- Запекаем этот чистый, автоматически собранный паспорт юнита в итоговый снапшот
            registry_snapshot[uid] = flat_unit
        end
    end

    -- Отдаем абсолютно сухую карту вселенной. json.encode сожрет её за 0 наносекунд!
    return registry_snapshot
end

---Раздача прилетевших из JSON данных обратно в оперативную память Lua монстров
---@param data table Таблица реестра монстров из файла сохранения
function M.restore_all(data)
    M.registry = data or {}
    M.is_loaded_from_save = true
    print("🔬 [units_state restore_all] ДАННЫЕ ИЗ СЕЙВА:")

    -- 🎯 ЧИСТОКРОВНАЯ РЕГЕНЕРАЦИЯ ВЕКТОРОВ И ООП-МЕТАТАБЛИЦ ПРИ ЗАГРУЗКЕ СЕЙВА:
    for uid, unit in pairs(M.registry) do
        local saved_position = unit.saved_position
        print(string.format("🔬   UID: %s | Жив: %s | Позиция в сейве: X=%s, Y=%s",
            uid, tostring(not unit.combat.is_dead),
            tostring(saved_position and saved_position.x), tostring(saved_position and saved_position.y)))

        -- 1. ВОССТАНОВЛЕНИЕ ВЕКТОРОВ DEFOLD (Твой оригинальный рабочий код!)
        if saved_position and type(saved_position) == "table" then
            unit.saved_position = vmath.vector3(saved_position.x, saved_position.y, saved_position.z or 1.0)
        end

        -- =========================================================================
        -- 🦾 2. AAA-РЕАНИМАЦИЯ ИНВЕНТАРЕЙ ДЛЯ ВСЕЙ ВСЕЛЕННОЙ ЮНИТОВ (ИСПРАВЛЕНО):
        -- =========================================================================
        -- Временная локалка raw_ здесь полезна, чтобы не мутировать unit.inventory до наката
        local raw_inventory = unit.inventory

        if raw_inventory then
            -- 🚀 ШЁЛКОВЫЙ КОНТУР НА ЛЕТУ:
            -- Мы убрали все "live_" переменные. Мы сразу создаем зрячий инстанс класса,
            -- накатываем на него сырой JSON-мешок и запекаем прямо в паспорт юнита!
            unit.inventory = inventory_model.new(unit, (uid == "player") and 49 or 24)
            unit.inventory:load_save_data(raw_inventory)
        end

        -- =========================================================================
        -- 🦾 3. AAA-РЕАНИМАЦИЯ КУКОЛ ШМОТА ДЛЯ ВСЕЙ ВСЕЛЕННОЙ ЮНИТОВ (ИСПРАВЛЕНО):
        -- =========================================================================
        local raw_paperdoll = unit.paperdoll

        if raw_paperdoll then
            -- 🚀 ШЁЛКОВЫЙ КОНТУР НА ЛЕТУ:
            -- Никакого мусора в именах. Создали куклу, скормили сейв, запечатали в ОЗУ!
            unit.paperdoll = paperdoll_model.new(unit)
            unit.paperdoll:load_save_data(raw_paperdoll)
        end
    end

    print("💾 БЭКЕНД [units_state]: Все JSON-координаты монстров успешно переведены в Си-векторы vmath.vector3!")
end

function M.clear()
    M.registry = {}
    M.instances = {}
    M.is_loaded_from_save = false
end

---Легкий бэкенд-мутатор для динамического обновления геймплейных данных монстра (WoW-канон)
---@param uid string Уникальный строковый UID существа ("c_1200_700")
---@param current_data table Новая плоская таблица с измененными полями (saved_position, health и т.д.)
function M.update_unit(uid, current_data)
    -- Мы работаем строго и только если паспорт моба реально существует в памяти RAM!
    if M.registry and M.registry[uid] then
        local unit = M.registry[uid]

        -- =========================================================================
        -- 🛡️ 1. ГВАРД ОКРУГЛЕНИЯ ПИКСЕЛЕЙ КООРДИНАТ (X и Y):
        -- =========================================================================
        if current_data.saved_position then
            local live_pos = current_data.saved_position
            unit.saved_position = vmath.vector3(
                math.floor(live_pos.x + 0.5),
                math.floor(live_pos.y + 0.5),
                live_pos.z -- Z оставляем в покое, сохраняем вертикальность
            )
        end

        -- =========================================================================
        -- 🩸 2. ЗРЯЧЕЕ ОБНОВЛЕНИЕ ТЕКУЩЕГО ХП В RAM (ИСПРАВЛЕНО НАМЕРТВО):
        -- =========================================================================
        -- Если прилетело плоское внешнее поле current_data.health (например, 50)
        if current_data.health then
            -- Пишем strictly внутрь нашего нового ААА-ресурса здоровья в реестре!
            unit.health_resource.current = current_data.health

            -- Си-гварды безопасности: ХП не может упасть ниже нуля и подняться выше потолка параметров!
            if unit.health_resource.current < 0 then
                unit.health_resource.current = 0
            end
            if unit.health_resource.current > unit.parameters.max_health then
                unit.health_resource.current = unit.parameters.max_health
            end
        end

        -- =========================================================================
        -- 💥 3. ПУЛЕНЕПРОБИВАЕМЫЙ ГВАРД СМЕРТИ (ИСПРАВЛЕНО НАМЕРТВО БЕЗ ОПЕЧАТОК):
        -- =========================================================================
        -- Читаем плоское внешнее поле current_data.is_dead, а пишем во вложенный блок combat!
        if current_data.is_dead ~= nil then
            unit.combat.is_dead = (current_data.is_dead == true)
        end

        -- 🎯 4. ДОПОЛНИТЕЛЬНЫЙ ГВАРД ДУШИ:
        -- Если моб умер, принудительно страхуем текущее здоровье на жесткий ноль в ОЗУ,
        -- чтобы оно никогда фантомно не сбросилось в nil или микро-минусы!
        if current_data.is_dead == true or unit.combat.is_dead == true then
            unit.health_resource.current = 0
        end
        -- =========================================================================
    else
        print("🚨 БЭКЕНД ГВАРД: Предотвращена попытка затереть паспорт моба пустышкой координат:", uid)
    end
end


---Централизованный ААА-Мутатор боевого стейта существ в RAM
---@param unit_uid string UID существа ("skeleton_mage_4")
---@param victim_uid string|nil UID жертвы ("player") или nil для сброса боя
function M.set_combat_state(unit_uid, victim_uid)
    local unit = M.registry and M.registry[unit_uid]
    if not unit then return end

    if victim_uid then
        -- ⚔️ ВЕТКА ВХОДА В БОЙ (АГРО):
        unit.combat.is_in_combat = true
        unit.combat.combat_target_uid = victim_uid
        -- Запекаем тактовый миг старта комбата через нативное Си-время Defold
        unit.combat.combat_start_time = socket.gettime()

        -- ЭТАЛОН 1: Если моб сагрился на игрока — маг ТОЖЕ мгновенно входит в комбат!
        -- Это сразу вешает комбат на HUD игрока, закрывает сумки и включает боевой реген.
        if victim_uid == "player" and M.registry["player"] then
            M.registry["player"].combat.is_in_combat = true
        end
    else
        -- 🏃‍♂️ ВЕТКА ВЫХОДА ИЗ БОЯ (ЭВЕЙД / СМЕРТЬ ИГРОКА):
        unit.combat.is_in_combat = false
        unit.combat.combat_target_uid = nil
        unit.combat.combat_start_time = nil

        -- ЭТАЛОН 2: Умный автоматический сброс комбата у Игрока-Мага!
        -- Если кастер, который только что сбросил бой — это моб, напавший на игрока,
        -- мы проверяем: а остался ли в Meadows ЕЩЁ ХОТЬ КТО-ТО, кто покадрово бьёт мага?
        if unit_uid ~= "player" then
            local player_is_still_threatened = false

            for other_uid, other_unit in pairs(M.registry) do
                if other_unit.combat.is_in_combat and other_unit.combat.combat_target_uid == "player" then
                    player_is_still_threatened = true
                    break
                end
            end

            -- Если Meadows-вселенная вокруг мага очистилась, и его больше никто не трогает —
            -- мага сочно и автоматически выпускает из режима боя!
            if not player_is_still_threatened and M.registry["player"] then
                M.registry["player"].combat.is_in_combat = false
                print("🛡️ БЭКЕНД: Все враги повержены или отстали. Игрок вышел из боя!")
            end
        end
    end
end

---🚨 ДОМЕННЫЙ МУТАТОР: Списать ресурс у юнита в Single Source of Truth
---@param unit_uid string UID существа ("player")
---@param resource_type "mana"|"energy"|"rage"|string Тип требуемого ресурса
---@param cost number Количество списываемой энергии
function M.consume_unit_resource(unit_uid, resource_type, cost)
    if not M.registry or not M.registry[unit_uid] then return end

    local unit = M.registry[unit_uid]
    if not unit or not unit.resource then return end

    -- 🦾 ЗРЯЧАЯ СИ-ПРОВЕРКА ТИПА (ИСПРАВЛЕНО НАМЕРТВО):
    -- Мы проверяем, совпадает ли требуемый ресурс с тем, что запечен в поле .type!
    if unit.resource.type == resource_type then
        -- Списываем цифры напрямую из RAM-ячейки
        unit.resource.current = math.max(0, unit.resource.current - (cost or 0))

        print(string.format("💾 БЭКЕНД [UnitsState]: Юнит [%s] потратил %d %s. Осталось: %d",
            unit_uid, cost or 0, resource_type:upper(), unit.resource.current))

        -- 🚀 ЕДИНЫЙ СЛEПОЙ СВIСТOК РЕАКТИВНОСТИ:
        -- Пуляем в шину строго ОДИН ивент и скармливаем только UID пострадавшего!
        -- Никаких мешков с процентами и типами — HUD сам deferred-пнёт PlayerFrame, 
        -- а фрейм игрока наносекундно высосет свежий стейт из RAM и обновит полоску! 
        broadcast.send("unit_events", {
            message_id = hash("unit_resource_changed"),
            uid = unit_uid -- 🎯 КРИТИЧЕСКИ ВАЖНО: передаем strictly под именем uid, как в ХП!
        })
    end
end

---Проверить, находится ли Душа моба в боевом состоянии (WoW-канон)
---@param uid string
---@return boolean
function M.is_unit_in_combat(uid)
    local unit = M.registry and M.registry[uid]
    if not unit then return false end

    -- Вся логика флагов ИИ и агро спрятана внутри синглтона стейта!
    -- Прямое, моментальное чтение полей без создания ООП-геттеров и метатаблиц!
    return unit.combat.is_in_combat == true or unit.combat.combat_target_uid ~= nil
end

---⏳ ЦЕНТРАЛЬНЫЕ ЧАСЫ Meadows: Покадрово тикаем ГКД и касты ВСЕХ существ в RAM-реестре!
---Этот метод вызывается ровно ОДИН РАЗ внутри update(self, dt) твоего world.script!
---@param dt number Покадровая дельта времени
function M.update_all_timers(dt)
    -- Проверяем твою центральную рантайм-таблицу живых сущностей на карте.
    -- Так как игрок при создании тоже регистрируется в ней под своим UID,
    -- этот один-единственный цикл будет автоматически тикать время ВСЕМ разом!
    local registry = M.registry
    if not registry then return end

    for uid, unit in pairs(registry) do
        -- 1. Покадрово гасим глобальный кулдаун (ГКД) для этого существа
        if unit.cast.gcd_current and unit.cast.gcd_current > 0 then
            unit.cast.gcd_current = unit.cast.gcd_current - dt
            if unit.cast.gcd_current < 0 then unit.cast.gcd_current = 0 end
        end

        -- 2. Покадрово тикаем время активного кастбара заклинания
        if unit.cast.ability_id and unit.cast.time then
            unit.cast.time = unit.cast.time + dt
        end
    end
end

-- =========================================================================
-- 🦾 ЛЕГКИЕ БОЕВЫЕ МУТАТОРЫ (WoW-канон: Только RAM и Бродкаст)
-- =========================================================================

---Установить точное значение здоровья монстра в оперативной памяти
---@param uid string Уникальный строковый UID существа
---@param new_health number Финальное высчитанное значение ХП
function M.set_health(uid, new_health)
    if M.registry and M.registry[uid] then
        -- Жесткое атомарное присвоение
        M.registry[uid].health = math.max(0, new_health)
    end
end

---Установить точное значение маны/энергии монстра
---@param uid string Уникальный строковый UID существа
---@param new_mana number Финальное значение маны
function M.set_mana(uid, new_mana)
    if M.registry and M.registry[uid] then
        M.registry[uid].mana = math.max(0, new_mana)
    end
end

---Обновить состояние аур (баффов/дебаффов) монстра
---@param uid string Уникальный строковый UID существа
---@param auras_table table Актуальный массив аур существа
function M.set_auras(uid, auras_table)
    if M.registry and M.registry[uid] then
        M.registry[uid].auras = auras_table or {}
    end
end

return M

