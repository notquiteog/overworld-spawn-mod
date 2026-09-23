-- Logic checks against the official engine's native capture/storage modules.
-- No gameplay, graphics, profiles or saves are opened.
local engine=os.getenv('GEN1RECOMP_ROOT') or '/tmp/release-031-20260922/engine'
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
local n=0
local function eq(a,b,label) assert(a==b,(label or 'check')..': '..tostring(a)..' ~= '..tostring(b));n=n+1 end
love={math={random=math.random},filesystem={getInfo=function()end}}
local version=require('src.core.GameVersion')
local modules={}
local mod={id='overworld_wild_spawns',path='.',options={get=function(_,key)if key=='enabled' or key=='overworld_catching' then return true end end}}
local V={mod=mod,path='.'}
function V.require(name)
  if modules[name]==nil then modules[name]=assert(loadfile('lib/'..name..'.lua'))(V) end
  return modules[name]
end
local C=V.require('catching/shared')
local Target=V.require('catching/target')
local Compat=V.require('game_compat')
local Math=V.require('catching/catch_math')
local baseStats={hp=40,attack=45,defense=40,speed=56,special=35,specialAttack=35,specialDefense=35}
local function setup(generation)
  version.set(generation==2 and 'crystal' or 'red')
  local game={save={inventory={MASTER_BALL=9,POKE_BALL=9},party={},pokedex={seen={},caught={}},player={name='QA',id=123}},
    data={pokemon={PIDGEY={name='PIDGEY',catchRate=255,baseStats=baseStats,level1Moves={'TACKLE'},learnset={},growthRate='MEDIUM_FAST',types={'NORMAL'}}},moves={TACKLE={pp=35}}}}
  local map={id='ROUTE_TEST',widthCells=12,heightCells=12,
    isWalkableCell=function(self,x,y)return self.blocked~=x end,isWaterCell=function()return false end,
    warpAtCell=function(self,x,y)return self.warp==x end,stepPermitted=function(self)return not self.wall end}
  local ow={map=map,player={cellX=2,cellY=2,facing='right'},entities={},npcs={}}
  local logic={mod=mod,spawns={},entities={},_despawn=function()error('shared capture must never remove locally')end}
  local catcher={mod=mod,logic=logic,phase='idle',projectile={isBusy=function()return false end},
    hud={showFeedback=function(self,msg)self.message=msg end},playerHasControl=function()return true end,
    safariBlocks=function(self)return self.safari==true end,showSharedResult=function(self,_,_,_,_,_,result)self.result=result end}
  logic.catching=catcher
  local e={id='local1',species='PIDGEY',cellX=5,cellY=2,sharedWild=true,sharedCatchable=true,
    overworldWildSpawn=true,visibleSprite=true,facing='right'}
  logic.entities[e.id]=e; logic.spawns[e.id]={id=e.id,networkId='host:1',species=e.species,level=5}
  local wire={id='host:1',species=e.species,level=5,x=5,y=2,facing='right',visibleSprite=true}
  local action
  logic.sharedAuthority={role='guest',session='qa',catching=true,request=function(map,id,a)action=a;return true end}
  local hit={entity=e,kind=Target.HitKind.WILD,distance=3,x=5,y=2,facing='right'}
  local function request(power,ball)
    eq(C.request(catcher,game,ow,hit,power or 3,ball or 'MASTER_BALL'),true,'shared request handled')
    return action
  end
  return game,ow,logic,catcher,e,wire,request
end
for generation=1,2 do
  local game,ow,logic,catcher,e,wire,request=setup(generation)
  eq(Target.isCatchableWild(e),true,'negotiated shared capture target')
  e.sharedCatchable=false;eq(Target.isCatchableWild(e),false,'legacy provider cannot catch');e.sharedCatchable=true
  local action=request(3.12)
  eq(action.charge,.25,'wire encodes rounded range');eq(catcher.sharedPending.power,3.12,'fractional quality preserved')
  eq(game.save.inventory.MASTER_BALL,9,'request consumes nothing');eq(#game.save.party,0,'request gives nothing')
  local accepted,result=C.begin(catcher,game,ow,wire,ow.map.id,action)
  eq(accepted,true,'host grant accepted');eq(result.caught,true,'native master ball capture')
  eq(game.save.inventory.MASTER_BALL,8,'one ball consumed on grant');eq(#game.save.party,1,'one native mon stored')
  eq(game.save.party[1].species,'PIDGEY','exact host species');eq(game.save.party[1].level,5,'exact host level')
  eq(type(game.save.party[1].dvs),'table','native DV construction');eq(game.save.pokedex.caught.PIDGEY,true,'native dex stamp')
  eq(C.begin(catcher,game,ow,wire,ow.map.id,action),false,'replayed grant does not duplicate')
  eq(game.save.inventory.MASTER_BALL,8,'replay consumes nothing')
  action=request();ow.player.facing='left'
  eq(C.begin(catcher,game,ow,wire,ow.map.id,action),false,'turn before grant cancels');ow.player.facing='right'
  eq(game.save.inventory.MASTER_BALL,8,'cancel consumes nothing')
  action=request();catcher.safari=true
  eq(C.begin(catcher,game,ow,wire,ow.map.id,action),false,'special session rejected');catcher.safari=false
  local position={x=2,y=2,facing='right'}
  eq(C.canCatch(logic,game,ow,position,wire,action),true,'clear native throw ray')
  ow.map.blocked=4;eq(C.canCatch(logic,game,ow,position,wire,action),false,'solid cell blocks throw');ow.map.blocked=nil
  ow.map.warp=4;eq(C.canCatch(logic,game,ow,position,wire,action),false,'warp blocks throw');ow.map.warp=nil
  ow.map.wall=true;eq(C.canCatch(logic,game,ow,position,wire,action),false,'directional native wall blocks throw');ow.map.wall=nil
  ow.npcs={{cellX=4,cellY=2}};eq(C.canCatch(logic,game,ow,position,wire,action),false,'native NPC blocks throw');ow.npcs={}
  eq(C.canCatch(logic,game,nil,position,wire,action),false,'unavailable remote map rejected')
  wire.scenery=true;eq(C.canCatch(logic,game,ow,position,wire,action),false,'scenery never captured');wire.scenery=nil
  wire.hiddenEncounter=true;eq(C.canCatch(logic,game,ow,position,wire,action),false,'hidden marker never captured');wire.hiddenEncounter=nil
  -- Fill native party and every native box; no ball or dex mutation on denial.
  for i=1,6 do game.save.party[i]={species='PIDGEY'} end
  local boxes=generation==2 and require('src.core.gen2.Boxes') or require('src.pokemon.Boxes')
  local count=boxes.NUM_BOXES or boxes.COUNT
  game.save.boxes={};for i=1,count do game.save.boxes[i]={};for k=1,20 do game.save.boxes[i][k]={}end end
  request();eq(catcher.sharedPending,nil,'full party and PC reject before request');eq(game.save.inventory.MASTER_BALL,8,'full storage keeps ball')
  table.remove(game.save.boxes[count]);action=request()
  accepted,result=C.begin(catcher,game,ow,wire,ow.map.id,action)
  eq(result.caught,true,'native overflow storage succeeds');eq(#game.save.boxes[count],20,'last available box receives mon')
  eq(game.save.boxes[count][generation==2 and 1 or 20].species,'PIDGEY','native box placement')
  table.remove(game.save.boxes[count]);action=request(3,'POKE_BALL')
  local engineCatch=require(generation==2 and 'src.battle.gen2.Catching' or 'src.battle.Catching')
  local nativeAttempt=engineCatch.attempt;engineCatch.attempt=function()return false,2 end
  accepted,result=C.begin(catcher,game,ow,wire,ow.map.id,action);engineCatch.attempt=nativeAttempt
  eq(accepted,true,'failed roll still accepted');eq(result.caught,false,'failure returns release outcome')
  eq(game.save.inventory.POKE_BALL,8,'failed native roll uses one ball');eq(#game.save.boxes[count],19,'failure stores nothing')
  action=request();C.denied(catcher,ow.map.id,wire.id,'claimed by peer')
  eq(catcher.sharedPending,nil,'authority denial clears pending');eq(catcher.phase,'idle','denial unblocks input')

  -- Public provider and the actual release method must use the same contract.
  mod.world={game=game};mod.hooks={wrap=function()end}
  logic._ow=function()return ow end;logic.clearAll=function()end;logic.initializeForMap=function()end
  modules.shared_ambient=function()return{configure=function()end}end
  local provider=V.require('shared_spawns')(mod,logic,{},{} )
  local authority=logic.sharedAuthority;provider.configure(authority)
  eq(provider.canCatch(position,wire,action,ow.map.id),true,'public provider verifies current map')
  eq(provider.canCatch(position,wire,action,'MISSING'),false,'public provider fails closed on unknown remote map')
  local Overworld=V.require('catching/init')
  local real=Overworld.new(mod,logic);logic.catching=real
  real.selectedBallIndex=4;real.meter.power=3.12
  real.showSharedResult=function()end
  real:_releaseThrow(game,ow)
  eq(real.sharedPending.power,3.12,'actual release method uses host request')
  eq(game.save.inventory.MASTER_BALL,7,'actual release does not consume before grant')
  accepted,result=provider.beginCatch(wire,ow.map.id,{action='catch',ballId=1,charge=.25})
  eq(accepted,true,'public grant accepted');eq(result.caught,true,'public grant stores native capture')
  eq(game.save.inventory.MASTER_BALL,6,'public grant consumes once')
end
print('shared_catching_parity_unit_test: '..n..' assertions passed (official native Gen1 + Gen2 capture/storage)')
