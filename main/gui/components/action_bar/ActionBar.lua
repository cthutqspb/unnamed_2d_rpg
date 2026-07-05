local component = require("druid.component")
local StaticGrid = require("main.gui.components.static_grid.StaticGrid")
local unit_logic = require("main.modules.unit.logic.unit_logic")
local units_state = require("main.modules.game_state.units_state")
local character_data = require("main.modules.character.character_data")

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
    self.bar_index = config and config.bar_index or 1

    self.static_grid = druid:new(StaticGrid, get_id(template_id, "static_grid"), {
        grid_type = "action_bar",
        bar_index = self.bar_index,
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

---🎯 РЕАКТИВНЫЙ WoW-ОБРАБОТЧИК: Синхронизация графики с Глобальным Реестром RAM
function M:refresh_bar()
    if not self.static_grid then return end

    -- 🧠 ЧИТАЕМ АКТУАЛЬНЫЙ СТEЙТ ИЗ ЦЕНТРАЛЬНОГО РЕЕСТРА (TargetFrame Канон):
    -- Вытаскиваем самый свежий паспорт мага из RAM по токену сессии
    local unit_state = units_state.get(character_data.PLAYER_UID)
    local action_bars = unit_state and unit_state.action_bars

    -- Нагло, принудительно всаживаем актуальную таблицу в data_source сетки прямо из RAM-реестра!
    -- Никакого кэширования старых ссылок, никакого слова LIVE, чистый Си-транзит!
    self.static_grid.data_source = action_bars and action_bars[self.bar_index] or {}

    -- Пинаем слепую сетку обновить пиксели на экране
    self.static_grid:refresh()
end

function M:refresh()
    self:refresh_bar()
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

---Покадрово перекрасить кнопки и бинды панели на основе живого контекста боя
---@param dt number Дельта времени кадра
---@param player UnitInstance|nil Живой RAM-паспорт мага
---@param target UnitInstance|nil Живой RAM-паспорт его текущей боевой жертвы
function M:update(dt, player, target)
    if not self.static_grid or not self.static_grid.slots then return end

    -- Готовим дефолтные векторы цветов
    local color_normal = vmath.vector4(1, 1, 1, 1)
    local color_dimmed = vmath.vector4(0.4, 0.4, 0.4, 1.0) -- Затемненная иконка
    local color_bind_normal = vmath.vector4(0.8, 0.8, 0.8, 1.0) -- Дефолтный бинд
    local color_bind_red = vmath.vector4(1.0, 0.1, 0.1, 1.0) -- Out of Range красный!

    for index = 1, #self.static_grid.slots do
        local slot_data = self.static_grid:get_slot_data(index)

        if slot_data and slot_data.action_id and slot_data.action_type == "ability" then
            -- 🦾 ДЁРГАЕМ ЦЕНТРАЛЬНОГО СУДЬЮ НАПРЯМУЮ ЧЕРЕЗ ПРИЛЕТЕВШИЕ ОБЪЕКТЫ (БЕЗ ПРОСЛОЕК):
            local is_possible, error_reason = unit_logic.check_cast_possibility(player, slot_data.action_id, target)

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
end

return M
