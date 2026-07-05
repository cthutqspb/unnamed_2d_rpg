local broadcast = require("main.modules.system.broadcast")
local utils = require("main.modules.utils")
local units_db = require("main.modules.data.units_db")
local paperdoll_model = require("main.modules.models.paperdoll_model")
local inventory_model = require("main.modules.models.inventory_model")

---@class UnitInstanceData
---@field go_id hash идентификатор движка
---@field is_player boolean
---@field name string|nil Конкретное имя
---@field name_key string Имя типа юнита: скелет, кабан, росянка
---@field race string|nil
---@field class string|nil
---@field unit_id string Строковый ID вида ("skeleton")
---@field uid string Уникальный строковый UID конкретного монстра
---@field level number Текущий уровень существа
---@field experience number
---@field base_stats table<string, number>
---@field current_stats table<string, number>
---@field type string Тип существа ("undead", "beast", "humanoid")
---@field rank string Ранг сложности ("common", "rare", "elite")
---@field loot_table_id string|nil
---@field is_collected boolean
---@field health number Текущее живое ХП в данный момент времени
---@field max_health number Рассчитанный лимит ХП с учетом уровня и ранга
---@field resource UnitResourceData
---@field auras table|nil
---@field damage number Рассчитанный урон с учетом уровня
---@field speed number Скорость перемещения
---@field hitbox_size number
---@field spellcast_range number
---@field ai_profile string
---@field saved_position vector3|nil
---@field is_dead boolean|nil
---@field is_invulnerable boolean|nil 🛡️ ОПЦИОНАЛЬНО: Флаг полной неуязвимости (вместо nil-ХП!)
---@field action_bars table<number, (ActionSlotData|nil)[]>|nil 🌟 ОПЦИОНАЛЬНО: Панели способностей
---@field current_cast_ability_id string|nil Строковый ID кастуемой способности из БД ("frostbolt")
---@field current_cast_duration number|nil Полное эталонное время каста из базы (2.5)
---@field current_cast_time number|nil Текущее покадрово тикающее время каста в секундах
---@field gcd_current number|nil Текущий таймер глобального кулдауна в RAM
---@field ai_target vector3|nil
---@field base_aggro_radius number
---@field faction string
---@field paperdoll PaperdollInstance
---@field inventory InventoryInstance
---@field is_in_combat boolean Флаг нахождения в бою (активирует боевой реген маны/ХП)
---@field last_attacker_uid string|nil UID последнего существа, нанесшего урон в RAM
---@field combat_target_uid string|nil UID текущей боевой жертвы (кого юнит покадрово лупит)
---@field combat_start_time number|nil Таймстамп старта комбата в секундах

---@class UnitStatsTable
---@field strength number
---@field agility number
---@field intellect number
---@field stamina number

---@class UnitResourceData
---@field type "mana"|"rage"|"energy"|string Строковый тип энергии (индекс ресурса)
---@field current number Актуальное текущее значение в RAM (например, 45)
---@field max number Максимальный потолок пула в RAM (например, 100)

---@class ActionSlotData
---@field action_type "ability"|"item"|"empty" Тип действия в слоте
---@field action_id string|nil            Строковый ID из базы способностей или предметов

---@class RankModifiers
---@field health_multiplier number       Множитель максимального здоровья
---@field damage_multiplier number      Множитель базового урона
---@field resists table<string, number> Задел под резисты к стихиям (fire, frost и т.д.)
---@field bonus_abilities string[] Список дополнительных способностей, открываемых рангом

---@class UnitState
---@field registry table<string, UnitInstanceData>
---@field instances table<hash, string>
---@field is_loaded_from_save boolean
local M = {}

-- Главный реестр живых монстров в оперативной памяти [uid] = UnitInstanceData
---@type table<string, UnitInstanceData>
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
    local monster_cfg = (not props.is_player and uid ~= "player") and units_db.get_unit(props.unit_id) or nil

    local calculated_max_health = props.max_health or props.health or 100
    local calculated_max_mana = props.max_mana or props.mana or 50
    local source_stats = props.base_stats or props.stats or { strength = 10, agility = 10, intellect = 10, stamina = 10 }
    local source_abilities = props.abilities or { "melee_attack" }

    -- Если это фабричный монстр, прогоняем его через динамическое левел-скалирование ХП
    if monster_cfg then
        source_stats = props.base_stats or monster_cfg.base_stats or source_stats
        source_abilities = props.abilities or monster_cfg.abilities or source_abilities

        local level_modifier = math.pow(monster_cfg.health_growth or 1, (props.level or 1) - 1)
        calculated_max_health = math.floor((monster_cfg.base_health or 40) * level_modifier)

        if compute_rank_modifiers then
            local rank_mods = compute_rank_modifiers(props.rank or monster_cfg.default_rank)
            calculated_max_health = math.floor(calculated_max_health * rank_mods.health_multiplier)
        end
        calculated_max_mana = monster_cfg.base_mana or calculated_max_mana
    end

    local clean_stats = utils.deepcopy(source_stats)
    local clean_current_stats = utils.deepcopy(source_stats)
    local clean_source_abilities = utils.deepcopy(source_abilities)
    local raw_bars = props.action_bars or {}
    local raw_resource = props.resource or {}

    -- Сборка монолитной Души существа в RAM-реестре:
    local instance_data = {
        go_id = props.go_id or (props.is_player and hash("/player") or msg.url().path),
        uid = uid,
        unit_id = props.unit_id,
        name_key = props.name_key or (monster_cfg and monster_cfg.name_key) or "unknown_unit",
        is_player = (props.is_player == true or uid == "player"),
        type = props.type or (monster_cfg and monster_cfg.type) or "humanoid",
        rank = props.rank or (monster_cfg and monster_cfg.default_rank) or "common",
        level = props.level or 1,
        experience = props.experience or 0,
        health = props.health or calculated_max_health,
        max_health = calculated_max_health,
        resource = {
            type    = raw_resource.type or (monster_cfg and monster_cfg.resource and monster_cfg.resource.type) or "mana",
            current = raw_resource.current or 100,
            max     = raw_resource.max or 100
        },
        speed = props.speed or (props.is_player and 220 or (monster_cfg and monster_cfg.base_speed) or 90),
        spellcast_range = props.spellcast_range or (monster_cfg and monster_cfg.spellcast_range) or (props.is_player and 0 or 120),
        hitbox_size = props.hitbox_size or (monster_cfg and monster_cfg.hitbox_size) or 64,
        loot_table_id = props.loot_table_id or (monster_cfg and monster_cfg.default_loot_table_id) or "empty",
        ai_profile = props.ai_profile or (props.is_player and "none" or (monster_cfg and monster_cfg.ai_profile) or "aggressive_patrol"),
        base_aggro_radius = props.base_aggro_radius or (props.is_player and 0 or (monster_cfg and monster_cfg.base_aggro_radius) or 350),
        
        -- 🚀 ЗРЯЧИЙ АAА-ВЗВОД ФРАКЦИИ (ТИ ПEРВЫЙ КOНТУР ПОЛНОСТЬЮ СМЫКАЕТСЯ):
        -- Мы больше не гадаем вслепую! Если в props прилетел nil (из сейва или спавнера),
        -- мы берем породистую фракцию прямо из его верхнего monster_cfg базы данных units_db!
        -- И только если это чистокровный игрок, ставим "neutral_humanoid", а мобу — "undead".
        faction = props.faction or (monster_cfg and monster_cfg.faction) or (props.is_player and "neutral_humanoid" or "undead"),
        is_ranged = props.is_ranged or (monster_cfg and monster_cfg.is_ranged),
        flee_range = props.flee_range or (monster_cfg and monster_cfg.flee_range),
        tag_weights = props.tag_weights or (monster_cfg and monster_cfg.tag_weights),

        paperdoll = paperdoll_model.new(),
        inventory = inventory_model.new(),
        action_bars = {
            [1] = raw_bars[1] or {},
            [2] = raw_bars[2] or {},
            [3] = raw_bars[3] or {},
        },
        is_in_combat = false
    }

    -- Накат данных сохранения шмота и сумок, если они прилетели из файла
    if props.paperdoll_data and instance_data.paperdoll then
        instance_data.paperdoll:load_save_data(props.paperdoll)
    end
    if props.inventory_data and instance_data.inventory then
        instance_data.inventory:load_save_data(props.inventory)
    end

    -- 🦾 ЭТАЛОН 3: СКЛЕЙКА ОБЩИХ СИСТЕМНЫХ ПОЛЕЙ ЮНИТА
    instance_data.is_collected = (props.is_collected == true)
    instance_data.is_dead = (props.is_dead == true)
    instance_data.saved_position = props.saved_position or vmath.vector3(0, 0, 1.0)
    instance_data.base_stats = clean_stats
    instance_data.current_stats = clean_current_stats
    instance_data.abilities = clean_source_abilities

    if instance_data.paperdoll then instance_data.paperdoll.owner = instance_data end
    if instance_data.inventory then instance_data.inventory.owner = instance_data end

    -- Записываем готовую Душу Юнита в реестр RAM
    M.registry[uid] = instance_data
    return instance_data
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
---@return UnitInstanceData|nil Возвращает таблицу живого паспорта юнита из RAM
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
---@return UnitInstanceData|nil
function M.get(uid)
    return M.registry[uid]
end

---Получить весь реестр живых монстров (для сохранения игры)
---@return table<string, UnitInstanceData>
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
function M.add_unit_item(uid, item_id, amount, item_uid, sub_items, is_looted, loot_table_id)
    if not M.registry or not M.registry[uid] then return false end

    local unit_data = M.registry[uid]
    -- Гвард защиты: проверяем, что у существа физически существует объект рюкзака в памяти
    if not unit_data or not unit_data.inventory then
        print("🚨 БЭКЕНД [UnitsState]: Не удалось выдать предмет, инвентарь отсутствует у UID:", uid)
        return false
    end

    -- 🦾 ЧЕСТНЫЙ, ЗРЯЧИЙ НАЛИВ ЧЕРЕЗ ДВOЕTOЧIЕ:
    -- Вызываем метод прямо на живом ООП-инстансе рюкзака из глобального реестра RAM!
    local success = unit_data.inventory:add_item(
        item_id,
        amount,
        item_uid,
        sub_items,
        is_looted,
        loot_table_id
    )

    -- Если шмотка шёлково легла в ячейку, и это был ИГРОК — взрываем шину реактивности!
    if success and (unit_data.is_player or uid == "player") then
        local broadcast = require("main.modules.system.broadcast")
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

    local unit_data = M.registry[uid]
    if not unit_data or not unit_data.action_bars then return end

    -- Находим нужную плоскую таблицу панели внутри глобального RAM-паспорта Души
    local current_bar = unit_data.action_bars[bar_index]
    if not current_bar then
        unit_data.action_bars[bar_index] = {}
        current_bar = unit_data.action_bars[bar_index]
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
    if unit_data.is_player or uid == "player" then
        broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
        broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    end
end

---Раздача прилетевших из JSON данных обратно в оперативную память Lua монстров
---@param data table Таблица реестра монстров из файла сохранения
function M.restore_all(data)
    M.registry = data or {}
    M.is_loaded_from_save = true
    print("🔬 [units_state restore_all] ДАННЫЕ ИЗ СЕЙВА:")

    -- 🎯 ЧИСТОКРОВНАЯ РЕГЕНЕРАЦИЯ ВЕКТОРОВ И ООП-МЕТАТАБЛИЦ ПРИ ЗАГРУЗКЕ СЕЙВА:
    for uid, unit_data in pairs(M.registry) do
        local saved_pos = unit_data.saved_position
        print(string.format("🔬   UID: %s | Жив: %s | Позиция в сейве: X=%s, Y=%s",
            uid, tostring(not unit_data.is_dead),
            tostring(saved_pos and saved_pos.x), tostring(saved_pos and saved_pos.y)))

        -- 1. ВОССТАНОВЛЕНИЕ ВЕКТОРОВ DEFOLD (Твой оригинальный рабочий код!)
        if saved_pos and type(saved_pos) == "table" then
            unit_data.saved_position = vmath.vector3(saved_pos.x, saved_pos.y, saved_pos.z or 1.0)
        end

        -- =========================================================================
        -- 🦾 2. AAA-РЕАНИМАЦИЯ ИНВЕНТАРЕЙ ДЛЯ ВСЕЙ ВСЕЛЕННОЙ ЮНИТОВ (ДОБАВЛЕНО)
        -- =========================================================================
        -- В JSON-монолите сохранения шмот лежит в полях inventory_data / paperdoll_data,
        -- либо в твоих оригинальных полях inventory / paperdoll.
        local raw_inventory = unit_data.inventory or unit_data.inventory

        if raw_inventory then
            -- Вычисляем размер сетки существа. Для мага — 49 слотов, для монстров — дефолт 24
            local max_slots = (uid == "player") and 49 or 24

            -- Рождаем чистокровный, зрячий инстанс класса со всеми методами!
            -- Первым аргументом передаем 'unit' (паспорт хозяина), чтобы намертво зашить .owner!
            local live_inventory = inventory_model.new(unit_data, max_slots)

            -- Вызываем твой роскошный, нетронутый метод наката шмоток из JSON!
            -- Он сочно пройдется циклом, переведет ID строк в Си-хэши и заполнит ячейки.
            live_inventory:load_save_data(raw_inventory)

            -- Намертво перезаписываем плоское поле юнита готовым объектным инстансом!
            unit_data.inventory = live_inventory
        end

        -- =========================================================================
        -- 🦾 3. AAA-РЕАНИМАЦИЯ КУКОЛ ШМОТА ДЛЯ ВСЕЙ ВСЕЛЕННОЙ ЮНИТОВ (ДОБАВЛЕНО)
        -- =========================================================================
        local raw_paperdoll = unit_data.paperdoll or unit_data.paperdoll

        if raw_paperdoll then
            -- Рождаем зрячий инстанс куклы шмота, привязывая паспорт хозяина в .owner!
            local live_paperdoll = paperdoll_model.new(unit_data)

            -- Вызываем метод наката экипированных вещей из JSON
            live_paperdoll:load_save_data(raw_paperdoll)

            -- Перезаписываем плоское поле юнита готовым объектным инстансом!
            unit_data.paperdoll = live_paperdoll
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
---@param current_data table Новая таблица с измененными полями (saved_position, health и т.д.)
function M.update_data(uid, current_data)
    -- Мы работаем строго и только если паспорт моба реально существует в памяти RAM!
    if M.registry and M.registry[uid] then
        -- 🧱 СИММЕТРИЧНАЯ КЛАДКА ДАННЫХ (Data Merge):
        -- Мы аккуратно перезаписываем только то, что реально прилетело, защищая типы!
        if current_data.saved_position then
            local live_pos = current_data.saved_position

            -- 🛡️ ПУЛЕНЕПРОБИВАЕМЫЙ ГВАРД ОКРУГЛЕНИЯ ПИКСЕЛЕЙ (X и Y):
            -- Мы принудительно округляем покадровые X и Y до ближайшего целого числа.
            -- Это полностью уничтожает дробные хвосты (вроде .4239), которые ломают 
            -- математику генерации UID и чертежей в спавнере!
            -- При этом ось Z мы ВООБЩЕ НЕ ТРОГАЕМ (работает как работала)!
            M.registry[uid].saved_position = vmath.vector3(
                math.floor(live_pos.x + 0.5),
                math.floor(live_pos.y + 0.5),
                live_pos.z -- Z оставляем в покое, создатели движка не идиоты!
            )
        end

        if current_data.health then
            M.registry[uid].health = current_data.health
        end

        if current_data.is_dead ~= nil then
            M.registry[uid].is_dead = current_data.is_dead
        end

        -- 🎯 ДОПОЛНИТЕЛЬНЫЙ ГВАРД ПАСПОРТА:
        -- Если моб умер, принудительно страхуем здоровье на жесткий ноль,
        -- чтобы оно никогда фантомно не сбросилось в nil!
        if current_data.is_dead == true then
            M.registry[uid].health = 0
        end
    else
        -- ❌ СТИРАЕМ ОТСЮДА НАФИГ СЛEПОE ЗА ТИРAНИE M.registry[uid] = current_data!
        -- Интерфейс и ИИ больше никогда не потеряют паспортные данные моба!
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
        unit.is_in_combat = true
        unit.combat_target_uid = victim_uid
        -- Запекаем тактовый миг старта комбата через нативное Си-время Defold
        unit.combat_start_time = socket.gettime()

        -- ЭТАЛОН 1: Если моб сагрился на игрока — маг ТОЖЕ мгновенно входит в комбат!
        -- Это сразу вешает комбат на HUD игрока, закрывает сумки и включает боевой реген.
        if victim_uid == "player" and M.registry["player"] then
            M.registry["player"].is_in_combat = true
        end
    else
        -- 🏃‍♂️ ВЕТКА ВЫХОДА ИЗ БОЯ (ЭВЕЙД / СМЕРТЬ ИГРОКА):
        unit.is_in_combat = false
        unit.combat_target_uid = nil
        unit.combat_start_time = nil

        -- ЭТАЛОН 2: Умный автоматический сброс комбата у Игрока-Мага!
        -- Если кастер, который только что сбросил бой — это моб, напавший на игрока,
        -- мы проверяем: а остался ли в Meadows ЕЩЁ ХОТЬ КТО-ТО, кто покадрово бьёт мага?
        if unit_uid ~= "player" then
            local player_is_still_threatened = false

            for other_uid, other_unit in pairs(M.registry) do
                if other_unit.is_in_combat and other_unit.combat_target_uid == "player" then
                    player_is_still_threatened = true
                    break
                end
            end

            -- Если Meadows-вселенная вокруг мага очистилась, и его больше никто не трогает —
            -- мага сочно и автоматически выпускает из режима боя!
            if not player_is_still_threatened and M.registry["player"] then
                M.registry["player"].is_in_combat = false
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
    local unit_state = M.registry and M.registry[uid]
    if not unit_state then return false end

    -- Вся логика флагов ИИ и агро спрятана внутри синглтона стейта!
    -- Прямое, моментальное чтение полей без создания ООП-геттеров и метатаблиц!
    return unit_state.is_in_combat == true or unit_state.ai_target ~= nil
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
        if unit.gcd_current and unit.gcd_current > 0 then
            unit.gcd_current = unit.gcd_current - dt
            if unit.gcd_current < 0 then unit.gcd_current = 0 end
        end

        -- 2. Покадрово тикаем время активного кастбара заклинания
        if unit.current_cast_ability_id and unit.current_cast_time then
            unit.current_cast_time = unit.current_cast_time + dt
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

