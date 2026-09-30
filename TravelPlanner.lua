addon.name = 'TravelPlanner'
addon.author = 'TravelPlanner contributors'
addon.version = '1.0.1'
addon.desc = 'Plan routes between Vana\'diel zones.'

require('common')
local imgui = require('imgui')
local settings = require('settings')
local planner = require('planner')
local controller = require('controller')
local zones = require('data.zones')

local defaults = T{
    visible = true, collapsed = false, current_start = true, start = 230, destination = 244,
    mode = 'fastest', boats = false, airships = false, portals = false, restricted = true,
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
local filters = { start = { region = 'All', search = { '' } }, destination = { region = 'All', search = { '' } } }
local regions, seen = { 'All' }, {}
for _, zone in pairs(zones) do
    if not seen[zone.region] then regions[#regions + 1] = zone.region; seen[zone.region] = true end
end
table.sort(regions, function(a, b) if a == 'All' then return b ~= 'All' elseif b == 'All' then return false end return a < b end)

settings.register('settings', 'travelplanner_settings', function(updated)
    if updated then config = updated; state = controller.new(zones, config) end
end)

local function name(id)
    if zones[id] then return zones[id].name end
    return id and ('Unknown zone #' .. tostring(id)) or 'Unavailable'
end

local function save() settings.save() end
local function changed() state:invalidate(); save() end

local function checkbox(label, key, affects_route)
    local value = { config[key] }
    if imgui.Checkbox(label, value) then
        config[key] = value[1]
        if affects_route then changed() else save() end
    end
end

local function selector(label, key)
    local filter = filters[key]
    imgui.PushID(key)
    imgui.Text(label)
    imgui.SetNextItemWidth(340)
    if imgui.BeginCombo('Region', filter.region) then
        for _, region in ipairs(regions) do
            if imgui.Selectable(region, filter.region == region) then filter.region = region end
        end
        imgui.EndCombo()
    end
    imgui.SetNextItemWidth(340)
    imgui.InputText('Search', filter.search, 128)
    local choices = planner.filter(zones, filter.region, filter.search[1])
    imgui.SetNextItemWidth(340)
    if imgui.BeginCombo('Zone', name(config[key])) then
        if #choices == 0 then imgui.TextDisabled('No zones match these filters.') end
        for _, id in ipairs(choices) do
            if imgui.Selectable(zones[id].name .. '##' .. id, config[key] == id) then config[key] = id; changed() end
            if config[key] == id then imgui.SetItemDefaultFocus() end
        end
        imgui.EndCombo()
    end
    imgui.PopID()
end

local function summary()
    local next_id, message = state:next_zone()
    imgui.Text('Current: ' .. name(state.current))
    if next_id then imgui.Text('Next:    ' .. name(next_id)) end
    if message then imgui.TextWrapped(message) end
    if state.tracking and state.result then
        local edge = state.result.edges[state.cursor]
        if edge then
            if edge.kind ~= 'walk' then imgui.Text('Travel: ' .. edge.kind) end
            if edge.requirement then imgui.TextWrapped('Access: ' .. edge.requirement) end
        end
    end
end

local function route_view()
    local route = state.result
    if not route then imgui.TextWrapped(state.message or 'No route planned.'); return end
    summary()
    if state.message then imgui.TextWrapped(state.message) end
    imgui.Separator()
    imgui.TextWrapped(string.format('%d zone changes  |  Route average %.1f  |  Highest zone average %.1f',
        route.changes, route.average, route.peak))
    if route.unknown > 0 then imgui.TextWrapped(string.format('%d unknown zone level(s), scored as 150.', route.unknown)) end
    if state.job then
        if state.job.error then
            imgui.TextWrapped('Search error: ' .. state.job.error)
        elseif state.job.paused then
            imgui.TextWrapped('Best found route. Search stopped; minimum average has not been proven.')
        elseif not state.job.done then
            imgui.Text(string.format('Searching: best found so far (%d paths explored).', state.job.examined))
            if imgui.Button('Use best found route') then state.job.paused = true end
        else imgui.TextDisabled('Lowest average verified for the available graph and options.') end
    end
    imgui.BeginChild('route_steps', { 0, 230 }, true)
    for i, id in ipairs(route.path) do
        local zone = zones[id]
        local prefix = (state.tracking and i == state.cursor) and '> ' or '  '
        local level = zone.average_level and string.format('%.1f', zone.average_level) or '?'
        imgui.Text(string.format('%s%d. %s  [Lv %s]', prefix, i, zone.name, level))
        local edge = route.edges[i]
        if edge then
            if edge.kind ~= 'walk' then imgui.TextDisabled('     Via ' .. edge.kind) end
            if edge.requirement then imgui.TextWrapped('     Access: ' .. edge.requirement) end
        end
    end
    imgui.EndChild()
end

local function draw()
    if not config.visible or in_cutscene() then return end
    local open = { true }
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse)
    imgui.SetNextWindowSize({ config.collapsed and 380 or 580, 0 }, ImGuiCond_Always)
    if imgui.Begin('TravelPlanner', open, flags) then
        imgui.PushItemWidth(340)
        if config.collapsed then
            summary()
            if state.job and not state.job.done then imgui.TextDisabled('Best found route; expand for search status.') end
            if imgui.Button('Expand') then config.collapsed = false; save() end
        else
            if imgui.Button('Collapse') then config.collapsed = true; save() end
            imgui.SameLine(); imgui.TextDisabled('Vana\'diel route planner')
            imgui.Separator()
            checkbox('Start in current zone', 'current_start', true)
            if config.current_start then imgui.Text('Starting zone: ' .. name(state.current))
            else selector('Starting zone', 'start') end
            imgui.Separator()
            selector('Destination', 'destination')
            imgui.Separator()
            if imgui.RadioButton('Fastest (fewest zone changes)', config.mode == 'fastest') then config.mode = 'fastest'; changed() end
            if imgui.RadioButton('Least dangerous (lowest route average)', config.mode == 'safest') then config.mode = 'safest'; changed() end
            if imgui.CollapsingHeader('Connection options') then
                imgui.TextDisabled('Walking is always enabled. Optional connections:')
                checkbox('Boats / ferries', 'boats', true)
                checkbox('Airships', 'airships', true)
                checkbox('Cavernous Maw portals', 'portals', true)
                checkbox('Allow connections with access requirements', 'restricted', true)
                imgui.TextWrapped('Requirements are flagged, not checked against your character. Enable only travel you can use.')
            end
            if imgui.Button('Plan route', { 130, 0 }) then state:plan(); save() end
            imgui.SameLine()
            if imgui.Button('Clear route') then state:invalidate() end
            imgui.Separator()
            route_view()
            if imgui.CollapsingHeader('Data and routing notes') then
                imgui.TextWrapped('Offline LandSandBoat data. CatsEyeXI levels and access may differ. Missing levels are unknown, not safe.')
                imgui.TextWrapped('Route average includes every zone, including start and destination. No zone repeats; ties prefer fewer changes. Low-level detours can reduce the average.')
                imgui.TextWrapped('A zone connection graph does not model separate map sections, locked interior doors or exact walking directions. Verify dungeon passage. Connections and access notes are not exhaustive.')
            end
        end
        imgui.PopItemWidth()
    end
    imgui.End()
    if not open[1] then config.visible = false; save() end
end

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
    local party = AshitaCore:GetMemoryManager():GetParty()
    local zone = party and party:GetMemberZone(0) or 0
    if zone == 0 or not party or party:GetMemberIsActive(0) == 0 or party:GetMemberServerId(0) == 0 then zone = nil end
    state:update(zone)
    draw()
end)

ashita.events.register('unload', 'travelplanner_unload', save)
