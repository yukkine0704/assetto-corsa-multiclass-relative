local Classes = {}

Classes.colors = {
  HY = rgb(0.95, 0.26, 0.32), LMP1 = rgb(0.95, 0.26, 0.32), LMP2 = rgb(0.98, 0.58, 0.18),
  LMP3 = rgb(0.98, 0.78, 0.20), GT3 = rgb(0.20, 0.64, 1.00), GT4 = rgb(0.28, 0.82, 0.52),
  GTE = rgb(0.66, 0.38, 1.00), TCR = rgb(0.22, 0.83, 0.82), TC = rgb(0.22, 0.83, 0.82),
  CUP = rgb(0.92, 0.92, 0.92), UNKNOWN = rgb(0.58, 0.60, 0.64)
}

local known = {
  { 'hypercar', 'HY' }, { 'lmdh', 'HY' }, { 'lmh', 'HY' }, { 'lmp1', 'LMP1' },
  { 'lmp2', 'LMP2' }, { 'lmp3', 'LMP3' }, { 'gt3', 'GT3' }, { 'gt4', 'GT4' },
  { 'gte', 'GTE' }, { 'tcr', 'TCR' }, { 'touring', 'TC' }, { ' cup', 'CUP' }
}

local ini = ac.INIConfig.load(__dirname .. '/classes.ini')

local function classOverride(id)
  return ac.storage['multiclass-relative.class.' .. id]
end

function Classes.setOverride(id, classID)
  ac.storage['multiclass-relative.class.' .. id] = classID
end

function Classes.detect(id, name, automatic)
  local override = classOverride(id)
  if override and override ~= '' then return override, 'OVERRIDE' end
  local exact = ini and ini:get('EXACT', id, '') or ''
  if exact ~= '' then return exact, 'MAPPING' end
  if not automatic then return 'UNKNOWN', 'UNKNOWN' end
  local value = (id .. ' ' .. (name or '')):lower()
  for _, rule in ipairs(known) do
    if value:find(rule[1], 1, true) then return rule[2], 'INFERRED' end
  end
  return 'UNKNOWN', 'UNKNOWN'
end

return Classes
