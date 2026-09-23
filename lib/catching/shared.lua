-- Shared Gen1/2 throws use the existing native capture adapters, but only after
-- Online grants the host-owned spawn. Never despawn a shared actor locally.
local V = ...
local Config = V.require('config')
local GameCompat = V.require('game_compat')
local CatchMath = V.require('catching/catch_math')
local Target = V.require('catching/target')
local C = {}
C.balls = {POKE_BALL=4, GREAT_BALL=3, ULTRA_BALL=2, MASTER_BALL=1}
local names = {[4]='POKE_BALL', [3]='GREAT_BALL', [2]='ULTRA_BALL', [1]='MASTER_BALL'}
local dirs = {up={0,-1}, down={0,1}, left={-1,0}, right={1,0}}
local function integer(n) return type(n)=='number' and n==n and n%1==0 end
local function native(path) local ok,m=pcall(require,path); if ok then return m end end

function C.hasStorage(game)
  local save=game and game.save
  if not save or type(save.party)~='table' then return false end
  if #save.party<6 then return true end
  if GameCompat.isGen2(nil,game) then
    local Boxes=native('src.core.gen2.Boxes')
    if not Boxes or not Boxes.isFull then return false end
    for i=1,Boxes.NUM_BOXES or 14 do if not Boxes.isFull(save,i) then return true end end
  else
    local Boxes=native('src.pokemon.Boxes')
    if not Boxes or not Boxes.ensure then return false end
    local boxes=Boxes.ensure(save)
    for i=1,Boxes.COUNT or 12 do
      if type(boxes[i])=='table' and #boxes[i]<(Boxes.CAPACITY or 20) then return true end
    end
  end
  return false
end

-- Both current and remote maps use their native collision predicates. Missing
-- layouts or predicates fail closed; this does not change the active map.
function C.canCatch(logic,game,ow,position,row,action)
  local authority=logic.sharedAuthority
  if not authority or authority.catching~=true or not Config.isEnabled(logic.mod or V.mod)
      or not Config.overworldCatchingEnabled(logic.mod or V.mod) then return false end
  if not row or row.ambient or row.scenery or row.hiddenEncounter or row.visibleSprite==false
      or not action or action.action~='catch' or not names[action.ballId] then return false end
  local charge=action.charge
  if type(charge)~='number' or charge~=charge or charge<0 or charge>1 then return false end
  local d=position and dirs[position.facing]
  if not d or not integer(position.x) or not integer(position.y)
      or not integer(row.x) or not integer(row.y) then return false end
  local distance=(row.x-position.x)*d[1]+(row.y-position.y)*d[2]
  if distance<1 or distance>2+math.floor(charge*4)
      or row.x~=position.x+d[1]*distance or row.y~=position.y+d[2]*distance then return false end
  local map=ow and ow.map
  if not map or not map.widthCells or not map.heightCells or not map.isWalkableCell
      or not map.isWaterCell or not map.warpAtCell then return false end
  if position.x<0 or position.y<0 or position.x>=map.widthCells or position.y>=map.heightCells then return false end
  for step=1,distance do
    local x,y=position.x+d[1]*step,position.y+d[2]*step
    if x<0 or y<0 or x>=map.widthCells or y>=map.heightCells
        or map:warpAtCell(x,y) or (not map:isWalkableCell(x,y) and not map:isWaterCell(x,y)) then return false end
    if map.stepPermitted and not map:stepPermitted(x-d[1],y-d[2],position.facing) then return false end
    if logic.isStoryReservedCell and logic:isStoryReservedCell(game,map.id,x,y) then return false end
    for _,list in ipairs({ow.npcs or {},ow.entities or {}}) do
      for _,e in pairs(list) do
        if e.cellX==x and e.cellY==y and not e.overworldWildSpawn and not e.wildsProjectile
            and not e.isPokeBallEntity and not e.wildsFollower and not e.pokepcTrailer then return false end
      end
    end
  end
  return true
end

-- Called before the ordinary release path consumes a ball or locks a target.
function C.request(catcher,game,ow,hit,power,ball)
  local e=hit.entity
  if not e or not e.sharedWild then return false end
  local logic,authority=catcher.logic,catcher.logic.sharedAuthority
  local r=logic.spawns and logic.spawns[e.id]
  if not authority or authority.catching~=true or not r or not r.networkId or not C.balls[ball] then
    catcher.phase='idle'; return true
  end
  if CatchMath.throwQuality(power,hit.distance)==CatchMath.QUALITY.MISS then return false end
  if not C.hasStorage(game) then
    catcher.hud:showFeedback('PARTY AND PC FULL',1.5); catcher.phase='idle'; return true
  end
  local x,y=GameCompat.playerCell(game,ow)
  local facing=Target.facingOf(GameCompat.catchPlayer(game,ow))
  local action={action='catch',ballId=C.balls[ball],charge=math.max(0,(CatchMath.roundedPower(power)-2)/4)}
  local row={x=e.cellX,y=e.cellY,scenery=e.caveScenery,hiddenEncounter=e.hiddenEncounter,visibleSprite=e.visibleSprite}
  if not C.canCatch(logic,game,ow,{x=x,y=y,facing=facing},row,action) then
    catcher.hud:showFeedback('BLOCKED THROW',1); catcher.phase='idle'; return true
  end
  -- Keep fractional meter power locally; the wire charge only describes the
  -- rounded range. A delayed/stale grant cannot create an unsolicited catch.
  local pending={id=r.networkId,map=ow.map.id,power=power,ballId=action.ballId,
    charge=action.charge,x=x,y=y,facing=facing,authority=authority,left=4}
  catcher.sharedPending=pending; catcher.phase='awaiting_host'
  local ok,reason=authority.request(ow.map.id,r.networkId,action)
  if not ok and catcher.sharedPending==pending then
    catcher.sharedPending=nil; catcher.phase='idle'
    catcher.hud:showFeedback(tostring(reason or 'THROW DECLINED'),1)
  end
  return true
end

function C.denied(catcher,map,id,reason)
  local p=catcher and catcher.sharedPending
  if p and p.map==map and p.id==id then
    catcher.sharedPending=nil; catcher.phase='idle'
    catcher.hud:showFeedback(tostring(reason or 'THROW DECLINED'),1)
  end
end

function C.begin(catcher,game,ow,row,map,action)
  local p=catcher and catcher.sharedPending
  if not p or not row or p.id~=row.id or p.map~=map or not action or p.ballId~=action.ballId
      or p.charge~=action.charge or p.authority~=catcher.logic.sharedAuthority then
    return false,{message='NO MATCHING THROW'}
  end
  catcher.sharedPending=nil; catcher.phase='idle'
  local ball=names[action.ballId]
  local x,y=GameCompat.playerCell(game,ow)
  local facing=Target.facingOf(GameCompat.catchPlayer(game,ow))
  if not ow or not ow.map or ow.map.id~=map or x~=p.x or y~=p.y or facing~=p.facing
      or not catcher:playerHasControl(game,ow) or catcher:safariBlocks(game,ow)
      or catcher.projectile:isBusy() or not C.canCatch(catcher.logic,game,ow,{x=x,y=y,facing=facing},row,action) then
    return false,{message='FIELD UNAVAILABLE'}
  end
  if not C.hasStorage(game) then return false,{message='PARTY AND PC FULL'} end
  local rate,def=GameCompat.catchRate(game,row.species)
  local quality=CatchMath.throwQuality(p.power,math.abs(row.x-x)+math.abs(row.y-y))
  if not def or quality==CatchMath.QUALITY.MISS then return false,{message='TARGET MOVED'} end
  local gen2=GameCompat.isGen2(nil,game)
  local engine=native(gen2 and 'src.battle.gen2.Catching' or 'src.battle.Catching')
  local constructor=native(gen2 and 'src.battle.gen2.Mon' or 'src.pokemon.Pokemon')
  if not engine or not engine.attempt or not constructor or not constructor.new then
    return false,{message='NATIVE CAPTURE UNAVAILABLE'}
  end
  local mon=GameCompat.createCaughtPokemon(game,row.species,row.level,{strict=true,shiny=row.shiny,variant=row.variant})
  if not mon then return false,{message='CANNOT CREATE POKEMON'} end
  if not GameCompat.consumeBall(game,ball) then return false,{message='NO POKE BALLS'} end
  local angle=CatchMath.facingAngle(x,y,row.x,row.y,row.facing)
  local maxHp=math.max(1,math.floor(row.level*2.5+10))
  local caught,shakes=GameCompat.attemptCatch(game,{ballType=ball,
    mon={species=row.species,hp=maxHp,stats={hp=maxHp}},def=def,species=row.species,level=row.level,
    rng=love and love.math and love.math.random or math.random,
    rateOverride=CatchMath.effectiveCatchRate(rate,row.level,quality,angle)})
  local result={caught=false,shakes=shakes or 0,message='BROKE FREE'}
  if caught then
    local stored=GameCompat.giveCaughtPokemon(game,mon,{species=row.species}) or {}
    if stored.destination and not stored.boxFull then
      result.caught=true; result.message=tostring(def.name or row.species)..' WAS CAUGHT!'
      -- A cosmetic failure after storage must not turn a real capture into a
      -- released host claim. Native storage is the irreversible commit point.
      pcall(GameCompat.markSpeciesCaught,game,row.species,mon)
      if catcher.logic.refreshDiscoveryPresentation then
        pcall(catcher.logic.refreshDiscoveryPresentation,catcher.logic,row.species)
      end
    else result.message='PARTY AND PC FULL' end
  end
  if catcher.showSharedResult then
    local shown=pcall(catcher.showSharedResult,catcher,game,ow,row,ball,p,result)
    if not shown then catcher.phase='idle' end
  end
  return true,result
end
return C
