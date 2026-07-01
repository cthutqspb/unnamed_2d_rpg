local component = require("druid.component")

---@class ResourceBar : druid.component
---@field fill node Спрайт-заливка шкалы ресурса
---@field max_width number Максимальная ширина полоски в пикселях
local M = component.create("ResourceBar")

function M:init(template_id)
    self.fill = gui.get_node(template_id .. "/fill")
    self.max_width = 240  -- Дефолтная ширина из твоего GUI-редактора Defold

    -- Взводим начальное состояние (100% маны по умолчанию при старте)
    self:update_resource("mana", 1.0)
end

---Покадрово перекрасить и плавно сжать полоску ЛЮБОГО ресурса вселенной Meadows
---@param resource "mana"|"energy"|"rage"|string Строковый тип ресурса из паспорта RAM
---@param percentage number Процент заполнения шкалы (от 0.0 до 1.0)
function M:update_resource(resource, percentage)
    percentage = math.max(0, math.min(1, percentage or 0))
    local target_width = self.max_width * percentage

    -- 🦾 ПЛАВНАЯ СИ-АНИМАЦИЯ СЖАТИЯ ДРУИДА (Сохранена безбажно копейка в копейку):
    gui.cancel_animations(self.fill, gui.PROP_SIZE)
    gui.animate(self.fill, gui.PROP_SIZE, vmath.vector4(target_width, gui.get_size(self.fill).y, 0, 0), gui.EASING_OUTSINE, 0.3)

    -- =========================================================================
    -- 🎨 WOW-ТАБЛИЦА СТИЛЕЙ И КЛАССОВЫХ ЦВЕТОВ (ВЫЖЖЕН ХАРДКОД МАНЫ):
    -- =========================================================================
    -- Готовим девственные ААА-векторы цветов для каждого типа энергии:
    local color_mana    = vmath.vector4(0.00, 0.27, 0.92, 1.0) -- Твоя благородная синяя мана магов
    local color_energy  = vmath.vector4(1.00, 0.85, 0.00, 1.0) -- Чистокровный разбойничий жёлтый цвет
    local color_rage    = vmath.vector4(0.85, 0.00, 0.00, 1.0) -- Свирепый красный цвет воинской ярости

    local final_color = color_mana -- Фоллбек на ману, если тип не прилетел

    if resource == "energy" then
        final_color = color_energy
    elseif resource == "rage" then
        final_color = color_rage
    elseif resource == "mana" then
        -- 🧱 СИ-ЗАЩИТА И ЗАТЕМНЕНИЕ МАНЫ ПРИ ОПУСТОШЕНИИ (Твой оригинальный градиент):
        if percentage < 0.3 then
            final_color = vmath.vector4(0.27, 0.72, 0.92, 1.0) -- Светло-синий/бледный при сухом пуле
        elseif percentage < 0.7 then
            final_color = vmath.vector4(0.00, 0.50, 1.00, 1.0) -- Переходный лазурный
        end
    end

    -- Нагло и реактивно красим пиксели ноды fill на HUD экрана!
    gui.set_color(self.fill, final_color)
end

return M
