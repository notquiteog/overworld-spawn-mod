-- PMDCollab animation island: PmdWalk must never affect other providers.
-- Run: luajit tests/pmd_walk_isolation_unit_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if not cond then
    failures = failures + 1
    io.stderr:write("FAIL: " .. tostring(msg) .. "\n")
  else
    print("ok  " .. tostring(msg))
  end
end
local function eq(a, b, msg)
  check(a == b, string.format("%s (got %s expected %s)", msg, tostring(a), tostring(b)))
end

local modules = {}
local V = {
  mod = { path = ".", id = "overworld_wild_spawns", log = { info = function() end, warn = function() end } },
  path = ".",
}
function V.require(name)
  if modules[name] ~= nil then return modules[name] end
  local chunk = assert(loadfile("lib/" .. name .. ".lua"))
  local value = chunk(V)
  modules[name] = value
  return value
end

modules.movement = {
  isBusy = function(e) return e and e.moving == true end,
}

local PmdWalk = V.require("pmd_walk")
local PmdIdle = V.require("pmd_idle")

print("== provider hard gate ==")
local folEnt = {
  spriteProviderId = "followers_ex",
  facing = "down",
  moving = true,
  -- Stale PMD state left behind after a style switch (the leak scenario).
  _pmdWalkMeta = {
    walkFrameCount = 4,
    walkDurations = { 8, 10, 8, 10 },
    walkCycleBase = 34,
  },
  _pmdWalk = { frame = 2, frameElapsed = 0, facing = "down" },
  sprite = { def = { walkFrameCount = 4, walkCycleBase = 34 } },
}
eq(PmdWalk.frameOverride(folEnt), nil, "followers_ex: frameOverride nil despite stale meta")
eq(PmdWalk.animationOwner(folEnt), "native", "followers_ex: animationOwner native")
PmdWalk.update(folEnt, 1.0)
eq(folEnt._pmdWalk.frame, 2, "followers_ex: update does not advance stale state")

local hgss = {
  spriteProviderId = "pokemmo",
  facing = "down",
  moving = true,
  _pmdWalkMeta = { walkFrameCount = 4, walkCycleBase = 10, walkDurations = { 4, 4, 4, 4 } },
}
eq(PmdWalk.frameOverride(hgss), nil, "pokemmo: frameOverride nil")
eq(PmdWalk.animationOwner(hgss), "native", "pokemmo: native owner")

local dex = { spriteProviderId = "pokedex", moving = true, _pmdWalkMeta = { walkFrameCount = 4, walkCycleBase = 6 } }
eq(PmdWalk.frameOverride(dex), nil, "pokedex: frameOverride nil")

print("== no def.walkFrameCount fallback ==")
local leakedDef = {
  spriteProviderId = "pmdcollab", -- provider ok
  facing = "down",
  moving = true,
  -- Missing _pmdWalkMeta; only def has walk fields (must NOT activate).
  sprite = { def = { walkFrameCount = 4, walkCycleBase = 34, walkDurations = { 8, 8, 8, 8 } } },
}
eq(PmdWalk.frameOverride(leakedDef), nil, "no override without _pmdWalkMeta")

print("== pmdcollab island still works ==")
local pmd = {
  spriteProviderId = "pmdcollab",
  facing = "down",
  moving = true,
  _pmdWalkMeta = {
    walkFrameCount = 4,
    walkDurations = { 8, 10, 8, 10 },
    walkCycleBase = 34,
  },
  _pmdWalk = { frame = 1, frameElapsed = 0, facing = "down" },
}
eq(PmdWalk.animationOwner(pmd), "pmdcollab", "pmd: animationOwner")
eq(PmdWalk.frameOverride(pmd), 35, "pmd: moving override")
pmd.moving = false
eq(PmdWalk.frameOverride(pmd), 34, "pmd: stand override")
pmd.facing = "right"
eq(PmdWalk.frameOverride(pmd), 34 + 12, "pmd: real right stand")

print("== clearEntityState / detach wrap ==")
local drewNative = 0
local sprite = {
  draw = function()
    drewNative = drewNative + 1
  end,
}
local npc = {
  spriteProviderId = "pmdcollab",
  sprite = sprite,
  facing = "down",
  moving = true,
  _pmdWalkMeta = { walkFrameCount = 4, walkCycleBase = 34, walkDurations = { 4, 4, 4, 4 } },
  _pmdIdleMeta = { idleFrameCount = 1, idleDurations = { 4 } },
}
check(PmdIdle.attachDrawWrap(sprite, npc) == true, "attach pmd wrap")
-- Switch away from PMDCollab
npc.spriteProviderId = "followers_ex"
PmdIdle.clearEntityState(npc)
eq(npc._pmdWalkMeta, nil, "cleared _pmdWalkMeta")
eq(npc._pmdWalk, nil, "cleared _pmdWalk")
eq(npc._pmdIdleMeta, nil, "cleared _pmdIdleMeta")
eq(sprite._pmdIdleWrapped, nil, "wrap detached")
-- Draw must be native (no override path)
sprite:draw(0, 0, 0, 0, "down", 1, true)
eq(drewNative, 1, "native draw after detach")
eq(PmdWalk.frameOverride(npc), nil, "no override after switch to followers")

print("== followers_ex has no disableVerticalStepFlip ==")
modules.config = {
  DEFAULTS = { sprite_style = "followers" },
  spriteStyle = function() return "followers" end,
  normalizeSpriteStyle = function(v) return v or "followers" end,
  pokemonSizeMode = function() return "classic" end,
  spriteTrueColor = function() return false end,
  paletteFxRedpp = function() return false end,
  VALID_SPRITE_STYLES = { followers = true, pokemmo = true, pokedex = true, pmdcollab = true },
}
modules.debug_log = { warn = function() end, info = function() end, error = function() end, debug = function() end }
modules.wilds_fs = { pathExists = function() return true end, assetExists = function() return true end }
modules.runtime_sheets = { new = function() return { ready = false, load = function() end, isReady = function() return false end } end }
modules.animated_sprites = {
  normalizeVariant = function(v)
    if v == true or v == "shiny" or v == "s" then return "shiny" end
    return "normal"
  end,
}
modules.variable_size = {
  applyToDef = function(_, def) return def, { applied = false } end,
  effectiveMode = function() return "classic" end,
}
modules.luminance_sheet = {}
modules.species_assets = V.require("species_assets")
-- Use real pmdcollab_assets (not a stub) so provider resolve can load tables.
modules.pmdcollab_assets = nil

local savedOpts = { sprite_style = "followers" }
V.mod.options = { get = function(_, k) return savedOpts[k] end }
V.mod.read = function(_, rel)
  local f = io.open(rel, "rb") or io.open("./" .. rel, "rb")
  if not f then return nil end
  local d = f:read("*a"); f:close(); return d
end
V.mod.assets = { path = function(_, rel) return rel end }
V.mod.content = { pokemon = { get = function() return nil end, each = function() return function() end end } }
V.mod.find = function() return nil end

local render = {
  runtimeSheets = { ready = false, load = function() end, isReady = function() return false end },
  _modAssetPath = function(_, rel) return rel end,
}

modules.game_compat = { isGen2 = function() return false end }
local SpriteProviders = V.require("sprite_providers")
local providers = SpriteProviders.new(V.mod, render)
local r = providers:resolve("followers", 25, "normal", {
  data = { pokemon = { PIKACHU = { dex = 25 } } },
})
if r and r.def then
  eq(r.providerId, "followers_ex", "followers provider")
  check(r.def.disableVerticalStepFlip ~= true,
    "followers_ex must NOT set disableVerticalStepFlip")
  check(r.def.walkFrameCount == nil, "followers_ex must NOT set walkFrameCount")
  check(r.def.walkCycleBase == nil, "followers_ex must NOT set walkCycleBase")
else
  print("skip followers resolve (pack path unavailable in this env)")
end

local rp = providers:resolve("pmdcollab", 25, "normal", nil)
if rp and rp.def then
  eq(rp.def.disableVerticalStepFlip, true, "pmdcollab keeps disableVerticalStepFlip")
  check((tonumber(rp.def.walkFrameCount) or 0) >= 2, "pmdcollab walkFrameCount")
else
  check(false, "pmdcollab resolve failed")
end
print("== native walker pose sequence (no frameOverride) ==")
-- Simulate Gen1Recomp STAND/WALK indices for a non-PMD entity over one tile.
local STAND = { down = 0, up = 1, left = 2, right = 2 }
local WALK = { down = 3, up = 4, left = 5, right = 5 }
local function nativeFrame(facing, walkPhase, stepFlip)
  if walkPhase == 1 then
    local f = WALK[facing] or 3
    -- Native stepFlip mirrors up/down walk; frame index itself is unchanged.
    return f, (facing == "right") or ((facing == "up" or facing == "down") and stepFlip == true)
  end
  return STAND[facing] or 0, facing == "right"
end
local seq = {}
for _, facing in ipairs({ "down", "up", "left", "right" }) do
  local f0 = nativeFrame(facing, 0, false)
  local f1a = nativeFrame(facing, 1, false)
  local f1b = nativeFrame(facing, 1, true)
  seq[#seq + 1] = { facing, f0, f1a, f1b }
  -- PmdWalk must not rewrite these for followers
  local e = { spriteProviderId = "followers_ex", facing = facing, moving = true,
    _pmdWalkMeta = { walkFrameCount = 4, walkCycleBase = 34, walkDurations = { 4, 4, 4, 4 } } }
  eq(PmdWalk.frameOverride(e), nil, "no PMD override during " .. facing .. " walk")
end
-- Known-good cadence: stand then walk index per facing (right shares left).
eq(seq[1][2], 0, "down stand")
eq(seq[1][3], 3, "down walk")
eq(seq[2][2], 1, "up stand")
eq(seq[2][3], 4, "up walk")
eq(seq[3][2], 2, "left stand")
eq(seq[3][3], 5, "left walk")
eq(seq[4][2], 2, "right stand uses left frame")
eq(seq[4][3], 5, "right walk uses left frame")

print("")
if failures > 0 then
  io.stderr:write(failures .. " failure(s)\n")
  os.exit(1)
end
print("ALL PASSED")
