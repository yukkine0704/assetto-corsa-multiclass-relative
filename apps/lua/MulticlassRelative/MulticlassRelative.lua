local Timing = require('src/timing')
local Relative = require('src/relative')
local Classes = require('src/classes')

local settings = ac.storage({
  ahead = 3, behind = 3, mode = 0, showOverall = true, showClassPosition = true,
  showNumber = true, showPits = true, showHeader = true, showTitle = false,
  decimals = 1, maximumGap = 30, smoothing = 0.40, uiScale = 1.0,
  automaticClasses = true, debug = false
})

local timing = Timing.new()
local cars, player, shownAhead, shownBehind = {}, nil, {}, {}
local metadata, lastClassCycle = {}, {}
local telemetryAccumulator, previousSession, previousPlayerLap = 0, nil, nil

local function shorten(value, count)
  value = value or 'Unknown driver'
  return #value > count and value:sub(1, count - 1) .. '…' or value
end

local function metadataFor(car)
  local cached = metadata[car.index]
  local id = car:id()
  if cached and cached.id == id then return cached end
  local name = car:name()
  local classID, source = Classes.detect(id, name, settings.automaticClasses)
  cached = { id = id, name = name, driver = car:driverName(), number = car:driverNumber(), classID = classID, classSource = source }
  metadata[car.index] = cached
  ac.log('[MulticlassRelative] ' .. id .. ' -> ' .. classID .. ' (' .. source:lower() .. ')')
  return cached
end

local function updateTelemetry(dt)
  telemetryAccumulator = telemetryAccumulator + dt
  if telemetryAccumulator < 0.10 then return end
  local interval = telemetryAccumulator
  telemetryAccumulator = 0
  local sim, now = ac.getSim(), ui.time()
  if previousSession ~= nil and sim.currentSessionIndex ~= previousSession then
    timing:reset(); metadata = {}; previousPlayerLap = nil
    ac.log('[MulticlassRelative] Session changed; timing history reset')
  end
  previousSession = sim.currentSessionIndex
  cars, player = {}, nil
  for _, car in ac.iterateCars() do
    -- CSP documents iterateCars() as the full grid iterator. isConnected is
    -- authoritative online; isActive keeps offline/AI entries usable.
    if car.index == 0 or car.isConnected or car.isActive then
      local lap, spline = math.max(0, car.lapCount or 0), math.max(0, math.min(1, car.splinePosition or 0))
      local static = metadataFor(car)
      local state = timing:update(car.index, now, lap, spline, car.isInPitlane or car.isInPit)
      local row = {
        index = car.index, driver = static.driver, number = static.number, carID = static.id,
        classID = static.classID, classSource = static.classSource, overall = car.racePosition or 0,
        lap = lap, spline = spline, progress = state.progress, inPitlane = car.isInPitlane or car.isInPit,
        connected = car.isConnected, speedKmh = car.speedKmh or 0
      }
      table.insert(cars, row)
      if car.index == 0 then player = row end
    end
  end
  if player and previousPlayerLap and player.lap + 1 < previousPlayerLap then timing:reset() end
  previousPlayerLap = player and player.lap or previousPlayerLap
  timing:prune(now)
  if player then
    table.sort(cars, function(a, b) return a.progress > b.progress end)
    local positions = {}
    for _, row in ipairs(cars) do
      positions[row.classID] = (positions[row.classID] or 0) + 1
      row.classPosition = positions[row.classID]
    end
    shownAhead, shownBehind = Relative.build(cars, player, timing, now, settings, interval)
  end
end

local function gapText(row)
  local lap = Relative.lapText(row, player)
  if lap then return lap end
  if not row.filteredGap then return '…' end
  if math.abs(row.filteredGap) > settings.maximumGap then return '>' .. settings.maximumGap .. 's' end
  return string.format('%+.' .. settings.decimals .. 'f', row.filteredGap)
end

local function rowText(row, isPlayer)
  local ovr = settings.showOverall and string.format('%2d', row.overall) or ''
  local cls = settings.showClassPosition and string.format('%2d', row.classPosition) or ''
  local num = settings.showNumber and (' #' .. (row.number or '?')) or ''
  local pit = settings.showPits and row.inPitlane and ' PIT' or ''
  local who = isPlayer and 'YOU' or shorten(row.driver, 20)
  return string.format('%s %s %-5s%-5s %-20s %6s%s', ovr, cls, row.classID, num, who, isPlayer and ' 0.0' or gapText(row), pit)
end

local function drawRow(row, isPlayer)
  local color = Classes.colors[row.classID] or Classes.colors.UNKNOWN
  local start, finish = vec2(0, ui.getCursorY()), vec2(ui.windowWidth(), ui.getCursorY() + 22 * settings.uiScale)
  if isPlayer then ui.drawRectFilled(start, finish, rgbm(0.92, 0.92, 0.96, 0.20))
  elseif row.filteredGap and math.abs(row.filteredGap) < 0.5 then ui.drawRectFilled(start, finish, rgbm(color.r, color.g, color.b, 0.16)) end
  ui.setCursorY(ui.getCursorY() + 3 * settings.uiScale)
  ui.pushStyleColor(ui.StyleColor.Text, isPlayer and rgb(1, 1, 1) or color)
  ui.text((isPlayer and '> ' or '  ') .. rowText(row, isPlayer))
  ui.popStyleColor()
  ui.setCursorY(finish.y)
end

function script.windowMain(dt)
  Relative.clampSettings(settings)
  updateTelemetry(dt)
  if not player then ui.text('Waiting for race telemetry…'); return end
  if settings.showTitle then ui.text('MULTICLASS RELATIVE') end
  if settings.showHeader then ui.text(' OVR CL  CLASS #    DRIVER                   GAP') end
  for _, row in ipairs(shownAhead) do drawRow(row, false) end
  drawRow(player, true)
  for _, row in ipairs(shownBehind) do drawRow(row, false) end
  if settings.debug then
    ui.separator()
    ui.text(string.format('Debug: %d active · player L%d %.3f · %s', #cars, player.lap, player.spline, player.classSource))
    for _, row in ipairs(shownAhead) do ui.text(string.format('#%d raw=%s progress=%.3f', row.index, tostring(row.rawGap), row.progress)) end
  end
end

function script.windowSettings()
  settings.ahead = ui.slider('Cars ahead', settings.ahead, 1, 10, 'Cars ahead: %.0f')
  settings.behind = ui.slider('Cars behind', settings.behind, 1, 10, 'Cars behind: %.0f')
  settings.mode = ui.combo('Mode', settings.mode, ui.ComboFlags.None, { 'All cars', 'Same class' })
  if ui.checkbox('Show overall position', settings.showOverall) then settings.showOverall = not settings.showOverall end
  if ui.checkbox('Show class position', settings.showClassPosition) then settings.showClassPosition = not settings.showClassPosition end
  if ui.checkbox('Show car number', settings.showNumber) then settings.showNumber = not settings.showNumber end
  if ui.checkbox('Show cars in pits', settings.showPits) then settings.showPits = not settings.showPits end
  if ui.checkbox('Show header', settings.showHeader) then settings.showHeader = not settings.showHeader end
  if ui.checkbox('Show title', settings.showTitle) then settings.showTitle = not settings.showTitle end
  settings.decimals = ui.slider('Gap decimals', settings.decimals, 1, 3, 'Gap decimals: %.0f')
  settings.maximumGap = ui.slider('Maximum gap', settings.maximumGap, 5, 90, 'Maximum gap: %.0fs')
  settings.smoothing = ui.slider('Gap smoothing', settings.smoothing, 0.05, 1.5, 'Gap smoothing: %.2fs')
  if ui.checkbox('Automatic class detection', settings.automaticClasses) then settings.automaticClasses = not settings.automaticClasses end
  if ui.checkbox('Debug view', settings.debug) then settings.debug = not settings.debug end
  ui.separator(); ui.text('Click a detected class to cycle a persistent override:')
  local choices = { 'UNKNOWN', 'HY', 'LMP1', 'LMP2', 'LMP3', 'GT3', 'GT4', 'GTE', 'TCR', 'TC', 'CUP' }
  for _, row in ipairs(cars) do
    if ui.button(shorten(row.carID, 27) .. ' → ' .. row.classID .. '##class' .. row.index) then
      local n = 1
      for i, v in ipairs(choices) do if v == row.classID then n = i % #choices + 1 end end
      Classes.setOverride(row.carID, choices[n]); metadata[row.index] = nil
    end
  end
end
