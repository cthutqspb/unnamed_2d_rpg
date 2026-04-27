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
        count = count + 1
        callback(message_id, message)
    end
    print("Sent to " .. count .. " listeners") -- Это покажет, сколько реально объектов слушают
end

return M
