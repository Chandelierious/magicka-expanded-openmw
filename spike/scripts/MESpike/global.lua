-- MESpike GLOBAL script: performs the blink teleport when the player
-- watcher detects the custom effect — proves the full watch-react loop
-- (local watcher -> global event -> world mutation).

local util = require('openmw.util')

return {
  eventHandlers = {
    MESpike_Blink = function(data)
      local player = data.player
      if not player or not player.cell then return end
      local ok, err = pcall(function()
        local yaw = player.rotation:getYaw()
        local offset = util.vector3(math.sin(yaw) * 256, math.cos(yaw) * 256, 0)
        player:teleport(player.cell, player.position + offset)
      end)
      print(string.format('MESpike: blink teleport -> %s', ok and 'OK' or ('FAILED: ' .. tostring(err))))
    end,
  },
}
