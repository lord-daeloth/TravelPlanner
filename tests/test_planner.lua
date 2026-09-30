local planner = require('planner')
local controller = require('controller')
local count = 0
local function check(value, message)
    count = count + 1
    assert(value, message or ('Check ' .. count .. ' failed'))
end
local function zone(level, edges)
    local z = { name = 'Test', region = 'Test', average_level = level, connections = {} }
    for _, id in ipairs(edges or {}) do z.connections[#z.connections + 1] = { to = id, kind = 'walk' } end
    return z
end

local graph = { [1] = zone(0, { 2, 3 }), [2] = zone(80, { 4 }), [3] = zone(10, { 5 }),
                [4] = zone(10), [5] = zone(10, { 4 }) }
local fast = planner.route(graph, 1, 4, 'fastest')
check(fast.changes == 2 and fast.path[2] == 2, 'BFS must minimize zone changes')
local safe = planner.route(graph, 1, 4, 'safest')
check(safe.changes == 3 and safe.path[2] == 3 and safe.average == 7.5, 'Average objective')
check(planner.route(graph, 4, 1, 'fastest') == nil, 'Directed edges')
check(planner.route(graph, 99, 1, 'fastest') == nil, 'Unknown zone')
check(planner.route(graph, 1, 1, 'safest').changes == 0, 'Already there')

graph[1].connections = { { to = 4, kind = 'boat', requirement = 'Fare' } }
check(planner.route(graph, 1, 4, 'fastest') == nil, 'Walking default')
check(planner.route(graph, 1, 4, 'fastest', { kinds = { boat = true }, allow_restricted = false }) == nil, 'Requirements filter')
check(planner.route(graph, 1, 4, 'fastest', { kinds = { boat = true } }).changes == 1, 'Optional transport')
graph[4].average_level = nil
check(planner.route(graph, 1, 4, 'fastest', { kinds = { boat = true } }).average == 75, 'Unknown levels are conservative')
graph[1].connections[1].disabled = true
check(planner.route(graph, 1, 4, 'fastest', { kinds = { boat = true } }) == nil, 'Disabled edge')
graph[1].name = 'A [Special] Place'
check(#planner.filter(graph, 'All', '[special]') == 1, 'Search is a case-insensitive literal')
check(#planner.filter(graph, 'Elsewhere', '') == 0, 'Region and search intersect')

-- Independent exhaustive oracle: randomized graphs expose incorrect additive,
-- minimax, greedy, or single-label implementations of a minimum-mean path.
math.randomseed(5246)
for trial = 1, 200 do
    local n = math.random(3, 8)
    local g = {}
    for i = 1, n do
        g[i] = zone(math.random(0, 100))
        for j = 1, n do
            if i ~= j and math.random() < 0.30 then g[i].connections[#g[i].connections + 1] = { to = j, kind = 'walk' } end
        end
    end
    local best, hops, visited = math.huge, math.huge, { [1] = true }
    local function oracle(u, sum, size)
        if u == n then
            local avg = sum / size
            if avg < best - 1e-9 or (math.abs(avg - best) < 1e-9 and size - 1 < hops) then best = avg; hops = size - 1 end
            return
        end
        for _, e in ipairs(g[u].connections) do
            if not visited[e.to] then
                visited[e.to] = true; oracle(e.to, sum + g[e.to].average_level, size + 1); visited[e.to] = nil
            end
        end
    end
    oracle(1, g[1].average_level, 1)
    local job = planner.search(g, 1, n)
    while not job.done do planner.step(job, 2) end
    if best == math.huge then check(not job.result, 'Unreachable oracle match')
    else
        check(math.abs(job.result.average - best) < 1e-8 and job.result.changes == hops, 'Minimum mean oracle match')
        local seen = {}
        for _, id in ipairs(job.result.path) do check(not seen[id], 'No repeated zones'); seen[id] = true end
    end
end

local g = { [1] = zone(10,{2}), [2] = zone(20,{3}), [3] = zone(30), [4] = zone(5,{3}) }
local cfg = { current_start = true, start = 1, destination = 3, mode = 'fastest', restricted = true }
local c = controller.new(g, cfg)
c:plan(); check(not c.result and c.message:find('unavailable'), 'Current zone unavailable cannot fall back silently')
c:update(1); c:plan(); check(c:next_zone() == 2, 'Next from current')
c:update(2); check(c:next_zone() == 3 and c.cursor == 2, 'Advance on zone change')
c:update(4); check(c.result.path[1] == 4 and c:next_zone() == 3, 'Replan off route')
c:update(3); local _, message = c:next_zone(); check(message == 'Destination reached.', 'Arrival')
c:invalidate(); check(not c.result and not c.job, 'Discard stale route')
cfg.current_start = false; cfg.start = 1
c:update(4); c:plan(); check(c:next_zone() == 1 and not c.tracking, 'Manual start preview')
c:update(1); check(c.tracking and c:next_zone() == 2, 'Begin manual route when start reached')
cfg.mode = 'safest'; c:plan(); check(c.job and not c.job.done, 'Incremental search')
c:update(2); check(c.job.paused and c.cursor == 2, 'Movement freezes unfinished route')
c:update(nil); check(select(2, c:next_zone()) == 'Current zone unavailable.', 'Zoning/logged-out state')

local data = require('data.zones')
check(planner.route(data, 230, 244, 'fastest').changes == 5, 'San d\'Oria to Jeuno walking')
check(planner.route(data, 126, 158, 'fastest').changes == 3, 'Delkfutt scripted stair connections')
check(planner.route(data, 239, 242, 'fastest').changes == 1, 'Heavens Tower entrance')
check(not planner.route(data, 231, 233, 'fastest', {allow_restricted=false}), 'Chateau access filter')
check(not planner.route(data, 230, 250, 'fastest'), 'Kazham disconnected overland')
local air = planner.route(data, 230, 250, 'fastest', { kinds = { walk = true, airship = true } })
check(air and air.changes > 0, 'Kazham airship option')
for id, z in pairs(data) do
    check(z.id == id and type(z.region) == 'string', 'Valid zone identity')
    check(z.average_level == nil or z.average_level >= 0, 'Valid danger score')
    for _, e in ipairs(z.connections) do
        check(data[e.to] and e.to ~= id, 'Valid non-self connection')
        check(e.kind == 'walk' or e.kind == 'boat' or e.kind == 'airship' or e.kind == 'portal', 'Valid connection type')
    end
end
print(string.format('PASS: %d routing, state and dataset checks, including 200 independent exhaustive comparisons.', count))
