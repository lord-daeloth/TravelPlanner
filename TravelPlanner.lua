addon.name = 'TravelPlanner'
addon.author = 'Daeloth'
addon.version = '1.1.0'
addon.desc = 'Plan routes between Vana\'diel zones.'

require('common')
local ui = require('ui')
local settings = require('settings')
local controller = require('controller')
local zones = require('data.zones')

local defaults = T{
    visible = true, collapsed = false, current_start = true, start = 230, destination = 244,
    mode = 'fastest', boats = false, airships = false, portals = false, restricted = true,
    expanded_position = T{ x = 0, y = 0, saved = false },
    collapsed_position = T{ x = 0, y = 0, saved = false },
    accent_primary = 'Cyan', accent_secondary = 'Violet',
}
local config = settings.load(defaults)
local state = controller.new(zones, config)
local event_pointer

-- Use the same client event flag as Journal and LibraPlates. Only rendering
-- is suppressed; the route and saved visibility preference remain intact.
local function in_cutscene()
    local ok, active = pcall(function()
        if event_pointer == nil then
            event_pointer = ashita.memory.find('FFXiMain.dll', 0,
                'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3', 0, 0) or 0
        end
        if event_pointer == 0 then return false end
        local pointer = ashita.memory.read_uint32(event_pointer + 1)
        return pointer ~= nil and pointer ~= 0 and ashita.memory.read_uint8(pointer) == 1
    end)
    return ok and active
end
settings.register('settings', 'travelplanner_settings', function(updated)
    if updated then config = updated; state = controller.new(zones, config) end
end)

local function save() settings.save() end

ashita.events.register('command', 'travelplanner_command', function(e)
    local command = e.command:lower():match('^%s*(.-)%s*$')
    local root, arg = command:match('^(%S+)%s*(.*)$')
    if root ~= '/travelplanner' and root ~= '/tp' then return end
    e.blocked = true
    if arg == 'show' then config.visible = true
    elseif arg == 'hide' then config.visible = false
    elseif arg == 'collapse' then config.visible = true; config.collapsed = true
    elseif arg == 'expand' then config.visible = true; config.collapsed = false
    elseif arg == 'plan' then config.visible = true; state:plan()
    elseif arg == 'clear' then state:invalidate()
    elseif arg == '' then config.visible = not config.visible
    else print('[TravelPlanner] /tp [show|hide|expand|collapse|plan|clear]') end
    save()
end)

ashita.events.register('d3d_present', 'travelplanner_present', function()
    local memory = AshitaCore:GetMemoryManager()
    local party = memory:GetParty()
    local player = memory:GetPlayer()
    local zone = party and party:GetMemberZone(0) or 0
    -- Login status and a live player distinguish the world from title/character
    -- selection and zoning, even while old party data is still present. Do not
    -- use menu or entity-render flags: the map must not suppress this window.
    if not player or player:GetLoginStatus() ~= 2 or zone == 0 or not party
        or party:GetMemberIsActive(0) == 0 or party:GetMemberServerId(0) == 0
        or party:GetMemberTargetIndex(0) == 0 or GetPlayerEntity() == nil then
        zone = nil
    end
    state:update(zone)
    if zone ~= nil and config.visible and not in_cutscene() then ui.draw(state, config, zones, save) end
end)

ashita.events.register('unload', 'travelplanner_unload', save)
