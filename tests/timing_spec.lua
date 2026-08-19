package.path = './apps/lua/MulticlassRelative/?.lua;./apps/lua/MulticlassRelative/?/init.lua;' .. package.path
local Timing = require('src/timing')

local function equal(actual, expected, epsilon)
  assert(math.abs(actual - expected) <= (epsilon or 0.001), ('expected %.3f, got %.3f'):format(expected, actual))
end

-- Car 1 is one second ahead at the player’s current progress.
local timing = Timing.new()
timing:update(0, 0, 3, 0.00, false); timing:update(1, 0, 3, 0.01, false)
timing:update(0, 10, 3, 0.10, false); timing:update(1, 10, 3, 0.11, false)
local gap, historical = timing:relativeGap(0, 1, 10)
assert(historical); equal(gap, -1)

-- A trailing car crosses the player’s earlier point five seconds later.
timing:update(2, 0, 3, 0.00, false); timing:update(2, 10, 3, 0.05, false)
gap, historical = timing:relativeGap(0, 2, 10)
assert(historical); equal(gap, 5)

-- Crossing start/finish continues monotonically thanks to lapCount.
local wrap = Timing.new()
local before = wrap:update(0, 0, 5, 0.99, false)
local after = wrap:update(0, 1, 6, 0.01, false)
assert(after.progress > before.progress, 'spline wrap must not move race progress backwards')

-- A sudden backwards move on the same lap invalidates history.
local _, teleported = wrap:update(0, 2, 6, 0.30, false)
assert(not teleported)
_, teleported = wrap:update(0, 3, 6, 0.01, true)
assert(teleported, 'pit teleport must invalidate stale crossings')

print('timing_spec: ok')
