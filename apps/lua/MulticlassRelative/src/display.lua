local Relative = require('src/relative')

local Display = {}

local function driverWidth(settings)
  return math.max(8, math.floor(20 * 18 / settings.fontSize + 0.5))
end

local function shorten(value, count)
  value = value or 'Unknown driver'
  return #value > count and value:sub(1, count - 3) .. '...' or value
end

local function add(parts, enabled, value)
  if enabled and value then table.insert(parts, value) end
end

function Display.headerText(settings)
  local width = driverWidth(settings)
  local parts = {}
  add(parts, settings.showOverall, string.format('%2s', 'POS'))
  add(parts, settings.showClassPosition, string.format('%2s', 'CP'))
  add(parts, settings.showClassText, string.format('%-5s', 'CLASS'))
  add(parts, settings.showNumber, string.format('%3s', '#'))
  add(parts, settings.showDriver, string.format('%-' .. width .. 's', 'DRIVER'))
  add(parts, settings.showGap, string.format('%6s', 'GAP'))
  return ' ' .. table.concat(parts, ' ')
end

function Display.gapText(row, settings)
  if not row.filteredGap then return '...' end
  if math.abs(row.filteredGap) > settings.maximumGap then return '>' .. settings.maximumGap .. 's' end
  return string.format('%+.' .. settings.decimals .. 'f', row.filteredGap)
end

function Display.rowText(row, isPlayer, player, settings)
  local width = driverWidth(settings)
  local parts = {}
  add(parts, settings.showOverall, string.format('%2d', row.overall))
  add(parts, settings.showClassPosition, string.format('%2d', row.classPosition))
  add(parts, settings.showClassText, string.format('%-5s', row.classID or 'UNKNOWN'))
  add(parts, settings.showNumber, string.format('%3s', tostring(row.number or '?')))
  add(parts, settings.showDriver, string.format('%-' .. width .. 's', shorten(row.driver, width)))
  add(parts, settings.showGap, string.format('%6s', isPlayer and string.format('%.' .. settings.decimals .. 'f', 0) or Display.gapText(row, settings)))
  add(parts, settings.showPitIndicator and row.inPitlane, 'PIT')
  add(parts, settings.showLapDifference, Relative.lapText(row, player))
  add(parts, row.approaching, 'FAST')
  return (isPlayer and '>' or ' ') .. table.concat(parts, ' ')
end

return Display
