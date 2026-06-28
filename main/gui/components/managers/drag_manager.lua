local item_transfer_manager = require("main.modules.item_transfer_manager")
local actions_dispatcher = require("main.modules.logic.actions_dispatcher")

---@class DragManager
local M = {}

---@class ActiveDragData
---@field source table @Компонент-источник драга (например, StaticGrid)
---@field slot number|string @Индекс или тип слота-источника
---@field item table @Модель данных перетаскиваемого предмета
---@field item_cfg table @Конфигурация предмета из items_db
---@field drag_type string
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
---@param source InventoryInstance|PaperdollInstance|table @Модель-источник, откуда забираем вещь
---@param slot number|string @Индекс слота или тип слота куклы
---@param item table @Данные предмета
---@param item_cfg table @Конфиг предмета из БД
function M.start(source, slot, item, item_cfg)
    local animation_name = item_cfg.animation or item_cfg.icon
    for k,v in pairs(item) do
        print("ITEM", k,v)
    end
    active_drag = {
        drag_type = item_cfg.action_type,
        source = source,
        slot = slot,
        item = item,
        item_cfg = item_cfg,
        amount = item.amount or 0,
        texture = item_cfg.texture,
        animation = hash(animation_name),
        x = 0, y = 0
    }
    print("Drag started with amount:", item.amount)
end

function M.abort_drag()
    if not active_drag then return end

    local d = active_drag

    -- Вытаскиваем чистую бэкенд-модель источника
    local source_model = d.source
    if type(source_model) == "table" and source_model.get_data_source then
        source_model = source_model:get_data_source()
    end

    -- =========================================================================
    -- 🦾 АБСОЛЮТНО СЛЕПОЙ AAA-ГВАРД ХОЗЯИНА СУМКИ (ИСПРАВЛЕНО ЧЕРЕЗ DUCK TYPING)
    -- =========================================================================
    -- Никаких require("game_state") и никаких стёртых синглтонов инвентаря!
    -- Мы просто зряче проверяем: если у источника есть овнер, и этот овнер — Игрок,
    -- значит вещь тащат из личного рюкзака мага. Пропускаем отмену!
    local owner = source_model and source_model.owner
    local is_player_bag = owner and owner.is_player == true

    if not is_player_bag then
        print("DRAG_MANAGER: Внешний фокус потерян или это чужой сундук. Отменяем перетаскивание!")

        active_drag = nil
        is_over_any_gui = false

        -- Возвращаем оригинальный стак предметов на место
        item_transfer_manager.finalize()
    end
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

---Завершить перетаскивание (успех переноса, отмена или сброс предмета в мир)
---@param target_component table|nil Компонент-цель (куда бросили мышку: StaticGrid, CharacterPaperdoll)
---@param target_slot number|string|nil Индекс целевого слота ячейки/куклы
function M.finish(target_component, target_slot)
    if not active_drag then return end

    local d = active_drag
    active_drag = nil

    local is_to_bar = target_component and target_component.grid_type == "action_bar"
    local is_from_bar = d.source and d.source.grid_type == "action_bar"

    -- =========================================================================
    -- 🎯 ФИКС КОНВЕЙЕРА (Развод доменов):
    -- Боевой блок имеет право сработать ТОЛЬКО если это была абилка,
    -- ЛИБО если это был предмет, который физически летит НА или С боевой панели!
    -- =========================================================================
    if d.drag_type == "ability" or (d.drag_type == "item" and (is_to_bar or is_from_bar)) then

        -- 1. ЗАЩИТА WoW ЧЕРЕЗ DUCK TYPING (ИСПРАВЛЕНО БЕЗ ИМПОРТОВ СТЕЙТА!):
        -- Если тащим расходник (банку) НА боевую панель быстрых клавиш НЕ из личной сумки игрока
        if d.drag_type == "item" and is_to_bar and not is_from_bar then
            local source_model = d.source
            if type(source_model) == "table" and source_model.get_data_source then
                source_model = source_model:get_data_source()
            end

            -- 🦾 ЗРЯЧИЙ ЮНИТ-ГВАРД: Читаем паспорт хозяина сумки прямо из RAM-ссылки!
            local owner = source_model and source_model.owner
            local is_player_bag = owner and owner.is_player == true

            if not is_player_bag then
                print("❌ ГЕЙМДИЗАЙН: Нельзя тащить вещи из чужих сундуков или трупов сразу на панель!")
                if d.source and d.source.request_refresh then
                    d.source:request_refresh()
                end
                is_over_any_gui = false
                return
            end
        end

        -- 2. ВЫЧИСЛЯЕМ ПЕРЕМЕННЫЕ ДЛЯ РОКИРОВКИ И ОЧИСТКИ (Твой оригинальный безбажный код!)
        local target_bar, target_idx, target_type, target_id
        local old_data = nil

        if target_component ~= nil then
            -- 🟢 КЕЙС А: Бросили НА какую-то сетку интерфейса
            if target_component.grid_type == "action_bar" then
                target_bar  = target_component.bar_index or 1
                target_idx  = target_slot
                target_type = d.drag_type
                target_id   = d.item.item_id or d.item.action_id
                old_data    = target_component:get_slot_data(target_slot)
            else
                -- Страховка на случай непредвиденного домена
                target_bar  = d.source.bar_index or 1
                target_idx  = d.slot
                target_type = "empty"
                target_id   = nil
            end
        else
            -- 🔵 КЕЙС Б: Выбросили в пустой мир / мимо интерфейсов
            target_bar  = d.source.bar_index or 1
            target_idx  = d.slot
            target_type = "empty"
            target_id   = nil
        end

        -- 3. Единственный вызов редьюсера на целевой слот
        actions_dispatcher.REDUCERS["action_bar_assign"]({
            target_bar_index = target_bar,
            target_slot_index = target_idx,
            drag_type = target_type,
            action_id = target_id
        })

        -- 4. Уничтожаем дюп при перемещении ВНУТРИ экшен-бара
        if is_from_bar then
            actions_dispatcher.REDUCERS["action_bar_assign"]({
                target_bar_index = d.source.bar_index,
                target_slot_index = d.slot,
                drag_type = old_data and old_data.action_type or "empty",
                action_id = old_data and old_data.action_id or nil
            })
        end

        is_over_any_gui = false
        return -- Выходим наглухо, инвентарь ниже застрахован!
    end

    -- 1. ОПРЕДЕЛЯЕМ ЧИСТУЮ МОДЕЛЬ ИСТОЧНИКА (View -> Model)
    local source_model = d.source
    if type(source_model) == "table" then
        if source_model.get_data_source then
            source_model = source_model:get_data_source()
        -- 🛡️ ИСПРАВЛЕНО: Никаких get_player_paperdoll() и проверок строк!
        -- Если это наша новая универсальная кукла шмота из RAM — она уже прилетела сюда 
        -- как готовая таблица напрямую из drag.on_drag_start! Ничего подменять не нужно.
        end
    end

    local source_slot = d.slot
    local item = d.item
    local item_cfg = d.item_cfg

    -- === СЦЕНАРИЙ А: ОТМЕНА ДРАГА (Отпустили внутри GUI, но мимо валидных слотов) ===
    if not target_component and is_over_any_gui then
        -- Сбрасываем визуал, возвращая вещь на её законное место
        item_transfer_manager.finalize()

    -- === СЦЕНАРИЙ Б: УСПЕШНЫЙ ПЕРЕНОС (Бросили над ячейкой инвентаря или куклы) ===
    elseif target_component then
        local target_model = target_component
        if type(target_model) == "table" then
            if target_model.get_data_source then
                target_model = target_model:get_data_source()
            -- 🛡️ ИСПРАВЛЕНО: Никаких get_player_paperdoll()!
            -- Если бросили вещь на куклу, в target_component уже лежит живая модель куклы 
            -- из нашего обновленного M:on_drop! Пропускаем подмену.
            end
        end

        -- 🦾 ЧИСТЫЙ DUCK TYPING (ИСПРАВЛЕНО):
        -- Проверяем, является ли источник куклой шмота. У куклы есть метод get_item,
        -- но напрочь отсутствует метод get_first_empty_slot (карманы рюкзака). 
        -- Никаких сравнений с синглтонами, код на 100% зрячий и автономный!
        local is_from_doll = (source_model and source_model.get_item and not source_model.get_first_empty_slot)

        -- Вытаскиваем UID существа, шмот которого сейчас таскают (чтобы прокинуть в диспетчер гварду стат)
        -- Если это игрок — в модели куклы или инвентаря будет лежать "player", иначе возьмет дефолт.
        local current_unit_uid = (target_model and target_model.uid) or (source_model and source_model.uid) or "player"
        print("TARGET", target_component, "SOURCE", source_model)
        -- Диспатчим экшен переноса, ПРОБРАСЫВАЯ МЕТКИ СПЛИТА В PAYLOAD
        actions_dispatcher.REDUCERS["item_transfer"]({
            slot_index = source_slot,
            item_id = item_cfg and item_cfg.id or item.item_id,
            from_paperdoll = is_from_doll,
            target_slot = target_slot,
            source_model_override = source_model,
            target_model_override = target_model,
            unit_uid = current_unit_uid, -- 🎯 Прокидываем UID сессии для проверки Силы/Интеллекта!

            -- 🚩 ПРОБРОС МЕТОК СПЛИТА ДЛЯ РЕДЬЮСЕРА
            item_override = item
        })

        item_transfer_manager.finalize()

    -- === СЦЕНАРИЙ В: ВЫБРОС В МИР (Отпустили мышь за пределами интерфейсов) ===
    else
        actions_dispatcher.REDUCERS["item_drop"]({
            slot_index = source_slot,
            -- Пробрасываем модель источника (инвентарь/кукла), чтобы редьюсер 
            -- знал, откуда стирать стак предметов после успешного броска на землю
            source_model = source_model,
            item = item
        })
    end

    is_over_any_gui = false
end
return M
