dofile(GetInfo(60) .. "aardwolf_colors.lua")

require "aardwolf_colors"

--
-- Variables
--

-- Plugin IDs
plugin_id_gmcp_handler = "3e7dedbe37e44942dd46d264"
inventory_plugin_id = "88c86ea252fc1918556df9fe"

-- Character state
character = {
    level = 0,
    tier = 0
}

-- Current weapon tracking
current_damage_type = nil

-- Debug mode
debug_mode_var_name = "switch_var_debug_mode"
debug_mode = tonumber(GetVariable(debug_mode_var_name)) or 0

--
-- Plugin Methods
--

function OnPluginBroadcast(msg, id, name, text)
    if (id == plugin_id_gmcp_handler) then
        if (text == "char.base") then
            on_character_base_update(gmcp("char.base"))
        end
    end
end

function OnPluginInstall()
    init_plugin()
end

function OnPluginConnect()
    init_plugin()
end

function OnPluginEnable()
    init_plugin()
end

function init_plugin()
    if not IsConnected() then
        return
    end

    EnableTimer("timer_init_plugin", false)
    Message("Switch Weapons Plugin Enabled")
    
    -- Initialize character data from GMCP
    on_character_base_update(gmcp("char.base"))
end

function gmcp(s)
    local ret, datastring = CallPlugin(plugin_id_gmcp_handler, "gmcpdata_as_string", s)
    if ret == 0 and datastring then
        local success, data = pcall(loadstring("return " .. datastring))
        if success then
            return data
        end
    end
    return {}
end

function on_character_base_update(base)
    -- Example: {"name":"Deathr","perlevel":"3000","clan":"emerald","classes":"21603","remorts":"5","class":"Thief","subclass":"Ninja","redos":"0","totpups":"39","tier":"1","race":"Tigran","level":"30","pups":"0","pretitle":""}
    character.tier = tonumber(base.tier) or 0
    character.level = tonumber(base.level) or 0
end

function get_effective_level()
    if character == nil or character.level == nil or character.tier == nil then
        return 100
    end
    return character.level + character.tier * 10
end

--
-- Inventory Plugin Integration
--

function get_weapon_list(search_query)
    local rc, result = CallPlugin(inventory_plugin_id, "SearchAndReturn", search_query)
    if rc == 0 then
        Debug("CallPlugin result: " .. result)
        local weapon_data = loadstring(string.format("return %s", result))()
        return weapon_data
    else
        Error("Failed to call inventory plugin")
        return nil
    end
end

function get_all_weapons()
    return get_weapon_list("type weapon")
end

function get_current_wielded_weapon()
    -- Get currently wielded weapon
    local weapons = get_all_weapons()
    if not weapons or not weapons.items then
        return nil
    end
    
    for _, weapon in ipairs(weapons.items) do
        if weapon.objectLocation == "wielded" then
            return weapon
        end
    end
    
    return nil
end

function get_current_second_weapon()
    -- Get currently wielded second weapon
    local weapons = get_all_weapons()
    if not weapons or not weapons.items then
        return nil
    end
    
    for _, weapon in ipairs(weapons.items) do
        if weapon.objectLocation == "second" then
            return weapon
        end
    end
    
    return nil
end

--
-- Weapon Selection Logic
--

function get_best_weapons_by_damage_type()
    local weapons = get_all_weapons()
    if not weapons or not weapons.items then
        Error("No weapons found in inventory")
        return nil
    end
    
    local effective_level = get_effective_level()
    local best_weapons = {}
    
    -- Filter and group weapons by damage type
    for _, weapon in ipairs(weapons.items) do
        local weapon_level = tonumber(weapon.stats.level) or 0
        local weapon_damtype = weapon.stats.damtype
        local weapon_avedam = tonumber(weapon.stats.avedam) or 0
        
        -- Only consider weapons the player can wear
        if weapon_level <= effective_level and weapon_damtype then
            -- Normalize damage type to lowercase for consistent lookup
            local damtype_key = string.lower(weapon_damtype)
            
            -- Initialize damage type entry if not exists
            if not best_weapons[damtype_key] then
                best_weapons[damtype_key] = {
                    wielded = nil,
                    second = nil
                }
            end
            
            -- Check if this weapon is better than current best for wielded slot
            if not best_weapons[damtype_key].wielded or 
               weapon_avedam > tonumber(best_weapons[damtype_key].wielded.stats.avedam or 0) then
                -- Move current wielded to second if it exists
                if best_weapons[damtype_key].wielded then
                    best_weapons[damtype_key].second = best_weapons[damtype_key].wielded
                end
                best_weapons[damtype_key].wielded = weapon
            -- Check if this weapon is better than current second
            elseif not best_weapons[damtype_key].second or
                   weapon_avedam > tonumber(best_weapons[damtype_key].second.stats.avedam or 0) then
                best_weapons[damtype_key].second = weapon
            end
        end
    end
    
    return best_weapons
end

function get_sorted_damage_types(best_weapons)
    -- Get all damage types and sort them alphabetically
    local damage_types = {}
    for damtype, _ in pairs(best_weapons) do
        table.insert(damage_types, damtype)
    end
    table.sort(damage_types)
    return damage_types
end

function get_next_damage_type(current_damtype, damage_types)
    -- Find current damage type in list and return next one (loop to beginning if at end)
    if not current_damtype or #damage_types == 0 then
        return damage_types[1]
    end
    
    for i, damtype in ipairs(damage_types) do
        if damtype == current_damtype then
            -- Return next damage type, or loop to first
            if i < #damage_types then
                return damage_types[i + 1]
            else
                return damage_types[1]
            end
        end
    end
    
    -- Current damage type not found, return first
    return damage_types[1]
end

function can_wear_second_weapon(wielded_weapon, second_weapon)
    -- Check weight constraint: second weapon must be half or less the weight of wielded
    if not wielded_weapon or not second_weapon then
        return false
    end
    
    local wielded_weight = tonumber(wielded_weapon.stats.weight) or 0
    local second_weight = tonumber(second_weapon.stats.weight) or 0
    
    return second_weight <= (wielded_weight / 2)
end

function prepare_weapon_for_wearing(weapon)
    local location = weapon.objectLocation
    
    if location == "inventory" then
        -- Weapon is already in inventory, ready to wear
        return true
    elseif location == "wielded" or location == "second" then
        -- Weapon is already worn, will be removed before re-wearing
        return true
    elseif location == "keyring" then
        -- Weapon is in keyring, get it
        SendNoEcho("keyring get " .. weapon.objid)
        return true
    elseif tonumber(location) then
        -- Weapon is in a bag, get it
        SendNoEcho("get " .. weapon.objid .. " " .. location)
        return true
    else
        Error("Unknown weapon location: " .. tostring(location))
        return false
    end
end

function equip_weapons(wielded_weapon, second_weapon, target_damtype)
    -- Remove current weapons first
    SendNoEcho("remove wielded")
    SendNoEcho("remove second")
    
    -- Add blank line before output
    Note("")
    
    -- Prepare and equip wielded weapon
    if wielded_weapon then
        if prepare_weapon_for_wearing(wielded_weapon) then
            SendNoEcho("wear " .. wielded_weapon.objid .. " wielded")
            Message(string.format("Switched to @Y%s@w damage type", target_damtype))
            Message(string.format("  Wielded: @C%s@w (Avg: @Y%d@w)", 
                strip_colours(wielded_weapon.stats.name or "Unknown"),
                tonumber(wielded_weapon.stats.avedam) or 0))
        else
            Error("Failed to prepare wielded weapon")
            Note("")
            return
        end
    end
    
    -- Try to equip second weapon if weight allows
    if second_weapon then
        if can_wear_second_weapon(wielded_weapon, second_weapon) then
            if prepare_weapon_for_wearing(second_weapon) then
                SendNoEcho("wear " .. second_weapon.objid .. " second")
                Message(string.format("  Second:  @C%s@w (Avg: @Y%d@w)", 
                    strip_colours(second_weapon.stats.name or "Unknown"),
                    tonumber(second_weapon.stats.avedam) or 0))
            else
                Debug("Failed to prepare second weapon")
            end
        else
            Debug("Second weapon too heavy, skipping")
        end
    end
    
    -- Add blank line after output
    Note("")
end

--
-- Alias Handlers
--

function alias_switch(name, line, wildcards)
    local target = wildcards[1]
    
    if not target or target == "" then
        -- No argument, cycle to next damage type
        switch_to_next_damage_type()
    elseif string.lower(target) == "status" then
        -- Show status
        show_weapon_status()
    elseif string.lower(target) == "help" then
        -- Show help
        alias_switch_help(name, line, wildcards)
    elseif string.lower(target) == "update" then
        -- Update plugin
        alias_update_plugin(name, line, wildcards)
    elseif string.lower(target) == "reload" then
        -- Reload plugin
        alias_reload_plugin(name, line, wildcards)
    else
        -- Switch to specific damage type
        switch_to_damage_type(target)
    end
end

function switch_to_next_damage_type()
    local best_weapons = get_best_weapons_by_damage_type()
    if not best_weapons or next(best_weapons) == nil then
        Error("No weapons available")
        return
    end
    
    local damage_types = get_sorted_damage_types(best_weapons)
    
    -- Get current wielded weapon to determine current damage type
    local current_weapon = get_current_wielded_weapon()
    local current_damtype = nil
    if current_weapon and current_weapon.stats then
        current_damtype = string.lower(current_weapon.stats.damtype)
    end
    
    -- Get next damage type
    local next_damtype = get_next_damage_type(current_damtype, damage_types)
    
    -- Equip weapons for next damage type
    local weapons = best_weapons[next_damtype]
    if weapons then
        equip_weapons(weapons.wielded, weapons.second, next_damtype)
        current_damage_type = next_damtype
    else
        Error("No weapons found for damage type: " .. next_damtype)
    end
end

function switch_to_damage_type(target_damtype)
    target_damtype = string.lower(target_damtype)
    
    local best_weapons = get_best_weapons_by_damage_type()
    if not best_weapons or next(best_weapons) == nil then
        Error("No weapons available")
        return
    end
    
    -- Check if damage type exists
    if not best_weapons[target_damtype] then
        Error(string.format("No weapons found for damage type: @Y%s@w", target_damtype))
        return
    end
    
    -- Equip weapons for target damage type
    local weapons = best_weapons[target_damtype]
    equip_weapons(weapons.wielded, weapons.second, target_damtype)
    current_damage_type = target_damtype
end

function show_weapon_status()
    local best_weapons = get_best_weapons_by_damage_type()
    if not best_weapons or next(best_weapons) == nil then
        Error("No weapons available")
        return
    end
    
    local damage_types = get_sorted_damage_types(best_weapons)
    
    -- Get current wielded weapon to determine current damage type
    local current_weapon = get_current_wielded_weapon()
    local current_damtype = nil
    if current_weapon and current_weapon.stats then
        current_damtype = string.lower(current_weapon.stats.damtype)
    end
    
    Note("")
    Message("@WBest Weapons by Damage Type:@w")
    TableNote("")
    TableNote("=" .. string.rep("=", 91))
    TableNote(string.format("@W%-13s| %-9s| %-36s| %-6s| %-7s| %-7s@w", "Damage Type", "Slot", "Weapon Name", "Level", "Avg", "Weight"))
    TableNote("-" .. string.rep("-", 91))
    
    for _, damtype in ipairs(damage_types) do
        local weapons = best_weapons[damtype]
        local wielded = weapons.wielded
        local second = weapons.second
        local is_current = (damtype == current_damtype) and "@G*@w" or " "
        
        -- Show wielded weapon
        if wielded then
            local weapon_name = strip_colours(wielded.stats.name or "Unknown")
            local weapon_level = tonumber(wielded.stats.level) or 0
            local weapon_avedam = tonumber(wielded.stats.avedam) or 0
            local weapon_weight = tonumber(wielded.stats.weight) or 0
            
            -- Truncate name if too long
            if string.len(weapon_name) > 36 then
                weapon_name = string.sub(weapon_name, 1, 33) .. "..."
            end
            
            local name_padding = string.rep(" ", math.max(0, 36 - string.len(weapon_name)))
            
            local formatted_line = string.format("%s @Y%-11s@w| @CWielded  @w| %s%s| @C%-6d@w| @M%-7d@w| @W%-7d@w",
                is_current,
                damtype,
                weapon_name,
                name_padding,
                weapon_level,
                weapon_avedam,
                weapon_weight)
            
            TableNote(formatted_line)
            
            -- Show second weapon if it can be dual wielded
            if second and can_wear_second_weapon(wielded, second) then
                local second_name = strip_colours(second.stats.name or "Unknown")
                local second_level = tonumber(second.stats.level) or 0
                local second_avedam = tonumber(second.stats.avedam) or 0
                local second_weight = tonumber(second.stats.weight) or 0
                
                -- Truncate name if too long
                if string.len(second_name) > 36 then
                    second_name = string.sub(second_name, 1, 33) .. "..."
                end
                
                local second_name_padding = string.rep(" ", math.max(0, 36 - string.len(second_name)))
                
                local second_line = string.format("  %-11s| @cSecond   @w| %s%s| @C%-6d@w| @M%-7d@w| @W%-7d@w",
                    "",
                    second_name,
                    second_name_padding,
                    second_level,
                    second_avedam,
                    second_weight)
                
                TableNote(second_line)
            end
        end
    end
    
    TableNote("=" .. string.rep("=", 91))
    TableNote("")
    if current_damtype then
        Message(string.format("@WCurrent damage type: @Y%s@w (@G*@w = currently equipped)", current_damtype))
    else
        Message("@WNo weapon currently equipped@w")
    end
    Note("")
end

function alias_switch_help(name, line, wildcards)
    Message([[@WCommands:@w

  @Wswitch                 @w- Cycle to next damage type
  @Wswitch <damage_type>   @w- Switch to specific damage type
  @Wswitch status          @w- Show best weapons for each damage type
  @Wswitch help            @w- Show this help message
  @Wswitch update          @w- Update to latest version
  @Wswitch reload          @w- Reload the plugin

@WDescription:@w
This plugin automatically switches between weapons based on damage type.
It finds the best weapons (by average damage) for each damage type that
you can currently wear, and cycles through them when you type 'switch'.

The plugin prioritizes keeping weapons in both wielded and second slots,
but will remove the second weapon if weight constraints prevent dual
wielding (second weapon must be half the weight or less of wielded).

@WExamples:@w
  @Gswitch@w              - Switch to next damage type
  @Gswitch fire@w         - Switch to fire damage weapons
  @Gswitch status@w       - Show all available damage types
]])
end

--
-- Print methods
--

function Message(str)
    AnsiNote(stylesToANSI(ColoursToStyles(string.format("@C[@GSwitch@C] %s@w", str))))
end

function TableNote(str)
    AnsiNote(stylesToANSI(ColoursToStyles(str)))
end

function Debug(str)
    if debug_mode == 1 then
        Message(string.format("@gDEBUG@w %s", str))
    end
end

function Error(str)
    Message(string.format("@RERROR@w %s", str))
end

--
-- Update code
--

async = require "async"

local version_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Switch-Weapons/refs/heads/main/VERSION"
local plugin_base_url = "https://raw.githubusercontent.com/AardPlugins/Aardwolf-Switch-Weapons/refs"
local plugin_files = {
    {
        remote_file = "Aardwolf_Switch_Weapons.xml",
        local_file =  GetPluginInfo(GetPluginID(), 6),
        update_page= ""
    },
    {
        remote_file = "Aardwolf_Switch_Weapons.lua",
        local_file =  GetPluginInfo(GetPluginID(), 20) .. "Aardwolf_Switch_Weapons.lua",
        update_page= ""
    }
}
local download_file_index = 0
local download_file_branch = ""
local plugin_version = GetPluginInfo(GetPluginID(), 19)

function download_file(url, callback)
    Debug("Starting download of " .. url)
    -- Add timestamp as a query parameter to bust cache
    url = url .. "?t=" .. GetInfo(304)
    async.doAsyncRemoteRequest(url, callback, "HTTPS")
end

function alias_reload_plugin(name, line, wildcards)
    Message("Reloading plugin")
    reload_plugin()
end

function alias_update_plugin(name, line, wildcards)
    Debug("Checking version to see if there is an update")
    download_file(version_url, check_version_callback)
end

function check_version_callback(retval, page, status, headers, full_status, request_url)
    if status ~= 200 then
        Error("Error while fetching latest version number")
        return
    end

    local upstream_version = Trim(page)
    if upstream_version == tostring(plugin_version) then
        Message("@WNo new updates available")
        return
    end

    Message("@WUpdating to version " .. upstream_version)

    local branch = "tags/v" .. upstream_version
    download_plugin(branch)
end

function alias_force_update_plugin(name, line, wildcards)
    local branch = "main"

    if wildcards.branch and wildcards.branch ~= "" then
        branch = wildcards.branch
    end

    Message("@WForcing updating to branch " .. branch)

    branch = "heads/" .. branch
    download_plugin(branch)
end

function download_plugin(branch)
    Debug("Downloading plugin branch " .. branch)
    download_file_index = 0
    download_file_branch = branch

    download_next_file()
end

function download_next_file()
    download_file_index = download_file_index + 1

    if download_file_index > #plugin_files then
        Debug("All plugin files downloaded")
        finish_update()
        return
    end

    local url = string.format("%s/%s/%s", plugin_base_url, download_file_branch, plugin_files[download_file_index].remote_file)
    download_file(url, download_file_callback)
end

function download_file_callback(retval, page, status, headers, full_status, request_url)
    if status ~= 200 then
        Error("Error while fetching the plugin")
        return
    end

    plugin_files[download_file_index].update_page = page

    download_next_file()
end

function finish_update()
    Message("@WUpdating plugin. Do not touch anything!")

    -- Write all downloaded files to disk
    for i, plugin_file in ipairs(plugin_files) do
        local file = io.open(plugin_file.local_file, "w")
        file:write(plugin_file.update_page)
        file:close()
    end

    reload_plugin()

    Message("@WUpdate complete!")
end

function reload_plugin()
    if GetAlphaOption("script_prefix") == "" then
        SetAlphaOption("script_prefix", "\\\\\\")
    end
    Execute(
        GetAlphaOption("script_prefix") .. 'DoAfterSpecial(0.5, "ReloadPlugin(\'' .. GetPluginID() .. '\')", sendto.script)'
    )
end
