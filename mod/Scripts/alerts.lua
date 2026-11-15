-- Squad Status HUD: event tracking only. No game state is changed.
local Alerts = {}
function Alerts.new(settings)
    settings = settings or {}
    local self = { previous = nil, active = {} }
    local duration = math.max(1, math.min(15, tonumber(settings.AlertDuration) or 5))
    local limit = math.max(1, math.min(5, math.floor(tonumber(settings.MaxAlerts) or 3)))
    function self:reset() self.previous, self.active = nil, {} end
    function self:update(roster, now, silent, confirmDeath)
        local nextState, events = {}, {}
        local function emit(kind, member)
            if silent then return end
            events[#events + 1] = { kind = kind, key = member.key, name = member.name, started = now, expires = now + duration }
        end
        for _, member in ipairs(roster) do
            local key = member.key
            if key and not nextState[key] then
                local previous = self.previous and self.previous[key]
                local dead = member.known and member.hp <= 0
                if self.previous then
                    if not previous then
                        if not dead then emit('joined', member) end
                    elseif dead and not previous.dead then
                        emit('died', member)

                    end
                end
                nextState[key] = { key = key, name = member.name, actor = member.actor, dead = dead }
            end
        end
        -- Leaving the squad is not proof of death. Require live health confirmation.
        for key, previous in pairs(self.previous or {}) do
            if not nextState[key] and not previous.dead and confirmDeath then
                local ok, dead = pcall(confirmDeath, previous.actor)
                if ok and dead then emit('died', previous) end
            end
        end
        self.previous = nextState
        if silent then self.active = {}; return self.active end
        local active = {}
        for _, event in ipairs(self.active) do
            if event.expires > now then active[#active + 1] = event end
        end
        for _, event in ipairs(events) do active[#active + 1] = event end
        while #active > limit do table.remove(active, 1) end
        self.active = active
        return active
    end
    return self
end
-- Small, local opacity changes. Never flash the screen or change health values.
function Alerts.visual(event, now)
    local age = math.max(0, now - event.started)
    local fadeIn = 0.35 + 0.65 * math.min(1, age / 0.35)
    local fadeOut = math.max(0, math.min(1, (event.expires - now) / 0.6))
    local emphasis = 1
    if event.kind == "died" and age < 1.8 then
        emphasis = 0.72 + 0.28 * (0.5 + 0.5 * math.cos(age * math.pi * 2 / 0.9))
    end
    return fadeIn * fadeOut * emphasis, event.kind == "joined" and -8 * (1 - math.min(1,age/0.5)) or 0
end
function Alerts.healthOpacity(ratio, now)
    if ratio and ratio > 0 and ratio <= 0.15 then
        return 0.65 + 0.35 * (0.5 + 0.5 * math.cos(now * math.pi * 2 / 1.6))
    end
    return 1
end
return Alerts
