local character_config = require("main.modules.character.character_config")
local data = require("main.modules.character.character_data")
local paperdoll = require("main.modules.player.player_paperdoll") -- Добавь это
local items_db = require("main.modules.data.items_db")

local M = {}


function M.get_total_stat(stat_name)
    local total = data.player.stats[stat_name] or 0
    for _, item_data in pairs(paperdoll.slots) do
        if item_data and item_data.item_id then
            local item_cfg = items_db.get_item(item_data.item_id)
            if item_cfg and item_cfg.stats and item_cfg.stats[stat_name] then
                total = total + item_cfg.stats[stat_name]
            end
        end
    end
    return total
end


function M.calculate_max_health()
    local base = 100
    local total_stamina = M.get_total_stat("stamina")
    -- ВАЖНО: используем total_stamina
    return base + math.max(0, total_stamina - 10) * 10
end

function M.calculate_max_mana()
    local base = 50
    local total_intellect = M.get_total_stat("intellect")
    -- ВАЖНО: используем total_intellect
    return base + math.max(0, total_intellect - 10) * 5
end

function M.update_derived_stats()
    data.player.current_stats.strength = M.get_total_stat("strength")
    data.player.current_stats.agility = M.get_total_stat("agility")
    data.player.current_stats.intellect = M.get_total_stat("intellect")
    data.player.current_stats.stamina = M.get_total_stat("stamina")

    data.player.max_health = M.calculate_max_health()
    data.player.max_mana = M.calculate_max_mana()

    msg.post("main:/gui_manager#hud", "update_health", { percentage = data.player.health / data.player.max_health })
    msg.post("game_scene:/player", "stats_changed")
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
