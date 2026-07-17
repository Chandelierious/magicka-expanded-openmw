-- Magicka Expanded (OpenMW port) — GLOBAL script.
-- Executes teleports dispatched by the player watcher.

local util = require('openmw.util')

local data = require('scripts.MagickaExpandedOMW.data')

return {
  eventHandlers = {
    MEOMW_Teleport = function(ev)
      local dest = ev and data.DESTINATIONS[ev.key]
      local player = ev and ev.player
      if not dest or not player then return end
      local ok, err = pcall(function()
        player:teleport(dest.cell,
          util.vector3(dest.pos[1], dest.pos[2], dest.pos[3]),
          { rotation = util.transform.rotateZ(math.rad(dest.rotZ)) })
      end)
      print(string.format('MEOMW: teleport to %s -> %s', tostring(ev.key),
        ok and 'OK' or ('FAILED: ' .. tostring(err))))
    end,
  },
}
