local M = {}

-- Стек открытых окон (список URL скриптов)
local stack = {}
M.hovered_states = {}
M.mouse_x = 0
M.mouse_y = 0
M.is_over_ui = false

function M.update_mouse(x, y)
    M.mouse_x = x
    M.mouse_y = y
end

function M.set_hover_status(url, is_hovered)
    M.hovered_states[url] = is_hovered
end

function M.is_any_hovered()
    for url, status in pairs(M.hovered_states) do
        if status then return true end
    end
    return false
end

-- Добавить окно в стек
function M.push(url, close_message)
    -- Чтобы не дублировать одно и то же окно
    M.pop(url) 
    table.insert(stack, { url = url, message = close_message or hash("close_window") })
    print("Stack push:", url, "Total:", #stack)
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

-- Закрыть самое верхнее окно
function M.close_top()
    if #stack > 0 then
        local top = table.remove(stack)
        msg.post(top.url, top.message)
        return true -- Сообщаем, что мы что-то закрыли
    end
    return false -- Стек пуст
end

return M

