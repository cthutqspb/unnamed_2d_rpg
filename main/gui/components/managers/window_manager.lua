local M = {}

-- Стек открытых окон (список URL скриптов)
local stack = {}

M.mouse_x = 0
M.mouse_y = 0

function M.update_mouse(x, y)
    M.mouse_x = x
    M.mouse_y = y
end

function M.push(instance, url, z)
    M.pop(url)
    -- Сохраняем Z вместе с инстансом
    table.insert(stack, { instance = instance, url = url, z = z or 0 })
    
    -- ЖЕСТКАЯ СОРТИРОВКА: теперь в конце стека всегда то окно, у которого Z больше
    table.sort(stack, function(a, b) 
        return a.z < b.z 
    end)
end

-- Удалить конкретное окно из стека (например, если закрыли кликом на крестик)
function M.pop(url)
    for i = #stack, 1, -1 do
        if stack[i].url == url then
            table.remove(stack, i)
            print("Stack pop:", url, "Total:", #stack)
            break
        end
    end
end

-- В методе close_top
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

function M.get_window_instance(url)
    for _, win in ipairs(stack) do
        if win.url == url then
            -- Мы сохраняли это в стеке при вызове push
            return win.instance
        end
    end
    return nil
end

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

function M.reorder_focus()
    -- Стек у нас уже отсортирован: [Z10, Z20, Z30]
    -- Мы идем от МЕНЬШЕГО к БОЛЬШЕМУ.
    for i = 1, #stack do
        local win = stack[i]
        -- Тот, кто вызвал acquire ПОСЛЕДНИМ в цикле, станет ПЕРВЫМ в on_input
        msg.post(win.url, "release_input_focus")
        msg.post(win.url, "acquire_input_focus")
    end
end


return M

