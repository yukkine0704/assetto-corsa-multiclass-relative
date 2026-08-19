local Relative = {}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

function Relative.build(cars, player, timing, now, settings, dt)
  local ahead, behind = {}, {}
  for _, row in ipairs(cars) do
    if row.index ~= player.index and (settings.mode ~= 1 or row.classID == player.classID) then
      local delta = row.progress - player.progress
      if math.abs(delta) > 0.0001 and (settings.showPits or not row.inPitlane) then
        row.progressDelta = delta
        local raw = timing:relativeGap(player.index, row.index, now)
        row.rawGap = raw
        if raw and math.abs(delta) < 0.98 then
          local alpha = 1 - math.exp(-dt / math.max(0.05, settings.smoothing))
          if not row.filteredGap or row.filteredGap * raw < 0 then row.filteredGap = raw
          else row.filteredGap = row.filteredGap + (raw - row.filteredGap) * alpha end
        else
          row.filteredGap = nil
        end
        if delta > 0 then table.insert(ahead, row) else table.insert(behind, row) end
      end
    end
  end
  table.sort(ahead, function(a, b) return a.progressDelta < b.progressDelta end)
  table.sort(behind, function(a, b) return a.progressDelta > b.progressDelta end)
  local selectedAhead, selectedBehind = {}, {}
  for i = math.min(#ahead, settings.ahead), 1, -1 do table.insert(selectedAhead, ahead[i]) end
  for i = 1, math.min(#behind, settings.behind) do table.insert(selectedBehind, behind[i]) end
  return selectedAhead, selectedBehind
end

function Relative.lapText(row, player)
  local laps = math.floor(row.progress) - math.floor(player.progress)
  if laps == 0 then return nil end
  return (laps > 0 and '-' or '+') .. math.abs(laps) .. 'L'
end

function Relative.clampSettings(settings)
  settings.ahead = clamp(math.floor(settings.ahead + 0.5), 1, 10)
  settings.behind = clamp(math.floor(settings.behind + 0.5), 1, 10)
end

return Relative
