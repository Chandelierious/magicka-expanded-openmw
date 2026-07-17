# PORT-ASSESSMENT: Magicka Expanded (MWSE) → OpenMW 0.51 Lua

Inputs: framework source analysis, MWSE API census (79 files, 1,177 API tokens), effect/spell inventory (117 custom effects), OpenMW 0.51 docs capability survey (API v129). Confidence markers: **[C]** confirmed by docs/source, **[U]** uncertain — needs verification, **[X]** experiment required.

---

## 1. Executive verdict

**Zero lines of this codebase port as-is.** Every one of the 117 custom effects is built on `tes3.claimSpellEffectId` + `tes3.addMagicEffect` with engine-invoked `onTick`/`onCollision` callbacks. OpenMW 0.51 has no equivalent: custom magic effect *records* can be created (load context only, data fields only), but there is **no engine-invoked Lua for effect behavior and no cast event** [C]. The port is therefore a rewrite of the behavior layer on a new substrate (Section 3), with the MWSE code serving as a mechanics spec.

At the **mechanic level**, classifying all 117 effects by whether their behavior is reproducible on that substrate:

| Category | Count | Share | Meaning |
|---|---|---|---|
| Ports cleanly (on substrate) | 34 | 29% | Behavior trivially reproduced with documented 0.51 APIs (teleports, banish, no-op display effects) |
| Needs redesign | 74 | 63% | Feasible, but engine mechanics must be reimplemented in Lua (summons, bound items) or semantics/presentation change (weather, darkness, scry UI) |
| Blocked | 9 | 8% | No documented API path in 0.51 (damage/melee-hit interception, projectile access) |

The 29% "clean" figure is conditional on the substrate working at all, which itself rests on one unverified assumption: that a custom effect id cast via a normal spell is behaviorally inert but otherwise flows through casting/magicka/resistance/activeSpells normally **[X — experiment 1, the single biggest risk]**.

Framework services: spell/enchantment/potion record creation ports [C]; tomes/grimoires and vendor distribution port with redesign (via `onActivate`/`onActorActive`) [C]; MCM ports to `I.Settings` [C]; the VFX subsystem (scenegraph node attach, stencils, decals, MGE XE fog shader, procedural lightning) is **almost entirely blocked** — OpenMW Lua exposes no scenegraph, only whole-mesh `AddVfx`/`SpawnVfx` and `.omwfx` post-process shaders [C].

---

## 2. Per-pack assessment

Buckets: **A** = portable as-is on the substrate, **B** = portable with redesign, **X** = blocked.

| Pack | Effects | A | B | X | Notes / blocking reasons |
|---|---|---|---|---|---|
| 01 Lore Friendly | 14 | 1 | 13 | 0 | banishDaedra = A (delete daedra ref via global `object:remove()`, creature type check [C]). 13 bound armor/weapon = B: MWSE delegated to `e:triggerBoundWeapon/Armor`; OpenMW has no bound-item mechanic for new effect ids — reimplement via inventory add + `Actor.setEquipment`, restore prior gear on expiry, handle death/drop edge cases manually [C]. ESP item records reusable as-is. |
| 02 Summoning | 17 | 0 | 17 | 0 | All `triggerSummon`. No scriptable summon mechanic; reimplement: `world.createObject(creatureId):teleport(...)` + attached local script + `I.AI` Follow/Combat packages + expiry despawn + caster-death unlink + corpse cleanup [C for the parts; U for parity details: dispel-summon, soul-trap-of-summons, crime attribution]. The 1 vanilla-effect spell (Centurion Sphere) is pure data — trivial. |
| 03 Teleportation | 12 | 12 | 0 | 0 | `tes3.positionCell` → global-context `object:teleport(cell, pos, opts)` [C]. Only needs the watcher substrate; hardcoded destinations are data. |
| 04 Tamriel Rebuilt | 43 | 17 | 26 | 0 | 17 teleports = A (same as Pack 03). 26 summons = B (same substrate as Pack 02). `Tamriel_Data.esm` gating via `core.contentFiles` [C]. |
| 05 Weather Magic | 12 | 0 | 10 | 2 | 10 weather effects = B with a caveat: **no documented Lua weather-write API in 0.51** [C per docs survey]; candidate workaround is an mwscript bridge (ESP global mwscript polling a variable set via `world.mwscript`, calling `ChangeWeather`) [U/X]. If the bridge fails, these move to blocked. conjureLightning = X: `onCollision` ground-impact point unavailable (no projectile access), procedural lightning NIF switch-node animation impossible; a degraded actor-impact variant is possible. conjureAshShell = X: core mechanic is damage-nulling via MWSE `damage` event — no damage hook in 0.51 [C]; decal attach also impossible (no scenegraph). Both hinge on experiment 6. |
| 06 Cortex | 12 | 0 | 8 | 4 | B: blink (semantic change — castRay at cast time instead of projectile impact), clone/cloneSource/permutation (summon substrate; the force-drink-potion hack becomes unnecessary), darkness (`.omwfx` shader rewrite replaces MGE XE fog; light-strip via `activeEffects:remove`; no crime API [C]), mindRip (full `openmw.ui` rewrite; target spell list readable via `types.Actor.spells` [C]), mindScan/soulScrye (engine tooltip injection impossible — redesign as crosshair-target HUD overlay). X: coalesce (guided projectile — no projectile object exists in Lua [C]); 3 palm effects (`attackHit` interception + weapon-bone VFX attach — no melee-hit hook confirmed, no bone attach [C]; contingent on experiment 6). |
| **ME subtotal** | **110** | **30** | **74** | **6** | |
| class-starting-spells | 4 | 4 | 0 | 0 | The 4 custom effects are behaviorless display dummies — pure record data, the cleanest case. The ~31 vanilla-effect spells are pure data via load context [C]. The chargen UI hooks (`uiActivated`/`mouseButtonDown` on engine menus) do not port — redesign as post-chargen state polling (`onNewGame` + poll player class) [C]; loses the in-menu presentation, keeps the function. |
| leech-effects | 3 | 0 | 0 | 3 | Entire mechanic is `damage`/`damageHandToHand` interception → heal attacker by % of dealt damage. No damage event in 0.51 [C]. Health-delta polling cannot attribute the attacker or measure pre-mitigation damage — not a viable approximation. Blocked unless the `Hit` built-in event proves to be engine-emitted and observable [X — experiment 6]. Spell/enchantment/ingredient records themselves port fine. |
| **Grand total** | **117** | **34** | **74** | **9** | |

---

## 3. Fundamental architecture decision

MWSE's model (engine calls your `onTick` per effect instance) inverts in OpenMW: **the engine never calls you about magic; you watch the engine.** The only viable pattern given 0.51's load context and handler set:

### 3.1 Record layer — LOAD context, `onContentFilesLoaded`
- `LOAD:` script creates all effect records via `content.magicEffects.records[id] = { template = <closest vanilla effect or none>, name, icon, school, baseCost, particle, castStatic/bolt/hitStatic, sounds, flags }`. This is the **only** place magic effect records can be created — not `world.createRecord`, not runtime [C].
- Spell/enchantment records via `content.spells.records` / `content.enchantments.records` — load context keeps author-chosen string IDs (runtime `world.createRecord` generates ids, which breaks stable references in saves) [C]. Standard per-effect cast/bolt/hit visuals and school cast sounds come **free** as record data — a genuine improvement over the MWSE re-register-every-load model, since records persist for the session.
- Keep `Magicka Expanded.esp` for statics, sounds, books, bound items, custom creatures — OpenMW consumes it natively [C]. Replace the MGE XE `.fx` shader with an `.omwfx` rewrite; drop `mwse.memory.writeByte`.
- `tes3.claimSpellEffectId` numeric-slot allocation disappears entirely; string ids replace it.
- **[U]** Cross-mod load-script ordering (framework records before pack records) and visibility of one mod's load-created records to another mod's load script are undocumented — experiment 8. The `"MagickaExpanded:Register"` interop event must be redesigned around whatever ordering guarantee exists (likely: packs declare data tables; a single framework load script consumes them via `openmw.interfaces`, available in load context [C]).

### 3.2 Behavior layer — activeSpells watching
- **Detection:** no cast event, no cast interception, none planned in 0.51 [C]. A local watcher script attached to every actor (PLAYER flag for the player; NPC/CREATURE registration or dynamic attach from a global `onActorActive`) polls `types.Actor.activeSpells(self)` each `onUpdate`, diffs `activeSpellId` sets against the previous frame, and dispatches when a spell containing a registered custom effect id appears. On-touch/on-target effects surface on the **victim's** activeSpells with a `caster` field [C] — this is how target-range effects find both parties.
- **Instant effects** (teleport, banish, blink): give the effect record `hasDuration = true` with a short duration (~1s) so a frame-poller cannot miss it; the handler acts once, then retires via `activeSpells:remove(id)`. **[U]** `remove` only works on temporary-flag spells — presumed true for cast spells, verify (experiment 3). Whether zero-duration/`isAppliedOnce` effects appear in `activeSpells` at all is experiment 2.
- **Parameters:** magnitude/duration read from `ActiveSpellEffect.minMagnitude/maxMagnitude/durationLeft/magnitudeThisFrame` [C].
- **Consequences** route by privilege: local watcher sends `core.sendGlobalEvent` for world mutations (spawn, teleport, remove, cross-actor); global script executes. Stat effects via `types.Actor.stats.*` writes or the `ModifyStat` event; secondary magic via `activeSpells:add` helper spells (paralysis, blind) and `activeEffects:modify/remove`; equipment via `Actor.setEquipment`; visuals/audio via `AddVfx`/`SpawnVfx`/`PlaySound3d`; summon AI via `I.AI` packages. All [C].
- **Resistance/reflection:** the engine resolves these at cast time for the spell as a whole, but per-effect elemental resistance mapping (fire damage ↔ resist fire) is hardcoded to vanilla ids — custom effects must read the target's `activeEffects:getEffect('resist*')` and scale manually, exactly where the MWSE code did it manually too [U on what the engine applies by default — experiment 5].
- **Persistence:** watcher state (active summons, bound-item restore lists, effect bookkeeping) must be serialized in `onSave`/`onLoad` and type-guarded on read — MWSE got summon/bound persistence free from the engine; here it is the framework's job [C].

### 3.3 What the substrate structurally cannot see (hard limits in 0.51)
Projectile objects (flight, steering, impact point); melee hits and damage flow (**unless** the `Hit` event is engine-emitted — experiment 6); engine tooltips and engine menus; the scenegraph (bones, decals, stencils, switch nodes); weather writes; crime. Every blocked item in Section 2 traces to exactly one of these.

---

## 4. Recommended phase-1 scope

**Pack 03 (Teleportation), preceded by a substrate spike.**

1. **Spike (no pack):** one load script creating one custom effect + one spell; one watcher script; verify experiments 1–5 in-game. This is go/no-go for the whole project.
2. **Pack 03:** 12 effects, one mechanic, zero engine-mechanic reimplementation — `object:teleport` is a documented one-call global API. It exercises the full pipeline end-to-end (load-context records, tome learning via `onActivate`, cast detection, instant-effect timing, magicka cost/school integration, save/load of known spells) with the minimum confounding surface. Success here makes Pack 04's 17 teleports near-free (+data), i.e. 29 of 117 effects for one mechanic's work.
3. Then Pack 01 (bound items — first engine-mechanic reimplementation, small blast radius), then Pack 02 (summons — the biggest reusable subsystem, unlocking Pack 04's 26 summons and three Cortex effects).
4. Defer Pack 05 until the weather-bridge experiment resolves; defer leech-effects and the palm/ash-shell/coalesce effects until experiment 6 resolves; ship packs with blocked effects omitted rather than approximated.

class-starting-spells' ~31 vanilla-effect spells are a useful zero-risk smoke test of load-context spell creation and can ride along with the spike.

---

## 4.1 Spike results (AJ in-game, 2026-07-17) — **VERDICT: GO**

- Exp 1 (custom effect id casting): **PASS.** Both from-scratch and templated
  custom effects created in load context, granted, and cast normally —
  cast animation and magicka drain work. Behavior is inert as predicted, and
  **templating does NOT inherit engine behavior** (templated summonscamp
  spawned nothing) — engine mechanics key off the hardcoded effect id, not
  record data. All behavior is the framework's to implement.
- Exp 2 (activeSpells visibility): **PASS.** All three spells appeared in the
  watcher with correct ids/durations; custom effect magThisFrame=nil for the
  templated effect, =magnitude for the from-scratch one.
- Exp 3 (activeSpells:remove): **PASS** (`remove(Generated:0xb28) -> OK`).
- Exp 4 (cast pipeline): **PASS** (magicka consumed, animations/sounds play).
- React loop: **PASS** — blink cast triggered watcher → global event →
  teleport. (Distance/direction math needs polish: moved "a few inches" and
  clipped into a slope once; real blink needs castRay + proper yaw handling.
  Irrelevant to go/no-go.)
- Note: round-2 control spell (Jump 10pts) was too subtle to feel; replaced
  with Levitate 50/10s for future runs.
- Permissions: AJ reports OperatorJack's page grants free use with credit —
  publishing unblocked, credit required.

## 5. Open questions requiring in-game experiments

1. **Custom effect id behavior (go/no-go):** create a from-scratch `content.magicEffects` record and a templated one (e.g. template `summonscamp`); cast each. Is the effect inert? Does templating inherit hardcoded behavior (and the template's creature)? Does anything crash?
2. **Instant-effect visibility:** do `isAppliedOnce`/no-duration custom effects appear in `activeSpells` for ≥1 frame? What minimum duration guarantees one-poll visibility?
3. **`activeSpells:remove`:** does it retire an engine-cast spell (temporary flag) on player and NPC?
4. **Cast pipeline integration:** does casting a custom-effect-only spell consume magicka, roll cast chance against the record's school skill, grant that school XP, and play the record's cast/hit visuals and sounds?
5. **Resist/reflect/absorb/dispel** against custom effect ids: what does the engine apply unprompted; does Dispel strip watcher-managed active spells?
6. **`Hit` event direction:** is the built-in `Hit` event emitted by engine combat to victim local scripts (observable attacker/damage), or send-only? Decides palm effects, ash shell, and all of leech-effects (7 effects total).
7. **Weather bridge:** confirm absence of a Lua weather API in 0.51 stable docs, then test an ESP mwscript `ChangeWeather` loop driven by a `world.mwscript` global variable set from Lua.
8. **Load-script ordering and cross-mod record visibility** (framework vs. pack load scripts; content-list order dependence).
9. **Spellmaking/enchanting services:** do custom effects with `allowsSpellmaking`/`allowsEnchanting` appear and function in the vanilla service menus?
10. **Save stability:** save with a custom spell known and active; reload; update/remove the mod; confirm no dangling-record crashes and stable ids.
11. **`AddVfx` lifecycle:** can a looping VFX attached to an actor be removed on demand (continuous-effect visuals)?
12. **NPC casting:** will NPC AI ever cast distributed custom spells (affects whether the vendor-distribution feature has any gameplay effect beyond selling)?