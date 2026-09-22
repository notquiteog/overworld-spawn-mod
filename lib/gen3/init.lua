-- Native FireRed encounter/follower adapter; Gen 1/2 retain their own modules.
return function(mod)
 local function loadfile(name)return assert((loadstring or load)(assert(mod:read('lib/gen3/'..name..'.lua')),'@wilds/gen3/'..name))()end
 local Actors=loadfile('actors')(mod,810000)
 local Player=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Collision=require('src.core.game3.collision')
 local Encounter=require('src.core.game3.encounters')
 local Pokemon=require('src.core.game3.pokemon')
 local Field=require('src.core.game3.field')
 local Compat=require('src.mods.Gen3Compat')
 local S={map=nil,spawns={},elapsed=0,nextId=0,follower=nil,shared=nil,cache={},trail={}}
 local schema=mod.options:define({
  {key='gen3_visible_wilds',label='VISIBLE WILDS',type='toggle',default=true},
  {key='gen3_follower',label='FOLLOWER',type='toggle',default=true},
  {key='gen3_random_encounters',label='RANDOM ENCOUNTERS',type='toggle',default=true},
  {key='catch_hud_size',label='CATCH HUD',type='choice',default=0,choices={{'HIDDEN',0}}},
 })
  assert((loadstring or load)(assert(mod:read('lib/InGameOptions.lua')),'@overworld-spawn-mod/options'))().install(mod,schema,'WILDS')
 local function game()return mod.world.game end
 local function busy()
  local r=mod.find and mod.find('DRAMATIC_SKY_RIDE');local ex=r and r.exports
  if ex and ex.isFlying and ex.isFlying()then return true,'airborne' end
  local ok,why=Compat.worldBusy();return ok,why
 end
 local function sprite(species)
  species=tonumber(species);if not species then return nil end
  local id=Actors.base+species
  if Actors.sprites[id]then return id end
  -- The mod's already-shipped six-frame sheets; duplicate the walking rows
  -- to the native nine-frame layout so both renderers share the same pose.
  local national=Pokemon.national and Pokemon.national(species) or species
  local bytes=mod:read(('assets/enhanced_overworld/poke_followers/follower_%03d_normal.png'):format(national))
  if bytes then
   local ok,image=pcall(function()return love.graphics.newImage(love.filesystem.newFileData(bytes,'follower.png'))end)
   if ok then
    local iw,ih=image:getDimensions()
    if iw==16 and ih==96 then
     local c=love.graphics.newCanvas(16,144);love.graphics.push('all');love.graphics.setCanvas(c);love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1,1)
     for i,row in ipairs({0,1,2,3,3,4,4,5,5})do love.graphics.draw(image,love.graphics.newQuad(0,row*16,16,16,16,96),0,(i-1)*16)end
     love.graphics.pop();c:setFilter('nearest','nearest');Actors.sprite(id,c,16,16,9);return id
    end
   end
  end
  return Actors.front(species)
 end
 local function sample(map,terrain)
  Encounter.ensureLoaded();local t=Encounter.tableFor(map)
  local area=t and (terrain=='water' and t.water or t.land or t.grass)
  local slots=area and (area.slots or area.mons or area)
  if not slots or #slots==0 then return nil end
  local weights=terrain=='water' and {60,30,5,4,1}or{20,20,10,10,10,10,5,5,4,4,1,1}
  local total=0;for i in ipairs(slots)do total=total+(weights[i]or 1)end
  local roll=love.math.random(total);local entry
  for i,row in ipairs(slots)do roll=roll-(weights[i]or 1);if roll<=0 then entry=row;break end end
  local species=tonumber(entry and (entry.species or entry[1]));if not species or not Pokemon.name(species)then return nil end
  local lo=math.max(1,tonumber(entry.minLevel or entry.level or entry[2])or 1)
  local hi=math.min(100,tonumber(entry.maxLevel or entry.level or entry[2])or lo)
  return {species=species,level=love.math.random(lo,math.max(lo,hi))}
 end
 function S.spawn(species,level,x,y,terrain)
  if S.shared and S.shared.role=='guest' then return nil,'host owns visible spawns' end
  local gid=sprite(species);if not gid then return nil,'no species sprite' end
  S.nextId=S.nextId+1;local row=Actors.add(S.nextId,Map.current,x,y,gid)
  row.networkId=(S.shared and S.shared.session or 'offline')..':'..Map.current..':'..S.nextId
  row.species=species;row.level=level;row.terrain=terrain or Encounter.terrainAt(x,y);row.nextMove=1+love.math.random()*2
  S.spawns[row.id]=row;return row
 end
 local function validCell(x,y,terrain)
  local def=Map.currentDef()
  return def and x>=0 and y>=0 and x<(def.midLayout and def.midLayout.width or def.width) and y<(def.midLayout and def.midLayout.height or def.height)
   and (terrain=='water' and Collision.isWater(x,y) or terrain=='land' and Collision.isWalkable(x,y))
   and not Collision.warpAt(x,y) and not require('src.core.game3.objects').blocks(x,y)
 end
 local function populate()
  if S.shared and S.shared.role=='guest' then return end
  if not mod.options:get('gen3_visible_wilds')then return end
  local occupied={};local count=0
  for _=1,100 do
   local x,y=Player.cellX+love.math.random(-8,8),Player.cellY+love.math.random(-6,6)
   local key=x..':'..y;local terrain=Encounter.terrainAt(x,y)
   if not occupied[key] and terrain and validCell(x,y,terrain)and math.abs(x-Player.cellX)+math.abs(y-Player.cellY)>2 then
    local e=sample(Map.current,terrain)
    if e and S.spawn(e.species,e.level,x,y,terrain)then occupied[key]=true;count=count+1;if count>=6 then break end end
   end
  end
 end
 function S.encounter(row)
  if not row or S.spawns[row.id]~=row then return false,'spawn no longer present' end
  local blocked,why=busy();if blocked then return false,why end
  if S.shared then return S.shared.request(S.map,row.networkId) end
  local ok,err=mod.world:startWildBattle(row.species,row.level)
  if ok then S.spawns[row.id]=nil;Actors.rows[row.id]=nil end
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
    px=r.px,py=r.py,facing=r.facing,moving=r.moving,terrain=r.terrain,phase=r.animClock or 0}
  end
  return S.map,rows
 end
 function Shared.configure(authority)
  assert(not authority or ((authority.role=='host' or authority.role=='guest')
   and type(authority.session)=='string' and type(authority.request)=='function'))
  if S.shared==authority then return end
  simulation=authority and authority.role=='host' and Simulation.new{session=authority.session,describe=remoteTerrain,pick=sample,random=love.math.random,count=6,nativeFrames=true}or nil
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
    local gid=sprite(wire.species)
    if gid then
     S.nextId=S.nextId+1;r=Actors.add(S.nextId,map,wire.x,wire.y,gid)
     r.networkId=wire.id;r.species=wire.species;r.level=wire.level;r.terrain=wire.terrain
     r.px=wire.px or wire.x*16;r.py=wire.py or wire.y*16;r.nextMove=2
    end
   end
   if r then
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
 function Shared.beginEncounter(wire,map)
  if not S.shared or map~=Map.current or busy()then return false,'field unavailable' end
  -- A grant can follow a removal snapshot; don't depend on a remaining actor.
  return mod.world:startWildBattle(wire.species,wire.level)
 end
 mod.exports.sharedSpawns=Shared
 local interact=Field.interact
 Field.interact=function(g,...)
  if not busy()then
   local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[Player.facing]or{0,1}
   for _,row in pairs(S.spawns)do if row.cellX==Player.cellX+d[1]and row.cellY==Player.cellY+d[2]then return S.encounter(row)end end
  end
  return interact(g,...)
 end
 local dirs={{0,-1,'up'},{0,1,'down'},{-1,0,'left'},{1,0,'right'}}
 function S.update(dt)
  local g=game();if not g or g.phase~='field' or not Map.current then return end
  if S.map~=Map.current then
   if S.shared and S.shared.role=='host' and S.map then local old,rows=Shared.snapshot();S.cache[old]=rows end
   S.map=Map.current;S.spawns={};S.follower=nil;S.trail={};S.lastCell=nil;Actors.clear()
   if S.shared and S.cache[S.map] then Shared.apply(S.map,S.cache[S.map]) else populate() end
  end
  dt=math.min(.1,math.max(0,dt or 0));S.elapsed=S.elapsed+dt
  for _,row in pairs(S.spawns)do
   if S.shared and S.shared.role=='guest' then
    row.px=row.px+((row.targetPx or row.px)-row.px)*math.min(1,dt*15)
    row.py=row.py+((row.targetPy or row.py)-row.py)*math.min(1,dt*15)
   else
   row.nextMove=row.nextMove-dt
   if row.moving then
    row.progress=math.min(1,row.progress+dt/.45);row.px=row.fromX+(row.cellX*16-row.fromX)*row.progress;row.py=row.fromY+(row.cellY*16-row.fromY)*row.progress
    row.animClock=(row.animClock or 0)+1
    if row.progress>=1 then row.moving=false end
   elseif row.nextMove<=0 then
    row.nextMove=1+love.math.random()*2;local d=dirs[love.math.random(4)];local x,y=row.cellX+d[1],row.cellY+d[2]
    local free=Encounter.terrainAt(x,y)==row.terrain and validCell(x,y,row.terrain) and not (x==Player.cellX and y==Player.cellY)
    for _,other in pairs(S.spawns)do if other~=row and other.cellX==x and other.cellY==y then free=false end end
    if free then row.fromX,row.fromY=row.px,row.py;row.cellX,row.cellY=x,y;row.facing=d[3];row.progress=0;row.moving=true end
   end
  end
  end
  if not busy()then
   for _,row in pairs(S.spawns)do
    if row.cellX==Player.cellX and row.cellY==Player.cellY then S.encounter(row);break end
   end
  end
  -- Record the cells actually vacated by the player. Never invent a cell
  -- behind their facing (that can be inside a wall or across a ledge).
  local riding=mod.find and mod.find('DRAMATIC_SKY_RIDE')
  local ride=riding and riding.exports
  local mounted=ride and ride.isMounted and ride.isMounted()
  local at={x=Player.cellX,y=Player.cellY}
  local last=S.lastCell
  if last and (last.x~=at.x or last.y~=at.y)then
   if math.abs(last.x-at.x)+math.abs(last.y-at.y)>2 then S.trail={};Actors.rows[0]=nil;S.follower=nil
   else S.trail[#S.trail+1]=last end
  end
  S.lastCell=at
  while #S.trail>16 do table.remove(S.trail,1)end
  local mon=not mounted and mod.options:get('gen3_follower')and g.session and g.session.party and g.session.party[1]
  if mon and (mon.hp or 0)>0 then
   local gid=sprite(mon.species)
   if gid then
    local function safe(c)
     return c and Collision.isWalkable(c.x,c.y)and not Collision.isWater(c.x,c.y)
      and not Collision.warpAt(c.x,c.y)and not require('src.core.game3.objects').blocks(c.x,c.y)
    end
    local f=S.follower
    if not f and safe(S.trail[1])then
     local c=table.remove(S.trail,1);f=Actors.add(0,Map.current,c.x,c.y,gid);S.follower=f
    end
    if f then
     f.graphicsId=gid;f.moving=false
     while S.trail[1] and math.abs(S.trail[1].x*16-f.px)+math.abs(S.trail[1].y*16-f.py)<.1 do table.remove(S.trail,1)end
     local c=S.trail[1]
     if c and not safe(c)then S.trail={};Actors.rows[0]=nil;S.follower=nil
     elseif c then
      local dx,dy=c.x*16-f.px,c.y*16-f.py;local dist=math.abs(dx)+math.abs(dy)
      local step=math.min(dist,dt*100)
      if dist>32 then f.px=c.x*16;f.py=c.y*16
      elseif dist>.1 then
       f.facing=math.abs(dx)>math.abs(dy)and(dx>0 and 'right'or'left')or(dy>0 and'down'or'up')
       f.px=f.px+dx/dist*step;f.py=f.py+dy/dist*step;f.moving=true
      end
      f.animClock=(f.animClock or 0)+(f.moving and dt*60 or 0)
      if step>=dist then table.remove(S.trail,1)end
     end
     f.cellX=math.floor((f.px+8)/16);f.cellY=math.floor((f.py+8)/16)
    end
   end
  else Actors.rows[0]=nil;S.follower=nil;S.trail={}end
 end
 mod.hooks:wrap('input.step',function(next,g,dt)next(g,dt);S.update(dt)end)
 mod.hooks:wrap('encounter.roll',function(nextFn,def,ctx)
  if not mod.options:get('gen3_random_encounters')and next(S.spawns)then return nil end
  return nextFn(def,ctx)
 end)
 mod.exports.gen3=S;mod.exports.resolveGen3Sprite=sprite;mod.exports.gen3Actors=Actors
 mod.exports.getActiveFollowerMon=function(g)g=g or game();return g and g.session and g.session.party and g.session.party[1]end
 mod.exports.supportsFeature=function(feature)return feature=='encounters'or feature=='followers'end
 mod.log:info('Native FireRed visible encounters and follower adapter loaded')
end
