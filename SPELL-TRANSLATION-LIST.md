# Spell translation list — where the creativity is needed

Companion to PORT-ASSESSMENT.md. Every named custom effect from Magicka
Expanded + Class Starting Spells + Leech Effects, sorted by how much
reinvention its OpenMW translation needs. Substrate assumed working
(spike round 1 = GO).

## Tier 0 — clean translations (34): no creativity needed

- **All 29 teleports.** Packs 03+04: Ald-ruhn, Balmora, Ebonheart, Vivec,
  Caldera, Gnisis, Maar Gan, Molag Mar, Pelagiad, Suran, Tel Mora, Mournhold;
  TR: Akamora, Firewatch, Helnim, Necrom, Old Ebonheart, Port Telvannis,
  Alt Bosara, Bal Orya, Gah Sadrith, Gorne, Llothanis, Marog, Meralag,
  Tel Aranyon, Tel Mothrivra, Tel Muthada, Tel Ouada.
  `object:teleport` to the same hardcoded coordinates. Data + one mechanic.
- **Banish Daedra** (+ Weak Banishment from class-starting-spells):
  level-gated `object:remove()` on a daedra target.
- **The 4 chargen display dummies** (fortify Str/Int/Agi/Per) — behaviorless
  records, plus ~31 vanilla-effect starting spells = pure load-context data.

## Tier 1 — creative translations (the "we reimplement the engine" bucket)

These are feasible but we build what MWSE got for free:

- **~45 summons** — Pack 02 (Goblin Grunt/Officer/Warchief, Hulking
  Fabricant, Imperfect, Ascended Sleeper, Draugr, Lich, Ogrim, War Durzog,
  Spriggan, Centurion Steam/Archer/Spider, Ash Ghoul/Zombie/Slave), Pack 04's
  26 Tamriel Rebuilt summons (Frost Lich, Mammoth, Minotaur, Sload, Lamia,
  Silt Strider...), plus Cortex **Clone/Clone Source** (summon a copy of the
  scanned actor's record) and **Permutation** (summon tier picked by
  willpower+conjuration).
  Build once: spawn + follow/defend AI packages + expiry despawn +
  save/load bookkeeping + dispel handling. One subsystem unlocks all ~45.
- **13 bound weapons/armor** (Pack 01: Claymore, Club, Dai-Katana, Katana,
  Shortsword, Staff, Tanto, Wakizashi, War Axe, Warhammer, Greaves, both
  Pauldrons): temp item into inventory + force-equip + restore previous gear
  on expiry/death/dispel. The ESP's bound item records already exist.
- **Blink** (Cortex): original teleported to projectile impact. No
  projectiles in OpenMW Lua → cast-time `nearby.castRay` along the camera
  axis, teleport to first hit (this also fixes the spike's through-the-floor
  hop). Semantic change: instant, no travel time.
- **Mind Rip** (Cortex): the spell-stealing menu — full `openmw.ui` rewrite
  (we now have a working menu pattern from the pillow mod); target's spell
  list is readable via `types.Actor.spells`.
- **Mind Scan / Soul Scrye** (Cortex): tooltip injection is impossible →
  redesign as a crosshair-target HUD overlay while the buff is active
  (name + spells / vitals bars). Arguably an upgrade.
- **Darkness** (Dark Shadow / Veil of Darkness): MGE-XE fog shader →
  `.omwfx` post-process sphere-fog rewrite + strip Light effects via
  `activeEffects:remove`; blind via helper spell. Crime trigger is lost
  (no crime API).
- **10 weather spells** (Winter's Embrace, Kyne's Wrath, Dagoth's Domain,
  Veloth's Tears, + Snow/Thunder/Ash/Blight/Clear/Cloudy/Fog/Overcast/Rain
  variants): NO Lua weather write exists. Candidate: mwscript bridge — ESP
  global script polling a variable we set via `world.mwscript`, calling
  vanilla `ChangeWeather`. Experiment 7 decides; if it fails these move to
  Tier 2.
- **Class Starting Spells chargen flow**: engine-menu hooks don't exist →
  post-chargen detection (`onNewGame` + class polling) grants the same
  spells; loses the in-menu presentation, keeps the function.

## Tier 2 — blocked as designed: needs REAL creativity (9 effects)

The original mechanic has no API path in 0.51. Options are reimagination or
omission. Experiment 6 (is the built-in `Hit` event engine-emitted to victim
scripts?) is the single gate for six of the nine.

| Effect | Why blocked | Most-creative viable reimagining |
|---|---|---|
| **Health / Magicka / Fatigue Leech** (3) | Heal attacker by % of dealt damage — no damage event, no attacker attribution | If `Hit` fires engine-side: port as designed. If not: redesign as a pulsing aura — while buffed and in combat, drain nearest engaged enemy X/sec and credit the caster. Different feel, same fantasy. |
| **Conjure Palm Flame/Frost/Lightning** (3) | `attackHit` interception + VFX welded to the hand bone (no scenegraph, no melee hook) | Same `Hit` gate for the damage rider. Hand VFX is unachievable; nearest approximation is a whole-body `AddVfx` glow. If `Hit` fails: reimagine as short-range touch-cast strikes that consume the buff. |
| **Conjure Ash Shell** | Damage-nulling via damage-event hook + body decals | Approximate invulnerability: stack huge elemental resists + Sanctuary via a helper ability, keep the self-paralysis. No ash decals (no scenegraph). Accepts imperfection: direct weapon damage can't be zeroed without a damage hook. |
| **Conjure Lightning** | Projectile ground-impact point + procedural lightning mesh + crime | Cast-time `castRay` to the aimed ground point during thunderstorms, `SpawnVfx` a shipped lightning-bolt NIF there, thunderclap sound, radius damage via `nearby.actors` scan. Loses: throwable arc, crime attribution. Keeps: the fantasy. |
| **Coalesce** | Steers a live spell projectile along the eye vector — projectiles don't exist as Lua objects | Cannot exist as designed. Reimagining: a channeled "beam" — repeated short castRay damage ticks while held, or a player-steered `SpawnVfx` orb that detonates via our own position math. Honestly a different spell wearing the same name. |

## Suggested build order (after Pack 03 ships)

1. Pack 03 Teleportation (Tier 0, proves the pipeline end-to-end).
2. Pack 01 bound items (first engine-mechanic rebuild, small blast radius).
3. Summon subsystem → Packs 02 + 04 + Cortex clone/permutation (~45 effects).
4. Run experiment 6 (`Hit`) and 7 (weather bridge) as spikes — they decide
   Tier 2's fate and Pack 05.
5. Cortex UI effects (mindRip menu, scan/scrye overlays) — reuses pillow
   menu experience.
6. Tier 2 reimaginings last, with AJ's sign-off per spell on semantic changes.

Credit: all spell design by OperatorJack (Magicka Expanded), Merlord-era
framework patterns, chantox (Leech Effects), class-starting-spells author.
OperatorJack grants use with credit (per his page).
