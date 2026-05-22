local M = {}

-- Стек открытых окон (список URL скриптов)
local stack = {}
M.hovered_states = {}
M.mouse_x = 0
M.mouse_y = 0
-- M.is_over_ui = false

function M.update_mouse(x, y)
    M.mouse_x = x
    M.mouse_y = y
end

function M.set_hover_status(url, is_hovered)
    M.hovered_states[url] = is_hovered
end

function M.is_over_ui()
    -- 1. Если стек пуст - мир точно свободен
    if #stack == 0 then return false end

    -- 2. Проверяем только то окно, которое САМОЕ ВЕРХНЕЕ в стеке
    local top = stack[#stack]
    local url_str = tostring(top.url)
    
    -- 3. Если верхнее окно говорит "я под мышкой" - блокируем мир
    if M.hovered_states[url_str] then
        return true
    end
    
    return false
end


function M.push(instance, url, z)
    M.pop(url)
    table.insert(stack, { instance = instance, url = url, z = z or 0 })
    -- Сортируем: чем больше Z, тем дальше в таблице (выше)
    table.sort(stack, function(a, b) return a.z < b.z end)
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

return M

