local planner = require('planner')
local M = {}

function M.new(zones, config)
    local self = { zones = zones, config = config, current = nil, result = nil, job = nil,
                   message = 'Choose your destination, then plan a route.', cursor = 1, tracking = false }

    function self:invalidate()
        self.result = nil; self.job = nil; self.tracking = false; self.cursor = 1
        self.message = 'Options changed. Select Plan route.'
    end

    function self:plan(start_override)
        self.job = nil; self.result = nil; self.cursor = 1
        local start = start_override
        if not start then
            if self.config.current_start then start = self.current else start = self.config.start end
        end
        if self.config.current_start and not start then
            self.message = 'Current zone unavailable. Log in or select a starting zone.'; return
        end
        self.tracking = start == self.current
        local options = { kinds = { walk = true, boat = self.config.boats, airship = self.config.airships,
                                    portal = self.config.portals }, allow_restricted = self.config.restricted,
                          unknown_level = 150 }
        if self.config.mode == 'safest' then
            self.job = planner.search(self.zones, start, self.config.destination, options)
            self.result = self.job.result; self.message = self.job.error
        else
            self.result, self.message = planner.route(self.zones, start, self.config.destination, 'fastest', options)
        end
    end

    function self:update(zone)
        local changed = zone ~= self.current
        self.current = zone
        if changed and zone and self.result then
            local found
            for i = self.cursor, #self.result.path do
                if self.result.path[i] == zone then found = i; break end
            end
            if found then
                -- Freeze the chosen route after movement, avoiding replanning loops
                -- caused by repeatedly optimizing an average from a new start.
                if found > self.cursor and self.job and not self.job.done then self.job.paused = true end
                self.cursor = found; self.tracking = true
            elseif self.tracking then
                self:plan(zone)
                if self.result then self.message = 'You left the route. Replanned from your current zone.' end
            end
        end
        if self.job and not self.job.done and not self.job.paused then
            planner.step(self.job, 100, 0.002)
            self.result = self.job.result
            if self.job.error then self.message = self.job.error end
        end
    end

    function self:next_zone()
        if not self.result then return nil, self.message end
        if not self.current then return nil, 'Current zone unavailable.' end
        if not self.tracking then return self.result.path[1], 'Go to the starting zone.' end
        if self.cursor == #self.result.path then return nil, 'Destination reached.' end
        return self.result.path[self.cursor + 1]
    end

    return self
end

return M
