-- Exercise actual addon callbacks with strict stubs for the Ashita/ImGui APIs.
local events, buttons, texts = {}, {}, {}
local current, active = 100, 1
local event_active, render_count = 0, 0
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
        load = function(defaults) config = defaults; return config end,
        save = function() end,
        register = function() end,
    }
end
local ui = {}
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
ui.Selectable = function() return false end
ui.RadioButton = function() return false end
ui.Checkbox = function() return false end
ui.Button = function(label) local hit = buttons[label]; buttons[label] = nil; return hit or false end
package.preload.imgui = function() return ui end
ashita = { events = { register = function(kind, _, fn) events[kind] = fn end } }
ashita.memory = {
    find = function() return 1000 end,
    read_uint32 = function(address) assert(address == 1001); return 2000 end,
    read_uint8 = function(address) assert(address == 2000); return event_active end,
}
local party = { GetMemberZone = function() return current end, GetMemberIsActive = function() return active end,
                GetMemberServerId = function() return active end }
AshitaCore = { GetMemoryManager = function() return { GetParty = function() return party end } end }
assert(loadfile('TravelPlanner.lua'))()
events.d3d_present()
buttons['Plan route'] = true; events.d3d_present()
buttons.Collapse = true; events.d3d_present(); events.d3d_present()
assert(config.collapsed)
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
active = 0; events.d3d_present()
local found = false
for _, text in ipairs(texts) do if text == 'Current: Unavailable' then found = true end end
assert(found, 'Logged-out state must be unavailable')
local unrelated = { command = '/targetnpc' }; events.command(unrelated); assert(not unrelated.blocked)
local command = { command = '/tp hide' }; events.command(command); assert(command.blocked and not config.visible)
local before = render_count
event_active = 1; events.d3d_present()
event_active = 0; events.d3d_present()
assert(render_count == before and not config.visible, 'Manually hidden window stays hidden after cutscene')
events.unload()
print('PASS: addon load, expanded/collapsed UI, plan, zone changes, logout and command callbacks with strict API stubs.')
