-- Function to check if a player is an owner of the area
local function is_player_an_area_owner(player_name, pos)
    minetest.log("action", "[areas_entities] Checking area ownership for player: " .. player_name)
    local owners = areas:getNodeOwners(pos)
    for _, owner in ipairs(owners) do
        if owner == player_name then
            minetest.log("action", "[areas_entities] Player is an area owner.")
            return true
        end
    end
    minetest.log("action", "[areas_entities] Player is not an area owner.")
    return false
end

local function update_entity_on_punch(entity)
    local original_on_punch = entity.on_punch
    entity.on_punch = function(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
        local pos = self.object:get_pos()
        local is_protected = false
        local log_msg = "[areas_entities] Checking protection at pos " .. minetest.pos_to_string(pos)

        if hitter then
            if hitter:is_player() then
                -- If the hitter is a player
                local player_name = hitter:get_player_name()
                is_protected = minetest.is_protected(pos, player_name)
                log_msg = log_msg .. " for player " .. player_name
            else
                -- If the hitter is another entity, check protection for the entity's owner (if available)
                local lua_entity = hitter:get_luaentity()
                if lua_entity and lua_entity._owner then
                    is_protected = minetest.is_protected(pos, lua_entity._owner)
                    log_msg = log_msg .. " for entity owner " .. lua_entity._owner
                end
            end
        end

        -- Log the output of minetest.is_protected
        minetest.log("action", log_msg .. ". Is protected: " .. tostring(is_protected))

        if is_protected then
            -- Prevent damage in protected areas
            minetest.log("action", "[areas_entities] Preventing entity damage in protected area.")
            return true  -- Returning true should prevent the default damage handling
        end

        if original_on_punch then
            return original_on_punch(self, hitter, time_from_last_punch, tool_capabilities, dir, damage)
        end
    end
end




-- Define the reset interval (in seconds)
local reset_interval = 60
local time_since_last_reset = 0

minetest.register_globalstep(function(dtime)
    -- Increment the timer
    time_since_last_reset = time_since_last_reset + dtime

    -- Check if the reset interval has been reached
    if time_since_last_reset >= reset_interval then
        -- Reset the timer
        time_since_last_reset = 0

        -- Reset _areas_entities_updated flag for entities around each player
        for _, player in ipairs(minetest.get_connected_players()) do
            local player_pos = player:get_pos()
            for _, obj in ipairs(minetest.get_objects_inside_radius(player_pos, 1000)) do
                local lua_entity = obj:get_luaentity()
                if lua_entity then
                    lua_entity._areas_entities_updated = false
                end
            end
        end
    end

    -- Regular update logic
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_pos = player:get_pos()
        for _, obj in ipairs(minetest.get_objects_inside_radius(player_pos, 1000)) do
            local lua_entity = obj:get_luaentity()
            if lua_entity then
                local updated_status = lua_entity._areas_entities_updated and "true" or "false"
                local entity_name = lua_entity.name or "<unknown>"
                local pos = obj:get_pos()
                local pos_str = pos and minetest.pos_to_string(pos) or "<unknown pos>"

                -- Log the status, entity name, and position
                minetest.log("action", "[areas_entities] Lua Entity _areas_entities_updated = " .. updated_status ..
                             ", Entity Name: " .. entity_name .. ", Position: " .. pos_str)

                -- Update the entity if it hasn't been updated yet
                if not lua_entity._areas_entities_updated then
                    update_entity_on_punch(lua_entity)
                    lua_entity._areas_entities_updated = true
                end
            end
        end
    end
end)





-- Update the on_punch for all registered entities
for _, entity in pairs(minetest.registered_entities) do
    update_entity_on_punch(entity)
end

minetest.register_on_mods_loaded(function()
    minetest.log("action", "[areas_entities] Server restarted, attempting to reset entity punch overrides.")
    for _, obj in pairs(minetest.luaentities) do
        if obj and obj.object and obj.object:get_luaentity() then
            local lua_entity = obj.object:get_luaentity()
            if lua_entity then
                lua_entity._areas_entities_updated = false
            end
        end
    end
end)
