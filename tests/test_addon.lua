-- Exercise actual addon callbacks with strict stubs for the Ashita/ImGui APIs.
local events, buttons, texts = {}, {}, {}
local selections, rendered_colors = {}, {}
local current, active = 100, 1
local event_active, render_count = 0, 0
local window_x,window_y,mouse_down = 100,100,false
local login_status, target_index, entity_present = 2, 1, true
GetPlayerEntity = function() if entity_present then return {} end end
addon = {}
T = function(v) return v end
bit = require('bit')
ImGuiWindowFlags_AlwaysAutoResize = 1
ImGuiWindowFlags_NoCollapse = 2
ImGuiCond_Always = 1
package.preload.common = function() return {} end
local config
package.preload.settings = function()
    return {
        load = function(defaults) config = config or defaults; return config end,
        save = function() end,
        register = function() end,
    }
end
local ui = {}
ui.GetWindowPos = function() return window_x,window_y end
ui.SetNextWindowPos = function(pos) window_x,window_y=pos[1],pos[2] end
ui.IsMouseDown = function() return mouse_down end
for _, key in ipairs({ 'PushID', 'PopID', 'SetNextItemWidth', 'SetNextWindowSize', 'SetItemDefaultFocus', 'EndCombo',
                        'Separator', 'EndChild', 'SameLine', 'PushItemWidth', 'PopItemWidth', 'End' }) do
    ui[key] = function() end
end
for _, key in ipairs({ 'Text', 'TextWrapped', 'TextDisabled' }) do ui[key] = function(s) texts[#texts+1] = s end end
ui.Begin = function() render_count = render_count + 1; return true end
ui.BeginChild = function() return true end
ui.BeginCombo = function() return true end
ui.CollapsingHeader = function() return true end
ui.InputText = function(_, buf, size) assert(type(buf[1]) == 'string' and size > 0); return false end
ui.Selectable = function(label) local hit=selections[label]; selections[label]=nil; return hit or false end
ui.RadioButton = function() return false end
ui.Checkbox = function() return false end
ui.Button = function(label) local hit = buttons[label]; buttons[label] = nil; return hit or false end
-- Resolve real ImGui constant names used by the skin, with strict stack counts.
local colors, vars, children = 0, 0, 0
local source = assert(io.open('ui.lua')):read('*a')
for constant in source:gmatch('(ImGui[%w_]+)') do if _G[constant] == nil then _G[constant] = 1 end end
ui.PushStyleColor = function() colors = colors + 1 end
ui.PopStyleColor = function(n) colors = colors - (n or 1); assert(colors >= 0) end
ui.PushStyleVar = function() vars = vars + 1 end
ui.PopStyleVar = function(n) vars = vars - (n or 1); assert(vars >= 0) end
ui.TextColored = function(color, value) texts[#texts+1] = value; rendered_colors[value]=color end
ui.TextUnformatted = function(value) texts[#texts+1] = value end
ui.Dummy = function() end
ui.GetCursorScreenPos = function() return 10, 10 end
ui.GetWindowDrawList = function() return { AddRectFilled = function() end } end
ui.GetColorU32 = function() return 0 end
ui.IsItemHovered = function() return true end
ui.BeginTooltip = function() end
ui.EndTooltip = function() end
ui.PushTextWrapPos = function() end
ui.PopTextWrapPos = function() end
ui.BeginChild = function() children = children + 1; return true end
ui.EndChild = function() children = children - 1; assert(children >= 0) end
package.preload.imgui = function() return ui end
ashita = { events = { register = function(kind, _, fn) events[kind] = fn end } }
ashita.memory = {
    find = function() return 1000 end,
    read_uint32 = function(address) assert(address == 1001); return 2000 end,
    read_uint8 = function(address) assert(address == 2000); return event_active end,
}
local party = { GetMemberZone = function() return current end, GetMemberIsActive = function() return active end,
                GetMemberServerId = function() return active end, GetMemberTargetIndex = function() return target_index end }
local player = { GetLoginStatus = function() return login_status end }
AshitaCore = { GetMemoryManager = function() return { GetParty = function() return party end, GetPlayer = function() return player end } end }
assert(loadfile('TravelPlanner.lua'))()
events.d3d_present()
buttons['Plan route'] = true; events.d3d_present()
events.d3d_present()
local route_summary
for _,value in ipairs(texts) do if value:match('^%d+ CHANGES$') then route_summary=value end end
assert(route_summary, 'Fixture has a planned route')
texts={}
selections['Ember##palette']=true; events.d3d_present(); events.d3d_present()
assert(config.accent_primary=='Coral red' and config.accent_secondary=='Gold')
assert(rendered_colors.TRAVEL[1]==1 and rendered_colors.PLANNER[2]==0.77)
selections['Green##accent_primary']=true; events.d3d_present(); events.d3d_present()
assert(config.accent_primary=='Green' and config.accent_secondary=='Gold', 'Accents change independently')
assert(rendered_colors.TRAVEL[2]==0.86)
local retained=false
for _,value in ipairs(texts) do if value==route_summary then retained=true end end
assert(retained, 'Appearance changes preserve the planned route')
buttons.Collapse = true; events.d3d_present(); events.d3d_present()
assert(rendered_colors.TRAVEL[2]==0.86 and rendered_colors.PLANNER[2]==0.77, 'Compact view shares palette')
assert(config.collapsed)
window_x,window_y=900,60; events.d3d_present()
assert(config.collapsed_position.x==900 and config.collapsed_position.y==60)
buttons.Expand=true; events.d3d_present(); events.d3d_present()
assert(window_x==100 and window_y==100, 'Expanded position restores independently')
mouse_down=true; window_x,window_y=250,200; events.d3d_present()
mouse_down=false; events.d3d_present()
events.command({command='/tp collapse'}); events.d3d_present()
assert(window_x==900 and window_y==60, 'Command collapse restores compact position')
events.command({command='/tp expand'}); events.d3d_present()
assert(window_x==250 and window_y==200, 'Expanded drag must not change compact position')
package.loaded.ui=nil
assert(loadfile('TravelPlanner.lua'))()
events.d3d_present()
assert(window_x==250 and window_y==200, 'Saved position restores after UI reload')
assert(config.accent_primary=='Green' and config.accent_secondary=='Gold', 'Accents survive UI reload')
for _, collapsed in ipairs({ false, true }) do
    config.collapsed = collapsed
    local before = render_count
    event_active = 1; events.d3d_present()
    assert(render_count == before and config.visible and config.collapsed == collapsed, 'Cutscene hides without changing preferences')
    event_active = 0; events.d3d_present()
    assert(render_count == before + 1, 'Window returns after cutscene')
end
current = 102; events.d3d_present()
events.command({ command = '/tp expand' }); events.d3d_present()
assert(not config.collapsed)
config.current_start = false; events.d3d_present()
config.mode = 'safest'; buttons['Plan route'] = true; events.d3d_present(); events.d3d_present()
for _, collapsed in ipairs({ false, true }) do
    config.collapsed = collapsed
    local before = render_count
    -- Stale party data must not make the title or character-selection UI render.
    for _, status in ipairs({ 0, 1, 3 }) do
        login_status = status; events.d3d_present()
        assert(render_count == before and config.visible, 'Hide outside logged-in world')
    end
    login_status = 2; target_index = 0; events.d3d_present()
    assert(render_count == before, 'Hide when player target is unavailable')
    target_index = 1; entity_present = false; events.d3d_present()
    assert(render_count == before, 'Hide while zoning without a player entity')
    entity_present = true; active = 0; events.d3d_present()
    assert(render_count == before, 'Hide when party player is inactive')
    active = 1; events.d3d_present()
    assert(render_count == before + 1 and config.collapsed == collapsed, 'Restore previous mode on world entry')
end
local unrelated = { command = '/targetnpc' }; events.command(unrelated); assert(not unrelated.blocked)
local command = { command = '/tp hide' }; events.command(command); assert(command.blocked and not config.visible)
local before = render_count
event_active = 1; events.d3d_present()
event_active = 0; events.d3d_present()
assert(render_count == before and not config.visible, 'Manually hidden window stays hidden after cutscene')
assert(colors == 0 and vars == 0 and children == 0, "UI state must not leak into other addons")
events.unload()
print('PASS: addon load, expanded/collapsed UI, plan, zone changes, logout and command callbacks with strict API stubs.')
