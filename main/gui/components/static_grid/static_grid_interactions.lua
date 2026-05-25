local interaction = require("main.modules.interaction")
local drag_manager = require("main.gui.components.managers.drag_manager")
local items_db = require("main.modules.data.items_db")
local M = {}

function M.setup(self)
    for i, slot in ipairs(self.slots) do
        -- Регистрируем стандартную Друид-кнопку (она поймает только ЛКМ)
        self.druid:new_button(slot.root, function(ctx, action_id, action)
            M.handle_slot_click(self, i, action_id, action)
        end)

        -- Регистрируем Драг
        local d = self.druid:new_drag(slot.root)
        d.on_drag_start:subscribe(function() M.on_item_drag_start(self, i) end)
    end
end

-- -- Этот метод вызывается ТОЛЬКО Друидом (для ЛКМ)
-- function M.handle_slot_click(self, index, action_id, action)
--     -- Мы ловим сплиттер (Shift + ЛКМ)
--     local is_shift = _G.HUD and _G.HUD.is_shift_pressed
--     if is_shift then
--         self:on_slot_click(index)
--         return true
--     end
--     
--     -- Тут может быть логика "Использовать предмет" на обычный клик
-- end
--
-- function M.handle_right_click(self, index, x, y)
--     local item_data = self:get_data_source():get_item(index)
--     
--     if not item_data or not item_data.item_id then 
--         print("RIGHT CLICK: Slot is empty")
--         return 
--     end
--
--     local item_cfg = items_db.get_item(item_data.item_id)
--     
--     -- Проверяем, можно ли разделить этот конкретный стак
--     local can_split = item_data.amount and item_data.amount >= 2
--     
--     msg.post("main:/context_menu_layer#gui", "show_menu", {
--         x = x, y = y,
--         type = "item",
--         sub_type = item_cfg.type,
--         flags = {
--             can_split = can_split, -- Передаем флаг в меню
--         },
--         data = { 
--             slot_index = index,
--             item_id = item_data.item_id,
--             source_url = msg.url()
--         }
--     })
-- end

function M.handle_slot_click(self, index, action_id, action)
    -- 1. Сначала проверяем Shift (Сплит)
    local is_shift = self.is_shift_pressed -- Берем из самого компонента
    if is_shift then
        self:on_slot_click(index)
        return true
    end

    --если зелье то можно бы выпить по даблклику

    -- 2. Логика ДАБЛКЛИКА через универсальный модуль
    -- Мы передаем уникальный ID (комбинация шаблона и индекса), 
    -- чтобы даблклик в одном окне не конфликтовал с другим.
    local click_id = self.template_id .. "_" .. index

    if interaction.is_double_click(click_id) then
        M.handle_double_click(self, index)
        return true
    end

    -- 3. Обычный клик (выделение и т.д.)
    return false
end


function M.handle_double_click(self, index)
    local ds = self:get_data_source()
    local item = ds:get_item(index)
    if not item or not item.item_id then return end

    -- Если нам дали инструкцию при создании — выполняем её
    if self.on_double_click_handler then
        self.on_double_click_handler(index, item)
    else
        print("GRID: No double-click handler defined for this grid")
    end
end

function M.handle_right_click(self, index, x, y)
    local item_data = self:get_data_source():get_item(index)

    if not item_data or not item_data.item_id then
        print("RIGHT CLICK: Slot is empty")
        return
    end

    local item_cfg = items_db.get_item(item_data.item_id)

    -- Проверяем, можно ли разделить этот конкретный стак
    local can_split = item_data.amount and item_data.amount >= 2

    msg.post("main:/context_menu_layer#gui", "show_menu", {
        x = x, y = y,
        type = "item",
        sub_type = item_cfg.type,
        flags = {
            can_split = can_split, -- Передаем флаг в меню
        },
        data = {
            slot_index = index,
            item_id = item_data.item_id,
            source_url = msg.url()
        }
    })
end




-- function M.handle_slot_input(self, index, action_id, action)
--     local item_data = self:get_data_source():get_item(index)
--     if not item_data or not item_data.item_id then return end
--
--     if action.released then
--         -- Читаем статус прямо из HUD
--         local is_shift = _G.HUD and _G.HUD.is_shift_pressed
--         
--         if is_shift then
--             print("SPLIT: Shift detected via HUD")
--             self:on_slot_click(index)
--             return true
--         end
--
--         -- 2. ПКМ (Контекстное меню)
--         if action.button_id == 2 then
--             msg.post("main:/context_menu_layer#gui", "show_menu", {
--                 x = action.x, y = action.y, type = "item",
--                 data = { slot_index = index, source = self, item_id = item_data.item_id }
--             })
--             return true
--         end
--     end
-- end

function M.on_item_drag_start(self, index)
    local item_data = self:get_data_source():get_item(index)
    if item_data and item_data.item_id then
        local cfg = items_db.get_item(item_data.item_id)
        drag_manager.start(self, index, item_data, cfg)
        -- Скрываем иконку на время драга
        gui.set_enabled(self.slots[index].icon, false)
        gui.set_enabled(self.slots[index].amount, false)
    end
end

return M



