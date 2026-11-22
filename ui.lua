-- TravelPlanner's self-contained ImGui skin. No VanaCore or external assets.
local imgui = require('imgui')
local planner = require('planner')
local M = {}
local C = {
    bg = {0.035,0.043,0.065,0.98}, panel = {0.064,0.075,0.11,1},
    card = {0.089,0.104,0.15,1}, border = {0.17,0.20,0.29,1},
    text = {0.88,0.91,0.97,1}, muted = {0.49,0.55,0.68,1},
    cyan = {0.29,0.83,0.96,1}, violet = {0.62,0.48,1,1},
    green = {0.30,0.86,0.62,1}, gold = {1,0.77,0.36,1},
}
local filters = { start = { region = 'All', search = {''} }, destination = { region = 'All', search = {''} } }
local regions
local position_config, position_mode
local position_dirty = false
-- Bright accents selected for readability on the dark panels.
local palette = {
    {'Cyan', {0.29,0.83,0.96,1}}, {'Violet', {0.70,0.60,1,1}},
    {'Coral red', {1,0.46,0.49,1}}, {'Gold', {1,0.77,0.36,1}},
    {'Green', {0.30,0.86,0.62,1}}, {'Sky blue', {0.43,0.70,1,1}},
    {'Rose', {1,0.55,0.78,1}}, {'Silver', {0.79,0.84,0.94,1}},
}
local presets = {
    {'Aurora','Cyan','Violet'}, {'Ember','Coral red','Gold'},
    {'Forest','Green','Gold'}, {'Ocean','Sky blue','Cyan'},
    {'Twilight','Violet','Rose'}, {'Moonlight','Silver','Sky blue'},
}
local function accent(value, fallback)
    for _,entry in ipairs(palette) do if entry[1]==value then return entry[2] end end
    return fallback
end
local function tint(color, amount)
    return {C.card[1]*(1-amount)+color[1]*amount,
        C.card[2]*(1-amount)+color[2]*amount,C.card[3]*(1-amount)+color[3]*amount,1}
end
local function appearance(config, save)
    if not imgui.CollapsingHeader('Appearance') then return end
    local selected='Custom'
    for _,p in ipairs(presets) do
        if config.accent_primary==p[2] and config.accent_secondary==p[3] then selected=p[1] end
    end
    imgui.SetNextItemWidth(220)
    if imgui.BeginCombo('Palette',selected) then
        for _,p in ipairs(presets) do
            if imgui.Selectable(p[1]..'##palette',selected==p[1]) then
                config.accent_primary=p[2]; config.accent_secondary=p[3]; save()
            end
        end
        imgui.EndCombo()
    end
    for _,field in ipairs({{'Primary accent','accent_primary'},{'Secondary accent','accent_secondary'}}) do
        imgui.SetNextItemWidth(220)
        if imgui.BeginCombo(field[1],config[field[2]]) then
            for _,entry in ipairs(palette) do
                imgui.PushStyleColor(ImGuiCol_Text,entry[2])
                if imgui.Selectable(entry[1]..'##'..field[2],config[field[2]]==entry[1]) then
                    config[field[2]]=entry[1]; save()
                end
                imgui.PopStyleColor()
            end
            imgui.EndCombo()
        end
    end
    imgui.TextWrapped('Mix any two accents. Colors are tuned for the dark background; access warnings remain gold and completed stops remain green.')
end
local function text(color, value) imgui.TextColored(color, value) end
local function wrapped(color, value)
    imgui.PushStyleColor(ImGuiCol_Text, color); imgui.TextWrapped(value); imgui.PopStyleColor()
end
local function space(n) imgui.Dummy({0,n or 6}) end
local function section(value) space(4); text(C.violet, value); space(2) end
local function name(zones, id) return zones[id] and zones[id].name or 'Unavailable' end

local function push_theme()
    local colors = {
        {ImGuiCol_WindowBg,C.bg}, {ImGuiCol_ChildBg,C.panel}, {ImGuiCol_PopupBg,C.panel},
        {ImGuiCol_Text,C.text}, {ImGuiCol_TextDisabled,C.muted}, {ImGuiCol_Border,C.border},
        {ImGuiCol_FrameBg,C.bg}, {ImGuiCol_FrameBgHovered,C.card}, {ImGuiCol_FrameBgActive,C.card},
        {ImGuiCol_Button,C.card}, {ImGuiCol_ButtonHovered,tint(C.cyan,0.20)},
        {ImGuiCol_ButtonActive,tint(C.cyan,0.30)}, {ImGuiCol_CheckMark,C.cyan},
        {ImGuiCol_Header,C.card}, {ImGuiCol_HeaderHovered,tint(C.violet,0.20)},
        {ImGuiCol_HeaderActive,tint(C.violet,0.30)}, {ImGuiCol_Separator,C.border},
        {ImGuiCol_ScrollbarBg,C.panel}, {ImGuiCol_ScrollbarGrab,C.border},
        {ImGuiCol_ScrollbarGrabHovered,C.muted}, {ImGuiCol_ScrollbarGrabActive,C.violet},
    }
    local vars = {
        {ImGuiStyleVar_WindowPadding,{18,16}}, {ImGuiStyleVar_FramePadding,{10,7}},
        {ImGuiStyleVar_ItemSpacing,{8,8}}, {ImGuiStyleVar_WindowRounding,14},
        {ImGuiStyleVar_ChildRounding,10}, {ImGuiStyleVar_FrameRounding,6},
        {ImGuiStyleVar_WindowBorderSize,1}, {ImGuiStyleVar_FrameBorderSize,1},
        {ImGuiStyleVar_ScrollbarSize,9},
    }
    for _, v in ipairs(colors) do imgui.PushStyleColor(v[1],v[2]) end
    for _, v in ipairs(vars) do imgui.PushStyleVar(v[1],v[2]) end
    return #colors, #vars
end

local function gradient(width)
    local a,b = imgui.GetCursorScreenPos()
    local x,y = a,b
    if type(a) == 'table' then x,y = a.x or a[1],a.y or a[2] end
    local dl = imgui.GetWindowDrawList()
    for i = 0,39 do
        local t = i/39
        local color = {C.cyan[1]*(1-t)+C.violet[1]*t,C.cyan[2]*(1-t)+C.violet[2]*t,C.cyan[3]*(1-t)+C.violet[3]*t,0.9}
        dl:AddRectFilled({x+i*width/40,y},{x+(i+1)*width/40+1,y+2},imgui.GetColorU32(color))
    end
    space(8)
end

local function button(label, selected, size)
    if selected then
        imgui.PushStyleColor(ImGuiCol_Button,tint(C.cyan,0.15))
        imgui.PushStyleColor(ImGuiCol_Text,C.cyan)
        imgui.PushStyleColor(ImGuiCol_Border,C.cyan)
    end
    local hit = imgui.Button(label,size)
    if selected then imgui.PopStyleColor(3) end
    return hit
end

local function selector(key, config, zones, changed)
    local f = filters[key]
    imgui.PushID(key)
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo('##region',f.region) then
        for _, r in ipairs(regions) do if imgui.Selectable(r,f.region==r) then f.region=r end end
        imgui.EndCombo()
    end
    text(C.muted,'Search zones')
    imgui.SetNextItemWidth(-1); imgui.InputText('##search',f.search,128)
    imgui.SetNextItemWidth(-1)
    if imgui.BeginCombo('##zone',name(zones,config[key])) then
        local choices = planner.filter(zones,f.region,f.search[1])
        if #choices==0 then text(C.muted,'No matching zones') end
        for _, id in ipairs(choices) do
            if imgui.Selectable(zones[id].name..'##'..id,config[key]==id) then config[key]=id; changed() end
            if config[key]==id then imgui.SetItemDefaultFocus() end
        end
        imgui.EndCombo()
    end
    imgui.PopID()
end

local function check(label,key,config,changed)
    local v={config[key]}
    if imgui.Checkbox(label,v) then config[key]=v[1]; changed() end
end

local function next_step(state,zones)
    text(C.muted,'CURRENT ZONE')
    wrapped(C.text,name(zones,state.current))
    space(3)
    local next_id,message=state:next_zone()
    text(C.cyan,next_id and 'NEXT STOP  >' or (state.result and 'ROUTE STATUS' or 'READY TO EXPLORE'))
    wrapped(next_id and C.cyan or C.muted,next_id and name(zones,next_id) or (message or 'Choose a destination to begin.'))
    if next_id and message then wrapped(C.muted,message) end
    local e=state.tracking and state.result and state.result.edges[state.cursor]
    if e then
        if e.kind~='walk' then text(C.violet,'Via '..e.kind) end
        if e.requirement then wrapped(C.gold,'Access: '..e.requirement) end
    end
end

local function route(state,zones)
    local r=state.result
    if not r then
        space(18); text(C.cyan,'YOUR NEXT ADVENTURE')
        wrapped(C.text,'Every journey starts with a destination.')
        space(10); wrapped(C.muted,state.message or 'Choose your zones and select Plan route.')
        space(14); imgui.Separator(); space(8)
        wrapped(C.muted,'Walking routes by default. Enable boats, airships or Maw portals in connection options.')
        return
    end
    local next_id, status = state:next_zone()
    if next_id then
        text(C.muted,state.tracking and 'NEXT STOP' or 'START YOUR JOURNEY AT')
        wrapped(C.cyan,name(zones,next_id)); space(4)
    elseif status then wrapped(C.green,status) end
    text(C.cyan,string.format('%d CHANGES',r.changes)); imgui.SameLine()
    text(C.muted,string.format(' /  AVG %.1f  /  PEAK %.1f',r.average,r.peak))
    if r.unknown>0 then wrapped(C.gold,string.format('%d unknown level(s), scored as 150.',r.unknown)) end
    if state.message then wrapped(C.muted,state.message) end
    if state.job then
        if state.job.error then wrapped(C.gold,state.job.error)
        elseif state.job.paused then wrapped(C.gold,'Best found route / search stopped')
        elseif not state.job.done then
            wrapped(C.gold,'Searching / showing best found route')
            if imgui.Button('Use best found route') then state.job.paused=true end
        else text(C.green,'Lowest route average verified') end
    end
    if state.tracking then
        text(C.muted,string.format('PROGRESS  %d / %d',state.cursor,#r.path))
    else text(C.muted,'ROUTE PREVIEW') end
    space(2)
    for i,id in ipairs(r.path) do
        local current=state.tracking and i==state.cursor
        local done=state.tracking and i<state.cursor
        local accent=current and C.cyan or (done and C.green or C.violet)
        imgui.PushID(i)
        imgui.PushStyleColor(ImGuiCol_ChildBg,current and tint(C.cyan,0.10) or C.card)
        imgui.PushStyleColor(ImGuiCol_Border,current and C.cyan or C.border)
        if imgui.BeginChild('stop',{0,124},true) then
            text(accent,string.format('%02d  %s',i,current and 'YOU ARE HERE' or (done and 'VISITED' or (i==#r.path and 'DESTINATION' or 'WAYPOINT'))))
            wrapped(C.text,name(zones,id))
            local level=zones[id].average_level
            text(C.muted,level and string.format('Zone average  %.1f',level) or 'Zone average  unknown')
            local e=r.edges[i]
            if e and e.requirement then
                imgui.SameLine(); text(C.gold,'Access !')
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip(); imgui.PushTextWrapPos(360)
                    imgui.TextUnformatted(e.requirement); imgui.PopTextWrapPos(); imgui.EndTooltip()
                end
            end
        end
        imgui.EndChild(); imgui.PopStyleColor(2)
        local e=r.edges[i]
        if e and e.kind~='walk' then text(C.violet,'    > '..e.kind) end
        imgui.PopID()
    end
end

function M.draw(state,config,zones,save)
    config.accent_primary=config.accent_primary or 'Cyan'
    config.accent_secondary=config.accent_secondary or 'Violet'
    C.cyan=accent(config.accent_primary,palette[1][2])
    C.violet=accent(config.accent_secondary,palette[2][2])
    if not regions then
        regions={'All'}; local seen={}
        for _,z in pairs(zones) do if not seen[z.region] then seen[z.region]=true; regions[#regions+1]=z.region end end
        table.sort(regions,function(a,b) if a=='All' then return b~='All' elseif b=='All' then return false end return a<b end)
    end
    local function changed() state:invalidate(); save() end
    local nc,nv=push_theme()
    local mini=config.collapsed
    local position_key=mini and 'collapsed_position' or 'expanded_position'
    local position=config[position_key]
    if not position then
        position={x=0,y=0,saved=false}; config[position_key]=position
    end
    -- Restore only on mode/character changes, leaving dragging unconstrained.
    if position_config~=config or position_mode~=mini then
        if position.saved then imgui.SetNextWindowPos({position.x,position.y},ImGuiCond_Always) end
        position_config=config; position_mode=mini; position_dirty=false
    end
    local width=mini and 440 or 840
    imgui.SetNextWindowSize({width,0},ImGuiCond_Always)
    local flags=bit.bor(ImGuiWindowFlags_AlwaysAutoResize,ImGuiWindowFlags_NoCollapse,ImGuiWindowFlags_NoTitleBar)
    local open = {true}
    if imgui.Begin('TravelPlanner',open,flags) then
        local x,y=imgui.GetWindowPos()
        if type(x)=='table' then x,y=x.x or x[1],x.y or x[2] end
        if type(x)=='number' and type(y)=='number' and
            (not position.saved or position.x~=x or position.y~=y) then
            position.x=x; position.y=y; position.saved=true; position_dirty=true
        end
        -- Persist once after dragging, not on every mouse-move frame.
        if position_dirty and not imgui.IsMouseDown(0) then save(); position_dirty=false end
        text(C.cyan,'TRAVEL'); imgui.SameLine(0,5); text(C.violet,'PLANNER')
        imgui.SameLine(width-(mini and 162 or 180))
        if imgui.Button(mini and 'Expand' or 'Collapse') then config.collapsed=not mini; save() end
        imgui.SameLine()
        if imgui.Button('X##close') then config.visible=false; save() end
        text(C.muted,mini and 'ON THE ROAD' or "FIND YOUR WAY THROUGH VANA'DIEL")
        space(4); gradient(width-36)
        if mini then
            next_step(state,zones)
            if state.result and state.tracking then
                space(4); text(C.muted,string.format('%d zone changes remaining',#state.result.path-state.cursor))
            end
            if state.job and not state.job.done then wrapped(C.gold,'Best found route / expand for search status') end
        else
            if imgui.BeginChild('plan_panel',{340,530},true) then
                section('01 / START')
                check('Start in current zone','current_start',config,changed)
                if config.current_start then wrapped(C.cyan,name(zones,state.current))
                else selector('start',config,zones,changed) end
                space(5); imgui.Separator(); section('02 / DESTINATION')
                selector('destination',config,zones,changed)
                space(5); imgui.Separator(); section('03 / ROUTE PREFERENCE')
                if button('Fastest',config.mode=='fastest',{135,36}) then config.mode='fastest'; changed() end
                imgui.SameLine()
                if button('Least dangerous',config.mode=='safest',{150,36}) then config.mode='safest'; changed() end
                wrapped(C.muted,config.mode=='fastest' and 'Fewest zone changes.' or 'Lowest average level across the whole route.')
                space(3)
                if imgui.CollapsingHeader('Connection options') then
                    check('Boats / ferries','boats',config,changed)
                    check('Airships','airships',config,changed)
                    check('Cavernous Maw portals','portals',config,changed)
                    check('Allow access requirements','restricted',config,changed)
                    wrapped(C.muted,'Access is flagged, not checked against your character.')
                end
            end
            imgui.EndChild(); imgui.SameLine()
            if imgui.BeginChild('journey_panel',{0,530},true) then
                section('YOUR JOURNEY'); route(state,zones)
            end
            imgui.EndChild()
            space(3)
            if button('Plan route',true,{180,38}) then state:plan(); save() end
            imgui.SameLine()
            if imgui.Button('Clear route',{120,38}) then state:invalidate() end
            imgui.SameLine(); text(C.muted,'WALK / EXPLORE / ARRIVE')
            appearance(config,save)
            if imgui.CollapsingHeader('Data and routing notes') then
                wrapped(C.muted,'LandSandBoat data may differ from CatsEyeXI. Route averages include start and destination; low-level detours can reduce the score. Unknown levels score 150.')
                wrapped(C.muted,'Zone routes do not model all interior gates, separate map sections or access requirements. Hover an Access ! label for details. PEAK is the highest zone average, not the strongest monster.')
            end
        end
    end
    imgui.End()
    if not open[1] then config.visible=false; save() end
    imgui.PopStyleVar(nv); imgui.PopStyleColor(nc)
end

return M
