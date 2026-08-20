local Timing = {}
Timing.__index = Timing

local HISTORY_SECONDS = 90
local MAX_SAMPLES = 1000

function Timing.new()
  return setmetatable({ cars = {}, session = nil }, Timing)
end

function Timing:reset()
  self.cars = {}
end

function Timing:update(index, now, lap, spline, inPit)
  local state = self.cars[index] or { history = {} }
  self.cars[index] = state
  local progress = lap + spline
  local teleported = false
  if state.progress then
    local delta = progress - state.progress
    -- A large backwards movement without a lap change is a pit teleport/restart,
    -- not a valid path through the timing history.
    if delta < -0.20 and lap == state.lap then
      state.history = {}
      teleported = true
    end
  end
  state.progress, state.lap, state.spline, state.inPit = progress, lap, spline, inPit
  state.lastUpdate = now
  local h = state.history
  h[#h + 1] = { t = now, p = progress }
  while #h > 2 and (h[1].t < now - HISTORY_SECONDS or #h > MAX_SAMPLES) do table.remove(h, 1) end
  return state, teleported
end

function Timing:prune(now)
  for index, state in pairs(self.cars) do
    if now - state.lastUpdate > 5 then self.cars[index] = nil end
  end
end

function Timing:crossingTime(index, target)
  local state = self.cars[index]
  if not state then return nil end
  local h = state.history
  for i = #h, 2, -1 do
    local a, b = h[i - 1], h[i]
    if a.p <= target and target <= b.p and b.p > a.p then
      return a.t + (target - a.p) * (b.t - a.t) / (b.p - a.p)
    end
  end
  return nil
end

function Timing:estimateRate(index)
  local state = self.cars[index]
  if not state then return 0 end
  local h = state.history
  if #h < 2 then return 0 end
  local a, b = h[math.max(1, #h - 12)], h[#h]
  return math.max(0, (b.p - a.p) / math.max(0.01, b.t - a.t))
end

-- `physicalDelta` is the shortest signed circular spline distance. It must not
-- be inferred from total race progress: a car one lap ahead can be physically
-- behind the player while preparing to lap them.
-- Returns a signed time: negative means physically ahead, positive behind.
function Timing:relativeGap(playerIndex, otherIndex, now, physicalDelta)
  local player, other = self.cars[playerIndex], self.cars[otherIndex]
  if not player or not other then return nil, false end
  local delta = physicalDelta or (other.progress - player.progress)
  if math.abs(delta) < 0.0001 then return 0, true end
  local crossing
  if delta > 0 then
    -- Find when this car crossed the player’s *physical* current point, on
    -- the correct local lap for the other car.
    crossing = self:crossingTime(otherIndex, other.progress - delta)
    if crossing then return -(now - crossing), true end
  else
    -- Likewise, find when the player crossed the trailing car’s physical
    -- current point on the player’s own progress timeline.
    crossing = self:crossingTime(playerIndex, player.progress + delta)
    if crossing then return now - crossing, true end
  end
  local rate = self:estimateRate(playerIndex)
  if rate <= 0 then return nil, false end
  return (delta > 0 and -1 or 1) * math.abs(delta) / rate, false
end

return Timing
