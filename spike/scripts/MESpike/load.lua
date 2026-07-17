-- MESpike load-context script: the record-layer half of the go/no-go
-- experiments from PORT-ASSESSMENT.md section 5 (experiments 1, 4, 8).
-- Everything is pcall-wrapped and logged with a "MESpike:" prefix —
-- grep openmw.log for MESpike after launch.

local content = require('openmw.content')

local function attempt(label, fn)
  local ok, err = pcall(fn)
  print(string.format('MESpike: %s -> %s', label, ok and 'OK' or ('FAILED: ' .. tostring(err))))
  return ok
end

local function readback(kind, records, id)
  local ok, rec = pcall(function() return records[id] end)
  if ok and rec then
    print(string.format('MESpike: readback %s "%s" -> present (name=%s)', kind, id, tostring(rec.name)))
  else
    print(string.format('MESpike: readback %s "%s" -> MISSING (%s)', kind, id, tostring(rec)))
  end
end

local function onContentFilesLoaded()
  print('MESpike: onContentFilesLoaded running')

  -- Experiment 1a: from-scratch custom effect (no template). The docs only
  -- document the templated form; whether this works AT ALL is the question.
  attempt('create from-scratch effect mespike_blink', function()
    content.magicEffects.records.mespike_blink = {
      name = 'Spike Blink',
      school = 'alteration',
      baseCost = 5,
      hasDuration = true,
    }
  end)
  readback('effect', content.magicEffects.records, 'mespike_blink')

  -- Experiment 1b: templated custom effect (the exact documented form).
  attempt('create templated effect mespike_summontest', function()
    content.magicEffects.records.mespike_summontest = {
      template = content.magicEffects.records['summonscamp'],
      name = 'Spike Summon Test',
    }
  end)
  readback('effect', content.magicEffects.records, 'mespike_summontest')

  -- Spells carrying the custom effects. duration >= 2s so the per-frame
  -- watcher cannot miss them (experiment 2).
  -- Testing config: free to cast, always succeeds (alwaysSucceedFlag skips
  -- skill checks; isAutocalc=false so cost=0 is taken literally).
  attempt('create spell mespike_spell_blink', function()
    content.spells.records.mespike_spell_blink = {
      name = 'Spike: Blink',
      type = content.spells.TYPE.Spell,
      cost = 0,
      isAutocalc = false,
      alwaysSucceedFlag = true,
      effects = { { id = 'mespike_blink', duration = 2, magnitudeMin = 1, magnitudeMax = 1 } },
    }
  end)
  readback('spell', content.spells.records, 'mespike_spell_blink')

  attempt('create spell mespike_spell_summon', function()
    content.spells.records.mespike_spell_summon = {
      name = 'Spike: Summon Test',
      type = content.spells.TYPE.Spell,
      cost = 0,
      isAutocalc = false,
      alwaysSucceedFlag = true,
      effects = { { id = 'mespike_summontest', duration = 10, magnitudeMin = 1, magnitudeMax = 1 } },
    }
  end)
  readback('spell', content.spells.records, 'mespike_spell_summon')

  -- Control: a spell of pure vanilla effects. If this fails, load-context
  -- spell creation itself is broken and the custom-effect results mean nothing.
  -- Levitate 50 for 10s: unmissable (round-2's Jump 10pts was too subtle to feel).
  attempt('create control spell mespike_spell_control', function()
    content.spells.records.mespike_spell_control = {
      name = 'Spike: Control (Levitate)',
      type = content.spells.TYPE.Spell,
      cost = 0,
      isAutocalc = false,
      alwaysSucceedFlag = true,
      effects = { { id = 'levitate', duration = 10, magnitudeMin = 50, magnitudeMax = 50 } },
    }
  end)
  readback('spell', content.spells.records, 'mespike_spell_control')

  print('MESpike: onContentFilesLoaded done')
end

return {
  engineHandlers = {
    onContentFilesLoaded = onContentFilesLoaded,
  },
}
