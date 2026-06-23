local locales = require("main.modules.data.locales.locale_manager")
local component = require("druid.component")
local HealthBar = require("main.gui.components.health_bar.HealthBar")
local ManaBar = require("main.gui.components.mana_bar.ManaBar")
local units_state = require("main.modules.game_state.units_state")

---@class TargetFrame : druid.component
---@field target_health_bar HealthBar Кастомный компонент полоски ХП
---@field target_mana_bar ManaBar Кастомный компонент полоски маны
---@field target_name node Текстовая нода имени монстра
---@field target_level node Текстовая нода уровня монстра
---@field root node
local M = component.create("TargetFrame")

local function get_id(template_id, node_name)
    if not template_id or template_id == "" then
        return node_name
    end
    return template_id .. "/" .. node_name
end

function M:init(template_id)
    self.druid = self:get_druid()
    -- Получаем узлы из GUI-шаблона
    self.target_health_bar = self.druid:new(HealthBar, get_id(template_id, "health_bar"))
    self.target_mana_bar = self.druid:new(ManaBar, get_id(template_id, "mana_bar"))
    self.target_name = gui.get_node("target_frame/target_name")
    self.target_level = gui.get_node("target_frame/target_level")
    self.root = gui.get_node("target_frame/root")
    gui.set_enabled(self.root, false)
end

---🎯 РЕАКТИВНЫЙ WoW-ОБРАБОТЧИК СОБЫТИЙ ШИНЫ ТАРГЕТИНГА:
---@param message_id hash Тип события (target_changed / target_lost)
---@param message table Пакет с Си-адресами и UID существа из бэкенда
function M:on_target_event(message_id, message)
    -- А) ЗАХВАТ ЦЕЛИ (PLAYER_TARGET_CHANGED канон)
    if message_id == hash("target_changed") then
        self.uid = message.uid 
        -- 🧠 ЧИТАЕМ СТEЙТ ИЗ ПAМЯТИ ПО УИКAЛЬНОМУ UID СУЩEСТВA:
        local unit_instance_data = units_state.get(message.uid)
        
        if unit_instance_data then
            -- Включаем визуал плашки на HUD экрана
            gui.set_enabled(self.root, true)
            
            -- Выплескиваем паспортные данные в текстовые ноды
            for key,value in pairs(unit_instance_data) do
                print('KEY', key, "VALUE", value)
            end
            gui.set_text(self.target_name, locales.get(unit_instance_data.name_key)) -- в будущем locales.get()
            gui.set_text(self.target_level, string.format("Ур. %d", unit_instance_data.level))
            
            -- Считаем актуальный процент здоровья и скармливаем компоненту Друида!
            -- Твой HealthBar сочно и плавно сдвинет зеленую шкалу на нужный пиксель!
            local hp_percent = unit_instance_data.health / unit_instance_data.max_health
            self.target_health_bar:update_health(hp_percent)
            
           -- Задел под ману/энергию драконов кастеров
           --  self.target_mana_bar:update_health(1.0) 
        end

    -- Б) ПОТЕРЯ ЦЕЛИ (Моб умер / кликнули в пустоту)
    elseif message_id == hash("target_lost") then
        -- Мгновенно тушим плашку таргета с экрана, освобождая Meadows-обзор
        gui.set_enabled(self.root, false)
    
    -- Б) ЛЕГКИЙ БОЕВОЙ АПДЕЙТ ФРЕЙМА (Канон WoW)
    elseif message_id == hash("target_update") then
        
        -- 🛡️ ГВАРД АОЕ/КЛИВОВ: Сверяем UID побитого моба с UID этой плашки
        if not self.uid or message.uid ~= self.uid then
            return -- Отрезаем AoE по чужим мобам
        end

        -- Идем в стерильную базу данных за свежими цифрами существа
        local unit_instance_data = units_state.get(self.uid)
        if not unit_instance_data then return end

        -- 🎯 МОНОЛИТНАЯ СИНХРОНИЗАЦИЯ СТЕЙТА: 
        -- Нам плевать, что именно изменилось (ХП или мана). Мы просто обновляем ВСЁ разом!
        
        -- 1. Красим полоску здоровья Друида
        local hp_percent = unit_instance_data.health / unit_instance_data.max_health
        self.target_health_bar:update_health(hp_percent)
        
        -- 2. Красим полоску маны Друида (Если у моба есть мана в конфиге базы данных)
        if unit_instance_data.max_mana and unit_instance_data.max_mana > 0 then
            local mana_percent = unit_instance_data.mana / unit_instance_data.max_mana
            self.target_mana_bar:update_mana(mana_percent)
        end

        -- 3. Задел под ауры/дебаффы (когда сделаешь их, они будут рендериться здесь же)
        -- self:refresh_auras(unit_instance_data.auras)
    end    
end

return M
