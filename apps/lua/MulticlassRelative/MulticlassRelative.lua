local Timing = require('src/timing')
local Relative = require('src/relative')
local Classes = require('src/classes')
local Display = require('src/display')

local settings = ac.storage({
  ahead = 3, behind = 3, mode = 0, showOverall = true, showClassPosition = false,
  showClassText = false, showNumber = true, showDriver = true, showGap = true,
  showPitIndicator = true, showLapDifference = true, showPits = true,
  showHeader = true, showTitle = true, classMarkerWidth = 4,
  decimals = 1, maximumGap = 30, smoothing = 0.40, uiScale = 1.0, fontSize = 18,
  automaticClasses = true, debug = false,
  backgroundColor = rgb(0.025, 0.030, 0.045), backgroundOpacity = 0.72,
  showApproaching = true, approachRange = 8.0, approachRate = 0.20,
  approachColor = rgb(1.00, 0.58, 0.12),
  classColorHY = Classes.colors.HY:clone(), classColorLMP1 = Classes.colors.LMP1:clone(),
  classColorLMP2 = Classes.colors.LMP2:clone(), classColorLMP3 = Classes.colors.LMP3:clone(),
  classColorGT3 = Classes.colors.GT3:clone(), classColorGT4 = Classes.colors.GT4:clone(),
  classColorGTE = Classes.colors.GTE:clone(), classColorTCR = Classes.colors.TCR:clone(),
  classColorTC = Classes.colors.TC:clone(), classColorCUP = Classes.colors.CUP:clone(),
  classColorUNKNOWN = Classes.colors.UNKNOWN:clone()
})

local timing = Timing.new()
local cars, player, shownAhead, shownBehind = {}, nil, {}, {}
local metadata, relativeMemory, approachMemory = {}, {}, {}
local telemetryAccumulator, previousSession, previousPlayerLap = 0, nil, nil
local classIDs = { 'HY', 'LMP1', 'LMP2', 'LMP3', 'GT3', 'GT4', 'GTE', 'TCR', 'TC', 'CUP', 'UNKNOWN' }

local function shorten(value, count)
  value = value or 'Unknown driver'
  return #value > count and value:sub(1, count - 1) .. '…' or value
end

local function classColor(classID)
  return settings['classColor' .. classID] or Classes.colors[classID] or Classes.colors.UNKNOWN
end

local function relativeRowHeight()
  return math.max(22, math.floor(settings.fontSize * 1.45))
end

local function classMarkerWidth()
  return math.max(2, math.floor(settings.classMarkerWidth + 0.5))
end

local function updateApproachAlerts(now, dt)
  for _, row in ipairs(cars) do
    local state = approachMemory[row.index] or {}
    if row.filteredGap and state.gap and dt > 0 then
      local rawRate = (state.gap - row.filteredGap) / dt
      local alpha = 1 - math.exp(-dt / 0.35)
      state.rate = state.rate and state.rate + (rawRate - state.rate) * alpha or rawRate
    end
    state.gap, state.lastSeen = row.filteredGap, now
    approachMemory[row.index] = state
    row.closingRate = state.rate or 0
    row.approaching = settings.showApproaching and not row.inPitlane and row.filteredGap
      and row.filteredGap > 0 and row.filteredGap <= settings.approachRange
      and row.closingRate >= settings.approachRate and Classes.isFaster(row.classID, player.classID)
  end
  for index, state in pairs(approachMemory) do
    if state.lastSeen < now - 5 then approachMemory[index] = nil end
  end
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
    timing:reset(); metadata = {}; relativeMemory = {}; approachMemory = {}; previousPlayerLap = nil
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
    -- Keep class data live regardless of presentation settings: filtering,
    -- positions, colours and approach warnings all depend on it.
    local positions = {}
    for _, row in ipairs(cars) do
      positions[row.classID] = (positions[row.classID] or 0) + 1
      row.classPosition = positions[row.classID]
    end
    shownAhead, shownBehind = Relative.build(cars, player, timing, now, settings, interval, relativeMemory)
    Relative.pruneMemory(relativeMemory, now)
    updateApproachAlerts(now, interval)
  end
end

local function drawRow(row, isPlayer)
  local color = classColor(row.classID)
  local height = relativeRowHeight()
  local markerWidth = classMarkerWidth()
  local start, finish = vec2(0, ui.getCursorY()), vec2(ui.windowWidth(), ui.getCursorY() + height)
  if isPlayer then ui.drawRectFilled(start, finish, rgbm(0.92, 0.92, 0.96, 0.20))
  elseif row.approaching then ui.drawRectFilled(start, finish, rgbm(settings.approachColor.r, settings.approachColor.g, settings.approachColor.b, 0.34))
  elseif row.filteredGap and math.abs(row.filteredGap) < 0.5 then ui.drawRectFilled(start, finish, rgbm(color.r, color.g, color.b, 0.16)) end
  ui.drawRectFilled(start, vec2(start.x + markerWidth, finish.y), rgbm(color.r, color.g, color.b, 0.95))
  ui.setCursorX(start.x + markerWidth + 4)
  ui.setCursorY(start.y + math.max(1, (height - settings.fontSize) / 2))
  ui.dwriteText(Display.rowText(row, isPlayer, player, settings), settings.fontSize, isPlayer and rgb(1, 1, 1) or rgb(0.90, 0.92, 0.96))
  ui.setCursorX(0)
  ui.setCursorY(finish.y)
end

function script.windowMain(dt)
  Relative.clampSettings(settings)
  updateTelemetry(dt)
  if not player then ui.text('Waiting for race telemetry…'); return end
  ui.drawRectFilled(vec2(), ui.windowSize(), rgbm(settings.backgroundColor.r, settings.backgroundColor.g, settings.backgroundColor.b, settings.backgroundOpacity))
  if settings.showTitle then ui.dwriteText('RELATIVE', math.ceil(settings.fontSize * 1.15)) end
  if settings.showHeader then
    ui.setCursorX(classMarkerWidth() + 4)
    ui.dwriteText(Display.headerText(settings), settings.fontSize, rgb(0.72, 0.75, 0.80))
    ui.setCursorX(0)
  end
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
  ui.separator(); ui.header('Columns')
  if ui.checkbox('Show overall position', settings.showOverall) then settings.showOverall = not settings.showOverall end
  if ui.checkbox('Show class position', settings.showClassPosition) then settings.showClassPosition = not settings.showClassPosition end
  if ui.checkbox('Show class text', settings.showClassText) then settings.showClassText = not settings.showClassText end
  if ui.checkbox('Show car number', settings.showNumber) then settings.showNumber = not settings.showNumber end
  if ui.checkbox('Show driver name', settings.showDriver) then settings.showDriver = not settings.showDriver end
  if ui.checkbox('Show gap', settings.showGap) then settings.showGap = not settings.showGap end
  if ui.checkbox('Show pit indicator', settings.showPitIndicator) then settings.showPitIndicator = not settings.showPitIndicator end
  if ui.checkbox('Show lap difference', settings.showLapDifference) then settings.showLapDifference = not settings.showLapDifference end
  ui.separator(); ui.header('Rows')
  if ui.checkbox('Show cars in pits', settings.showPits) then settings.showPits = not settings.showPits end
  if ui.checkbox('Show header', settings.showHeader) then settings.showHeader = not settings.showHeader end
  if ui.checkbox('Show title', settings.showTitle) then settings.showTitle = not settings.showTitle end
  settings.decimals = ui.slider('Gap decimals', settings.decimals, 1, 3, 'Gap decimals: %.0f')
  settings.maximumGap = ui.slider('Maximum gap', settings.maximumGap, 5, 90, 'Maximum gap: %.0fs')
  settings.smoothing = ui.slider('Gap smoothing', settings.smoothing, 0.05, 1.5, 'Gap smoothing: %.2fs')
  ui.separator(); ui.header('Appearance')
  settings.fontSize = ui.slider('Relative font size', settings.fontSize, 12, 32, 'Relative font size: %.0f px')
  settings.classMarkerWidth = ui.slider('Class marker width', settings.classMarkerWidth, 2, 8, 'Class marker width: %.0f px')
  ui.text('Background color'); ui.sameLine(); ui.colorButton('##background', settings.backgroundColor, ui.ColorPickerFlags.PickerHueBar)
  settings.backgroundOpacity = ui.slider('Background opacity', settings.backgroundOpacity, 0, 1, 'Background opacity: %.0f%%')
  ui.text('Approach warning color'); ui.sameLine(); ui.colorButton('##approach', settings.approachColor, ui.ColorPickerFlags.PickerHueBar)
  ui.separator(); ui.header('Faster-class approach warning')
  if ui.checkbox('Highlight faster class closing quickly', settings.showApproaching) then settings.showApproaching = not settings.showApproaching end
  settings.approachRange = ui.slider('Warning range', settings.approachRange, 2, 20, 'Warning range: %.1fs')
  settings.approachRate = ui.slider('Minimum closing rate', settings.approachRate, 0.05, 2.0, 'Minimum closing rate: %.2f s/s')
  ui.text('Shows FAST only for a quicker class behind and closing.')
  ui.separator(); ui.header('Class colors')
  for _, classID in ipairs(classIDs) do
    ui.text(classID); ui.sameLine(110)
    ui.colorButton('##classColor' .. classID, classColor(classID), ui.ColorPickerFlags.PickerHueBar)
  end
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
