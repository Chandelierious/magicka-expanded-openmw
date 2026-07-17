# Pack 03 (Teleportation) — build prep

Extracted from the MWSE source, ready to drop into the port. Everything the
build round needs, no re-derivation.

## Destinations (position / z-rotation in DEGREES / cell)

```lua
local DESTINATIONS = {
  aldruhn   = { name = 'Ald-Ruhn',   pos = {-16328,  52678, 1841}, rotZ =   92, cell = 'Ald-Ruhn' },
  balmora   = { name = 'Balmora',    pos = {-22707, -17639,  403}, rotZ =    0, cell = 'Balmora' },
  ebonheart = { name = 'Ebonheart',  pos = { 18122, -101919, 337}, rotZ =  268, cell = 'Ebonheart' },
  vivec     = { name = 'Vivec',      pos = { 29906, -76553,  790}, rotZ =  178, cell = 'Vivec' },
  caldera   = { name = 'Caldera',    pos = {-10373,  17241, 1284}, rotZ =    4, cell = 'Caldera' },
  gnisis    = { name = 'Gnisis',     pos = {-86430,  91415, 1035}, rotZ =   34, cell = 'Gnisis' },
  maargan   = { name = 'Maar Gan',   pos = {-22118, 102242, 1979}, rotZ =   34, cell = 'Maar Gan' },
  molagmar  = { name = 'Molag Mar',  pos = {106763, -61839,  780}, rotZ =   92, cell = 'Molag Mar' },
  pelagiad  = { name = 'Pelagiad',   pos = {  1008, -56746, 1360}, rotZ =   86, cell = 'Pelagiad' },
  suran     = { name = 'Suran',      pos = { 56217, -50650,   52}, rotZ =  178, cell = 'Suran' },
  telmora   = { name = 'Tel Mora',   pos = {106925, 117169,  264}, rotZ =   34, cell = 'Tel Mora' },
  mournhold = { name = 'Mournhold',  pos = {    -4,   3170,  199}, rotZ =    0, cell = 'Mournhold, Plaza Brindisi Dorom' },
}
```

Original effects: school mysticism, baseCost 150 each, self-range, instant.

## Build checklist (the substrate is proven — spike GO)

1. `mod/` folder in this repo as the shippable data path: `.omwscripts` with
   LOAD + GLOBAL + PLAYER.
2. load.lua: 12 custom effect records (`me_teleport_<key>`, hasDuration with
   ~1s so the watcher can't miss them, school mysticism, baseCost 150) + 12
   spells (`me_spell_teleport_<key>`, 'Teleport To <name>') — spike record
   mechanism, pcall+receipts.
3. player.lua watcher (from MESpike): on custom teleport effect →
   `LPH`-style global event with the destination key → retire via
   activeSpells:remove.
4. global.lua: `player:teleport(cell, vector3(pos), rotateZ(math.rad(rotZ)))`
   — degree→radian; verify the sign convention in-game on a city with a
   distinctive facing (Ebonheart 268).
5. Tomes: original ships 12 tome books teaching the spells (ESP BOOK records
   + leveled-list injection). v1: skip tomes, grant via the vanilla spell
   vendor question — or simplest test path: a console/startup grant setting.
   Decide with AJ.
6. Harness: extend mespike-harness pattern — records, watcher dispatch,
   teleport payloads.
7. Magicka cost: spike used alwaysSucceed/0-cost for testing; Pack 03 spells
   get real costs (150 base effect cost → autocalc or explicit ~150).

## Open decisions for AJ

- How spells are ACQUIRED in v1: free grant on load (fastest to test), buy
  from vanilla spell vendors (needs vendor injection research), or port the
  tome books properly (ESP-less book records + placement = more work).
- Keep original 150-cost Mysticism balance, or cheaper while testing?
