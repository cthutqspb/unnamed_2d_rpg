local items_db = require("main.modules.data.items_db")
local abilities_db = require("main.modules.data.abilities_db")

---@class SlotVisualState
---@field icon_texture string|nil     Имя атласа (например, "project_utumno")
---@field icon_animation string|hash|nil Имя флипбука/спрайта/иконки внутри атласа
---@field icon_color vector4|nil      Подсветка редкости предмета или яркость КД
---@field amount_text string|nil      Текст количества в стаке (для инвентаря)
---@field bind_text string|nil        Текст горячей клавиши (для экшен-бара)
---@field is_icon_enabled boolean     Включена ли картинка в слоте

---@class GridSlotNodeCache
---@field root node
---@field icon node
---@field amount node
---@field bind node|nil

---@class StaticGridLayoutModule
local M = {}

---Динамически сгенерировать Box-ноды ячеек сетки на основе prefab-шаблона и добавить их в Druid Grid
---@param self StaticGrid Ссылка на родительский компонент универсальной сетки слотов
function M.create_slots(self)
    self.slots = {}
    local base_path = self.template_id .. "/slot_prefab"
    local prefab_root = gui.get_node(base_path .. "/root")

    -- Кэшируем хэши путей нод для быстрого поиска внутри склонированного дерева (clone_tree)
    local path_root  = hash(base_path .. "/root")
    local path_icon  = hash(base_path .. "/icon")
    local path_amount = hash(base_path .. "/amount")
    local path_bind   = hash(base_path .. "/bind")

    for i = 1, self.columns * self.rows do
        local nodes = gui.clone_tree(prefab_root)
        local slot_root = nodes[path_root]

        gui.set_enabled(slot_root, true)
        gui.set_parent(slot_root, self.container)
        gui.set_position(slot_root, vmath.vector3(0.0, 0.0, 0.0))

        -- Регистрируем созданную ячейку во внутреннем статическом гриде Druid
        self.grid:add(slot_root)

        ---@type GridSlotNodeCache
        local slot_cache = {
            root   = slot_root,
            icon   = nodes[path_icon],
            amount = nodes[path_amount],
            bind   = nodes[path_bind]
        }
        table.insert(self.slots, slot_cache)
    end
end

---@param self StaticGrid
---@param index number
---@param data table Таблица данных из бэкенд-массива (item или action_data)
function M.draw_slot(self, index, data)
    ---@type StaticGridSlotVisual
    local slot = self.slots[index]
    if not slot or not data then return end

    -- =========================================================================
    -- ВEТКA А: ЭКШEН-БAР (ПАНЕЛЬ СПОСОБНОСТЕЙ)
    -- =========================================================================
    if self.grid_type == "action_bar" then
        -- Вычисляем строку хоткея строго по индексу ячейки (1..12)
        local bind_string = tostring(index == 11 and "-" or (index == 12 and "=" or (index == 10 and "0" or index)))

        if slot.bind then
            gui.set_enabled(slot.bind, true)
            gui.set_text(slot.bind, bind_string)
        end
        if slot.amount then gui.set_enabled(slot.amount, false) end

        -- Если в слоте сидит способность — лезем в базу спеллов!
        if data.action_id and data.action_type == "ability" then
            local cfg = abilities_db.get_ability(data.action_id)
            if cfg then
                gui.set_enabled(slot.icon, true)
                if cfg.texture then gui.set_texture(slot.icon, cfg.texture) end
                gui.play_flipbook(slot.icon, hash(cfg.animation or data.action_id))
                gui.set_color(slot.icon, vmath.vector4(1, 1, 1, 1))
            end
        -- 2. 🎯 СЛОТ СОДЕРЖИТ ПРЕДМЕТ (Зелья / Оружие / Мусор):
        elseif data.action_id and data.action_type == "item" then
            local item_cfg = items_db.get_item(data.action_id)
            if item_cfg then
                gui.set_enabled(slot.icon, true)
                if item_cfg.texture then gui.set_texture(slot.icon, item_cfg.texture) end
                gui.play_flipbook(slot.icon, hash(item_cfg.animation or data.action_id))

                -- 🧱 СИ-ЗАЩИТА И ЗАТЕМНЕНИЕ НЕЮЗАБЕЛЬНЫХ ПРЕДМЕТОВ (WoW-канон):
                -- Проверяем, есть ли у шмотки активный прожимаемый use_effects в базе данных
                if item_cfg.use_effects and #item_cfg.use_effects > 0 then
                    -- Предмет можно прожать (зелье маны) -> Даем иконке 100% сочный цвет
                    gui.set_color(slot.icon, vmath.vector4(1, 1, 1, 1))
                else
                    -- Предмет не имеет юза (меч, глина, панцирь) -> Насильно ТEМНИМ иконку в серый!
                    -- Слот заблокирован, но иконка шмотки красиво сидит на экшен-баре!
                    gui.set_color(slot.icon, vmath.vector4(0.3, 0.3, 0.3, 1.0))
                end
            end
        else
            -- Пустой боевой слот
            gui.set_enabled(slot.icon, false)
        end
        return -- Выходим
    end

    -- =========================================================================
    -- ВEТКA Б: ТТOЙ РOДНOЙ ИНВEНТAРЬ (Остается в полной безопасности)
    -- =========================================================================
    -- data здесь — это твой чистый item, у которого есть поле item_id!
    if slot.bind then gui.set_enabled(slot.bind, false) end

    if data.item_id then
        -- Лезем в твою базу предметов по item_id, как это и работало раньше!
        local item_cfg = items_db.get_item(data.item_id)
        if item_cfg then
            gui.set_enabled(slot.icon, true)
            gui.set_color(slot.icon, item_cfg.color or vmath.vector4(1, 1, 1, 1))

            if item_cfg.texture then
                gui.set_texture(slot.icon, item_cfg.texture)
            end
            gui.play_flipbook(slot.icon, hash(item_cfg.animation or data.item_id))

            -- Твой родной вывод количества предметов
            local is_stack = data.amount and data.amount > 1
            gui.set_enabled(slot.amount, is_stack)
            if is_stack then
                gui.set_text(slot.amount, tostring(data.amount))
            end
        end
    else
        -- Пустой слот сумки
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.amount, false)
    end
end

---Полностью сбросить и скрыть визуальное содержимое ячейки (сделать пустой)
---@param self StaticGrid
---@param index number
function M.clear_slot_visual(self, index)
    local slot = self.slots[index]
    if slot then
        gui.set_enabled(slot.icon, false)
        gui.set_enabled(slot.amount, false)
        gui.set_enabled(slot.bind, false)
    end
end

---Принудительно обновить исключительно цифру количества предметов в слоте (без полной перерисовки иконки)
---Используется при сплитах на курсор для создания иллюзии отщипывания стака
---@param self StaticGrid
---@param index number
---@param amount number Новое количество предметов для отображения
function M.set_slot_amount_visual(self, index, amount)
    local slot = self.slots[index]
    if not slot then return end

    if amount and amount > 1 then
        gui.set_enabled(slot.amount, true)
        gui.set_text(slot.amount, tostring(amount))
    elseif amount and amount <= 1 then
        -- Если остался 1 или меньше, скрываем цифру (по канонам draw_slot)
        gui.set_enabled(slot.amount, false)
    else
        -- Сейв-гард на случай непредвиденного нуля или nil
        gui.set_enabled(slot.amount, false)
    end
end

return M

