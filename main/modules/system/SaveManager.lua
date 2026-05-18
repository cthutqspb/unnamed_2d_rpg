local settings = require("main.modules.data.settings")
local broadcast = require("main.modules.system.broadcast")
local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local character_data = require("main.modules.character.character_data")
local world_items_state = require("main.modules.game_state.world_items_state")
local containers_state = require("main.modules.game_state.containers_state")
local character_logic = require("main.modules.character.character_logic")

local M = {}

local SAVE_FILE = "save_01.dat"
-- Вместо get_save_config
local SAVE_PATH = sys.get_save_file("MyAwesomeRPG", "save_01.dat")

-- ПРОВЕРКА: есть ли сейв вообще? (Для кнопки Continue)
function M.exists()
    local file = io.open(SAVE_PATH, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

function M.new_game()
    -- 1. Полностью очищаем все модули данных (чистим старый прогресс)
    player_inventory.clear()
    player_paperdoll.clear()
    containers_state.clear()
    world_items_state.clear()
    
    -- 2. ВОТ ЗДЕСЬ выдаем начальные предметы в чистый инвентарь
    player_inventory.init() -- заполняем ячейки пустышками
    player_inventory.add_item("iron_sword", 1)
    player_inventory.add_item("lesser_mana_potion", 10)
    player_inventory.add_item("leather_helmet", 1)

    -- 3. Сбрасываем статы персонажа на дефолтные значения (1 уровень, полное ХП)
    character_data.player.level = 1
    character_data.player.experience = 0
    character_data.player.health = 100
    
    -- 4. Телепортируем игрока в начальную точку мира
    local start_pos = vmath.vector3(500, 500, 1)
    msg.post("/player", "teleport_to", { position = start_pos })

    -- 5. Принудительно пересчитываем статы (чтобы шлем сразу дал прибавку)
    character_logic.update_derived_stats()

    -- 6. Сразу ЖЕ сохраняем этот чистый старт на диск, перезаписывая старый сейв!
    M.save_game()

    -- 7. Сообщаем интерфейсу, что мир готов и нужно обновить картинки
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
end

-- function M.new_game()
--     player_inventory.clear()
--     player_paperdoll.clear()
--     containers_state.clear()
--     world_items_state.clear()
--
--     player_inventory.init() -- заполняем ячейки пустышками
--     player_inventory.add_item("iron_sword", 1)
--     player_inventory.add_item("lesser_mana_potion", 10)
--     player_inventory.add_item("leather_helmet", 1)
--
--     character_data.player.level = 1
--     character_data.player.experience = 0
--     character_data.player.health = 100
--
--     -- Ставим игрока в стартовую позицию
--     local center_x, center_y = settings.get_center()
--     -- local start_pos = vmath.vector3(center_x, center_y, 1.0)
--     local start_pos = vmath.vector3(500, 500, 1)
--     msg.post("/player", "teleport_to", { position = start_pos})
--     M.save_game()
--     broadcast.send("inventory_events", { message_id = hash("refresh_all")})
-- end


-- СОХРАНЕНИЕ
function M.save_game()
    local player_data = character_data.player

    local data = {
        version = 1,
        time = os.time(),
        inventory = player_inventory.get_save_data(),
        paperdoll = player_paperdoll.get_save_data(),
        player = {
            level = character_data.player.level,
            experience = character_data.player.experience,
            health = character_data.player.health,
            max_health = character_data.player.max_health,
            last_pos = player_data.last_pos
        },
        world = {
            containers_state = containers_state.get_all(),
            world_items_state = world_items_state.get_all()
        }
    }

    local ok = sys.save(SAVE_PATH, data)
    print(ok and "SUCCESS: Game Saved" or "ERROR: Save Failed")
    return ok
end

-- ЗАГРУЗКА
function M.load_game()
    local data = sys.load(SAVE_PATH)
    if not next(data) then return false end

    -- 1. СНАЧАЛА восстанавливаем все сырые данные и шмотки из файла
    player_inventory.load_save_data(data.inventory)
    player_paperdoll.load_save_data(data.paperdoll)
    containers_state.restore_all(data.world.containers_state)
    world_items_state.restore_all(data.world.world_items_state)

    -- 2. Накатываем базовый прогресс игрока из сейва
    character_data.player.level = data.player.level
    character_data.player.experience = data.player.experience
    
    -- ВАЖНО: ХП берем пока просто как число, максимумы пересчитаем ниже
    character_data.player.health = data.player.health
    -- character_data.player.max_health = data.player.max_health


    -- 3. Телепортируем игрока в сохраненную точку
    local p = data.player.last_pos
    msg.post("/player", "teleport_to", { position = vmath.vector3(p.x, p.y, 1) })
    msg.post("/world#world", "spawn_all_saved_items")

    -- 4. ТЕПЕРЬ запускаем пересчет статов. 
    -- Он увидит загруженные шмотки, посчитает правильный max_health 
    -- и САМ отправит правильный msg.post("/gui_manager#hud", "update_health") в HUD!
    character_logic.update_derived_stats()

    -- 5. Дублируем обновление для всех остальных окон интерфейса через бродкаст
    broadcast.send("inventory_events", { message_id = hash("refresh_all") })
    
    print('Game loaded successfully with proper stats recalculation')
    return true
end

return M


-- local broadcast = require("main.modules.system.broadcast")
--
-- local M = {}
--
-- -- Путь к файлу (Defold сам найдет нужную папку в системе)
-- local SAVE_PATH = sys.get_save_config("my_game", "save.dat")
--
-- function M.save()
--     local data = {
--         version = 1, -- Чтобы старые сейвы не ломали игру при обновлениях
--         inventory = require("main.modules.player.player_inventory").get_save_data(),
--         paperdoll = require("main.modules.player.player_paperdoll").get_save_data(),
--         stats = require("main.modules.character.character_data").player,
--         world = {
--             containers = require("main.modules.game_state.containers_state").get_all()
--         }
--     }
--
--     -- Добавляем позицию игрока
--     local p_pos = go.get_position("/player")
--     data.player_pos = { x = p_pos.x, y = p_pos.y }
--
--     local ok = sys.save(SAVE_PATH, data)
--     if ok then print("Игра сохранена!") end
-- end
--
-- function M.load()
--     local data = sys.load(SAVE_PATH)
--     if not next(data) then
--         print("Файл сохранения не найден или пуст")
--         return false
--     end
--
--     -- Раскладываем данные обратно
--     require("main.modules.player.player_inventory").load_save_data(data.inventory)
--     require("main.modules.player.player_paperdoll").load_save_data(data.paperdoll)
--     require("main.modules.game_state.containers_state").restore_all(data.world.containers)
--
--     -- ... и так далее для всех модулей
--
--     -- Ставим игрока на место
--     go.set_position(vmath.vector3(data.player_pos.x, data.player_pos.y, 0), "/player")
--
--     -- Кричим всем GUI: "Обновитесь!"
--     broadcast.send("inventory_events", { message_id = hash("refresh_all") })
--
--     return true
-- end
--
-- return M
--
