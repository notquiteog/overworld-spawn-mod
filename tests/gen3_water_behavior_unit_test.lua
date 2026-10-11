local R=assert(loadfile('lib/gen3/rules.lua'))()
local function enabled()return true end
local function last(n)return n end
assert(R.behavior(enabled,last,'land')=='hidden','land camouflage preserved')
assert(R.behavior(enabled,last,'water')=='aggressive','water pool excludes hidden')
assert(not R.behaviorEnabled(enabled,'hidden','water'))
assert(R.behaviorEnabled(enabled,'hidden','land'))
local function onlyHidden(key)return key=='enable_hidden'end
assert(R.behavior(onlyHidden,last,'water')=='idle','water fallback is visible even with only hidden toggle on')
assert(R.behavior(onlyHidden,last,'cave')=='hidden')
print('PASS native water behaviors match GB terrain policy')
