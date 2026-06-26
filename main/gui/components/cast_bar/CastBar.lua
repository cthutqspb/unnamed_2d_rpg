local locales = require("main.modules.data.locales.locale_manager")
local abilities_db = require("main.modules.data.abilities_db"
)
---@class CastBar
local M = {}
M.__index = M

---Универсальное ААА-рождение кастбара в ОДНУ СТРОЧКУ (С поддержкой аддонов)
---@param template_prefix string Имя твоего шаблона в hud.gui (передаем "cast_bar")
---@return CastBar
function M.new(template_prefix)
    local self = setmetatable({}, M)
    
    -- Вычисляем префикс нод шаблона строго по твоему имени
    local prefix = template_prefix and (template_prefix .. "/") or ""
    
    -- Зряче выковыриваем Си-ноды шаблона из hud.gui в RAM
    self.root = gui.get_node(prefix .. "root")
    self.background = gui.get_node(prefix .. "background")
    self.fill = gui.get_node(prefix .. "fill")
    self.title = gui.get_node(prefix .. "title")

    -- Кэшируем начальный масштаб для правильного пивота W полоски fill
    if self.fill then
        self.initial_scale = gui.get_scale(self.fill)
    end
    
    -- Сразу тушим кастбар с экрана при старте Meadows
    self:set_visible(false)
    
    return self
end

---Включить/выключить видимость кастбара
---@param visible boolean
function M:set_visible(visible)
    if self.root then 
        gui.set_enabled(self.root, visible) 
    end
end

---Проверить, горит ли кастбар на экране
---@return boolean
function M:is_visible()
    return self.root and gui.is_enabled(self.root) or false
end

---Отобразить полосу прогресса и название заклинания
---@param spell_id string ID способности
function M:show(spell_id)
    self:set_visible(true)
    
    if self.fill then
        local current_scale = vmath.vector3(self.initial_scale)
        current_scale.x = 0
        gui.set_scale(self.fill, current_scale)
    end

    -- Получаем конфигурацию из твоей базы
    local ability_cfg = abilities_db.get_ability(spell_id)
    
    if self.title and ability_cfg then
        -- Используем name_key из конфига (например, "frostbolt_name") для локализации
        gui.set_text(self.title, locales.get(ability_cfg.name_key) or spell_id)
    else
        gui.set_text(self.title, tostring(spell_id))
    end
end

---Покадровое обновление шкалы прогресса
---@param progress number Значение от 0.0 до 1.0
function M:set_progress(progress)
    if not self:is_visible() or not self.fill then return end
    
    local clamped = math.max(0, math.min(1, progress))
    local scale = vmath.vector3(self.initial_scale)
    scale.x = self.initial_scale.x * clamped
    gui.set_scale(self.fill, scale)
end

---Схлопнуть кастбар
function M:hide()
    self:set_visible(false)
end

---Принудительно переместить кастбар в новые координаты на экране (Задел под аддоны и MoveAnything!)
---@param x number
---@param y number
function M:set_position(x, y)
    if self.root then
        gui.set_position(self.root, vmath.vector3(x, y, 0))
        print("💾 АДДОНЫ [CastBar]: Позиция кастбара изменена на:", x, y)
    end
end

return M

