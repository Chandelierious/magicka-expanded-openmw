-- Magicka Expanded (OpenMW port) — shared data. Pure Lua, any context.
-- Pack 03: Teleportation. Destinations extracted from OperatorJack's MWSE
-- source (see PACK03-PREP.md); rotZ in degrees.

local data = {}

data.DESTINATIONS = {
  aldruhn   = { name = 'Ald-Ruhn',  pos = { -16328, 52678, 1841 },  rotZ = 92,  cell = 'Ald-Ruhn' },
  balmora   = { name = 'Balmora',   pos = { -22707, -17639, 403 },  rotZ = 0,   cell = 'Balmora' },
  ebonheart = { name = 'Ebonheart', pos = { 18122, -101919, 337 },  rotZ = 268, cell = 'Ebonheart' },
  vivec     = { name = 'Vivec',     pos = { 29906, -76553, 790 },   rotZ = 178, cell = 'Vivec' },
  caldera   = { name = 'Caldera',   pos = { -10373, 17241, 1284 },  rotZ = 4,   cell = 'Caldera' },
  gnisis    = { name = 'Gnisis',    pos = { -86430, 91415, 1035 },  rotZ = 34,  cell = 'Gnisis' },
  maargan   = { name = 'Maar Gan',  pos = { -22118, 102242, 1979 }, rotZ = 34,  cell = 'Maar Gan' },
  molagmar  = { name = 'Molag Mar', pos = { 106763, -61839, 780 },  rotZ = 92,  cell = 'Molag Mar' },
  pelagiad  = { name = 'Pelagiad',  pos = { 1008, -56746, 1360 },   rotZ = 86,  cell = 'Pelagiad' },
  suran     = { name = 'Suran',     pos = { 56217, -50650, 52 },    rotZ = 178, cell = 'Suran' },
  telmora   = { name = 'Tel Mora',  pos = { 106925, 117169, 264 },  rotZ = 34,  cell = 'Tel Mora' },
  mournhold = { name = 'Mournhold', pos = { -4, 3170, 199 },        rotZ = 0,   cell = 'Mournhold, Plaza Brindisi Dorom' },
}

-- stable iteration order
data.KEYS = {
  'aldruhn', 'balmora', 'ebonheart', 'vivec', 'caldera', 'gnisis',
  'maargan', 'molagmar', 'pelagiad', 'suran', 'telmora', 'mournhold',
}

function data.effectId(key) return 'me_teleport_' .. key end
function data.spellId(key) return 'me_spell_teleport_' .. key end

-- reverse lookup: effect record id -> destination key
data.keyByEffect = {}
for _, key in ipairs(data.KEYS) do
  data.keyByEffect[data.effectId(key)] = key
end

return data
