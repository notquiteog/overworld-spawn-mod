-- Native routes, unchanged Wilds defaults, then interaction with an actual
-- naturally selected visible actor. The only party fixture is native givemon.
return function(game)
 assert(love.filesystem.getIdentity():match('%-qa$'))
 local U=dofile(assert(os.getenv('QA_UTIL')));local Json=require('src.link.Json')
 local E=assert(game.mods.exports.overworld_wild_spawns);local S=assert(E.gen3)
 local Map,Player,Encounter,C,Objects=require('src.core.game3.map'),require('src.core.game3.player'),require('src.core.game3.encounters'),require('src.core.game3.collision'),require('src.core.game3.objects')
 game:_handleBootAction({action='new_game',start={map='FR_PALLET_TOWN',x=7,y=8,facing='down'}});U.wait(120)
 local ba=game.mods.exports.BATTLE_ART_VOXEL_FORK;local V=ba and ba.lib;local BC=V and V.require('Gen3Integration')
 local out={edition=require('src.core.GameVersion').get(),missingOptionalArt=os.getenv('QA_MISSING_ART')=='1',maps={}}
 for _,q in ipairs{{'FR_ROUTE_1',16,16},{'FR_VIRIDIAN_FOREST',11,12},{'FR_ROUTE_3',34,11}}do
  if BC then BC.setLevel(0,game)end
  assert(Map.load(nil,game,q[1],{x=q[2],y=q[3],facing='up'}));Player.reset(q[2],q[3],'up');game.input:reset()
  assert(C.isWalkable(q[2],q[3])and Encounter.terrainAt(q[2],q[3])=='land','fixture must start in native walkable habitat')
  U.wait(420);require('src.ui.game3.map_preview_screen').dismiss();require('src.ui.game3.map_name_popup').dismiss();U.wait(5)
  local record={map=Map.current,player={Player.cellX,Player.cellY},signature=S.signature,spawns={},drawRows=0,bodies=0,frontFallback=0}
  for _,r in pairs(S.spawns)do
   record.spawns[#record.spawns+1]={id=r.id,species=r.species,level=r.level,x=r.cellX,y=r.cellY,behavior=r.behavior,graphicsId=r.graphicsId}
   if r.behavior~='hidden'then record.bodies=record.bodies+1 end
   local base=E.gen3Actors.sprites[E.resolveGen3Sprite(r.species,r.terrain,r.shiny)]
   if base.frameCount==1 then record.frontFallback=record.frontFallback+1 end
   local spr=assert(E.gen3Actors.sprites[r.graphicsId]);assert(spr.frameCount==9)
  end
  for _,r in ipairs(Objects.forDraw())do if E.gen3Actors.rows[r.id]==r then record.drawRows=record.drawRows+1 end end
  assert(#record.spawns==6 and record.drawRows==6 and record.bodies>0,'default natural population missing')
  if out.missingOptionalArt then assert(record.frontFallback==6,'optional-art fixture must use actual native front pictures')end
  if q[1]=='FR_ROUTE_1'then
   local x,y=Player.cellX,Player.cellY;local direction
   for _,d in ipairs{{1,0,'right'},{-1,0,'left'},{0,1,'down'},{0,-1,'up'}}do
    local nx,ny=x+d[1],y+d[2];local free=C.isWalkable(nx,ny)and not C.warpAt(nx,ny)and not Objects.blocks(nx,ny)and not C.directionallyImpassable(x,y,nx,ny,d[3])
    for _,r in pairs(S.spawns)do if r.cellX==nx and r.cellY==ny then free=false end end
    if free then direction=d[3];break end
   end
   assert(direction);U.hold(game,direction,20);U.wait(20)
   out.input={before={x,y},after={Player.cellX,Player.cellY},direction=direction};assert(Player.cellX~=x or Player.cellY~=y,'native directional input stalled')
  end
  assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..q[1]..'-native.png'))
  if BC then
   V.require('RenderDistance').setting:sync(24);V.require('DayNight').setting:sync('day');BC.setLevel(3,game)
   local Scene=V.require('Gen3Scene');local stable=0
   for _=1,2000 do U.wait(1);local a=Scene.streaming;if Scene.sceneDef==Map.currentDef()and a.started+a.promoted==a.completed+a.cancelled then stable=stable+1 else stable=0 end;if stable>=6 then break end end
   assert(stable>=6 and BC.active and BC.recovery.failures==0);assert(U.shot(game,os.getenv('SHOT_DIR')..'/'..q[1]..'-3d.png'))
  end
  out.maps[#out.maps+1]=record;print('NATURAL FRLG',Json.encode(record))
 end
 if BC then BC.setLevel(0,game);U.wait(3)end
 -- A fixture relocation within the same real map models reaching its far
 -- encounter patch without changing map, options, rows or encounter tables.
 local old={};for id in pairs(S.spawns)do old[id]=true end
 assert(Map.current=='FR_ROUTE_3'and C.isWalkable(78,15)and Encounter.terrainAt(78,15)=='land')
 Player.reset(78,15,'up');U.wait(660)
 out.travel={fixtureRelocation=true,player={Player.cellX,Player.cellY},near=0,count=0,drawRows=0,retired=0}
 for id in pairs(old)do assert(not S.spawns[id],'distant original actor still occupies quota');assert(not E.gen3Actors.rows[id],'retired actor retained by renderer');out.travel.retired=out.travel.retired+1 end
 for _,r in pairs(S.spawns)do out.travel.count=out.travel.count+1;if math.max(math.abs(r.cellX-Player.cellX),math.abs(r.cellY-Player.cellY))<=12 then out.travel.near=out.travel.near+1 end end
 for _,r in ipairs(Objects.forDraw())do if E.gen3Actors.rows[r.id]==r then out.travel.drawRows=out.travel.drawRows+1 end end
 assert(out.travel.count==6 and out.travel.near==6 and out.travel.drawRows==6 and out.travel.retired==6,'distant same-map natural population failed to replenish')
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/route3-distant-native.png'))
 if BC then
  BC.setLevel(3,game);local Scene=V.require('Gen3Scene');local stable=0
  for _=1,2000 do U.wait(1);local a=Scene.streaming;if Scene.sceneDef==Map.currentDef()and a.started+a.promoted==a.completed+a.cancelled then stable=stable+1 else stable=0 end;if stable>=6 then break end end
  assert(stable>=6 and BC.active and BC.recovery.failures==0);assert(U.shot(game,os.getenv('SHOT_DIR')..'/route3-distant-3d.png'));BC.setLevel(0,game);U.wait(3)
 end
 print('NATURAL TRAVEL',Json.encode(out.travel))
 local Party=require('src.core.game3.party');assert(Party.giveMon(game.session,1,30));assert(Party.giveMon(game.session,7,30));Party.healAll(game.session.party)
 local target,px,py,facing
 for _,r in pairs(S.spawns)do
  if not target and not r.ambient and not r.scenery and r.behavior~='hidden'then
   for _,d in ipairs{{0,1,'up'},{0,-1,'down'},{1,0,'left'},{-1,0,'right'}}do
    local x,y=r.cellX+d[1],r.cellY+d[2]
    if C.isWalkable(x,y)and not C.warpAt(x,y)and not Objects.blocks(x,y)and not C.directionallyImpassable(x,y,r.cellX,r.cellY,d[3])then target,px,py,facing=r,x,y,d[3];break end
   end
  end
 end
 assert(target,'no approachable naturally spawned visible actor');Player.reset(px,py,facing)
 out.encounter={species=target.species,level=target.level,personality=target.personality,actorId=target.id}
 assert(require('src.core.game3.field').interact(game),'native field interaction refused natural actor')
 local Battle=require('src.core.game3.battle')
 for _=1,900 do U.wait(1);if Battle.isActive()then break end end
 assert(Battle.isActive(),'natural actor did not enter native battle')
 for _=1,120 do if Battle._phase=='command'then break end;U.tap(game,'a');U.wait(8)end
 assert(Battle._phase=='command','native encounter did not reach command input')
 local st=assert(Battle.getState());local mon=assert(st.enemy.mon)
 assert(mon.species==target.species and mon.level==target.level and mon.personality==target.personality,'battle must retain natural actor identity')
 assert(S.spawns[target.id]==nil,'interacted actor must be removed once')
 assert(U.shot(game,os.getenv('SHOT_DIR')..'/natural-actor-battle.png'))
 out.modErrors=game.mods.errors;out.legacy=game.mods:legacyReport();out.battle={species=mon.species,level=mon.level,personality=mon.personality,phase=Battle._phase}
 assert(not out.modErrors or next(out.modErrors)==nil,'runtime mod error')
 local f=assert(io.open(os.getenv('SHOT_DIR')..'/natural-frlg.json','wb'));f:write(Json.encode(out));f:close()
 print('PASS NATURAL FRLG SPAWNING RENDER AND INTERACTION',out.edition)
end
