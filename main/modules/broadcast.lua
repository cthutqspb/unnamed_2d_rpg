-- broadcast.lua
local M = {}

-- Храним функции, которые нужно вызвать при событии
local listeners = {}

-- Объект вызывает это в init, чтобы "подписаться"
function M.subscribe(callback)
    listeners[callback] = true
end

-- Объект вызывает это в final, чтобы "отписаться"
function M.unsubscribe(callback)
    listeners[callback] = nil
end

-- Вызываем это из world.script для рассылки
function M.send(message_id, message)
    local count = 0
    for callback, _ in pairs(listeners) do
        -- pcall пытается вызвать функцию. Если объект удален, 
        -- вызов внутри callback (например, go.get_position) упадет,
        -- pcall вернет false, и мы просто удалим этого слушателя.
        local ok, err = pcall(callback, message_id, message)
        if ok then
            count = count + 1
        else
            listeners[callback] = nil -- Чистим "мертвеца"
        end
    end
    -- Теперь принт будет показывать только реально живых слушателей
    -- print("Sent to " .. count .. " alive listeners") 
end

return M
