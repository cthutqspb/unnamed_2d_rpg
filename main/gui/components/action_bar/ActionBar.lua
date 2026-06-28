local component = require("druid.component")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")
local abilities_db = require("main.modules.data.abilities_db")
local interaction_manager = require("main.modules.logic.interaction_manager")
local character_data = require("main.modules.character.character_data")
local game_state = require("main.modules.game_state.game_state")
local unit_logic = require("main.modules.unit.logic.unit_logic")

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
    msg.post("game_scene:/player", "player_action", {
        event = "action",
        data = {
            slot_index = index,
            action_type = slot_data.action_type, -- Наш вчерашний ААА-стандарт: "ability" или "item"
            action_id = slot_data.action_id,      -- "melee_attack" / "frostbolt" / "lesser_mana_potion"
            triggers_gcd = slot_data.triggers_gcd
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

---@param duration number Длительность ГКД (1.5 сек)
function M:trigger_gcd(duration)
    -- Панель сама зряче знает, что у нее внутри живет static_grid, 
    -- и делегирует ей эту команду через чистое двоеточие!
    if self.static_grid and self.static_grid.trigger_gcd then
        self.static_grid:trigger_gcd(duration)
    end
end

---@param x number
---@param y number
---@return number|nil
function M:get_slot_at_position(x, y)
    if self.static_grid then
        return self.static_grid:get_slot_at_position(x, y)
    end
end

function M:update(dt)
    if not self.static_grid or not self.static_grid.slots then return end
    -- 1. Забираем чистый Си-хэш текущего таргета мага из твоего interaction_manager
    local current_target_uid = interaction_manager.get_current_target_uid and interaction_manager.get_current_target_uid()
    local current_target_unit = game_state.get_entity_by_uid(current_target_uid)

    -- Готовим дефолтные векторы цветов
    local color_normal = vmath.vector4(1, 1, 1, 1)
    local color_dimmed = vmath.vector4(0.4, 0.4, 0.4, 1.0) -- Затемненная иконка
    local color_bind_normal = vmath.vector4(0.8, 0.8, 0.8, 1.0) -- Дефолтный бинд
    local color_bind_red = vmath.vector4(1.0, 0.1, 0.1, 1.0) -- Out of Range красный!

    for index = 1, #self.static_grid.slots do
        local slot_data = self.static_grid:get_slot_data(index)

        if slot_data and slot_data.action_id and slot_data.action_type == "ability" then
            -- 🦾 ДЁРГАЕМ ЦЕНТРАЛЬНОГО СУДЬЮ:
            local player = character_data.player
            local is_possible, error_reason = unit_logic.check_cast_possibility(player, slot_data.action_id, current_target_unit)

            local final_icon_color = color_normal
            local final_bind_color = color_bind_normal

            if not is_possible then
                if error_reason == "NO_TARGET" then
                    final_icon_color = color_dimmed -- Нет цели -> Темним иконку спелла
                elseif error_reason == "OUT_OF_RANGE" then
                    final_bind_color = color_bind_red -- Out of Range -> Краснеет бинд хоткея!
                end
            end

            -- Вежливо просим слепую сетку обновить цвета пикселей
            self.static_grid:set_slot_colors(index, final_icon_color, final_bind_color)
        end
    end

    -- -- 🦾 Покадрово пробегаемся по всем 12 ячейкам нашей слепой панели!
    -- for index = 1, #self.static_grid.slots do
    --     local slot_data = self.static_grid:get_slot_data(index)
    --
    --     if slot_data and slot_data.action_id and slot_data.action_type == "ability" then
    --         local cfg = abilities_db.get_ability(slot_data.action_id)
    --
    --         if cfg then
    --             local final_icon_color = color_normal
    --             local final_bind_color = color_bind_normal
    --
    --             if cfg.requires_target then
    --                 if not current_target_id then
    --                     -- КЕЙС А: Цели нет вообще -> Насильно ТЕМНИМ иконку в серый!
    --                     final_icon_color = color_dimmed
    --                 else
    --                     -- КЕЙС Б: Цель есть -> Считаем расстояние в мире
    --                     local target_unit = game_state.get_entity_by_uid(current_target_id)
    --                     local player = character_data.player
    --                     if target_unit and player then
    --                         local player_pos = player.saved_position
    --                         local target_pos = target_unit.saved_position
    --                         local dist = vmath.length(target_pos - player_pos)
    --
    --                         -- Если скелет убежал дальше range из базы (350 пикселей)
    --                         if dist > (cfg.range or 0) then
    --                             -- Иконка горит цветом, но БИНД СТАНОВИТСЯ КРАСНЫМ!
    --                             final_bind_color = color_bind_red
    --                         end
    --                     end
    --                 end
    --             end
    --
    --             -- 🚀 ВЕЖЛИВО ПИНАЕМ НАШУ ГЛУПУЮ СЕТКУ ОБНОВИТЬ ПИКСЕЛИ!
    --             -- Чистый проброс цветов без нарушения инкапсуляции!
    --             self.static_grid:set_slot_colors(index, final_icon_color, final_bind_color)
    --         end
    --     end
    -- end
end

return M
