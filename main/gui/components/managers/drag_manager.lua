local item_transfer_manager = require("main.modules.item_transfer_manager")
local interaction_manager = require("main.modules.logic.interaction_manager")

---@class DragManager
local M = {}

---@class ActiveDragData
---@field source table @Компонент-источник драга (например, StaticGrid)
---@field slot number|string @Индекс или тип слота-источника
---@field item table @Модель данных перетаскиваемого предмета
---@field item_cfg table @Конфигурация предмета из items_db
---@field amount number @Количество предметов в пачке
---@field texture string|hash @Текстура атласа
---@field animation hash @Хеш имени анимации/иконки
---@field x number @Текущая экранная координата X мыши
---@field y number @Текущая экранная координата Y мыши

---@type ActiveDragData|nil
local active_drag = nil

---@type boolean
local is_over_any_gui = false

---Начать процесс перетаскивания предмета
---@param source table @Компонент-источник (StaticGrid или кукла)
---@param slot number|string @Индекс слота или тип слота куклы
---@param item table @Данные предмета
---@param item_cfg table @Конфиг предмета из БД
function M.start(source, slot, item, item_cfg)
    local animation_name = item_cfg.animation or item_cfg.icon

    active_drag = {
        source = source,
        slot = slot,
        item = item,
        item_cfg = item_cfg,
        amount = item.amount,
        texture = item_cfg.texture,
        animation = hash(animation_name),
        x = 0, y = 0
    }
    print("Drag started with amount:", item.amount)
end

---Обновить текущие координаты мыши
---@param x number
---@param y number
function M.update(x, y)
    if not active_drag then return end
    active_drag.x = x
    active_drag.y = y
    is_over_any_gui = false
end

---Получить данные активного драга
---@return ActiveDragData|nil
function M.get_active()
    return active_drag
end

---Проверить, перетаскивается ли сейчас что-нибудь
---@return boolean
function M.is_dragging()
    return active_drag ~= nil
end

---Получить данные источника перетаскивания
---@return table|nil @source component
---@return number|string|nil @slot id
---@return table|nil @item data
function M.get_source()
    if not active_drag then return nil, nil, nil end
    return active_drag.source, active_drag.slot, active_drag.item
end

---Установить флаг нахождения курсора над любым GUI окном
---@param value boolean
function M.set_over_gui(value)
    is_over_any_gui = value
end

---Завершить перетаскивание (успех, отмена или сброс в мир)
---@param target_component table|nil @Компонент-цель (куда бросили)
---@param target_slot number|string|nil @Слот-цель (куда бросили)
function M.finish(target_component, target_slot)
    if not active_drag then return end

    local d = active_drag
    active_drag = nil

    -- 🎯 ПЕРЕВОД ПРОВАЙДЕРА В МОДЕЛЬ ДАННЫХ (View -> Model)
    local source_model = d.source
    if type(source_model) == "table" and source_model.get_data_source then
        source_model = source_model:get_data_source()
    end

    local source_slot = d.slot
    local item = d.item 
    local item_cfg = d.item_cfg

    -- 1. СЛУЧАЙ: ОТМЕНА (Над GUI мимо слотов или за пределы окон)
    if not target_component and is_over_any_gui then
        -- Вызываем finalize() без аргументов. Он кинет бродкаст, 
        -- и все открытые окна (включая фокусное) обновятся и отлипнут!
        item_transfer_manager.finalize()

    -- 2. СЛУЧАЙ: ПЕРЕМЕЩЕНИЕ (Успешный перенос)
    elseif target_component then
        -- 🎯 ПЕРЕВОД ЦЕЛИ В МОДЕЛЬ ДАННЫХ (View -> Model)
        local target_model = target_component
        if type(target_model) == "table" and target_model.get_data_source then
            target_model = target_model:get_data_source()
        end

        -- Передаем в ядро строго модели данных
        item_transfer_manager.execute_transfer(source_model, source_slot, target_model, target_slot, item, item_cfg)

    -- 3. СЛУЧАЙ: ДРОП В МИР
    else
        item_transfer_manager.drop_to_world(source_model, source_slot, item, d.x, d.y)
    end

    is_over_any_gui = false
end


-- function M.finish(target_component, target_slot)
--     if not active_drag then return end
--
--     local d = active_drag
--     active_drag = nil
--
--     local source = d.source
--     local source_slot = d.slot
--     local item = d.item 
--     local item_cfg = d.item_cfg
--
--     -- 1. СЛУЧАЙ: ОТМЕНА (Над GUI мимо слотов или за пределы окон)
--     if not target_component and is_over_any_gui then
--         -- Нам вообще плевать, сплит это или нет. 
--         -- Просто вызываем finalize, чтобы сбросить визуал к реальным данным.
--         item_transfer_manager.finalize(source)
--
--     -- 2. СЛУЧАЙ: ПЕРЕМЕЩЕНИЕ (Успешный перенос)
--     elseif target_component then
--         item_transfer_manager.execute_transfer(source, source_slot, target_component, target_slot, item, item_cfg)
--
--     -- 3. СЛУЧАЙ: ДРОП В МИР
--     else
--         item_transfer_manager.drop_to_world(source, source_slot, item, d.x, d.y)
--     end
--
--     is_over_any_gui = false
-- end


return M
