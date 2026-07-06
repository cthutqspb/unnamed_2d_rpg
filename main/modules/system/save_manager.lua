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
    game_state.clear_all()

    -- 🛡️ ВЫТАCКИВАЕМ ДЕФОЛТЫ ИЗ АРХЕТИПА (ИСПРАВЛЕНО ПОД НОВЫЙ AAA-НЕЙМИНГ):
    -- Если пакет создания не прилетел (тест из редактора), запекаем идеальный, 
    -- вложенный стартовый шаблон Магаstrictly по нашей новой структуре доменов!
    local character = creation_package or {
        uid = "player",
        unit_id = "player_mage",
        identity = {
            name_key = "class_mage",
            race = "human",
            faction = "neutral_humanoid",
            type = "humanoid",
            default_rank = "common",
            unit_class = { mage = true }
        },
        -- Избавились от легаси "stats"! Теперь это гордые attributes!
        attributes = {
            strength = 10,
            agility = 10,
            intellect = 10,
            stamina = 10
        },
        parameters = {
            base_health = 100,
            max_health  = 100,
            base_speed  = 220,
            hitbox_size = 64,
            loot_table_id = "empty"
        },
        resource = {
            type    = "mana",
            current = 50,
            max     = 50
        }
    }

    -- =========================================================================
    -- 🚀 РОЖДАЕМ ЮНИТА ИГРОКА В RAM (ПOЛНOСТЬЮ СIНХРOНIЗIРOВAНO С M.add):
    -- =========================================================================
    -- Мы больше не кидаем плоскую кашу! Мы передаем в метод спавна props-пакет,
    -- который зеркально повторяет структуру вложенных доменов!
    game_state.create_player_unit({
        unit_id    = character.unit_id,
        is_player  = true,
        level      = 1,
        experience = 0,

        identity   = character.identity,
        attributes = character.attributes,
        parameters = character.parameters,

        -- Прокидываем Святую Троицу ХП на старт рантайма
        health_resource = {
            current = character.parameters and character.parameters.base_health or 100,
            max     = character.parameters and character.parameters.base_health or 100
        },

        -- Передаем ману/ярость мага
        resource = character.resource,

        visuals = {
            animation = "player_mage_idle",
            texture   = "project_utumno"
        },

        ai = {
            profile = "none",
            base_aggro_radius = 0,
            is_ranged = true,
            flee_range = 0,
            tag_weights = {}
        },

        abilities = { "melee_attack", "frostbolt", "lightning_bolt" },
        saved_position = vmath.vector3(1126, 725, 1.0)
    })
    -- =========================================================================

    -- Намертво привязываем мост UID
    character_data.PLAYER_UID = character.uid
    character_data.bind_to_units_registry()

    -- Вытаскиваем живую Душу игрока из свежесозданного реестра RAM стейта
    local player = game_state.get_entity_by_uid(character_data.PLAYER_UID)

    if player then
        -- 🎯 НАВАЛИВАЕМ СТАРТОВЫЙ ЛУТ В ОБЪЕКТНЫЙ ИНСТАНС ИЗ РЕЕСТРА:
        if player.inventory then
            player.inventory:clear()
            player.inventory:add_item("iron_sword", 1)
            player.inventory:add_item("lesser_mana_potion", 10)
            player.inventory:add_item("leather_helmet", 1)
            player.inventory:add_item("clown_hat", 1)
            player.inventory:add_item("crystal_sword", 1)
            print("💾 БЭКЕНД: Стартовый лут Новой Игры успешно засыпан в RAM-паспорт мага!")
        end

        -- =========================================================================
        -- 🔮 НAСТРOЙКA ДEФOЛТНOЙ РAСКЛAДКI ПAНEЛEЙ (ИСПРАВЛЕНО НАМЕРТВО):
        -- =========================================================================
        -- Никаких левых character_data.player! Мы пишем экшен-бары strictly внутрь
        -- легального RAM-паспорта игрока player_data, который прочитает HUD-интерфейс!
        player.action_bars = {
            [1] = {
                [1] = { action_type = "ability", action_id = "melee_attack" },
                [2] = { action_type = "ability", action_id = "frostbolt" },
                [3] = { action_type = "ability", action_id = "lightning_bolt" },
                [4] = { action_type = "item",    action_id = "lesser_mana_potion" },
                [5] = { action_type = "item",    action_id = "iron_sword" },
            },
            [2] = {},
            [3] = {}
        }
        -- =========================================================================
    else
        print("🚨 Critical Error БЭКЕНД: Не удалось вытащить инстанс игрока после спавна!")
    end

    -- Перезапускаем Proxy-коллекцию мира. Все маркеры редактора запекутся с нуля!
    msg.post("main:/loader#script", "reload_game", { saved_position = nil })

    -- Синхронно пинаем HUD-интерфейс сочными бродкастами
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
    broadcast.send("unit_events", { message_id = hash("unit_health_changed"), uid = character_data.PLAYER_UID })
    broadcast.send("unit_events", { message_id = hash("unit_resource_changed"), uid = character_data.PLAYER_UID })
    broadcast.send("target_events", { message_id = hash("target_lost") })
    broadcast.send("log_events", { message_id = hash("log_clear") })
end

---Засейвить игру на жесткий диск ПК (JSON-монолит)
---@return boolean
function M.save_game()
    -- 🚀 ПОЛНАЯ СЛЕПОТА ИИ И СЕРИАЛИЗАЦИИ (ИСПРАВЛЕНО НАМЕРТВО):
    -- 0% сборки payload руками! 0% перечисления полей игрока!
    -- game_state.get_full_save_data() возвращает ВСЮ живую RAM-память,
    -- включая реестр registry, где твой Игрок и так шёлково лежит как сущность!
    local world_snapshot = game_state.get_full_save_data()
    if not world_snapshot then return false end

    local data = {
        version = 1,
        time = os.time(),
        player_uid = character_data.PLAYER_UID, -- Просто запоминаем токен, за кого играли
        world = world_snapshot
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
        print(string.format("💾 БЭКЕНД [SaveManager]: Вселенная Meadows и Персонаж [%s] успешно сохранены в JSON-монолит!", character_data.PLAYER_UID))
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

    local save_data = json.decode(content)
    if not save_data then return false end

    -- 1. Стерильно очищаем оперативку RAM перед накатом новой вселенной
    game_state.clear_all()

    -- 2. Реанимируем в RAM динамические чанки мира и юнитов через restore_all
    -- Твой РОДНОЙ метод restore_all() внутри units_state АВТОМАТИЧЕСКИ
    -- создаст live_inventory, выкачает предметы по твоему старому канону и положит в ОЗУ!
    game_state.restore_all(save_data.world)

    -- Восстанавливаем токен сессии, за кого играли
    character_data.PLAYER_UID = save_data.player_uid or "player"

    -- 3. Намертво привязываем кэшированный мост-ссылку character_data.player в ОЗУ
    character_data.bind_to_units_registry()

    -- 4. Достаем живую Душу игрока из реестра RAM стейта
    local player_unit = game_state.get_entity_by_uid(character_data.PLAYER_UID)
    if not player_unit then
        print("🚨 Critical Error БЭКЕНД: Игрок не найден в реестре после работы restore_all!")
        return false
    end

    -- =========================================================================
    -- 📐 ФАЗА 3: ВОССТАНОВЛЕНИЕ СИ-ВЕКТОРОВ И ПЕРЕЗАПУСК КОЛЛЕКЦИИ (ИСПРАВЛЕНО):
    -- =========================================================================
    -- Вытаскиваем координаты, которые restore_all прочитал из JSON как таблицу
    local saved_position = player_unit.saved_position

    -- 🚀 ТИТАНОВЫЙ ФИКС ПEРЦEПЦИИ: 
    -- Принудительно переводим плоские JSON-координаты игрока в честный Си-вектор vmath.vector3!
    -- Теперь perception_manager.lua на строке 69 шёлково выполнит вычитание векторов без крэша!
    local base_x = saved_position and saved_position.x or 1126
    local base_y = saved_position and saved_position.y or 725
    local base_z = saved_position and saved_position.z or 1.0

    local live_vector_position = vmath.vector3(base_x, base_y, base_z)

    -- Запекаем честный Си-вектор обратно в паспорт игрока в ОЗУ!
    player_unit.saved_position = live_vector_position
    if character_data.player then
        character_data.player.saved_position = live_vector_position
    end

    -- Передаем Си-вектор в движковый прокси-лоадер Defold для стриминга сцены
    msg.post("main:/loader#script", "reload_game", {
        is_load = true,
        saved_position = live_vector_position,
        action_bars = player_unit.action_bars
    })

    -- Реактивно пинаем интерфейс бродкастами
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    broadcast.send("action_bar_events", { message_id = hash("action_bars_changed") })
    broadcast.send("ui_events", { message_id = hash("clear_world_ui") })

    print(string.format("💾 БЭКЕНД [SaveManager]: Сейв персонажа [%s] успешно развернут. Векторы восстановлены!", character_data.PLAYER_UID))
    return true
end



-- ---Засейвить игру на жесткий диск ПК (JSON-монолит)
-- ---@return boolean
-- function M.save_game()
--     local player_unit = game_state.get_entity_by_uid(character_data.PLAYER_UID)
--     if not player_unit then return false end
--
--     local player_position = player_unit.saved_position
--     local serializable_position = { x = player_position.x, y = player_position.y, z = player_position.z or 0 }
--
--     -- 🦾 1. СБОРКА ТИТАНОВОГО ПОЛИМОРФНОГО ПАКЕТА ПЕРСОНАЖА:
--     local character_payload = {
--         level = player_unit.level,
--         experience = player_unit.experience,
--         health = player_unit.health,
--         mana = player_unit.mana, -- Сохраняем ману/ресурс, если они есть
--         saved_position = serializable_position,
--         action_bars = player_unit.action_bars,
--
--         -- Объектные методы сохранения сумок и куклы шмота
--         inventory = player_unit.inventory and player_unit.inventory:get_save_data() or {},
--         paperdoll = player_unit.paperdoll and player_unit.paperdoll:get_save_data() or {}
--     }
--
--     -- 🦾 2. ДИНАМИЧЕСКИЙ СБОР КОРНЯ JSON (Канон WoW / BG3):
--     local data = {
--         version = 1,
--         time = os.time(),
--
--         -- СТЕРТО НАФИГ СЛЕПОЕ ЗАПЕКАНИЕ КЛЮЧА player = { ... }!
--         -- Мы динамически вшиваем мешок данных персонажа под его ИСТИННЫМ UID сессии!
--         -- Если мы играем за Артаса, в файле создастся ключ "Arthas": { ... }!
--         [character_data.PLAYER_UID] = character_payload,
--         -- Сбор динамической вселенной Meadows (монстры, сундуки, трава чанков)
--         world = game_state.get_full_save_data()
--     }
--
--     local file = io.open(SAVE_PATH, "w+")
--     if file then
--         -- Наш prepare_for_json сжирает матрешку мира за 1 Си-такт, убирая owner ссылки
--         local success, json_string = pcall(json.encode, prepare_for_json(data))
--         if not success then
--             print("🚨 БЭКЕНД [Save Error]: Критическая ошибка сериализации! В данных остался userdata/hash!")
--             file:close()
--             return false
--         end
--
--         file:write(json_string)
--         file:close()
--         print(string.format("💾 БЭКЕНД [SaveManager]: Сейв персонажа [%s] успешно записан на диск ПК (JSON-монолит)", character_data.PLAYER_UID))
--         return true
--     end
--     return false
-- end

-- ---Загрузить игру из файла сохранения JSON
-- ---@return boolean
-- function M.load_game()
--     local file = io.open(SAVE_PATH, "r")
--     if not file then return false end
--
--     local content = file:read("*all")
--     file:close()
--
--     local data = json.decode(content)
--     if not data then return false end
--
--     -- 1. Сначала реанимируем в RAM динамические чанки мира
--     game_state.restore_all(data.world)
--
--     -- =========================================================================
--     -- 🦾 ФАЗА 1: ОДУШЕВЛЕНИЕ И ЗАПЕКАНИЕ МОСТА (ПЕРЕНЕСЕНО НАМЕРТВО НАВЕРХ):
--     -- =========================================================================
--     -- Вызываем принудительный биндинг! Теперь в RAM гарантированно создана ячейка 
--     -- мага, и character_data.player пуленепробиваемо держит прямую ссылку на неё!
--     character_data.bind_to_units_registry()
--
--     -- Вытаскиваем зрячий RAM-паспорт нашего героя из Фасада вселенной по токену сессии!
--     local player_unit = game_state.get_entity_by_uid(character_data.PLAYER_UID)
--
--     -- 🚀 ПОЛИМОРФНЫЙ ВЫКАЧ PAYLOAD ИЗ JSON-ФАЙЛА:
--     -- Нам глубоко насрать на хардкод поля data.player. Мы читаем блок данных 
--     -- персонажа динамически по его токену сессии (character_data.PLAYER_UID)!
--     local saved_character_payload = data and (data[character_data.PLAYER_UID] or data.player)
--
--     -- =========================================================================
--     -- 🧱 ФАЗА 2: НАКАТКА ПРОГРЕССА СЕЙВА В ОПЕРАТИВНУЮ ПАМЯТЬ RAM:
--     -- =========================================================================
--     if player_unit and saved_character_payload then
--         -- Накатываем сохраненные инстансы куклы шмота и сумок через объектные методы
--         if saved_character_payload.inventory and player_unit.inventory then
--             player_unit.inventory:load_save_data(saved_character_payload.inventory)
--         end
--         if saved_character_payload.paperdoll and player_unit.paperdoll then
--             player_unit.paperdoll:load_save_data(saved_character_payload.paperdoll)
--         end
--
--         -- Реанимируем кастомные панели заклинаний, левел, ХП и ману из файла
--         player_unit.action_bars = saved_character_payload.action_bars or player_unit.action_bars
--         player_unit.experience = saved_character_payload.experience or 0
--         player_unit.level = saved_character_payload.level or 1
--         player_unit.health = saved_character_payload.health or player_unit.max_health
--
--         if player_unit.mana and saved_character_payload.mana then
--             player_unit.mana = saved_character_payload.mana
--         end
--
--         -- Выкачиваем позицию из сейва. Если её нет — берем текущую
--         if saved_character_payload.saved_position then
--             player_unit.saved_position = saved_character_payload.saved_position
--         end
--     else
--         print("🚨 БЭКЕНД [Load Error]: Не удалось состыковать паспорт в RAM с payloads файла JSON!")
--     end
--
--     -- =========================================================================
--     -- 📐 ФАЗА 3: ВОССТАНОВЛЕНИЕ СИ-ВЕКТОРОВ И ПЕРЕЗАПУСК КОЛЛЕКЦИИ:
--     -- =========================================================================
--     -- Читаем координаты наносекундно по прямой кэшированной ссылке-мосту!
--     local saved_position = character_data.player and character_data.player.saved_position
--
--     local base_x = saved_position and saved_position.x or 1126 -- Каноничный дефолт новой игры
--     local base_y = saved_position and saved_position.y or 725
--     local base_z = saved_position and saved_position.z or 1.0
--
--     local live_vector_position = vmath.vector3(base_x, base_y, base_z)
--     character_data.player.saved_position = live_vector_position
--
--     -- Передаем Си-вектор в движковый прокси-лоадер Defold для стриминга сцены
--     msg.post("main:/loader#script", "reload_game", {
--         is_load = true,
--         saved_position = live_vector_position,
--         action_bars = character_data.player.action_bars
--     })
--
--     broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
--     broadcast.send("ui_events", { message_id = hash("clear_world_ui") })
--
--     print(string.format("💾 БЭКЕНД [SaveManager]: Сейв персонажа [%s] успешно развернут. Векторы восстановлены!", character_data.PLAYER_UID))
--     return true
-- end

return M
