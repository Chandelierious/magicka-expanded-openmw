-- MESpike PLAYER script: grants the spike spells and runs the activeSpells
-- watcher — the behavior-layer half of the go/no-go experiments
-- (experiments 1-4 from PORT-ASSESSMENT.md section 5).
-- Grep openmw.log for "MESpike:" while casting the spells in-game.

local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')

local granted = false
local seen = {} -- activeSpellId -> true for spells already logged

local function grantSpells()
  if granted then return end
  granted = true
  local spells = types.Actor.spells(self)
  for _, id in ipairs({ 'mespike_spell_blink', 'mespike_spell_summon', 'mespike_spell_control' }) do
    local ok, err = pcall(function() spells:add(id) end)
    print(string.format('MESpike: grant %s -> %s', id, ok and 'OK' or ('FAILED: ' .. tostring(err))))
  end
end

local function describeActive(sp)
  print(string.format('MESpike: ACTIVE spell id=%s activeSpellId=%s name=%s temporary=%s caster=%s',
    tostring(sp.id), tostring(sp.activeSpellId), tostring(sp.name),
    tostring(sp.temporary), tostring(sp.caster and sp.caster.recordId)))
  local ok, err = pcall(function()
    for _, eff in pairs(sp.effects) do
      print(string.format('MESpike:   effect id=%s name=%s durationLeft=%s magThisFrame=%s',
        tostring(eff.id), tostring(eff.name), tostring(eff.durationLeft),
        tostring(eff.magnitudeThisFrame)))
    end
  end)
  if not ok then print('MESpike:   effect iteration FAILED: ' .. tostring(err)) end
end

local function onUpdate(dt)
  local active = types.Actor.activeSpells(self)
  local present = {}
  for _, sp in pairs(active) do
    local key = sp.activeSpellId or sp.id
    present[key] = true
    if not seen[key] then
      seen[key] = true
      describeActive(sp)
      -- React-loop proof: when our custom blink effect shows up, do the
      -- teleport through a global event, then try to retire the active
      -- spell (experiment 3: does remove work on an engine-cast spell?).
      local hasBlink = false
      local ok = pcall(function()
        for _, eff in pairs(sp.effects) do
          if eff.id == 'mespike_blink' then hasBlink = true end
        end
      end)
      if ok and hasBlink then
        print('MESpike: blink effect detected -> sending MESpike_Blink')
        core.sendGlobalEvent('MESpike_Blink', { player = self.object })
        local okR, errR = pcall(function() active:remove(sp.activeSpellId) end)
        print(string.format('MESpike: activeSpells:remove(%s) -> %s',
          tostring(sp.activeSpellId), okR and 'OK' or ('FAILED: ' .. tostring(errR))))
      end
    end
  end
  -- Forget spells that ended so a re-cast logs again.
  for key in pairs(seen) do
    if not present[key] then seen[key] = nil end
  end
end

return {
  engineHandlers = {
    onActive = grantSpells,
    onUpdate = onUpdate,
    onSave = function() return { version = 1, granted = granted } end,
    onLoad = function(data)
      granted = (data and data.granted) and true or false
    end,
  },
}
