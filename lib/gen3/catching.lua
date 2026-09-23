-- Native FireRed direct throws. Party construction, catch odds, inventory,
-- storage and dex registration use the engine's Gen3 implementations.
return function(mod,S,Actors,busy)
 local Player=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Objects=require('src.core.game3.objects')
 local Collision=require('src.core.game3.collision')
 local Pokemon=require('src.core.game3.pokemon')
 local Bag=require('src.core.game3.bag')
 local Party=require('src.core.game3.party')
 local Catching=require('src.core.game3.battle.catching')
 local Storage=require('src.core.game3.storage')
 local C={ball=4,charge=0,message='',cooldown=0,suppressed={}}
 local balls={4,3,2,1,6,7,8,9,10,11,12}
 local names={[1]='MASTER',[2]='ULTRA',[3]='GREAT',[4]='POKE',[6]='NET',[7]='DIVE',[8]='NEST',[9]='REPEAT',[10]='TIMER',[11]='LUXURY',[12]='PREMIER'}
 local dirs={up={0,-1},down={0,1},left={-1,0},right={1,0}}
 local function count(game,id)return Bag.get(game.session and game.session.bag,id)end
 local function cycle(game,dir)
  local at=1;for i,b in ipairs(balls)do if b==C.ball then at=i end end
  for off=1,#balls do local b=balls[(at-1+off*dir)%#balls+1];if count(game,b)>0 then C.ball=b;return end end
 end
 local function target(range)
  local d=dirs[Player.facing]or dirs.down
  for step=1,range do
   local x,y=Player.cellX+d[1]*step,Player.cellY+d[2]*step
   if(not Collision.isWalkable(x,y)and not Collision.isWater(x,y))or Collision.warpAt(x,y)or Objects.blocks(x,y)then return end
   if Collision.directionallyImpassable and Collision.directionallyImpassable(x-d[1],y-d[2],x,y,Player.facing)then return end
   for _,r in pairs(S.spawns)do if r.cellX==x and r.cellY==y and not r.ambient and not r.scenery and r.behavior~='hidden' then return r end end
  end
 end
 function C.resolve(game,row,ball)
  if not row or row.ambient or row.scenery then return false,'invalid target'end
  local session=game.session
  if #session.party>=6 and not Storage.findOpenSlot(Storage.ensure(session))then return false,'PARTY AND PC FULL'end
  -- Construct through native Party on a detached session. Only storeCaught
  -- writes the real party and dex, and only after a successful native roll.
  local scratch={party={},name=session.name,trainerId=session.trainerId,secretId=session.secretId,map=session.map,gender=session.gender}
  local ok,_,mon=Party.giveMon(scratch,row.species,row.level)
  if not ok or not mon then return false,'CANNOT CREATE POKEMON'end
  if type(row.personality)=='number' and row.personality%1==0 and row.personality>=0 and row.personality<4294967296 then
   mon.personality=row.personality
   if Pokemon.natureId then mon.nature=Pokemon.natureId(mon.personality)end
   if Pokemon.abilityId then mon.ability=Pokemon.abilityId(row.species,mon.personality);mon.abilityId=mon.ability end
   if Pokemon.gender then mon.gender=Pokemon.gender(row.species,mon.personality)end
   if Pokemon.applyStats then mon.hp=nil;Pokemon.applyStats(mon)end
  end
  -- The native summary/battle renderer recognizes isShiny as an explicit
  -- override. A host-supplied appearance survives stamping the catcher OT.
  if row.shiny~=nil then mon.isShiny=row.shiny==true end
  local types=Pokemon.types(row.species)
  local foe={mon=mon,species=row.species,type1=types[1],type2=types[2]}
  local caught,shakes=Catching.tryCatch(ball,foe,{terrain=row.terrain,turn=1},session,love.math.random)
  if not caught then return false,'BROKE FREE',shakes end
  local result=Catching.storeCaught(session,foe,ball)
  if not result.success then return false,'PARTY AND PC FULL'end
  return true,'CAUGHT '..(Pokemon.name(row.species)or'POKEMON'),shakes
 end
 local function launchVisual(row,ball,resolved)
  local gid=Actors.base+50000
  if not Actors.sprites[gid]then
   local img=love.graphics.newCanvas(8,8);love.graphics.push('all');love.graphics.setCanvas(img);love.graphics.clear(0,0,0,0)
   love.graphics.setColor(1,.18,.2,1);love.graphics.circle('fill',4,4,3);love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',1,4,6,3);love.graphics.pop()
   Actors.sprite(gid,img,8,8,1)
  end
  local actor=Actors.add(-1000,Map.current,Player.cellX,Player.cellY,gid)
  C.projectile={actor=actor,row=row,ball=ball,t=0,x=Player.px,y=Player.py,resolved=resolved};if not resolved then row.catching=true end
 end
 function C.throw(game,charge)
  if C.projectile or C.cooldown>0 or busy()or not mod.options:get('overworld_catching')then return false end
    local Safari=require('src.core.game3.safari')
  if Safari.isActive and Safari.isActive(game.session)then C.message='USE SAFARI BATTLE';return false end
  local row=target(2+math.floor(math.min(1,charge or 0)*4))
  if not row then C.message='NO WILD IN RANGE';return false end
  if count(game,C.ball)<=0 then cycle(game,1)end
  if count(game,C.ball)<=0 then C.message='NO POKE BALLS';return false end
  if #game.session.party>=6 and not Storage.findOpenSlot(Storage.ensure(game.session))then C.message='PARTY AND PC FULL';return false end
  if S.shared then
   if S.shared.catching~=true then C.message='SHARED CATCHING UNAVAILABLE';return false end
   C.cooldown=.5
   return S.shared.request(S.map,row.networkId,{action='catch',ballId=C.ball,charge=math.min(1,charge or 0)})
  end
  if Bag.remove(game.session.bag,C.ball,1)==false then return false end
  launchVisual(row,C.ball,false);C.message='THROW!';C.cooldown=.5
  return true
 end
 -- Called only with the host's reserved roster record. A false acceptance
 -- consumes nothing; a failed catch consumes its ball and releases the claim.
 function C.beginCatch(wire,map,request)
  local g=mod.world.game;local ball=tonumber(request and request.ballId)
  if not S.shared or S.shared.catching~=true or map~=Map.current or busy() then return false,{message='FIELD UNAVAILABLE'}end
  if not mod.options:get('overworld_catching')or not names[ball]or wire.ambient or wire.scenery or wire.hiddenEncounter or wire.visibleSprite==false then return false,{message='INVALID CATCH'}end
  local Safari=require('src.core.game3.safari')
  if Safari.isActive and Safari.isActive(g.session)then return false,{message='USE SAFARI BATTLE'}end
  if #g.session.party>=6 and not Storage.findOpenSlot(Storage.ensure(g.session))then return false,{message='PARTY AND PC FULL'}end
  if count(g,ball)<=0 or not Bag.remove(g.session.bag,ball,1)then return false,{message='NO POKE BALLS'}end
  local caught,message,shakes=C.resolve(g,wire,ball)
  C.ball=ball;C.message=message;C.cooldown=.5
  local visual={px=wire.px or(wire.x or Player.cellX)*16,py=wire.py or(wire.y or Player.cellY)*16}
  launchVisual(visual,ball,true)
  return true,{caught=caught,shakes=shakes or 0,message=message}
 end
 local function rawKey(key)return love.keyboard and love.keyboard.isDown(key)end
 function C.update(game,dt)
  C.cooldown=math.max(0,C.cooldown-dt)
  local p=C.projectile
  if p then
   if(not p.resolved and S.spawns[p.row.id]~=p.row)or Map.current~=p.actor.map then
    p.row.catching=nil;Actors.rows[-1000]=nil;C.projectile=nil
   else
    p.t=math.min(1,p.t+dt/.45);local a=p.actor
    a.px=p.x+(p.row.px-p.x)*p.t;a.py=p.y+(p.row.py-p.y)*p.t-math.sin(p.t*math.pi)*20
    if p.t>=1 then
     if not p.resolved then
      local caught,message=C.resolve(game,p.row,p.ball);C.message=message
      if caught then S.remove(p.row)end
     end
     p.row.catching=nil;Actors.rows[-1000]=nil;C.projectile=nil
    end
   end
  end
  local input=game.input
  if not input then return end
  if C.input~=input then
   C.input=input;C.rawDown=input.isDown;C.rawPressed=input.wasPressed
   input.isDown=function(self,key)if game.phase=='field'and not busy()and C.suppressed[key]then return false end;return C.rawDown(self,key)end
   input.wasPressed=function(self,key)if game.phase=='field'and not busy()and C.suppressed[key]then return false end;return C.rawPressed(self,key)end
  end
  C.suppressed={}
  if busy()or not mod.options:get('overworld_catching')then C.wasThrow=false;C.wasCycle=false;C.charge=0;return end
  local throwKey=mod.options:get('catch_throw_key')or'c'
  local cycleKey=mod.options:get('catch_cycle_key')or'q';if cycleKey==throwKey then cycleKey=throwKey=='q'and'e'or'q'end
  local combo=mod.options:get('catch_throw_combo');local modifier=combo=='b_a'and'b'or combo=='select_a'and'select'
  local down=function(key)return C.rawDown(input,key)end
  local comboThrow=modifier and down(modifier)and down('a')
  local throwing=rawKey(throwKey)or comboThrow
  if comboThrow then C.suppressed[modifier]=true;C.suppressed.a=true end
  if throwing then C.charge=math.min(1,C.charge+dt)
  elseif C.wasThrow then C.throw(game,C.charge);C.charge=0 end
  C.wasThrow=throwing
  local switch=mod.options:get('catch_cycle_combo');local cm=switch=='b_dpad'and'b'or switch=='select_dpad'and'select'
  local left,right=cm and down(cm)and down('left'),cm and down(cm)and down('right')
  local cycling=rawKey(cycleKey)or left or right
  if left or right then C.suppressed[cm]=true;C.suppressed.left=true;C.suppressed.right=true end
  if cycling and not C.wasCycle then cycle(game,left and-1 or 1)end
  C.wasCycle=cycling
 end
 mod.hooks:wrap('render.hud',function(nextFn,game,viewport)
  nextFn(game,viewport)
  local size=tonumber(mod.options:get('catch_hud_size'))or 5
  if size<=0 or not mod.options:get('overworld_catching')or game.phase~='field'then return end
  local scale=(viewport.scale or 1)*(.35+size*.08)
  love.graphics.push('all');love.graphics.translate((viewport.gameX or 0)+6,(viewport.gameY or 0)+(viewport.gameHeight or viewport.height or 160)-30*scale)
  love.graphics.scale(scale,scale);love.graphics.setColor(0,0,0,.75);love.graphics.rectangle('fill',0,0,235,28)
  love.graphics.setColor(1,1,1,1);love.graphics.print((names[C.ball]or'POKE')..' BALL x'..count(game,C.ball)..'  '..string.upper(mod.options:get('catch_throw_key')or'c')..' / '..string.upper(mod.options:get('catch_cycle_key')or'q'),4,2)
  love.graphics.print(C.charge>0 and('RANGE '..(2+math.floor(C.charge*4)))or C.message,4,14);love.graphics.pop()
 end)
 return C
end
