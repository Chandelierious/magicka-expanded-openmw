# OpenMW 0.51 Lua magic API — findings from official docs (openmw.readthedocs.io, `/en/openmw-0.51.0/`, all pages state "API v129"; `/en/stable/` currently serves identical content)

## (1) LOAD context and custom MAGIC EFFECT records

**The LOAD context** (Overview page, "Format of .omwscripts"): "LOAD - a load script, active while content files are being loaded;". Hot-reload note: "Load scripts will not run again until the game is restarted."

**Packages available to load scripts** (API Reference table): `async`, `content`, `core`, `interfaces`, `markup`, `storage`, `util`, `vfs`. `content` is load-exclusive: "content | load | Content manipulation."

**openmw.content package description** (verbatim): "Allows for manipulation of the data loaded from content files while the game is first started. Records can be created and deleted using this package as if a content file had done so."

**Magic effects in load context** — `content.magicEffects` → `MagicEffectContent.records`: "A mutable list of all openmw.core#MagicEffects." Documented usage (verbatim, the ONLY example given):
```lua
content.magicEffects.records.MyMagicEffect = { template = content.magicEffects.records['summonscamp'], name = 'Summon Nothing' }
```
Record types manipulable via content: activators, books, doors, enchantments, gameSettings (GMST), globals, ingredients, lights, **magicEffects**, miscs, potions, probes, sounds, **spells**, statics. (No skills, no races, no birthsigns.)

**MagicEffect record fields** (openmw_core, verbatim descriptions): `allowsEnchanting`, `allowsSpellmaking`, `areaSound`, `areaStatic`, `baseCost`, `bolt`, `boltSound`, `castSound`, `castStatic`, `casterLinked` ("If set, it is implied the magic effect links back to the caster in some way and should end immediately or never be applied if the caster dies or is not an actor."), `color`, `continuousVfx`, `description`, `harmful`, `hasAttribute`, `hasDuration` ("If set, the magic effect has a duration."), `hasMagnitude`, `hasSkill`, `hitSound`, `hitStatic`, `icon`, `id`, `isAppliedOnce` ("If set, the magic effect is applied fully on cast, rather than being continuously applied over the effect's duration."), `name`, `negativeLight`, `nonRecastable`, `onSelf`, `onTarget`, `onTouch`, `particle`, `school` ("Skill ID that is this effect's school"), `speed`, `unreflectable`.

**How is custom effect BEHAVIOR implemented? — NOT DOCUMENTED / ABSENT.** Load-bearing negatives, verified against the full pages:
- There is **no documented Lua callback, handler, or hook that the engine runs for a magic effect**. No "onApply", no per-effect script field, nothing. The docs describe only data fields (flags, visuals, sounds, cost, school) plus the `template` mechanism copying an existing hardcoded effect (`summonscamp` in the example). What runtime behavior a from-scratch effect id would have is **not stated anywhere**.
- `MagicEffect.createRecordDraft` **does not exist** (grep of the full core/types pages: `createRecordDraft` exists only for Spells, Enchantments, and the item/actor record types).
- `world.createRecord`'s supported-type list does **not** include MagicEffect — magic effect records are creatable **only** in the load context via `content.magicEffects`, not at runtime.

## (2) Custom SPELL records — YES, both runtime and load context

**Runtime (global scripts):** `core.magic.spells` → verbatim: "Spells.createRecordDraft(spell) — Creates a #Spell without adding it to the world database. Use openmw_world#world.createRecord to add the record to the world. Parameter: #Spell spell : A Lua table with the fields of a Spell, with an optional field template that accepts a #Spell as a base."

`world.createRecord(record)` (openmw_world, global context): "Creates a custom record in the world database; string IDs that came from ESM3 content files are lower-cased. Eventually meant to support all records, but the current set of supported types is limited to:" ActivatorRecord, ArmorRecord, BookRecord, ClothingRecord, ContainerRecord, CreatureRecord, DoorRecord, **openmw.core#Enchantment**, LightRecord, MiscellaneousRecord, NpcRecord, PotionRecord, ProbeRecord, **openmw.core#Spell**, StaticRecord, WeaponRecord. Parameter note: "The id field is not used, one will be generated for you." (So runtime-created spells get engine-generated ids; load-context records keep the key you assign.)

**Load context:** `content.spells.records` "A mutable list of all openmw.core#Spells." Documented usage:
```lua
content.spells.records.MySpell = { name = 'Enchantment?', type = content.spells.TYPE.Spell, cost = 1000, starterSpellFlag = true, isAutocalc = true, effects = { { id = 'FortifyAttribute', affectedAttribute = 'intelligence', duration = 5, magnitudeMin = 5, magnitudeMax = 10 } } }
```

**Spell fields** (verbatim descriptions): `alwaysSucceedFlag` ("If set, the spell should ignore skill checks and always succeed."), `autocalcFlag` (DEPRECATED), `cost`, `effects` ("#list<#MagicEffectWithParams>"), `id`, `isAutocalc` ("If set, the casting cost should be computed based on the effect list rather than read from the cost field"), `name`, `starterSpellFlag`, `type` (SPELL_TYPE: Ability/Blight/Curse/Disease/Power/"Spell — Normal spell, must be cast and costs mana"). Effect entries (`MagicEffectWithParams`): `affectedAttribute`, `affectedSkill`, `area`, `duration`, `effect`, `id`, `index`, `magnitudeMax`, `magnitudeMin`, `range` (core.magic.RANGE Self/Touch/Target).

## (3) Reacting to casting / active effects (openmw_types, Actor)

**`types.Actor.activeSpells(actor)` → ActorActiveSpells** — "Read-only list of spells currently affecting the actor. Can be iterated over for a list of openmw.core#ActiveSpell". Methods:
- `add(options)`: "Adds a new spell to the list of active spells (only in global scripts or on self). Note that this does not play any related VFX or sounds. Note that this should not be used to add spells without durations (i.e. abilities, curses, and diseases) as they will expire instantly. Use ActorSpells.add instead." Options (verbatim): required `id` ("Valid records are openmw.core#Spell, enchanted #Item, #IngredientRecord, or #PotionRecord"), `effects` ("A list of indexes of the effects to be applied"); optional `name`, `ignoreResistances`, `ignoreSpellAbsorption`, `ignoreReflect`, `caster`, `item`, `stackable`, `quiet`. This is the framework-grade "apply arbitrary effects" entry point.
- `isSpellActive(recordOrId)`; `remove(id)`: "Can only be used in global scripts or on self. Can only be used to remove spells with the temporary flag set."
- ActiveSpell fields: `activeSpellId`, `affectsBaseValues`, `caster`, `effects`, `fromEquipment`, `id`, `item`, `name`, `stackable`, `temporary`. ActiveSpellEffect: `id`, `index`, `name`, `affectedAttribute`, `affectedSkill`, `duration`, `durationLeft`, `minMagnitude`, `maxMagnitude`, `magnitudeThisFrame` ("a new random number between minMagnitude and maxMagnitude every frame").

**`types.Actor.activeEffects(actor)` → ActorActiveEffects** — "Read-only list of effects currently affecting the actor." Methods: `getEffect(effectId, extraParam)`; `modify(value, effectId, extraParam)`: "Permanently modifies the magnitude of an active effect by modifying it by the provided value. Note that some active effect values, such as fortify attribute effects, have no practical effect of their own, and must be paired with explicitly modifying the target stat to have any effect."; `set(value, ...)`: "(Note that using this function will override and conflict with all other sources of this effect. You probably want to use ActorActiveEffects.modify instead, this function is provided for mwscript parity only)"; `remove(effectId, extraParam)`: "Completely removes the active effect from the actor."

**Known-spell list:** `types.Actor.spells(actor)` → ActorSpells: "List of spells (modifications are only allowed in global scripts or on self)." — `add`, `remove`, `clear`, `canUsePower`. Also `Actor.getSelectedSpell` / `Actor.setSelectedSpell(actor, spell)` ("Spell (can be nil)"), `getSelectedEnchantedItem`/`setSelectedEnchantedItem`, `getStance`/`setStance` ("whether a weapon/spell is readied").

**Cast events/handlers — ABSENT.** The complete Engine Handlers reference contains **no** cast/magic handler (full list: onInterfaceOverride, onInit, onUpdate, onSave, onLoad, onNewGame, onPlayerAdded, onObjectActive, onActorActive, onItemActive, onActivate, onNewExterior, onActive, onInactive, onTeleported, onActivated, onConsume, onFrame, key/controller/touch input). The Events page has **no** spell-cast event; the only magic-adjacent built-ins are `ModifyStat` ("-- Consume 10 magicka \n actor:sendEvent('ModifyStat', {stat = 'magicka', amount = -10})"), `AddVfx`, `SpawnVfx`, `PlaySound3d`, `BreakInvisibility`, `Hit`. There is no documented way to intercept, cancel, or be notified of a cast — detecting casts requires polling `activeSpells` per-frame in `onUpdate`.

## (4) Enchantments — YES

Runtime: "Enchantments.createRecordDraft(enchantment) — Creates an #Enchantment without adding it to the world database. Use openmw_world#world.createRecord to add the record to the world." Fields: `charge` ("Charge capacity. Should not be confused with current charge."), `cost`, `effects`, `id`, `isAutocalc`, `type` (ENCHANTMENT_TYPE: CastOnStrike, CastOnUse, CastOnce "destroying the enchanted item", ConstantEffect "always active when equipped"). Load context: `content.enchantments.records` mutable, example: `content.enchantments.records.MyEnchantment = { type = content.enchantments.TYPE.CastOnUse, charge = 1, cost = 1, effects = { { id = 'FortifySkill', affectedSkill = 'enchant', duration = 5, magnitudeMin = 50, magnitudeMax = 100 } } }`.

## (5) Magic schools / magicka cost — mostly ABSENT

Documented: `MagicEffect.school` = "Skill ID that is this effect's school" (read field); `SkillRecord.school` = "Optional magic school" of type `MagicSchoolData` (fields: `areaSound`, `boltSound`, `castSound`, `failureSound`, `hitSound`, `name` — sounds + display name only). **Not documented / absent:** creating new magic schools (skills are not in the content package's record list and have no createRecordDraft); any API to override cast-cost/cast-chance formulas; any magicka-cost hook. The only documented cost levers are `Spell.cost`/`isAutocalc`, `MagicEffect.baseCost`, load-context GMST editing (`content.gameSettings.records` — "A mutable list of all game settings.", e.g. `content.gameSettings.records.fJumpAcrobaticsBase = 1024`), and manual magicka manipulation via `types.Actor.stats.dynamic.magicka` / the `ModifyStat` event.

## Porting verdict (one paragraph)

Record plumbing ports: spells and enchantments are creatable both at runtime (`createRecordDraft` + `world.createRecord`, engine-generated ids) and at load time with chosen ids; magic effect records are creatable **only** in the LOAD context via `content.magicEffects`, and only as data (name/visuals/flags/cost/school, optionally templated from an existing hardcoded effect). What does NOT port: MWSE-style scripted effect logic — the docs provide **no** engine-invoked Lua for effect behavior and **no** cast event/interception; a framework must implement custom behavior itself by polling `Actor.activeSpells`/`activeEffects` in `onUpdate` and applying consequences through `activeSpells:add`, `activeEffects:modify/remove`, stat writes, `AddVfx`/`ModifyStat` events.

Sources:
- [Overview (script contexts, LOAD flag)](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/overview.html)
- [API Reference (package/context table)](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/api.html)
- [Package openmw.content](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/openmw_content.html)
- [Package openmw.core (core.magic, MagicEffect, Spell, Enchantment, schools)](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/openmw_core.html)
- [Package openmw.world (createRecord)](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/openmw_world.html)
- [Package openmw.types (Actor.activeSpells/activeEffects/spells)](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/openmw_types.html)
- [Engine handlers reference](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/engine_handlers.html)
- [Built-in events](https://openmw.readthedocs.io/en/openmw-0.51.0/reference/lua-scripting/events.html)