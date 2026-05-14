-- Улучшенный broadcast.lua
local errored_callbacks = {} -- Запоминаем, кто уже ломался, чтобы не спамить

local M = {}
local events = {} -- { ["stats_updated"] = {callback1, callback2}, ... }

function M.subscribe(event_name, callback)
    events[event_name] = events[event_name] or {}
    events[event_name][callback] = true
end

function M.unsubscribe(event_name, callback)
    if events[event_name] then
        events[event_name][callback] = nil
    end
end

function M.send(event_name, message)
    if not events[event_name] then return end
    
    for callback, _ in pairs(events[event_name]) do
        local ok, err = pcall(callback, message)
        if not ok then 
            -- Выводим ошибку в консоль ТОЛЬКО ОДИН РАЗ
            if not errored_callbacks[callback] then
                print("WARNING: Broadcast error in [" .. tostring(event_name) .. "]:", err)
                errored_callbacks[callback] = true
            end
        else
            -- Если компонент исправился и отработал успешно, сбрасываем флаг ошибки
            errored_callbacks[callback] = nil
        end
    end
end

return M


-- -- broadcast.lua
-- local M = {}
--
-- -- Храним функции, которые нужно вызвать при событии
-- local listeners = {}
--
-- -- Объект вызывает это в init, чтобы "подписаться"
-- function M.subscribe(callback)
--     listeners[callback] = true
-- end
--
-- -- Объект вызывает это в final, чтобы "отписаться"
-- function M.unsubscribe(callback)
--     listeners[callback] = nil
-- end
--
-- -- Вызываем это из world.script для рассылки
-- function M.send(message_id, message)
--     local count = 0
--     for callback, _ in pairs(listeners) do
--         -- pcall пытается вызвать функцию. Если объект удален, 
--         -- вызов внутри callback (например, go.get_position) упадет,
--         -- pcall вернет false, и мы просто удалим этого слушателя.
--         local ok, err = pcall(callback, message_id, message)
--         if ok then
--             count = count + 1
--         else
--             listeners[callback] = nil -- Чистим "мертвеца"
--         end
--     end
--     -- Теперь принт будет показывать только реально живых слушателей
--     -- print("Sent to " .. count .. " alive listeners") 
-- end
--
-- return M
