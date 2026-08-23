package.path = './apps/lua/MulticlassRelative/?.lua;./apps/lua/MulticlassRelative/?/init.lua;' .. package.path

local Display = require('src/display')

local function contains(value, expected)
  assert(value:find(expected, 1, true), ('expected %q to contain %q'):format(value, expected))
end

local function excludes(value, unexpected)
  assert(not value:find(unexpected, 1, true), ('expected %q to exclude %q'):format(value, unexpected))
end

local settings = {
  showOverall = true,
  showClassPosition = false,
  showClassText = false,
  showNumber = true,
  showDriver = true,
  showGap = true,
  showPitIndicator = true,
  showLapDifference = true,
  maximumGap = 30,
  decimals = 1,
  fontSize = 18
}

local player = {
  overall = 17, classPosition = 7, classID = 'GT3', number = 27,
  driver = 'A piece of toast', filteredGap = 0, progress = 10.50,
  inPitlane = false
}
local row = {
  overall = 15, classPosition = 3, classID = 'HY', number = 42,
  driver = 'Driver B', filteredGap = -1.8, progress = 10.55,
  inPitlane = false
}

-- The compact defaults expose race information, not textual class data.
local header = Display.headerText(settings)
local text = Display.rowText(row, false, player, settings)
contains(header, 'POS'); contains(header, '#'); contains(header, 'DRIVER'); contains(header, 'GAP')
contains(text, '15'); contains(text, '42'); contains(text, 'Driver B'); contains(text, '-1.8')
excludes(header, 'CLASS'); excludes(header, 'CP'); excludes(text, 'HY')

-- The player keeps their real driver name and a dedicated row marker.
local playerText = Display.rowText(player, true, player, settings)
assert(playerText:sub(1, 1) == '>')
contains(playerText, 'A piece of toast'); contains(playerText, '0.0'); excludes(playerText, 'YOU')

-- Class text and class position are opt-in and independent.
settings.showClassPosition = true
settings.showClassText = true
text = Display.rowText(row, false, player, settings)
contains(text, 'HY'); contains(text, ' 3')
settings.showClassPosition = false
settings.showClassText = false

-- Pit visibility/filtering and the PIT presentation flag are separate.
row.inPitlane = true
settings.showPits = false
text = Display.rowText(row, false, player, settings)
contains(text, 'PIT')
settings.showPitIndicator = false
excludes(Display.rowText(row, false, player, settings), 'PIT')
settings.showPitIndicator = true
row.inPitlane = false

-- Lap difference has its own marker and never replaces the gap column.
row.progress = 11.45
text = Display.rowText(row, false, player, settings)
contains(text, '-1L'); contains(text, '-1.8')
settings.showLapDifference = false
text = Display.rowText(row, false, player, settings)
excludes(text, '-1L'); contains(text, '-1.8')

-- Every primary column can be disabled independently.
settings.showOverall = false
settings.showNumber = false
settings.showDriver = false
settings.showGap = false
header = Display.headerText(settings)
excludes(header, 'POS'); excludes(header, '#'); excludes(header, 'DRIVER'); excludes(header, 'GAP')

print('display_spec: ok')
