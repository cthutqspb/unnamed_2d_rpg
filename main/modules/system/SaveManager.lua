local settings = require("main.modules.data.settings")
local broadcast = require("main.modules.system.broadcast")
local player_inventory = require("main.modules.player.player_inventory")
local player_paperdoll = require("main.modules.player.player_paperdoll")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")
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
    -- 1. Стираем данные в Lua-модулях
    game_state.clear_all()
    player_inventory.clear()
    player_paperdoll.clear()

    player_inventory.init() -- заполняем ячейки пустышками
    player_inventory.add_item("iron_sword", 1)
    player_inventory.add_item("lesser_mana_potion", 10)
    player_inventory.add_item("leather_helmet", 1)
    player_inventory.add_item("clown_hat", 1)
    player_inventory.add_item("crystal_sword", 1)

    -- 2. ГОВОРИМ ЛОАДЕРУ: Перезагрузи всю сцену
    msg.post("main:/loader#script", "reload_game")
    broadcast.send("inventory_events", { message_id = hash("inventory_changed")})
    -- Всё! При старте новой сцены все init() сработают на чистых данных
end


-- function M.new_game()
--     -- 1. Полностью очищаем все модули данных (чистим старый прогресс)
--     player_inventory.clear()
--     player_paperdoll.clear()
--
--     game_state.clear_all()
--
--     broadcast.send("world_events", { message_id = hash("re_register_entities") })
--
--     -- 2. ВОТ ЗДЕСЬ выдаем начальные предметы в чистый инвентарь
--     player_inventory.init() -- заполняем ячейки пустышками
--     player_inventory.add_item("iron_sword", 1)
--     player_inventory.add_item("lesser_mana_potion", 10)
--     player_inventory.add_item("leather_helmet", 1)
--     player_inventory.add_item("clown_hat", 1)
--     player_inventory.add_item("crystal_sword", 1)
--
--
--     -- 3. Сбрасываем статы персонажа на дефолтные значения (1 уровень, полное ХП)
--     character_data.player.level = 1
--     character_data.player.experience = 0
--     character_data.player.health = 100
--
--     -- 4. Телепортируем игрока в начальную точку мира
--     local start_pos = vmath.vector3(500, 500, 1)
--     msg.post("/player", "teleport_to", { position = start_pos })
--
--     -- 5. Принудительно пересчитываем статы (чтобы шлем сразу дал прибавку)
--     character_logic.update_derived_stats()
--
--     -- 6. Сразу ЖЕ сохраняем этот чистый старт на диск, перезаписывая старый сейв!
--     M.save_game()
--
--     -- 7. Сообщаем интерфейсу, что мир готов и нужно обновить картинки
--     broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
-- end

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


-- СОХРАНЕНИЕ\
function M.save_game()
    local data = {
        version = 1,
        time = os.time(),
        inventory = player_inventory.get_save_data(),
        paperdoll = player_paperdoll.get_save_data(),
        player = {
            level = character_data.player.level,
            experience = character_data.player.experience,
            health = character_data.player.health,
            last_pos = character_data.player.last_pos
        },
        world = game_state.get_full_save_data()
    }

    local path = sys.get_save_file("MyAwesomeRPG", "save_01.json")
    local file = io.open(path, "w+")
    if file then
--         print("!!! DEEP CHECK BEFORE SAVE !!!")
-- local check_data = game_state.get_full_save_data()
-- if check_data.world_items_state then
--     local count = 0
--     for _ in pairs(check_data.world_items_state) do count = count + 1 end
--     print("Items in world_items_state registry:", count)
-- end
        file:write(json.encode(data))
        file:close()
        print("SUCCESS: Game Saved (JSON)")
        return true
    end
    print("ERROR: Save Failed")
    return false
end

-- function M.save_game()
--     local player_data = character_data.player
--     local world_data = game_state.get_full_save_data()
--
--     local data = {
--         version = 1,
--         time = os.time(),
--         inventory = player_inventory.get_save_data(),
--         paperdoll = player_paperdoll.get_save_data(),
--         player = {
--             level = character_data.player.level,
--             experience = character_data.player.experience,
--             health = character_data.player.health,
--             max_health = character_data.player.max_health,
--             last_pos = player_data.last_pos
--         },
--         world = {
--             world = world_data
--         }
--     }
--
--     -- Замени sys.save на это:
-- local ok, err = pcall(function()
--     local path = sys.get_save_file("MyAwesomeRPG", "save_01.json")
--     local file = io.open(path, "w+")
--     file:write(json.encode(data))
--     file:close()
-- end)
-- print(ok and "SUCCESS: Game Saved" or "ERROR: Save Failed: " .. tostring(err))
--
--     return ok
-- end


function M.load_game()
    local path = sys.get_save_file("MyAwesomeRPG", "save_01.json")
    local file = io.open(path, "r")
    if not file then return false end

    local content = file:read("*all")
    file:close()
    
    local data = json.decode(content)
    if not data then return false end

    -- Дальше твоя обычная логика восстановления
    player_inventory.load_save_data(data.inventory)
    player_paperdoll.load_save_data(data.paperdoll)
    game_state.restore_all(data.world)
    
    -- character_data.player.last_pos = data.player.last_pos
    -- ...
    
    msg.post("main:/loader#script", "reload_game", { 
        is_load = true,
        last_pos = data.player.last_pos 
    })
    broadcast.send("inventory_events", { message_id = hash("inventory_changed") })
    return true
end

return M
