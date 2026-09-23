-- Native FireRed adapter. Rules use the same public settings as Gen1/Gen2;
-- all map movement and battle/capture bookkeeping remain native Gen3.
return function(mod)
 local function loadfile(name)return assert((loadstring or load)(assert(mod:read('lib/gen3/'..name..'.lua')),'@wilds/gen3/'..name))()end
 local Actors=loadfile('actors')(mod,810000)
 local Player=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Collision=require('src.core.game3.collision')
 local Objects=require('src.core.game3.objects')
 local Encounter=require('src.core.game3.encounters')
 local Pokemon=require('src.core.game3.pokemon')
 local Field=require('src.core.game3.field')
 local Compat=require('src.mods.Gen3Compat')
 local schema=loadfile('settings')(mod)
 local Rules=loadfile('rules')
 local function get(key)return mod.options:get(key)end
 local S={map=nil,spawns={},elapsed=0,nextId=0,shared=nil,cache={},refill=0}
 local function game()return mod.world.game end
 local function busy()
  local r=mod.find and mod.find('DRAMATIC_SKY_RIDE');local ex=r and r.exports
  if ex and ex.isFlying and ex.isFlying()then return true,'airborne' end
  return Compat.worldBusy()
 end
 local function simulationBusy()
  local g=game();if not g or g.phase~='field'or Field.locked or Field.running==false then return true end
  local runtime=package.loaded['src.core.game3.runtime']
  if runtime and runtime.uiBusy and runtime.uiBusy()then return true end
  local space=package.loaded['src.core.game3.scripting.space'];local vm=space and((space.getVm and space.getVm())or space.vm)
  if vm and vm.isRunning and vm:isRunning()then return true end
  local warp=package.loaded['src.core.game3.warp'];return warp and warp.isBusy and warp.isBusy()or false
 end
 local Presentation=loadfile('presentation')(mod,Actors)
 local sprite=Presentation.sprite
 local Followers=loadfile('followers')(mod,Actors,Presentation,simulationBusy)
 local function sample(map,terrain)
  Encounter.ensureLoaded();local t=Encounter.tableFor(map)
  local area=t and(terrain=='water'and t.water or terrain~='water'and(t.land or t.grass))
  local slots=area and (area.slots or area.mons or area)
  if not slots or #slots==0 then return nil end
  local weights=terrain=='water' and {60,30,5,4,1}or{20,20,10,10,10,10,5,5,4,4,1,1}
  local total=0;for i in ipairs(slots)do total=total+(weights[i]or 1)end
  local roll=love.math.random(total);local entry
  for i,row in ipairs(slots)do roll=roll-(weights[i]or 1);if roll<=0 then entry=row;break end end
  local species=tonumber(entry and (entry.species or entry[1]));if not species or not Pokemon.name(species)then return nil end
  local lo=math.max(1,tonumber(entry.minLevel or entry.level or entry[2])or 1)
  local hi=math.min(100,tonumber(entry.maxLevel or entry.level or entry[2])or lo)
  return {species=species,level=love.math.random(lo,math.max(lo,hi)),behavior=Rules.behavior(get,love.math.random)}
 end
 function S.remove(row)S.spawns[row.id]=nil;Actors.rows[row.id]=nil end
 function S.spawn(species,level,x,y,terrain,opts)
  if S.shared and S.shared.role=='guest' then return nil,'host owns visible spawns' end
  local gid=sprite(species,terrain);if not gid then return nil,'no species sprite' end
  S.nextId=S.nextId+1;local row=Actors.add(S.nextId,Map.current,x,y,gid)
  row.networkId=(S.shared and S.shared.session or 'offline')..':'..Map.current..':'..S.nextId
  row.species=species;row.level=level;row.terrain=terrain or Encounter.terrainAt(x,y);row.nextMove=1+love.math.random()*2
  row.behavior=opts and opts.behavior or Rules.behavior(get,love.math.random)
  row.ambient=opts and opts.ambient;row.scenery=opts and opts.scenery
  S.spawns[row.id]=row;return row
 end
 local function validCell(x,y,terrain)
  local def=Map.currentDef()
  return def and x>=0 and y>=0 and x<(def.midLayout and def.midLayout.width or def.width) and y<(def.midLayout and def.midLayout.height or def.height)
   and (terrain=='water' and Collision.isWater(x,y) or terrain~='water' and Collision.isWalkable(x,y))
   and not Collision.warpAt(x,y) and not Objects.blocks(x,y)
 end
 local function reachable()
  local seen,queue={},{{Player.cellX,Player.cellY}};local head=1
  seen[Player.cellX..':'..Player.cellY]=true
  while queue[head]and head<=65536 do
   local c=queue[head];head=head+1
   for _,d in ipairs({{0,1,'down'},{0,-1,'up'},{1,0,'right'},{-1,0,'left'}})do
    local x,y=c[1]+d[1],c[2]+d[2];local k=x..':'..y
    if not seen[k]and validCell(x,y,'land')and not(Collision.directionallyImpassable and Collision.directionallyImpassable(c[1],c[2],x,y,d[3]))then seen[k]=true;queue[#queue+1]={x,y}end
   end
  end
  return seen
 end
 local towns={PALLET_TOWN=16,VIRIDIAN_CITY=19,PEWTER_CITY=16,CERULEAN_CITY=52,VERMILION_CITY=25,LAVENDER_TOWN=104,CELADON_CITY=133,FUCHSIA_CITY=54,SAFFRON_CITY=52,CINNABAR_ISLAND=58,INDIGO_PLATEAU=16}
 local function ambientSpecies()
  local map=tostring(Map.current):gsub('^FR_','');local species=towns[map]
  if not species and(map:find('POKECENTER',1,true)or map:find('HOUSE',1,true))then species=52 end
  return species
 end
 local function populate()
  if S.shared and S.shared.role=='guest' then return end
  local occupied,count,ambient={},0,0
  for _,r in pairs(S.spawns)do occupied[r.cellX..':'..r.cellY]=true;if r.ambient then ambient=ambient+1 else count=count+1 end end
  local target=Rules.count(get);local town=get('town_pokemon')and ambientSpecies()
  if count>=target and(not town or ambient>=2)then return end
  local connected=reachable()
  local mapName=tostring(Map.current):upper();local cave=mapName:find('CAVE',1,true)or mapName:find('MT_',1,true)or mapName:find('TUNNEL',1,true)or mapName:find('VICTORY_ROAD',1,true)
  for _=1,240 do
   local x,y=Player.cellX+love.math.random(-10,10),Player.cellY+love.math.random(-8,8)
   local key=x..':'..y;local terrain=Encounter.terrainAt(x,y)
   local scenery=cave and terrain~='water'and not connected[key]
   local allowScenery=get('cave_spawns')=='mixed'and scenery and love.math.random()<.2
   if not occupied[key]and math.abs(x-Player.cellX)+math.abs(y-Player.cellY)>2 then
    if count<target and terrain and Rules.visibleTerrain(get,terrain)and validCell(x,y,terrain)and(not cave or terrain=='water'or connected[key]or allowScenery)then
     local e=sample(Map.current,terrain)
     if e and S.spawn(e.species,e.level,x,y,terrain,{behavior=e.behavior,scenery=scenery})then occupied[key]=true;count=count+1 end
    elseif town and ambient<2 and not terrain and connected[key]and validCell(x,y,'land')then
     if S.spawn(town,5,x,y,'town',{ambient=true,behavior='wander'})then occupied[key]=true;ambient=ambient+1 end
    end
   end
   if count>=target and(not town or ambient>=2)then break end
  end
 end
 function S.encounter(row)
  if not row or S.spawns[row.id]~=row then return false,'spawn no longer present' end
  if row.ambient or row.scenery then return false,'peaceful scenery'end
  local blocked,why=busy();if blocked then return false,why end
  if S.shared then return S.shared.request(S.map,row.networkId) end
  local ok,err=mod.world:startWildBattle(row.species,row.level)
  if ok then S.remove(row)end
  return ok,err
 end
 -- Optional multiplayer contract. The host supplies every roster and pose;
 -- the encounter grant carries the exact species and level from that roster.
 local Simulation=assert((loadstring or load)(assert(mod:read('lib/shared_simulation.lua')),'@wilds/shared_simulation'))()
 local simulation
 local function remoteTerrain(map)
  local g=game();local def=g and g.data and g.data.maps and g.data.maps[map]
  if not def then return end
  local layout=Map.ensureMidLayout(g,map,def);if not layout then return end
  local types=Encounter._encounterTypes and Encounter._encounterTypes[def.pair or layout.pair]
  local excluded={}
  for _,list in ipairs({def.warps or {},def.objects or {}})do
   for _,e in ipairs(list)do if e.x and e.y then excluded[e.x..':'..e.y]=true end end
  end
  return function(x,y)
   if x<0 or y<0 or x>=layout.width or y>=layout.height or excluded[x..':'..y]then return end
   local coll=layout:collAt(x,y)
   local t=types and types[layout:midAt(x,y)]
   -- Native game3.scripting.collision emits these COLL bytes from the
   -- imported FRLG metatile attributes. No Gen 2 module or live grid swap.
   if (t==2 or not types) and coll==0x29 then return 'water' end
   local grass=coll==0x18 or coll==0x14 or coll==0x10 or coll==0x1c
   local floor=grass or coll==0x00 or coll==0x2b
   if floor and (t==1 or not types and grass)then return 'land' end
  end
 end
 local Shared={version=1}
 function Shared.snapshot()
  local rows={}
  for _,r in pairs(S.spawns)do
   rows[#rows+1]={id=r.networkId,species=r.species,level=r.level,x=r.cellX,y=r.cellY,
    px=r.px,py=r.py,facing=r.facing,moving=r.moving,terrain=r.terrain,phase=r.animClock or 0,behavior=r.behavior,ambient=r.ambient,scenery=r.scenery,
    personality=r.personality,shiny=r.shiny,hiddenEncounter=r.behavior=='hidden',visibleSprite=r.behavior~='hidden'}
  end
  return S.map,rows
 end
 function Shared.configure(authority)
  assert(not authority or ((authority.role=='host' or authority.role=='guest')
   and type(authority.session)=='string' and type(authority.request)=='function'))
  if S.shared==authority then return end
  simulation=authority and authority.role=='host' and Simulation.new{session=authority.session,describe=remoteTerrain,pick=sample,random=love.math.random,count=function()return Rules.count(get)end,allowTerrain=function(kind)return Rules.visibleTerrain(get,kind)end,nativeFrames=true}or nil
  S.shared=authority;S.cache={};S.spawns={};S.map=nil;S.follower=nil;Actors.clear()
 end
 function Shared.apply(map,rows)
  S.cache[map]=rows
  if simulation then simulation.adopt(map,rows)end
  if map~=S.map then return true end
  local existing={};for _,r in pairs(S.spawns)do existing[r.networkId]=r end
  local keep={}
  for _,wire in ipairs(rows)do
   local r=existing[wire.id]
   if not r then
    local gid=sprite(wire.species,wire.terrain)
    if gid then
     S.nextId=S.nextId+1;r=Actors.add(S.nextId,map,wire.x,wire.y,gid)
     r.networkId=wire.id;r.species=wire.species;r.level=wire.level;r.terrain=wire.terrain
     r.px=wire.px or wire.x*16;r.py=wire.py or wire.y*16;r.nextMove=2
    end
   end
   if r then
    r.behavior=wire.behavior or(wire.hiddenEncounter and'hidden')or'wander';r.ambient=wire.ambient;r.scenery=wire.scenery
    r.personality=wire.personality;r.shiny=wire.shiny
    if not S.shared or S.shared.role=='guest' then
     r.cellX,r.cellY=wire.x,wire.y;r.targetPx=wire.px or wire.x*16;r.targetPy=wire.py or wire.y*16
     r.facing=wire.facing or 'down';r.moving=wire.moving;r.animClock=wire.phase or 0
    end
    keep[r.id]=r
   end
  end
  for id in pairs(S.spawns)do if not keep[id]then Actors.rows[id]=nil end end
  S.spawns=keep;return true
 end
 function Shared.remoteSnapshot(map,player,dt)
  if not simulation or map==Map.current then return end
  return simulation.snapshot(map,player,dt)
 end
 -- Verify the complete ray against host-owned map data. Off-map checks use
 -- immutable native layouts; they never swap the host's live collision grid.
 function Shared.canCatch(position,row,action,map)
  if not S.shared or S.shared.catching~=true or not position or not row or row.ambient or row.scenery or row.hiddenEncounter or row.visibleSprite==false or not get('enabled')or not get('overworld_catching')then return false end
  local x,y=tonumber(position.x),tonumber(position.y)
  local tx,ty=tonumber(row.x or row.cellX),tonumber(row.y or row.cellY)
  local direction=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[position.facing]
  if not x or not y or not tx or not ty or not direction then return false end
  local distance=math.abs(tx-x)+math.abs(ty-y)
  local range=2+math.floor(math.max(0,math.min(1,tonumber(action and action.charge)or 0))*4)
  if distance<1 or distance>range or x+direction[1]*distance~=tx or y+direction[2]*distance~=ty then return false end
  local def,layout,excluded
  if map~=Map.current then
   local g=game();def=g and g.data and g.data.maps and g.data.maps[map]
   if not def then return false end
   layout=Map.ensureMidLayout(g,map,def);if not layout or not layout.collAt then return false end
   excluded={}
   for _,list in ipairs({def.objects or{},def.warps or{}})do
    for _,e in ipairs(list)do if e.x and e.y then excluded[e.x..':'..e.y]=true end end
   end
  end
  local clearCollision={[0x00]=true,[0x18]=true,[0x14]=true,[0x10]=true,[0x1c]=true,[0x2b]=true,[0x29]=true}
  for _=1,distance do
   local nx,ny=x+direction[1],y+direction[2]
   if map==Map.current then
    if not(Collision.isWalkable(nx,ny)or Collision.isWater(nx,ny))or Collision.warpAt(nx,ny)or Objects.blocks(nx,ny)then return false end
    if Collision.directionallyImpassable and Collision.directionallyImpassable(x,y,nx,ny,position.facing)then return false end
   else
    if nx<0 or ny<0 or nx>=layout.width or ny>=layout.height or excluded[nx..':'..ny]or not clearCollision[layout:collAt(nx,ny)]then return false end
    if Collision.directionallyImpassableOn and Collision.directionallyImpassableOn(def,x,y,nx,ny,position.facing)then return false end
   end
   x,y=nx,ny
  end
  return true
 end
 function Shared.beginEncounter(wire,map)
  if not S.shared or map~=Map.current or busy()then return false,'field unavailable' end
  -- A grant can follow a removal snapshot; don't depend on a remaining actor.
  return mod.world:startWildBattle(wire.species,wire.level)
 end
 mod.exports.sharedSpawns=Shared
 local Catching=loadfile('catching')(mod,S,Actors,busy)
 Shared.beginCatch=Catching.beginCatch
 local interact=Field.interact
 local dirs={{0,-1,'up'},{0,1,'down'},{-1,0,'left'},{1,0,'right'}}
 Field.interact=function(g,...)
  if not busy()then
   local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[Player.facing]or{0,1}
   for _,row in pairs(S.spawns)do
    if row.cellX==Player.cellX+d[1]and row.cellY==Player.cellY+d[2]then
     if row.ambient then
      mod.world:queueScript({{'text',(Pokemon.name(row.species)or'POKEMON')..' looks happy!'}})
      return true
     end
     return S.encounter(row)
    end
   end
   for _,row in pairs(Followers.rows)do
    if row.mon and row.cellX==Player.cellX+d[1]and row.cellY==Player.cellY+d[2]then
     mod.world:queueScript({{'text',(Pokemon.name(row.mon.species)or'POKEMON')..' is happy to follow you!'}})
     return true
    end
   end
  end
  return interact(g,...)
 end
 local function move(row,dt)
  if row.catching or row.scenery then return end
  if row.moving then
   row.progress=math.min(1,(row.progress or 0)+dt/(row.chasing and .25 or .45))
   row.px=row.fromX+(row.cellX*16-row.fromX)*row.progress;row.py=row.fromY+(row.cellY*16-row.fromY)*row.progress
   row.animClock=(row.animClock or 0)+dt*60
   if row.progress>=1 then row.moving=false end
   return
  end
  row.nextMove=(row.nextMove or 1)-dt;if row.nextMove>0 then return end
  row.nextMove=1+love.math.random()*2
  local behavior=row.behavior or'idle'
  if not row.ambient and not Rules.behaviorEnabled(get,behavior)then behavior=Rules.behavior(get,love.math.random);row.behavior=behavior end
  if behavior=='hidden'then return end
  local d=dirs[love.math.random(4)]
  if behavior=='idle'then if get('enable_idle')then row.facing=d[3]end;return end
  local dx,dy=Player.cellX-row.cellX,Player.cellY-row.cellY
  row.chasing=behavior=='aggressive'and math.abs(dx)+math.abs(dy)<=5
  if row.chasing then
   if math.abs(dx)>math.abs(dy)then d=dx>0 and dirs[4]or dirs[3]else d=dy>0 and dirs[2]or dirs[1]end
   row.nextMove=.05
  end
  local x,y=row.cellX+d[1],row.cellY+d[2]
  local same=row.ambient and not Encounter.terrainAt(x,y)or Encounter.terrainAt(x,y)==row.terrain
  local free=same and validCell(x,y,row.terrain)and not(Collision.directionallyImpassable and Collision.directionallyImpassable(row.cellX,row.cellY,x,y,d[3]))
  if x==Player.cellX and y==Player.cellY then
   if row.chasing then S.encounter(row)end
   free=false
  end
  for _,other in pairs(S.spawns)do if other~=row and other.cellX==x and other.cellY==y then free=false end end
  if free then row.fromX,row.fromY=row.px,row.py;row.cellX,row.cellY=x,y;row.facing=d[3];row.progress=0;row.moving=true end
 end
 local function signature()
  local keys={'enabled','spawn_density','water_spawns','cave_spawns','town_pokemon','enable_idle','enable_wander','enable_aggressive','enable_hidden'}
  local out={};for _,k in ipairs(keys)do out[#out+1]=tostring(get(k))end;return table.concat(out,':')
 end
 function S.update(dt)
  local g=game();if not g or g.phase~='field' or not Map.current then return end
  if S.map~=Map.current then
   if S.shared and S.shared.role=='host'and S.map then local old,rows=Shared.snapshot();S.cache[old]=rows end
   S.map=Map.current;S.spawns={};Actors.clear();Followers.reset();S.signature=signature()
   if S.shared and S.cache[S.map]then Shared.apply(S.map,S.cache[S.map])else populate()end
  end
  dt=math.min(.1,math.max(0,dt or 0));S.elapsed=S.elapsed+dt
  if S.signature~=signature()then
   S.signature=signature()
   if not S.shared or S.shared.role=='host'then
    for _,r in pairs(S.spawns)do S.remove(r)end
    S.cache={};if simulation then simulation.maps={}end;populate()
   end
  end
  local blocked=simulationBusy()
  for _,row in pairs(S.spawns)do
   if S.shared and S.shared.role=='guest'then
    row.px=row.px+((row.targetPx or row.px)-row.px)*math.min(1,dt*15)
    row.py=row.py+((row.targetPy or row.py)-row.py)*math.min(1,dt*15)
   elseif not blocked then move(row,dt)end
   row.visible=row.ambient and get('town_pokemon')or not row.ambient and get('enabled')and Rules.visibleTerrain(get,row.terrain)
   Presentation.apply(row,g)
  end
  if not blocked then
   for _,row in pairs(S.spawns)do
    if row.visible and not row.catching and row.cellX==Player.cellX and row.cellY==Player.cellY then S.encounter(row);break end
   end
   S.refill=S.refill+dt;if S.refill>5 then S.refill=0;populate()end
  end
  Followers.update(g,dt);Catching.update(g,dt)
 end
 mod.hooks:wrap('input.step',function(nextFn,g,dt)nextFn(g,dt);S.update(dt)end)
 mod.hooks:wrap('encounter.roll',function(nextFn,def,ctx)
  if not Rules.randomAllowed(get,ctx and ctx.terrain)then return nil end
  return nextFn(def,ctx)
 end)
 mod.hooks:wrap('render.hud',function(nextFn,g,viewport)
  nextFn(g,viewport)
  if not get('dev_overlay')or g.phase~='field'then return end
  love.graphics.push('all');love.graphics.setColor(1,1,1,1)
  local lines={};for _,r in pairs(S.spawns)do lines[#lines+1]=(Pokemon.name(r.species)or tostring(r.species))..' '..(r.ambient and'town'or r.behavior or'idle')..' '..r.facing..' ['..r.cellX..','..r.cellY..']'end
  table.sort(lines);love.graphics.print(table.concat(lines,'\n'),(viewport.gameX or 0)+4,(viewport.gameY or 0)+4);love.graphics.pop()
 end)
 mod.exports.gen3=S;mod.exports.resolveGen3Sprite=sprite;mod.exports.gen3Actors=Actors
 mod.exports.gen3Catching=Catching;mod.exports.gen3Followers=Followers;mod.exports.optionSchema=schema
 mod.exports.getActiveFollowerMon=function(g)return Followers.leader(g or game())end
 mod.exports.supportsFeature=function(feature)return feature=='encounters'or feature=='followers'or feature=='catching'or feature=='townPokemon'end
 mod.log:info('Native FireRed Wilds: shared settings, visible encounters, party followers and direct catching loaded')
end
