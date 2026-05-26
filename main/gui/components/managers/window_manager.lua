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


return M

