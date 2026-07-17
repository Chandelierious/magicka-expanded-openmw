-- Magicka Expanded (OpenMW port) — PLAYER script.
-- Grants the Pack 03 spells (testing v1: free on first activation) and runs
-- the activeSpells watcher: when a cast custom teleport effect appears,
-- dispatch the destination to the global script and retire the spell.

local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')

local data = require('scripts.MagickaExpandedOMW.data')

local granted = false
local seen = {}

local function grantSpells()
  if granted then return end
  granted = true
  local spells = types.Actor.spells(self)
  local count = 0
  for _, key in ipairs(data.KEYS) do
    local ok, err = pcall(function() spells:add(data.spellId(key)) end)
    if ok then count = count + 1 else
      print(string.format('MEOMW: grant %s failed: %s', data.spellId(key), tostring(err)))
    end
  end
  print(string.format('MEOMW: granted %d/12 teleport spells', count))
end

local function onUpdate(dt)
  local active = types.Actor.activeSpells(self)
  local present = {}
  for _, sp in pairs(active) do
    local id = sp.activeSpellId or sp.id
    present[id] = true
    if not seen[id] then
      seen[id] = true
      local destKey = nil
      pcall(function()
        for _, eff in pairs(sp.effects) do
          if data.keyByEffect[eff.id] then destKey = data.keyByEffect[eff.id] end
        end
      end)
      if destKey then
        print('MEOMW: teleport effect detected -> ' .. destKey)
        core.sendGlobalEvent('MEOMW_Teleport', { key = destKey, player = self.object })
        local okR, errR = pcall(function() active:remove(sp.activeSpellId) end)
        if not okR then print('MEOMW: activeSpells:remove failed: ' .. tostring(errR)) end
      end
    end
  end
  for id in pairs(seen) do
    if not present[id] then seen[id] = nil end
  end
end

return {
  engineHandlers = {
    onActive = grantSpells,
    onUpdate = onUpdate,
    onSave = function() return { version = 1, granted = granted } end,
    onLoad = function(saved)
      granted = (saved and saved.granted) and true or false
    end,
  },
}
