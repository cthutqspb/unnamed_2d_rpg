---@class WindowManager
local M = {}

---@class WindowStackEntry
---@field instance table @Ссылка на Lua-таблицу самого окна (компонент)
---@field url url @URL gui_script'а окна
---@field z number @Z-слой окна (render_order)
---@field message hash|nil @Кастомное сообщение для закрытия окна (например, hide_menu)

-- Стек открытых окон (список отсортированных по Z таблиц)
---@type WindowStackEntry[]
local stack = {}

M.active_instance = nil

---@type table<string, boolean>
M.hovered_states = {}

---@type number
M.mouse_x = 0
---@type number
M.mouse_y = 0

---Обновить глобальные координаты мыши для менеджера
---@param x number
---@param y number
function M.update_mouse(x, y)
    M.mouse_x = x
    M.mouse_y = y
end

---Добавить окно в стек фокуса и ввода
---@param instance table @Экземпляр (self) компонента окна
---@param url url @URL скрипта окна
---@param z number @Z-слой рендера окна
function M.push(instance, url, z)
    M.pop(url)
    -- Сохраняем Z вместе с инстансом
    table.insert(stack, { instance = instance, url = url, z = z or 0 })

    -- ЖЕСТКАЯ СОРТИРОВКА: теперь в конце стека всегда то окно, у которого Z больше
    table.sort(stack, function(a, b)
        return a.z < b.z
    end)

    -- 🚩 ФИКС: Тот, кто запушил себя последним по клику — тот и активен!
    M.active_instance = instance
end

-- Удалить конкретное окно из стека (например, если закрыли кликом на крестик)
---@param url url
function M.pop(url)
    for i = #stack, 1, -1 do
        if stack[i].url == url then
            -- Если закрывают то окно, которое сейчас светилось
            local was_active = (stack[i].instance == M.active_instance)

            table.remove(stack, i)
            print("Stack pop:", url, "Total:", #stack)

            -- 🚩 ФИКС: Передаем активность окну, которое оказалось выше всех из оставшихся
            if was_active then
                M.active_instance = (#stack > 0) and stack[#stack].instance or nil
            end
            break
        end
    end
end


---Закрыть самое верхнее окно в стеке (например, по нажатию на Esc)
---@return boolean @true, если окно было успешно найдено и закрыто
function M.close_top()
    if #stack > 0 then
        local top = table.remove(stack)
        -- Если top.message вдруг nil, ставим дефолтный hash("close_window")
        local message = top.message or hash("close_window")

        msg.post(top.url, message)
        print("Stack close_top:", top.url)
        return true
    end
    return false
end

---Получить экземпляр окна по его URL
---@param url url
---@return table|nil @Экземпляр Lua-компонента окна
function M.get_window_instance(url)
    for _, win in ipairs(stack) do
        if win.url == url then
            -- Мы сохраняли это в стеке при вызове push
            return win.instance
        end
    end
    return nil
end

---Проверить, открыто ли сейчас контекстное меню
---@return boolean
function M.is_context_menu_open()
    local menu_msg = hash("hide_menu")
    for _, win in ipairs(stack) do
        -- Ищем в стеке окно, у которого сообщение закрытия - hide_menu
        if win.message == menu_msg then
            return true
        end
    end
    return false
end

---Перестроить фокус ввода Defold на основе Z-слоёв из стека
function M.reorder_focus()
    print("🚨 ФOКУС: reorder_focus сработал!")
    -- Идем по стеку [Z5, Z7, Z10]
    for i = 1, #stack do
        local win = stack[i]

        -- 🚩 ЧЕСТНАЯ ПРОВЕРКА: Светимся только если ссылка совпала с M.active_instance
        local is_active = (win.instance == M.active_instance)

        -- 🚩 ФИКС: Отправляем сообщение скрипту окна!
        -- Каждое окно поймает его в своем родном контексте и само поменяет альфу
        msg.post(win.url, "set_focus_visual", { is_active = is_active })

        -- Очередь ввода Defold выстраивается по честным слоям Z
        msg.post(win.url, "release_input_focus")
        msg.post(win.url, "acquire_input_focus")
    end
end

---Сказать менеджеру, что окно получило фокус от клика игрока
---@param instance table Ссылка на self компонента окна
---@param url url URL скрипта окна
function M.handle_window_click(instance, url)
    -- Если это окно уже и так активное — ничего не делаем, экономим ресурсы
    if M.active_instance == instance then return end

    -- Находим его Z-слой из текущего стека
    local current_z = 0
    for _, win in ipairs(stack) do
        if win.url == url then
            current_z = win.z
            break
        end
    end

    -- Перевызываем push, чтобы обновить active_instance и перестроить слои
    M.push(instance, url, current_z)
    M.reorder_focus()
end

---Универсальный статический перехватчик ввода для абсолютно любого GUI-окна Meadows
---@param script_self table Контекст self самого .gui_script файла
---@param action_id hash
---@param action table
---@param drag_manager table Проброшенный извне менеджер перетаскивания предметов
---@param window_instance table Проброшенный извне ООП-объект конкретного инстанса окна
---@return boolean handled
function M.handle_window_input(script_self, action_id, action, drag_manager, window_instance)
    local h_touch = hash("touch")

    -- 🧱 1. ТИТАНОВЫЙ ААА-ГВАРД (Работаем строго с window_instance):
    if not window_instance or (window_instance.is_visible and not window_instance:is_visible()) then
        return script_self.druid:on_input(action_id, action)
    end

    -- 🦾 2. ТИТАНОВЫЙ ААА-ГВАРД ПРОЗРАЧНОСТИ НЕАКТИВНЫХ ОКН:
    local active_oop_win = M.active_instance
    local is_mouse_moving = (action_id == nil) or (action_id == h_touch)
    local is_item_dragging = drag_manager and drag_manager.is_dragging and drag_manager.is_dragging()

    if active_oop_win and (window_instance ~= active_oop_win) and is_mouse_moving and not action.pressed and not is_item_dragging then
        return false -- Неактивное окно засыпает, пропуская драг соседа сквозь себя!
    end

    -- 🦾 3. ВЗВОДИМ ГЛОБАЛЬНЫЙ СEМAФOР ДЛЯ СЛOЁВ ТУЛТИПOВ И КУРСOРA:
    if active_oop_win and (window_instance == active_oop_win) and is_mouse_moving then
        local is_currently_moving = window_instance.drag and window_instance.drag.is_drag
        M.is_any_window_moving = (is_currently_moving == true)
    end

    -- Сдаем ввод Внешнему Друиду Б строго в его родном context скрипта!
    local handled = script_self.druid:on_input(action_id, action)

    -- 🦾 4. УНИВЕРСАЛЬНАЯ ЛОГИКА ОПЕРАЦИЙ ДРАГА ПРЕДМЕТОВ НА КУРСОРЕ:
    if is_item_dragging then
        if not action_id or action_id == h_touch then
            drag_manager.update(action.x, action.y)
            if window_instance.root and gui.pick_node(window_instance.root, action.x, action.y) then
                drag_manager.set_over_gui(true)
            end
        end

        -- Фаза отпускания мыши (Дроп предмета в слоты)
        if action_id == h_touch and action.released then
            M.is_any_window_moving = false
            if window_instance.modules then
                for _, module in ipairs(window_instance.modules) do
                    if module and module.on_drop then
                        if module:on_drop(action.x, action.y) then
                            return true
                        end
                    end
                end
            end

            -- Честно проверяем коллизию root-ноды через прилетевший window_instance!
            if window_instance.root and gui.pick_node(window_instance.root, action.x, action.y) then
                print("🛡️ МЕНЕДЖЕР ОКOН: Дроп мимо слотов. Безопасно тушим драг внутри геометрии окна.")
                drag_manager.finish(nil, nil)
                return true
            end
        end
    end

    -- Как только отпустили ЛКМ — гарантированно гасим глобальный семафор
    if action.released and action_id == h_touch then
        M.is_any_window_moving = false
    end

    -- 🧱 5. БЛОКИРОВКА КЛИКОВ СКВОЗЬ ИНТЕРФЕЙС В МИР MEADOWS:
    if action_id and action.x and action.y then
        if window_instance.is_over_window and window_instance:is_over_window(action.x, action.y) then
            if action.pressed and action_id == h_touch then
                M.handle_window_click(window_instance, msg.url())
            end
            return true
        end
    end

    return handled
end

---Установить статус нахождения мыши над конкретным окном
---@param url url
---@param is_over boolean
function M.set_hover_status(url, is_over)
    M.hovered_states[tostring(url)] = is_over
end

---Проверить, находится ли мышь над любым открытым GUI-окном
---@return boolean
function M.is_over_ui()
    -- Если хотя бы одно окно говорит, что оно под мышкой — возвращаем true
    for _, is_over in pairs(M.hovered_states) do
        if is_over then return true end
    end
    return false
end

M.handle_window_input = M.handle_window_input

return M

