local window_manager = require("main.gui.components.managers.window_manager")

---@class InteractionModule
local M = {}

---@type number
local last_click_time = 2
---@type hash|nil
local last_click_id = nil
---@type vector3
local last_click_pos = vmath.vector3(0,0,0)

---@type number
local DOUBLE_CLICK_THRESHOLD = 0.3
---@type number
local MOVE_THRESHOLD = 5

-- 🚩 ФИКС ГРУПП: Полное согласование с архитектурой игрового мира
---@type hash[]
local GROUPS = {
    hash("container"),  -- Сундуки, бочки, трупы
    hash("item_loot"),  -- Вещи на земле
    hash("creature"),   -- Кабаны, росянки, NPC
    hash("interactable")        -- Двери, рычаги, разрушаемый декор
}

---@type number
local OFFSET = 10

---Обработать клик по интерактивному объекту в мире (проверка дистанции и добегание)
---@param self table Контекст скрипта объекта (сундука/лута)
---@param interaction_range number Дистанция взаимодействия в пикселях
---@param callback function Функция, которая выполнится, если игрок стоит вплотную
function M.handle_click(self, interaction_range, callback)
    -- 1. Если мышь над интерфейсом, клик в мир не проходит
    if window_manager.is_over_ui() then
        return
    end

    -- 🚩 ФИКС АДРЕСАЦИИ: Ищем игрока через относительный путь, без привязки к game_scene
    local player_pos = go.get_position("game_scene:/player")
    local my_pos = go.get_world_position()
    local dist = vmath.length(player_pos - my_pos)

    if dist < interaction_range then
        callback()
    else
        print("Too far:", dist)
        -- Передаем ID этой конкретной цели игроку, чтобы он включил бег к ней
        msg.post("game_scene:/player", "move_to_item", { item_id = go.get_id() })
    end
end

---Проверить, является ли клик по слоту или объекту двойным (Даблклик)
---@param id any Уникальный ID проверяемого элемента
---@param x number|nil Экранная координата X
---@param y number|nil Экранная координата Y
---@return boolean true если зафиксирован быстрый повторный клик в той же точке
function M.is_double_click(id, x, y)
    -- В Defold стандартный socket.gettime() отлично работает через pcall/sys, 
    -- но для надежности в скриптах можно использовать os.clock()
    local current_time = os.clock()
    local current_pos = vmath.vector3(x or 0, y or 0, 0)

    local dist = vmath.length(current_pos - last_click_pos)
    local success = false

    if id == last_click_id and (current_time - last_click_time) < DOUBLE_CLICK_THRESHOLD and dist < MOVE_THRESHOLD then
        success = true
        last_click_id = nil
    else
        last_click_id = id
        last_click_time = current_time
        last_click_pos = current_pos
    end

    return success
end

---Найти ОДИН ближайший объект под курсором мыши в мире (для клика)
---@param world_pos vector3 Мировые координаты курсора мыши
---@return hash|nil go_id Идентификатор Game Object или nil
function M.get_target_under_cursor(world_pos)
    local from1 = vmath.vector3(world_pos.x - OFFSET, world_pos.y + OFFSET, 10)
    local to1 = vmath.vector3(world_pos.x + OFFSET, world_pos.y - OFFSET, -10)

    local res = physics.raycast(from1, to1, GROUPS)

    if not res then
        local from2 = vmath.vector3(world_pos.x - OFFSET, world_pos.y - OFFSET, 10)
        local to2 = vmath.vector3(world_pos.x + OFFSET, world_pos.y + OFFSET, -10)
        res = physics.raycast(from2, to2, GROUPS)
    end

    return res and res.id or nil
end

---Получить список ВСЕХ объектов под курсором (для дифференциального тултипа слоёв)
---@param world_pos vector3 Мировые координаты курсора мыши
---@return table|nil Список попаданий рейкаста, отсортированный от камеры вглубь
function M.get_all_targets_under_cursor(world_pos)
    local from = vmath.vector3(world_pos.x - OFFSET, world_pos.y + OFFSET, 10)
    local to = vmath.vector3(world_pos.x + OFFSET, world_pos.y - OFFSET, -10)

    local results = physics.raycast(from, to, GROUPS, { all = true })

    if results and #results > 0 then
        table.sort(results, function(a, b)
            return a.fraction < b.fraction
        end)
        return results
    end

    return nil
end

---Очистить любой ID (строку или хэш движка Defold) от внутренних обёрток "hash: [item]"
---@param id any Произвольный идентификатор (хэш, строка или url)
---@return string|nil Чистая строка или nil, если аргумент пустой
function M.clean_id(id)
    if not id then return nil end
    local s = tostring(id)
    return s:match("%[(.+)%]") or s
end

return M


-- local window_manager = require("main.gui.components.managers.window_manager")
--
-- local M = {}
--
-- local last_click_time = 2
-- local last_click_id = nil
-- local last_click_pos = vmath.vector4(0)
-- local DOUBLE_CLICK_THRESHOLD = 1.3
-- local MOVE_THRESHOLD = 5 -- пикселей
--
-- -- Выносим константы, чтобы не "мусорить" в памяти каждый кадр
-- local GROUPS = { hash("container"), hash("item_loot"), hash("creature"), hash("interactable") }
-- local OFFSET = 10
--
-- function M.handle_click(self, interaction_range, callback)
--     -- 1. Если мышь над интерфейсом, клик в мир не должен проходить
--     if window_manager.is_over_ui() then
--         return
--     end
--
--     local player_pos = go.get_position("game_scene:/player")
--     local my_pos = go.get_world_position()
--     local dist = vmath.length(player_pos - my_pos)
--
--     if dist < interaction_range then
--         callback()
--     else
--         print("Too far:", dist)
--         -- Передаем только ID цели. Никаких функций!
--         msg.post("game_scene:/player", "move_to_item", { item_id = go.get_id() })
--     end
-- end
--
-- function M.is_double_click(id, x, y)
--     local current_time = socket.gettime()
--     local current_pos = vmath.vector3(x or 0, y or 0, 0)
--
--     -- Проверяем, не слишком ли далеко ушла мышь (если это драг)
--     local dist = vmath.length(current_pos - last_click_pos)
--
--     local success = false
--
--     if id == last_click_id and (current_time - last_click_time) < DOUBLE_CLICK_THRESHOLD and dist < MOVE_THRESHOLD then
--         success = true
--         last_click_id = nil
--     else
--         last_click_id = id
--         last_click_time = current_time
--         last_click_pos = current_pos
--     end
--
--     return success
-- end
--
-- -- function M.get_target_under_cursor(self)
-- --     -- Мы берем данные из твоего курсора (который в world.script или где он у тебя)
-- --     -- Если курсор сейчас ловит collision_response от объекта:
-- --     local hover_data = self.hovered_object -- Эту переменную должен обновлять курсор
-- --     
-- --     if hover_data then
-- --         -- Возвращаем тип (для БД меню) и ссылку на объект
-- --         return hover_data.type, hover_data.id
-- --     end
-- --     return nil
-- -- end
--
--
--
-- -- Для КЛИКА (берем один ID)
-- function M.get_target_under_cursor(world_pos)
--     local from1 = vmath.vector3(world_pos.x - OFFSET, world_pos.y + OFFSET, 10)
--     local to1 = vmath.vector3(world_pos.x + OFFSET, world_pos.y - OFFSET, -10)
--
--     local res = physics.raycast(from1, to1, GROUPS)
--
--     if not res then
--         local from2 = vmath.vector3(world_pos.x - OFFSET, world_pos.y - OFFSET, 10)
--         local to2 = vmath.vector3(world_pos.x + OFFSET, world_pos.y + OFFSET, -10)
--         res = physics.raycast(from2, to2, GROUPS)
--     end
--
--     return res and res.id or nil
-- end
--
-- ---Получить список ВСЕХ объектов под курсором (для дифференциального тултипа слоёв)
-- ---@param world_pos vector3 Мировые координаты курсора мыши
-- ---@return table|nil Список попаданий рейкаста, отсортированный от камеры вглубь
-- function M.get_all_targets_under_cursor(world_pos)
--     local from = vmath.vector3(world_pos.x - OFFSET, world_pos.y + OFFSET, 10)
--     local to = vmath.vector3(world_pos.x + OFFSET, world_pos.y - OFFSET, -10)
--
--     local results = physics.raycast(from, to, GROUPS, { all = true })
--
--     if results and #results > 0 then
--         table.sort(results, function(a, b)
--             return a.fraction < b.fraction
--         end)
--         return results
--     end
--
--     return nil
-- end
--
-- return M
