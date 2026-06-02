-- Улучшенный broadcast.lua
local errored_callbacks = {} -- Запоминаем, кто уже ломался, чтобы не спамить

local M = {}
local events = {} -- { ["stats_updated"] = {callback1, callback2}, ... }

function M.subscribe(event_name, callback)
    events[event_name] = events[event_name] or {}
    events[event_name][callback] = true
end

function M.unsubscribe(event_name, callback)
    if not event_name or not callback then return end

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
