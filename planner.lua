-- Pure Lua routing; no Ashita dependencies. Edges are directed.
local M = {}

local function allowed(edge, options)
    local kinds = options.kinds or { walk = true }
    return kinds[edge.kind or 'walk'] and not edge.disabled
        and (options.allow_restricted ~= false or not edge.requirement)
end

local function summarize(zones, path, edges, options)
    local r = { path = {}, edges = {}, total = 0, peak = 0, unknown = 0, changes = #path - 1 }
    for i, id in ipairs(path) do
        r.path[i] = id
        local level = zones[id].average_level
        if level == nil then r.unknown = r.unknown + 1; level = options.unknown_level or 150 end
        r.total = r.total + level
        r.peak = math.max(r.peak, level)
    end
    for i, edge in ipairs(edges) do r.edges[i] = edge end
    r.average = r.total / #path
    return r
end

-- Breadth-first search minimizes actual zone changes, including transport zones.
function M.route(zones, start, destination, mode, options)
    options = options or {}
    if mode == 'safest' then
        local job = M.search(zones, start, destination, options)
        while not job.done do M.step(job, 1000) end
        return job.result, job.error
    end
    if not zones[start] or not zones[destination] then return nil, 'Select a starting zone and destination.' end
    local queue, head, previous = { start }, 1, { [start] = false }
    while queue[head] do
        local u = queue[head]; head = head + 1
        if u == destination then
            local path, edges = { u }, {}
            while previous[u] do
                local p = previous[u]
                table.insert(path, 1, p.from); table.insert(edges, 1, p.edge); u = p.from
            end
            return summarize(zones, path, edges, options)
        end
        for _, edge in ipairs(zones[u].connections or {}) do
            if zones[edge.to] and allowed(edge, options) and previous[edge.to] == nil then
                previous[edge.to] = { from = u, edge = edge }; queue[#queue + 1] = edge.to
            end
        end
    end
    return nil, 'No route exists in the available data with these options.'
end

-- The minimum-average SIMPLE path is not an additive shortest-path problem.
-- Enumerate simple paths with an admissible lower bound, yielding between work
-- units. Never call an unfinished result optimal. No artificial hop cutoff.
function M.search(zones, start, destination, options)
    options = options or {}
    local seed, err = M.route(zones, start, destination, 'fastest', options)
    local job = { result = seed, error = err, done = not seed, examined = 0 }
    if not seed then return job end
    local function level(id) return zones[id].average_level or options.unknown_level or 150 end
    local reverse, adjacency = {}, {}
    for id, zone in pairs(zones) do
        adjacency[id] = {}
        local seen = {}
        for _, edge in ipairs(zone.connections or {}) do
            if zones[edge.to] and allowed(edge, options) and not seen[edge.to] then
                seen[edge.to] = true
                adjacency[id][#adjacency[id] + 1] = edge
                reverse[edge.to] = reverse[edge.to] or {}; reverse[edge.to][#reverse[edge.to] + 1] = id
            end
        end
        table.sort(adjacency[id], function(a,b)
            if level(a.to) == level(b.to) then return a.to < b.to end
            return level(a.to) < level(b.to)
        end)
    end
    local path, edges, visited = { start }, {}, { [start] = true }
    job.thread = coroutine.create(function()
        local function visit(u, sum)
            job.examined = job.examined + 1
            coroutine.yield()
            if u == destination then
                local avg = sum / #path
                if avg < job.result.average - 1e-9 or (math.abs(avg - job.result.average) < 1e-9 and #path < #job.result.path) then
                    job.result = summarize(zones, path, edges, options)
                end
                return
            end
            -- Reverse reachability excluding visited nodes prevents dead-end detours.
            local reachable, queue, head = { [destination] = true }, { destination }, 1
            while queue[head] do
                local v = queue[head]; head = head + 1
                for _, p in ipairs(reverse[v] or {}) do
                    if not reachable[p] and (not visited[p] or p == u) then
                        reachable[p] = true; queue[#queue + 1] = p
                    end
                end
            end
            if not reachable[u] then return end
            -- Optimistic: choose any subset of the remaining low-level zones,
            -- ignoring connectivity. This can only underestimate a real average.
            local candidates = {}
            for id in pairs(reachable) do
                if not visited[id] and id ~= destination then candidates[#candidates + 1] = level(id) end
            end
            table.sort(candidates)
            local count, total = #path + 1, sum + level(destination)
            local bound = total / count
            for _, value in ipairs(candidates) do
                total = total + value; count = count + 1; bound = math.min(bound, total / count)
            end
            if bound > job.result.average + 1e-9 then return end
            for _, edge in ipairs(adjacency[u]) do
                local v = edge.to
                if not visited[v] and reachable[v] then
                    visited[v] = true; path[#path + 1] = v; edges[#edges + 1] = edge
                    visit(v, sum + level(v))
                    visited[v] = nil; path[#path] = nil; edges[#edges] = nil
                end
            end
        end
        visit(start, level(start))
    end)
    return job
end

function M.step(job, units, seconds)
    if job.done then return end
    local deadline = seconds and (os.clock() + seconds)
    for _ = 1, units or 100 do
        local ok, err = coroutine.resume(job.thread)
        if not ok then job.error = tostring(err); job.done = true; return end
        if coroutine.status(job.thread) == 'dead' then job.done = true; return end
        if deadline and os.clock() >= deadline then return end
    end
end

function M.filter(zones, region, query)
    local result = {}
    query = (query or ''):lower()
    for id, zone in pairs(zones) do
        if (not region or region == 'All' or zone.region == region)
            and zone.name:lower():find(query, 1, true) then result[#result + 1] = id end
    end
    table.sort(result, function(a, b) return zones[a].name < zones[b].name end)
    return result
end

return M
