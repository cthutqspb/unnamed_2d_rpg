local broadcast = require("main.modules.system.broadcast")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")

---@class SaveManagerModule
local M = {}

-- 🎯 ГИГИЕНА: Единый пуленепробиваемый путь к JSON файлу сохранения
---@type string
local SAVE_PATH = sys.get_save_file("MyAwesomeRPG", "save_01.json")

-- =========================================================================
-- 🛡️ ААА-АТРИБУТ [JsonIgnore]: ТИТАНОВЫЙ ЧЕРНЫЙ СПИСОК РЕКУРСИЙ
-- =========================================================================
-- Сюда мы заносим любые служебные поля, ссылки на Си-объекты или обратные указатели,
-- которые JSON-устройство обязано НАГЛУХО игнорировать при записи игры на жесткий диск ПК.
local JSON_IGNORE_FIELDS = {
    ["owner"] = true,  -- Наша главная обратная ссылка «Рюкзак/Кукла -> Хозяин-Юнит»
    -- ["current_target"] = true, -- Сюда в будущем можно вписать ИИ-таргет монстра!
}

-- Рекурсивная проверка и конвертация типов Defold в типы JSON (Твой оригинальный код!)
---@param t any Входящие данные любого типа
---@return any Очищенная от хэшей таблица или примитив
local function prepare_for_json(t)
    -- 🎯 1. ТВОЙ ПУЛЕНЕПРОБИВАЕМЫЙ ПЕРЕХВАТ ВЕКТОРОВ DEFOLD (WoW/BG3 канон):
    -- Если прилетел userdata-вектор, у него тип равен "userdata", но у него ЕСТЬ поля x и y!
    -- Мы проверяем это первой строчкой через pcall (чтобы не крашнулось на голых хэшах).
    -- Если это вектор — мгновенно раскладываем его в стерильную JSON-таблицу чисел {x, y, z}!
    if type(t) == "userdata" and pcall(function() return t.x and t.y end) then
        return { x = t.x, y = t.y, z = t.z or 0 }
    end

    -- 2. ГВАРД ДЛЯ ОСТАЛЬНЫХ СИ-ТИПОВ (Голые Хэши движка):
    -- Сюда зайдут только чистые Си-хэши hash("skeleton_warrior"), у которых нет полей x и y.
    -- Они канонично превратятся в безопасный текст, чтобы json.encode не рушил игру.
    if type(t) ~= "table" then
        if type(t) == "userdata" then
            return tostring(t)
        end
        return t
    end

    -- 3. РЕКУРСИВНЫЙ ОБХОД ТАБЛИЦ (Твой оригинальный рабочий код!)
    local clean = {}
    for k, v in pairs(t) do
        -- 🦾 УЛЬТИМАТИВНЫЙ AAA-ПЕРЕХВАТЧИК [JsonIgnore] (ИСПРАВЛЕНО И ЗАФИКСИРОВАНО):
        -- Мы проверяем, лежит ли текущий ключ в нашем черном списке рекурсий.
        -- Если чистильщик видит поле "owner" — он СЛЕПО ПРОПУСКАЕТ эту итерацию!
        -- Мертвая петля рекурсии "маг -> рюкзак -> маг" разрывается посреди кадра на корню!
        local clean_key = type(k) == "userdata" and tostring(k) or k
        if not JSON_IGNORE_FIELDS[k] then
            -- Ключи JSON могут быть ТОЛЬКО строками. Хэш-ключ — смерть для json.encode
              clean[clean_key] = prepare_for_json(v)
        end
    end
    return clean
end

---@return boolean Проверить существует ли файл сохранения на диске ПК (Для кнопки Continue)
function M.exists()
    local file = io.open(SAVE_PATH, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

---Инициализировать стейт Памяти под Новую Игру (Канон WoW)
function M.new_game(creation_package)
    -- 1. Стерильно очищаем все домены данных в оперативной памяти Lua
    --character_data.player = nil
    game_state.clear_all()
    --player_paperdoll.clear()

     -- 🛡️ ВЫТАCКИВАЕМ ДЕФОЛТЫ ИЗ АРХЕТИПА:
    -- Если пакет не прилетел (тест из редактора), ставим жесткий фоллбек,
    -- но если пакет есть — игра запустится с тем именем и классом, что выбрал игрок!
    local character = creation_package or {
        uid = "player",
        unit_id = "player_mage",
        name_key = "class_mage",
        stats = { strength = 10, agility = 10, intellect = 10, stamina = 10 }
    }

    -- Рожаем Юнита игрока в RAM на основе прилетевшего пакета!
    game_state.create_player_unit({
        unit_id = character.unit_id,
        name_key = character.name_key,
        is_player = true,
        level = 1,
        experience = 0,
        health = 100,
        max_health = 100,
        resource = {
            type = character.resource_type or "mana", -- Динамически подхватит тип класса!
            current = character.base_max_resource or 100,
            max = character.base_max_resource or 100
        },
        base_stats = character.base_stats,
        faction = "neutral_humanoid",
        current_stats = character.current_stats,
        saved_position = vmath.vector3(1126, 725, 1.0)
    })

    -- Намертво привязываем мост
    character_data.PLAYER_UID = character.uid

    character_data.bind_to_units_registry()

    -- Насыпаем стартовый ААА-эквип магу в рюкзак
    local player_data = game_state.get_entity_by_uid(character_data.PLAYER_UID)

    if player_data and player_data.inventory then
        -- Очищаем рюкзак мага перед выдачей стартового сета
        player_data.inventory:clear()

        -- 🎯 НАВАЛИВАЕМ СТАРТОВЫЙ ЛУТ СТРОГО В ОБЪЕКТНЫЙ ИНСТАНС ИЗ ПАСПОРТА!
        -- Метод :add_item сам сочно раскидает мечи и банки по ячейкам в памяти RAM,
        -- а GUI-окно при открытии мгновенно и безбажно отрендерит эти иконки на экране!
        player_data.inventory:add_item("iron_sword", 1)
        player_data.inventory:add_item("lesser_mana_potion", 10)
        player_data.inventory:add_item("leather_helmet", 1)
        player_data.inventory:add_item("clown_hat", 1)
        player_data.inventory:add_item("crystal_sword", 1)

        print("💾 БЭКЕНД: Стартовый лут Новой Игры успешно засыпан в RAM-паспорт мага!")
    else
        print("🚨 БЭКЕНД: Не удалось выдать стартовый шмот, инвентарь игрока не инициализирован!")
    end

    -- Настраиваем дефолтную раскладку экшен-баров на HUD
    character_data.player.action_bars = {
        [1] = {
            [1] = { action_type = "ability", action_id = "melee_attack" },
            [2] = { action_type = "ability", action_id = "frostbolt", triggers_gcd = true },
            [3] = { action_type = "ability", action_id = "lightning_bolt", triggers_gcd = true },
            [4] = { action_type = "item",    action_id = "lesser_mana_potion", triggers_gcd = true },
            [5] = { action_type = "item",    action_id = "iron_sword" },
        },
        [2] = {},
    }

    -- Перезапускаем Proxy-коллекцию мира. Все маркеры редактора запекутся с нуля!
    msg.post("main:/loader#script", "reload_game", { saved_position = nil })
    broadcast.send("inventory_events", { message_id = hash("inventory_changed")})
    broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
    broadcast.send("unit_events", {
        message_id = hash("unit_health_changed"),
        uid = character_data.PLAYER_UID
    })
    broadcast.send("unit_events", {
        message_id = hash("unit_resource_changed"),
        uid = character_data.PLAYER_UID
    })
    broadcast.send("target_events", { message_id = hash("target_lost") })
    broadcast.send("log_events", { message_id = hash("log_clear") })
end

---Засейвить игру на жесткий диск ПК (JSON-монолит)
---@return boolean
function M.save_game()
    local player_unit = game_state.get_entity_by_uid(character_data.PLAYER_UID)
    if not player_unit then return false end

    local player_position = player_unit.saved_position
    local serializable_position = { x = player_position.x, y = player_position.y, z = player_position.z or 0 }

    -- 🦾 1. СБОРКА ТИТАНОВОГО ПОЛИМОРФНОГО ПАКЕТА ПЕРСОНАЖА:
    local character_payload = {
        level = player_unit.level,
        experience = player_unit.experience,
        health = player_unit.health,
        mana = player_unit.mana, -- Сохраняем ману/ресурс, если они есть
        saved_position = serializable_position,
        action_bars = player_unit.action_bars,

        -- Объектные методы сохранения сумок и куклы шмота
        inventory = player_unit.inventory and player_unit.inventory:get_save_data() or {},
        paperdoll = player_unit.paperdoll and player_unit.paperdoll:get_save_data() or {}
    }

    -- 🦾 2. ДИНАМИЧЕСКИЙ СБОР КОРНЯ JSON (Канон WoW / BG3):
    local data = {
        version = 1,
        time = os.time(),

        -- СТЕРТО НАФИГ СЛЕПОЕ ЗАПЕКАНИЕ КЛЮЧА player = { ... }!
        -- Мы динамически вшиваем мешок данных персонажа под его ИСТИННЫМ UID сессии!
        -- Если мы играем за Артаса, в файле создастся ключ "Arthas": { ... }!
        [character_data.PLAYER_UID] = character_payload,
        -- Сбор динамической вселенной Meadows (монстры, сундуки, трава чанков)
        world = game_state.get_full_save_data()
    }

    local file = io.open(SAVE_PATH, "w+")
    if file then
        -- Наш prepare_for_json сжирает матрешку мира за 1 Си-такт, убирая owner ссылки
        local success, json_string = pcall(json.encode, prepare_for_json(data))
        if not success then
            print("🚨 БЭКЕНД [Save Error]: Критическая ошибка сериализации! В данных остался userdata/hash!")
            file:close()
            return false
        end

        file:write(json_string)
        file:close()
        print(string.format("💾 БЭКЕНД [SaveManager]: Сейв персонажа [%s] успешно записан на диск ПК (JSON-монолит)", character_data.PLAYER_UID))
        return true
    end
    return false
end

---Загрузить игру из файла сохранения JSON
---@return boolean
function M.load_game()
    local file = io.open(SAVE_PATH, "r")
    if not file then return false end

    local content = file:read("*all")
    file:close()

    local data = json.decode(content)
    if not data then return false end

    -- 1. Сначала реанимируем в RAM динамические чанки мира
    game_state.restore_all(data.world)

    -- =========================================================================
    -- 🦾 ФАЗА 1: ОДУШЕВЛЕНИЕ И ЗАПЕКАНИЕ МОСТА (ПЕРЕНЕСЕНО НАМЕРТВО НАВЕРХ):
    -- =========================================================================
    -- Вызываем принудительный биндинг! Теперь в RAM гарантированно создана ячейка 
    -- мага, и character_data.player пуленепробиваемо держит прямую ссылку на неё!
    character_data.bind_to_units_registry()

    -- Вытаскиваем зрячий RAM-паспорт нашего героя из Фасада вселенной по токену сессии!
    local player_unit = game_state.get_entity_by_uid(character_data.PLAYER_UID)

    -- 🚀 ПОЛИМОРФНЫЙ ВЫКАЧ PAYLOAD ИЗ JSON-ФАЙЛА:
    -- Нам глубоко насрать на хардкод поля data.player. Мы читаем блок данных 
    -- персонажа динамически по его токену сессии (character_data.PLAYER_UID)!
    local saved_character_payload = data and (data[character_data.PLAYER_UID] or data.player)

    -- =========================================================================
    -- 🧱 ФАЗА 2: НАКАТКА ПРОГРЕССА СЕЙВА В ОПЕРАТИВНУЮ ПАМЯТЬ RAM:
    -- =========================================================================
    if player_unit and saved_character_payload then
        -- Накатываем сохраненные инстансы куклы шмота и сумок через объектные методы
        if saved_character_payload.inventory and player_unit.inventory then
            player_unit.inventory:load_save_data(saved_character_payload.inventory)
        end
        if saved_character_payload.paperdoll and player_unit.paperdoll then
            player_unit.paperdoll:load_save_data(saved_character_payload.paperdoll)
        end

        -- Реанимируем кастомные панели заклинаний, левел, ХП и ману из файла
        player_unit.action_bars = saved_character_payload.action_bars or player_unit.action_bars
        player_unit.experience = saved_character_payload.experience or 0
        player_unit.level = saved_character_payload.level or 1
        player_unit.health = saved_character_payload.health or player_unit.max_health

        if player_unit.mana and saved_character_payload.mana then
            player_unit.mana = saved_character_payload.mana
        end

        -- Выкачиваем позицию из сейва. Если её нет — берем текущую
        if saved_character_payload.saved_position then
            player_unit.saved_position = saved_character_payload.saved_position
        end
    else
        print("🚨 БЭКЕНД [Load Error]: Не удалось состыковать паспорт в RAM с payloads файла JSON!")
    end

    -- =========================================================================
    -- 📐 ФАЗА 3: ВОССТАНОВЛЕНИЕ СИ-ВЕКТОРОВ И ПЕРЕЗАПУСК КОЛЛЕКЦИИ:
    -- =========================================================================
    -- Читаем координаты наносекундно по прямой кэшированной ссылке-мосту!
    local saved_position = character_data.player and character_data.player.saved_position

    local base_x = saved_position and saved_position.x or 1126 -- Каноничный дефолт новой игры
    local base_y = saved_position and saved_position.y or 725
    local base_z = saved_position and saved_position.z or 1.0

    local live_vector_position = vmath.vector3(base_x, base_y, base_z)
    character_data.player.saved_position = live_vector_position

    -- Передаем Си-вектор в движковый прокси-лоадер Defold для стриминга сцены
    msg.post("main:/loader#script", "reload_game", {
        is_load = true,
        saved_position = live_vector_position,
        action_bars = character_data.player.action_bars
    })

    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    broadcast.send("ui_events", { message_id = hash("clear_world_ui") })

    print(string.format("💾 БЭКЕНД [SaveManager]: Сейв персонажа [%s] успешно развернут. Векторы восстановлены!", character_data.PLAYER_UID))
    return true
end

return M
