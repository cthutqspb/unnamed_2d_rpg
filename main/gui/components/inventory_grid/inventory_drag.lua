local gui_utils = require("main.gui.gui_utils")
local items_db = require("main.modules.data.items_db")
local drag_manager = require("main.gui.components.managers.drag_manager")

local M = {}

-- Кэшируем пустые хеши и константы путей
local HASH_EMPTY = hash("")
local WORLD_DRAG_END = hash("drag_end")
local SPLIT_WINDOW_URL = "main:/split_window#gui"

function M.init(self)
    self.dragging_index = nil
end

function M.create_slots(self)
    self.slots = {}
    -- Подготавливаем базовые пути один раз
    local base_path = self.template_id .. "/slot_prefab"
    local prefab_root = gui.get_node(base_path .. "/root")
    
    local path_root  = hash(base_path .. "/root")
    local path_icon  = hash(base_path .. "/icon")
    local path_count = hash(base_path .. "/count")

    local druid_inst = self:get_druid()

    for i = 1, self.columns * self.rows do
        local nodes = gui.clone_tree(prefab_root)
        local slot_root  = nodes[path_root]
        local slot_icon  = nodes[path_icon]
        local slot_count = nodes[path_count]

        if slot_root then
            gui.set_enabled(slot_root, true)
            gui.set_parent(slot_root, self.container)

            -- Сбрасываем Z, чтобы слоты не перекрывали друг друга некорректно
            local p = gui.get_position(slot_root)
            p.z = 0
            gui.set_position(slot_root, p)

            self.grid:add(slot_root)

            -- Настройка инпута через Druid
            local btn = druid_inst:new_button(slot_root, function() M.on_slot_click(self, i) end)
            local drag = druid_inst:new_drag(slot_root)

            drag.is_touch_threshold = false
            btn.click_zone = slot_root

            drag.on_drag_start:subscribe(function()
                if self.is_shift_pressed then
                    drag.is_drag = false
                    M.on_slot_click(self, i)
                else
                    M.on_item_drag_start(self, i)
                end
            end)

            drag.on_drag_end:subscribe(function()
                M.on_item_drag_end(self, i)
            end)

            table.insert(self.slots, {
                root   = slot_root,
                icon   = slot_icon,
                count  = slot_count,
                button = btn,
                drag   = drag
            })

            gui.set_enabled(slot_icon, false)
            gui.set_enabled(slot_count, false)
        end
    end
end

-- Универсальная проверка: жива ли нода и активна ли сцена
local function is_node_valid(self)
    return self.root and gui.is_enabled(self.root, true)
end

function M.on_input(self, action_id, action)
    if action and action.x and action.y then
        self.mouse_x = action.x
        self.mouse_y = action.y
    end
end

function M.update_slot_visual(self, slot_index, item_id, amount)
    if not is_node_valid(self) then return end

    local slot = self.slots[slot_index]
    if not slot then return end

    local data = items_db.get_item(item_id)
    if data then
        gui.set_enabled(slot.icon, true)
        gui.set_color(slot.icon, data.color)
        if data.texture then gui.set_texture(slot.icon, data.texture) end
        gui.play_flipbook(slot.icon, hash(data.animation))

        local is_stack = amount and amount > 1
        gui.set_enabled(slot.count, is_stack)
        if is_stack then
            gui.set_text(slot.count, tostring(amount))
        end
    end
end

function M.on_item_drag_start(self, index)
    local item_data = self:get_data_source().items[index]
    if not item_data or not item_data.item_id then return end

    local data = items_db.get_item(item_data.item_id)
    drag_manager.start(self, index, item_data, data)

    local slot = self.slots[index]
    gui.set_enabled(slot.icon, false)
    gui.set_enabled(slot.count, false)
end

function M.on_item_drag_end(self, _)
    msg.post("world", WORLD_DRAG_END)
    self.dragging_index = nil
end

function M.clear_slot_visual(self, slot_index)
    if not is_node_valid(self) then return end
    
    local slot = self.slots[slot_index]
    if slot then
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.count, false)
    end
end

function M.on_slot_click(self, index)
    local item_data = self:get_data_source().items[index]
    
    if self.is_shift_pressed and item_data and item_data.item_id and item_data.amount > 1 then
        msg.post(SPLIT_WINDOW_URL, "open_split_window", {
            item_data = item_data,
            slot_index = index
        })
    end
end

function M.get_slot_at_position(self, screen_x, screen_y)
    local cx, cy = gui_utils.get_screen_position(self.container)
    local lx, ly = screen_x - cx, screen_y - cy
    
    -- Кэшируем размер один раз, предполагая, что все слоты одинаковые
    local first_slot = self.slots[1]
    if not first_slot then return nil end
    local slot_size = gui.get_size(first_slot.root)
    local half_w, half_h = slot_size.x / 2, slot_size.y / 2
    
    for i, slot in ipairs(self.slots) do
        local p = gui.get_position(slot.root)
        if lx >= p.x - half_w and lx <= p.x + half_w and 
           ly >= p.y - half_h and ly <= p.y + half_h then
            return i
        end
    end
    return nil
end

return M


-- local gui_utils = require("main.gui.gui_utils")
-- local items_db = require("main.modules.data.items_db")
-- local drag_manager = require("main.gui.components.managers.drag_manager")
--
-- local M = {}
--
-- function M.init(self)
--     self.dragging_index = nil
-- end
--
-- function M.create_slots(self)
--     self.slots = {}
--     local prefab_path = self.template_id .. "/slot_prefab/root"
--
--     for i = 1, self.columns * self.rows do
--         local nodes = gui.clone_tree(gui.get_node(prefab_path))
--
--         local root_id  = hash(self.template_id .. "/slot_prefab/root")
--         local icon_id  = hash(self.template_id .. "/slot_prefab/icon")
--         local count_id = hash(self.template_id .. "/slot_prefab/count")
--
--         local slot_root  = nodes[root_id]
--         local slot_icon  = nodes[icon_id]
--         local slot_count = nodes[count_id]
--
--         if slot_root then
--             gui.set_enabled(slot_root, true)
--             gui.set_parent(slot_root, self.container)
--
--             local p = gui.get_position(slot_root)
--             p.z = 0
--             gui.set_position(slot_root, p)
--
--             self.grid:add(slot_root)
--
--             local d = self:get_druid()
--             local btn = d:new_button(slot_root, function() M.on_slot_click(self, i) end)
--
--             local drag = d:new_drag(slot_root, function(ctx, dx, dy) end)
--
--             drag.is_touch_threshold = false
--             btn.click_zone = slot_root
--
--             if drag.set_input_priority then
--                 drag:set_input_priority(100)
--             end
--
--             drag.on_drag_start:subscribe(function()
--                 -- НАШ ФИКС: Если в сетке инвентаря зажат Shift, отменяем драг и переключаемся на логику клика
--                 if self.is_shift_pressed then
--                     -- Принудительно гасим внутреннее состояние драга в Druid, чтобы он не думал, что мы что-то тащим
--                     drag.is_drag = false
--                     -- Вызываем обычный клик по слоту, который и откроет наше окно сплиттера
--                     M.on_slot_click(self, i)
--                     return
--                 end
--
--                 -- Старая логика обычного переноса
--                 M.on_item_drag_start(self, i)
--             end)
--
--             drag.on_drag_end:subscribe(function()
--                 M.on_item_drag_end(self, i)
--             end)
--
--             table.insert(self.slots, {
--                 root  = slot_root,
--                 icon  = nodes[icon_id],
--                 count = nodes[count_id],
--                 button = btn,
--                 drag = drag
--             })
--
--             gui.set_enabled(slot_icon, false)
--             gui.set_enabled(slot_count, false)
--         end
--     end
-- end
--
-- function M.update_slot_visual(self, slot_index, item_id, amount)
--     -- ЗАЩИТА КОНТЕКСТА: Если корневая нода сетки или сам корневой элемент выключен,
--     -- значит окно закрыто и мы в другой сцене. Трогать ноды нельзя!
--     if not self.root or not gui.is_enabled(self.root, true) then
--         return
--     end
--
--     local slot = self.slots[slot_index]
--     if not slot then return end
--
--     local data = items_db.get_item(item_id)
--     if data then
--         gui.set_enabled(slot.icon, true)
--         gui.set_color(slot.icon, data.color)
--         if data.texture then gui.set_texture(slot.icon, data.texture) end
--         gui.play_flipbook(slot.icon, hash(data.animation))
--
--         if amount and amount > 1 then
--             gui.set_enabled(slot.count, true)
--             gui.set_text(slot.count, tostring(amount))
--         else
--             gui.set_enabled(slot.count, false)
--         end
--     end
-- end
--
-- function M.on_input(self, action_id, action)
--     if action and action.x and action.y then
--         self.mouse_x = action.x
--         self.mouse_y = action.y
--     end
-- end
--
-- function M.on_item_drag_start(self, index)
--     -- 1. Получаем данные предмета
--     local item_data = self:get_data_source().items[index]
--     if not item_data or not item_data.item_id then return end
--
--     local data = items_db.get_item(item_data.item_id)
--
--     -- 2. Просто уведомляем менеджер, ЧТО мы тащим
--     -- Нам не нужно создавать ноды, менеджер скажет drag_layer.gui, что отрисовать
--     drag_manager.start(self, index, item_data, data)
--
--     -- 3. Скрываем оригинал в слоте
--     gui.set_enabled(self.slots[index].icon, false)
--     gui.set_enabled(self.slots[index].count, false)
--
--     -- НИКАКИХ gui.clone_tree, gui.set_parent и gui.set_render_order здесь больше не нужно!
-- end
--
-- function M.on_item_drag_end(self, index)
--     msg.post("world", "drag_end")
--     self.dragging_index = nil
--     -- Драг завершится в hud.gui_script
-- end
--
-- -- ОЧИСТИТЬ ВИЗУАЛ СЛОТА
-- function M.clear_slot_visual(self, slot_index)
--     -- ЗАЩИТА КОНТЕКСТА: Если корневая нода сетки или сам корневой элемент выключен,
--     -- значит окно закрыто и мы в другой сцене. Трогать ноды нельзя!
--     if not self.root or not gui.is_enabled(self.root, true) then
--         return
--     end
--
--     local slot = self.slots[slot_index]
--     if slot then
--         gui.set_enabled(slot.icon, false)
--         gui.set_enabled(slot.count, false)
--     end
-- end
--
-- function M.on_slot_click(self, index)
--     local data_source = self:get_data_source()
--     local item_data = data_source.items[index]
--      if self.is_shift_pressed and item_data and item_data.item_id and item_data.amount > 1 then
--         print("INVENTORY: Requesting split window for slot", index)
--
--         msg.post("main:/split_window#gui", "open_split_window", {
--             item_data = item_data,
--             slot_index = index
--             -- position больше НЕ передаем, окно само встанет в центр экрана
--         })
--         return
--     end
-- end
--
-- function M.get_slot_at_position(self, screen_x, screen_y)
--     
--     local container_screen_x, container_screen_y = gui_utils.get_screen_position(self.container)
--     
--     local local_x = screen_x - container_screen_x
--     local local_y = screen_y - container_screen_y
--     
--     for i, slot in ipairs(self.slots) do
--         local slot_pos = gui.get_position(slot.root)
--         local slot_size = gui.get_size(slot.root)
--         
--         local left = slot_pos.x - slot_size.x/2
--         local right = slot_pos.x + slot_size.x/2
--         local bottom = slot_pos.y - slot_size.y/2
--         local top = slot_pos.y + slot_size.y/2
--         
--         
--         if local_x >= left and local_x <= right and local_y >= bottom and local_y <= top then
--             print("HIT slot", i)
--             return i
--         end
--     end
--     
--     return nil
-- end
--
-- return M
