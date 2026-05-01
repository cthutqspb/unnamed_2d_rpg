local config = require("character_config")
local data = require("character_data")

local M = {}

function M.calculate_max_health()
    local base = 100
    local stamina = data.player.stats.stamina
    -- Каждое очко выносливости выше 10 даёт +10 здоровья
    return base + math.max(0, stamina - 10) * 10
end

function M.calculate_max_mana()
    local base = 50
    local intellect = data.player.stats.intellect
    -- Каждое очко интеллекта выше 10 даёт +5 маны
    return base + math.max(0, intellect - 10) * 5
end

function M.update_derived_stats()
    data.player.max_health = M.calculate_max_health()
    data.player.max_mana = M.calculate_max_mana()
    data.player.health = math.min(data.player.health, data.player.max_health)
    data.player.mana = math.min(data.player.mana, data.player.max_mana)
end

function M.take_damage(amount)
    data.player.health = math.max(0, data.player.health - amount)
    msg.post("/gui_manager", "update_health", { percentage = data.player.health / data.player.max_health })
end

function M.heal(amount)
    data.player.health = math.min(data.player.max_health, data.player.health + amount)
    msg.post("/gui_manager", "update_health", { percentage = data.player.health / data.player.max_health })
end

function M.add_stat(stat_name, value)
    data.player.stats[stat_name] = data.player.stats[stat_name] + value
    if stat_name == "stamina" or stat_name == "intellect" then
        M.update_derived_stats()
    end
end

return M
