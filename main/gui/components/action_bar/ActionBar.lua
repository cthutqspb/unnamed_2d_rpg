local component = require("druid.component")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")

---@class ActionBar : druid.component
---@field template_id string
---@field static_grid StaticGrid
local M = component.create("ActionBar")

---@private
---@param template_id string
---@param node_name string
---@return string
local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

---@param index number
---@param slot_data table Таблица ячейки бэкенда {action_type, action_id}
local function send_player_action(index, slot_data)
    if not slot_data or not slot_data.action_id or not slot_data.action_type then return end

    print(string.format("🔮 БОЙ [ActionBar]: Активация слота №%d -> [%s: %s]",
        index, slot_data.action_type, slot_data.action_id))

    -- Шлем Си-команду напрямую в физическое тело игрока! [C]
    -- "." означает текущий игровой объект, где висит HUD, 
    -- оттуда сообщение легально долетит до player.script через менеджеры [C]
    msg.post(".", "player_action", {
        event = "action",
        data = {
            slot_index = index,
            action_type = slot_data.action_type, -- Наш вчерашний ААА-стандарт: "ability" или "item"
            action_id = slot_data.action_id      -- "melee_attack" / "frostbolt" / "lesser_mana_potion"
        }
    })
end

---@param template_id string
---@param config table
function M:init(template_id, config)
    self.template_id = template_id
    local druid = self:get_druid()

    self.static_grid = druid:new(StaticGrid, get_id(template_id, "static_grid"), {
        grid_type = "action_bar",
        bar_index = config.bar_index,
        columns = config.columns or 12,
        rows = config.rows or 1,
        item_size = config.item_size or 40,
        spacing = config.spacing or 2,
        on_click = function(index, item)
            -- item здесь — это то, что наш глупый StaticGrid достал из self:get_slot_data(index)
            send_player_action(index, item)
        end
    })
    -- gui.set_visible(self.static_grid)
end

-- ---@param index number Числовой индекс ячейки панели
-- function M:on_slot_click(index)
--     if not self.static_grid then return end
--
--     -- Вежливо просим наш глупый StaticGrid выдать сырые данные из памяти сорса
--     local slot_data = self.static_grid:get_slot_data(index)
--     -- Скармливаем данные в тот же самый Си-конвейер отправки месседжа!
--     send_player_action(index, slot_data)
-- end

---🎯 ИНПУТ КЛAВИAТУРЫ: Вызвать принудительное прожатие слота по хоткею 1..12 (Вариант А)
---@param index number Числовой индекс ячейки панели
function M:on_slot_click(index)
    if not self.static_grid then return end

    -- 1. Вежливо просим наш глупый StaticGrid выдать сырые данные из памяти сорса
    local slot_data = self.static_grid:get_slot_data(index)
    if not slot_data then return end

    -- 2. 🧱 ЗАПУСКАЕМ ДЕФОЛТНУЮ ВИЗУАЛЬНУЮ АНИМАЦИЮ СЖАТИЯ ДРУИДА:
    local slot = self.static_grid.slots[index]

    if slot and slot.button then
        -- Вытаскиваем функцию из таблицы стилей, которую выдал твой дамп памяти! [🔍]
        local style_fn = slot.button.style and slot.button.style.on_click

        if style_fn then
            -- Вызываем Си-анимацию сжатия Друида!
            -- Передаем: саму кнопку (как self) и ноду, которую нужно сжать (anim_node) [🔍]
            style_fn(slot.button, slot.button.anim_node)
        end
    end

    -- 3. ОТПРАВЛЯЕМ НАШЕ БОЕВОЕ ДЕЙСТВИЕ В МИР ЧЕРЕЗ РОДНОЙ КОНВЕЙЕР:
    send_player_action(index, slot_data)
end

function M:refresh()
    self.static_grid:refresh()
end

---@param x number
---@param y number
---@return number|nil
function M:get_slot_at_position(x, y)
    if self.static_grid then
        return self.static_grid:get_slot_at_position(x, y)
    end
end

return M
