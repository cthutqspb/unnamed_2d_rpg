local items_db = require("main.modules.data.items_db")

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

    for i = 1, self.columns * self.rows do
        local nodes = gui.clone_tree(prefab_root)
        local slot_root = nodes[path_root]

        gui.set_enabled(slot_root, true)
        gui.set_parent(slot_root, self.container)
        gui.set_position(slot_root, vmath.vector3(0.0, 0.0, 0.0))

        -- Регистрируем созданную ячейку во внутреннем статическом гриде Druid
        self.grid:add(slot_root)

        -- Кэшируем ссылки на визуальные ноды ячейки для мгновенного доступа при рефреше
        table.insert(self.slots, {
            root = slot_root,
            icon = nodes[path_icon],
            amount = nodes[path_amount]
        })
    end
end

---Отрисовать текстуру, цвет и количество предметов внутри конкретного графического слота
---@param self StaticGrid
---@param index number Порядковый индекс ячейки в массиве slots
---@param item_id string Строковый идентификатор предмета из базы данных ("sword", "gold")
---@param amount number Текущее количество предметов в стаке
function M.draw_slot(self, index, item_id, amount)
    local slot = self.slots[index]
    if not slot then return end

    local data = items_db.get_item(item_id)
    if data then
        gui.set_enabled(slot.icon, true)

        -- Устанавливаем цвет иконки (например, серый/зеленый/фиолетовый в зависимости от раритетности)
        gui.set_color(slot.icon, data.color or vmath.vector4(1.0, 1.0, 1.0, 1.0))

        if data.texture then
            gui.set_texture(slot.icon, data.texture)
        end

        -- Запускаем анимацию иконки из флипбука (атласа)
        gui.play_flipbook(slot.icon, hash(data.animation or data.icon))

        -- Отображаем цифру количества только если в стаке больше одного предмета
        local is_stack = amount and amount > 1
        gui.set_enabled(slot.amount, is_stack)
        if is_stack then
            gui.set_text(slot.amount, tostring(amount))
        end
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

