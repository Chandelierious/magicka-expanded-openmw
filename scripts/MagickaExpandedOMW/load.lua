-- Magicka Expanded (OpenMW port) — LOAD-context record creation.
-- Pack 03: 12 custom teleport effects + 12 spells. TESTING BALANCE: spells
-- cost 1 and always succeed ("work perfectly before I worry about balance"
-- — AJ); real Mysticism-150 costs come later.
-- Effects get hasDuration + 2s so the per-frame watcher can't miss them.

local content = require('openmw.content')

local data = require('scripts.MagickaExpandedOMW.data')

local function attempt(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    print(string.format('MEOMW load: %s FAILED: %s', label, tostring(err)))
  end
  return ok
end

local function onContentFilesLoaded()
  local effects, spells = 0, 0
  for _, key in ipairs(data.KEYS) do
    local dest = data.DESTINATIONS[key]
    local eid, sid = data.effectId(key), data.spellId(key)
    attempt('effect ' .. eid, function()
      content.magicEffects.records[eid] = {
        name = 'Teleport To ' .. dest.name,
        school = 'mysticism',
        baseCost = 1,
        hasDuration = true,
      }
    end)
    if content.magicEffects.records[eid] then effects = effects + 1 end
    attempt('spell ' .. sid, function()
      content.spells.records[sid] = {
        name = 'Teleport To ' .. dest.name,
        type = content.spells.TYPE.Spell,
        cost = 1,
        isAutocalc = false,
        alwaysSucceedFlag = true,
        effects = { { id = eid, duration = 2, magnitudeMin = 1, magnitudeMax = 1 } },
      }
    end)
    if content.spells.records[sid] then spells = spells + 1 end
  end
  print(string.format('MEOMW load: %d/12 effects, %d/12 spells created', effects, spells))
end

return {
  engineHandlers = {
    onContentFilesLoaded = onContentFilesLoaded,
  },
}
