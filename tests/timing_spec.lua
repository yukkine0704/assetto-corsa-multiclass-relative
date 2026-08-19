package.path = './apps/lua/MulticlassRelative/?.lua;./apps/lua/MulticlassRelative/?/init.lua;' .. package.path
local Timing = require('src/timing')
local Relative = require('src/relative')

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
local before = wrap:update(0, 0, 5, 0.99, false).progress
local after = wrap:update(0, 1, 6, 0.01, false)
assert(after.progress > before, 'spline wrap must not move race progress backwards')

-- A sudden backwards move on the same lap invalidates history.
local _, teleported = wrap:update(0, 2, 6, 0.30, false)
assert(not teleported)
_, teleported = wrap:update(0, 3, 6, 0.01, true)
assert(teleported, 'pit teleport must invalidate stale crossings')

-- Filtered gaps persist independently from the freshly collected row table.
local gap = 3
local fakeTiming = { relativeGap = function() return gap, true end }
local settings = { mode = 0, showPits = true, smoothing = 0.4, ahead = 1, behind = 1 }
local memory = {}
local grid = { { index = 0, progress = 4.50 }, { index = 1, progress = 4.49 } }
local _, behind = Relative.build(grid, grid[1], fakeTiming, 1, settings, 1, memory)
equal(behind[1].filteredGap, 3)
gap = 2
grid = { { index = 0, progress = 4.50 }, { index = 1, progress = 4.49 } }
_, behind = Relative.build(grid, grid[1], fakeTiming, 2, settings, 1, memory)
assert(behind[1].filteredGap < 3 and behind[1].filteredGap > 2, 'gap filter must survive telemetry snapshots')

print('timing_spec: ok')
