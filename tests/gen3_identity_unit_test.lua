local scheduled,seen,callback
local Battle={}
function Battle.start(opts)
 local st={enemy={mon={personality=opts.foe.personality}},wild=opts.wild}
 if opts.onStarted then opts.onStarted(st)end
 seen=st;return 'started',17
end
local Bridge={startWild=function(_,game,foe,opts)
 scheduled=function()return Battle.start({wild=true,foe=foe,onStarted=function(st)callback=st.enemy.mon.isShiny end})end
 return true
end}
package.loaded['src.core.game3.battle_bridge']=Bridge
package.loaded['src.core.game3.battle']=Battle
package.loaded['src.core.game3.summary_data']={isShiny=function(mon)return mon.personality==0 end}
love={math={random=math.random}}
local fail,blocked=false,false
local mod={world={game={}}}
function mod.world:startWildBattle(species,level)
 if fail then error('SDK failure')end
 if blocked then return nil,'no healthy party'end
 return Bridge.startWild(nil,self.game,{species=species,level=level})
end
local I=assert(loadfile('lib/gen3/identity.lua'))()(mod)
local row=I.assign({species=25,level=12,personality=4294967295,shiny=true})
assert(I.begin(row));assert(not seen,'native transition must remain asynchronous')
local a,b=scheduled();assert(a=='started' and b==17)
assert(seen.enemy.mon.personality==4294967295 and seen.enemy.mon.isShiny==true and callback==true)
row.shiny=false;assert(I.begin(row));scheduled();assert(seen.enemy.mon.isShiny==false)
-- Identical species/level in a later unrelated battle must never inherit it.
Bridge.startWild(nil,mod.world.game,{species=25,level=12});scheduled();assert(seen.enemy.mon.personality==nil and seen.enemy.mon.isShiny==nil)
blocked=true;local ok,err=I.begin(row);assert(ok==nil and err=='no healthy party');blocked=false
fail=true;ok,err=I.begin(row);assert(ok==nil and err:find('SDK failure'));fail=false
Bridge.startWild(nil,mod.world.game,{species=25,level=12});scheduled();assert(seen.enemy.mon.personality==nil)
assert(I.assign({personality=0}).shiny==true)
for _,pid in ipairs({-1,4294967296,1.5,0/0})do local x=I.assign({personality=pid});assert(x.personality>=0 and x.personality<4294967296 and x.personality==math.floor(x.personality))end
print('PASS Gen3 host identity, delayed native battle, pre-event shiny state, return values, refusal/error cleanup and unrelated battle isolation')

local Simulation=assert(loadfile('lib/shared_simulation.lua'))()
math.randomseed(271)
local sim=Simulation.new({session='host',count=2,random=math.random,
 describe=function()return function()return 'land'end end,
 pick=function()return {species=25,level=12,personality=4294967295,shiny=true}end})
local roster=sim.snapshot('FR_ROUTE_1',{x=10,y=10},.016)
assert(#roster==2)
for _,r in ipairs(roster)do assert(r.personality==4294967295 and r.shiny==true)end
sim.adopt('FR_ROUTE_1',roster)
for _,r in ipairs(sim.snapshot('FR_ROUTE_1',{x=11,y=10},.016))do assert(r.personality==4294967295 and r.shiny==true)end
print('PASS host off-map simulation and roster adoption retain identity')
