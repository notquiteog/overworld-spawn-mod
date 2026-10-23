-- Run against the official API3 SDK: GEN1RECOMP_ROOT=/path/to/sdk luajit tests/api3_records_unit_test.lua
local root=os.getenv('GEN1RECOMP_ROOT')or'.deps/gen1recomp'
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
local Records=require('src.mods.UnifiedRecords')
local V={}
function V.require(name)
 if name=='game_compat'then return {party=function(g)return g.save.party end}end
 return assert(loadfile('lib/'..name..'.lua'))(V)
end
local Selection=V.require('follower/selection')
for gen=1,2 do
 local function mon(ot,attack)
  return {species=gen==2 and'FARFETCH_D'or'FARFETCHD',hp=12,maxHp=20,level=8,otId=ot,
   dvs={attack=attack,defense=3,speed=5,special=7},catchRate=45,moves={{id='PECK',pp=12,maxPp=35}}}
 end
 local a,b=mon(10,2),mon(20,4)
 local game={save={party={a,b}}};local state={setSelection=function(self,key,slot)self.key,self.slot=key,slot end}
 local selector=Selection.new({},state)
 local record=Records.mon(b,gen,{pokemon={},moves={PECK={pp=35}}})
 assert(record.species=='FARFETCHD'and record.native~=b and record.native.dvs~=b.dvs)
 local observed
 local ok,slot=selector:selectFollower(record,game,{onSelected=function(live)observed=live end})
 assert(ok and slot==2 and observed==b and state.slot==2,'detached callback selected wrong duplicate species')
 assert(state.key==Selection.monFingerprint(b)and game.save.followerSpecies==b.species)
 assert(record.species=='FARFETCHD'and record.native.species==b.species and record.native.otId==20,'canonical record was mutated')
 b.hp=0
 assert(not selector:selectFollower(record,game),'stale detached record must not select a now-fainted live mon')
 assert(a.hp==12 and a.otId==10 and a.dvs.attack==2,'other party mon changed')
end
local schema=assert(loadfile('options.lua'))()
for _,row in ipairs(schema)do if row.key=='ai_dialogues'then assert(row.default==false)end end
print('PASS official API3 detached Gen1/2 records, canonical alias, duplicate-species live identity, stale HP refusal, untouched records/party and AI default OFF')
