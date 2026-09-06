local Timing = require('src/timing')
local Relative = require('src/relative')
local Classes = require('src/classes')
local Theme = require('src/theme')

local HUD_THEME_EVENT = 'retro-engineering-hud/theme/v1'

local settings = ac.storage({
  ahead = 3, behind = 3, mode = 0, showOverall = true, showClassPosition = false,
  showClassText = false, showNumber = true, showDriver = true, showGap = true,
  showPitIndicator = true, showLapDifference = true, showPits = true,
  showHeader = true, showTitle = true, classMarkerWidth = 4,
  decimals = 1, maximumGap = 30, smoothing = 0.40, uiScale = 1.0, fontSize = 18,
  automaticClasses = true, debug = false, visualStyleVersion = 0,
  backgroundColor = rgb(0.043, 0.035, 0.027), backgroundOpacity = 0.72,
  approachColor = rgb(1.00, 0.58, 0.12),
  showApproaching = true, approachRange = 8.0, approachRate = 0.20,
  classColorHY = Classes.colors.HY:clone(), classColorLMP1 = Classes.colors.LMP1:clone(),
  classColorLMP2 = Classes.colors.LMP2:clone(), classColorLMP3 = Classes.colors.LMP3:clone(),
  classColorGT3 = Classes.colors.GT3:clone(), classColorGT4 = Classes.colors.GT4:clone(),
  classColorGTE = Classes.colors.GTE:clone(), classColorTCR = Classes.colors.TCR:clone(),
  classColorTC = Classes.colors.TC:clone(), classColorCUP = Classes.colors.CUP:clone(),
  classColorUNKNOWN = Classes.colors.UNKNOWN:clone()
})

-- Move the old default navy backdrop to the shared warm instrument palette,
-- while preserving a colour the user had already customized.
if (settings.visualStyleVersion or 0) < 1 then
  local color = settings.backgroundColor
  if color and math.abs(color.r - 0.025) < 0.001
      and math.abs(color.g - 0.030) < 0.001
      and math.abs(color.b - 0.045) < 0.001 then
    settings.backgroundColor = rgb(0.043, 0.035, 0.027)
  end
  settings.visualStyleVersion = 1
end

local hudTheme = {}

local function clampUnit(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.max(0, math.min(1, value))
end

local function receiveHudTheme(data)
  if type(data) ~= 'string' then return end
  local name, backdrop, instrument = data:match('^([^|]+)|([^|]+)|([^|]+)$')
  if name ~= 'light' and name ~= 'dark' then return end
  hudTheme.name = name
  hudTheme.backdropOpacity = clampUnit(backdrop, 0.78)
  hudTheme.instrumentOpacity = clampUnit(instrument, 1)
  hudTheme.lastReceived = ui.time()
end

-- The companion HUD republishes this compact event periodically. If it is
-- absent, no shared state is assumed and the relative falls back to black.
pcall(function()
  ac.onSharedEvent(HUD_THEME_EVENT, receiveHudTheme, true)
end)

local function visualStyle()
  local hudIsActive = hudTheme.lastReceived and ui.time() - hudTheme.lastReceived <= 2.5
  if not hudIsActive then
    return {
      palette = Theme.get('dark'),
      backdropOpacity = 0.78,
      instrumentOpacity = 1
    }
  end

  return {
    palette = Theme.get(hudTheme.name),
    backdropOpacity = hudTheme.backdropOpacity or 0.78,
    instrumentOpacity = hudTheme.instrumentOpacity or 1
  }
end

local timing = Timing.new()
local cars, player, shownAhead, shownBehind = {}, nil, {}, {}
local telemetryError
local metadata, relativeMemory, approachMemory = {}, {}, {}
local telemetryAccumulator, previousSession, previousPlayerLap = 0, nil, nil
local classIDs = { 'HY', 'LMP1', 'LMP2', 'LMP3', 'GT3', 'GT4', 'GTE', 'TCR', 'TC', 'CUP', 'UNKNOWN' }

local function shorten(value, count)
  value = value or 'Unknown driver'
  return #value > count and value:sub(1, count - 1) .. '...' or value
end

local function classColor(classID)
  return settings['classColor' .. classID] or Classes.colors[classID] or Classes.colors.UNKNOWN
end

local function driverWidth()
  return math.max(8, math.floor(20 * 18 / settings.fontSize + 0.5))
end

local function add(parts, enabled, value)
  if enabled and value then table.insert(parts, value) end
end

local function gapText(row)
  if not row.filteredGap then return '...' end
  if math.abs(row.filteredGap) > settings.maximumGap then return '>' .. settings.maximumGap .. 's' end
  return string.format('%+.' .. settings.decimals .. 'f', row.filteredGap)
end

local function rowText(row, isPlayer)
  local width = driverWidth()
  local parts = {}
  add(parts, settings.showOverall, string.format('%2d', row.overall))
  add(parts, settings.showClassPosition, string.format('%2d', row.classPosition))
  add(parts, settings.showClassText, string.format('%-5s', row.classID or 'UNKNOWN'))
  add(parts, settings.showNumber, string.format('%3s', tostring(row.number or '?')))
  add(parts, settings.showDriver, string.format('%-' .. width .. 's', shorten(row.driver, width)))
  add(parts, settings.showGap, string.format('%6s', isPlayer and string.format('%.' .. settings.decimals .. 'f', 0) or gapText(row)))
  add(parts, settings.showPitIndicator and row.inPitlane, 'PIT')
  add(parts, settings.showLapDifference, Relative.lapText(row, player))
  add(parts, row.approaching, 'FAST')
  return (isPlayer and '>' or ' ') .. table.concat(parts, ' ')
end

local function headerText()
  local width = driverWidth()
  local parts = {}
  add(parts, settings.showOverall, string.format('%2s', 'POS'))
  add(parts, settings.showClassPosition, string.format('%2s', 'P#'))
  add(parts, settings.showClassText, string.format('%-5s', 'CLASS'))
  add(parts, settings.showNumber, string.format('%3s', '#'))
  add(parts, settings.showDriver, string.format('%-' .. width .. 's', 'DRIVER'))
  add(parts, settings.showGap, string.format('%6s', 'GAP'))
  return ' ' .. table.concat(parts, ' ')
end

local function drawRow(row, isPlayer, visual)
  local color = classColor(row.classID)
  local palette = visual.palette
  local opacity = visual.instrumentOpacity
  local height = math.max(22, math.floor(settings.fontSize * 1.45))
  local markerWidth = math.max(2, math.floor(settings.classMarkerWidth + 0.5))
  local start = vec2(8, ui.getCursorY())
  local finish = vec2(ui.windowWidth() - 8, start.y + height)
  local lapState = Relative.lapState(row, player)

  ui.drawRectFilled(start, finish, Theme.withAlpha(palette.panel, 0.92 * opacity))
  if isPlayer then
    ui.drawRectFilled(start, finish, Theme.withAlpha(palette.amberDim, 0.78 * opacity))
  elseif lapState == 'lapping_player' then
    ui.drawRectFilled(start, finish, Theme.fromRgb(palette.lapper, 0.28 * opacity))
  elseif lapState == 'being_lapped' then
    ui.drawRectFilled(start, finish, Theme.fromRgb(palette.lapped, 0.24 * opacity))
  elseif row.approaching then
    ui.drawRectFilled(start, finish, Theme.fromRgb(settings.approachColor, 0.34 * opacity))
  elseif row.filteredGap and math.abs(row.filteredGap) < 0.5 then
    ui.drawRectFilled(start, finish, Theme.fromRgb(color, 0.16 * opacity))
  end

  ui.drawRectFilled(start, vec2(start.x + markerWidth, finish.y), Theme.fromRgb(color, 0.95 * opacity))
  ui.setCursorX(start.x + markerWidth + 7)
  ui.setCursorY(start.y + math.max(1, (height - settings.fontSize) / 2))
  ui.dwriteText(rowText(row, isPlayer), settings.fontSize, Theme.withAlpha(palette.primary, opacity))
  ui.setCursorX(8)
  ui.setCursorY(finish.y + 2)
end

local function drawMain()
  local visual = visualStyle()
  local palette = visual.palette
  local opacity = visual.instrumentOpacity
  ui.drawRectFilled(vec2(), ui.windowSize(), Theme.withAlpha(palette.void, visual.backdropOpacity * opacity))

  ui.setCursorX(8)
  ui.setCursorY(18)
  if telemetryError then
    ui.dwriteText('TELEMETRY ERROR', settings.fontSize, Theme.withAlpha(palette.red, opacity))
    ui.text(telemetryError)
    return
  end

  if not player then
    ui.dwriteText('WAITING FOR TELEMETRY', settings.fontSize, Theme.withAlpha(palette.primary, opacity))
    ui.text('Race data is not available yet.')
    return
  end

  if settings.showHeader then
    ui.setCursorX(8)
    ui.dwriteText(headerText(), settings.fontSize, Theme.withAlpha(palette.secondary, opacity))
  end
  ui.setCursorX(8)
  ui.setCursorY(math.max(40, ui.getCursorY() + 4))
  for _, row in ipairs(shownAhead) do drawRow(row, false, visual) end
  drawRow(player, true, visual)
  for _, row in ipairs(shownBehind) do drawRow(row, false, visual) end
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
  cached = {
    id = id,
    name = name,
    driver = car:driverName(),
    number = car:driverNumber(),
    classID = classID,
    classSource = source
  }
  metadata[car.index] = cached
  ac.log('[MulticlassRelative] ' .. id .. ' -> ' .. classID .. ' (' .. source:lower() .. ')')
  return cached
end

local function updateTelemetry(dt)
  dt = dt or 0
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

function script.update(dt)
  if telemetryError then return end
  local ok, err = pcall(function()
    Relative.clampSettings(settings)
    updateTelemetry(dt)
  end)
  if not ok then
    telemetryError = tostring(err)
    ac.error('[MulticlassRelative] update error: ' .. telemetryError)
  end
end

function script.windowMain(_)
  local ok, err = pcall(drawMain)
  if not ok then
    local message = tostring(err)
    ac.error('[MulticlassRelative] draw error: ' .. message)
    ui.text('MULTICLASS RELATIVE')
    ui.text('DRAW ERROR')
    ui.text(message)
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
  ui.text('Theme and translucency follow Retro Engineering HUD when it is running.')
  ui.text('Fallback: black theme when the HUD is unavailable.')
  ui.text('Red = car lapping you; teal = car you are lapping.')
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
    if ui.button(shorten(row.carID, 27) .. ' -> ' .. row.classID .. '##class' .. row.index) then
      local n = 1
      for i, value in ipairs(choices) do if value == row.classID then n = i % #choices + 1 end end
      Classes.setOverride(row.carID, choices[n]); metadata[row.index] = nil
    end
  end
end
