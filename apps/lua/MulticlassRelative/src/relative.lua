local Relative = {}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function circularSplineDelta(fromSpline, toSpline)
  local delta = toSpline - fromSpline
  if delta > 0.5 then return delta - 1 end
  if delta < -0.5 then return delta + 1 end
  return delta
end

function Relative.build(cars, player, timing, now, settings, dt, memory)
  memory = memory or {}
  local ahead, behind = {}, {}
  for _, row in ipairs(cars) do
    if row.index ~= player.index and (settings.mode ~= 1 or row.classID == player.classID) then
      -- Race progress is for classification and lap markers. A relative needs
      -- physical track proximity, so take the shortest direction around the
      -- circuit from spline positions instead. This keeps a lapping car below
      -- the player when it is physically approaching from behind.
      local delta = circularSplineDelta(player.spline, row.spline)
      if math.abs(delta) > 0.0001 and (settings.showPits or not row.inPitlane) then
        row.progressDelta = delta
        local raw = timing:relativeGap(player.index, row.index, now, delta)
        row.rawGap = raw
        local previous = memory[row.index] or {}
        if raw and math.abs(delta) < 0.98 then
          local alpha = 1 - math.exp(-dt / math.max(0.05, settings.smoothing))
          if not previous.filteredGap or previous.filteredGap * raw < 0 then row.filteredGap = raw
          else row.filteredGap = previous.filteredGap + (raw - previous.filteredGap) * alpha end
        else
          row.filteredGap = nil
        end
        memory[row.index] = { filteredGap = row.filteredGap, lastSeen = now }
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

Relative.circularSplineDelta = circularSplineDelta

function Relative.pruneMemory(memory, now)
  for index, entry in pairs(memory) do
    if entry.lastSeen < now - 5 then memory[index] = nil end
  end
end

function Relative.lapText(row, player)
  local laps = Relative.lapDelta(row, player)
  if laps == 0 then return nil end
  return (laps > 0 and '-' or '+') .. math.abs(laps) .. 'L'
end

function Relative.lapDelta(row, player)
  return math.floor(row.progress) - math.floor(player.progress)
end

function Relative.lapState(row, player)
  local laps = Relative.lapDelta(row, player)
  if laps > 0 then return 'lapping_player' end
  if laps < 0 then return 'being_lapped' end
  return nil
end

function Relative.clampSettings(settings)
  settings.ahead = clamp(math.floor(settings.ahead + 0.5), 1, 10)
  settings.behind = clamp(math.floor(settings.behind + 0.5), 1, 10)
end

return Relative
