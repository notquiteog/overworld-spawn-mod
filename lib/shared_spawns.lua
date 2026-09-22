-- Optional host-authority adapter for the existing Gen 1/2 spawner. Rendering,
-- sprites and encounters remain owned by Wilds; networking lives in Online.
local V = ...
local Config = V.require('config')
local GameCompat = V.require('game_compat')
local Movement = V.require('movement')
return function(mod, logic, render, ambient)
  local A = {version=1}
  local authority, cache, lastMap = nil, {}, nil
  local simulation
  local Simulation=V.require("shared_simulation")
  local EncounterPick=V.require("encounter_pick")
  local function game() return mod.world.game end
  local function world() return logic:_ow(game()) end
  local function makeWorld(mapId,player)
    local g,w=game(),world();if not g or not w then return end
    local maps=GameCompat.isGen2(mod,g) and w.maps or g.data.maps
    local def=maps and maps[mapId]
    local sets=GameCompat.isGen2(mod,g) and w.tilesets or g.data.tilesets
    local tiles=def and sets and sets[def.tileset];if not tiles then return end
    local Map=require(GameCompat.isGen2(mod,g) and 'src.world.gen2.Map' or 'src.world.Map')
    local map=Map.new(def,tiles)
    local ow={map=map,player={cellX=player.x,cellY=player.y},npcs={},entities={}}
    for _,e in ipairs(def.objects or def.people or {})do
      ow.entities[#ow.entities+1]={cellX=e.x,cellY=e.y}
    end
    return ow
  end
  local town=V.require('shared_ambient')(mod,ambient,makeWorld)
  local function describe(mapId)
    local ow=makeWorld(mapId,{x=-100,y=-100});if not ow then return end
    local map=ow.map
    return function(x,y)
      if x<0 or y<0 or x>=map.widthCells or y>=map.heightCells then return end
      if map:warpAtCell(x,y) or logic:isStoryReservedCell(g,mapId,x,y) then return end
      for _,e in ipairs(ow.entities)do if e.cellX==x and e.cellY==y then return end end
      if map:isWaterCell(x,y)then return 'water' end
      if map:isWalkableCell(x,y) and map:isGrassCell(x,y)then return 'land' end
    end
  end
  function A.configure(config)
    assert(not config or ((config.role=='host' or config.role=='guest')
      and type(config.session)=='string' and type(config.request)=='function'))
    if authority==config then return end
    authority=config
    simulation=config and config.role=='host' and Simulation.new{session=config.session,describe=describe,
      pick=function(map,terrain)return EncounterPick.pick(logic:_encDef(map,game()),love.math.random,terrain=='water' and 'water' or 'grass')end,
      count=Config.maxVisible(mod),random=love.math.random}or nil
    cache={};lastMap=nil;logic.sharedAuthority=config
    logic:clearAll()
    local ow=world()
    town.configure(config,ow)
    if ow and ow.map then logic.activeMapId=ow.map.id;logic:initializeForMap(ow.map.id,game())end
  end
  function A.snapshot()
    local ow=world();local map=ow and ow.map and ow.map.id
    if not map then return end
    local rows={}
    for id,r in pairs(logic.spawns)do
      local e=logic.entities[id]
      if r.mapId==map and e and r.state==Config.STATE.AVAILABLE and not e.wildsAmbientPokemon then
        r.networkId=r.networkId or ((authority and authority.session or 'offline')..':'..id)
        e.sharedWild=authority~=nil
        rows[#rows+1]={id=r.networkId,species=r.species,level=r.level,
          x=e.cellX,y=e.cellY,px=e.px,py=e.py,facing=e.facing,moving=e.moving,
          phase=Movement.walkPhase(e),surface=r.surface,encounterKind=r.encounterKind,
          visibleSprite=r.visibleSprite,hiddenEncounter=r.hiddenEncounter,terrain=r.surface=='WATER' and 'water' or 'land'}
      end
    end
    if authority then for _,row in ipairs(town.snapshot(ow))do rows[#rows+1]=row end end
    return map,rows
  end
  function A.apply(map,rows)
    cache[map]=rows
    local wildRows,townRows={},{}
    for _,row in ipairs(rows)do
      local list=row.ambient and townRows or wildRows;list[#list+1]=row
    end
    if simulation then simulation.adopt(map,wildRows)end
    local ow=world()
    if authority then town.apply(map,townRows,ow)end
    if not ow or not ow.map or ow.map.id~=map then return true end
    local existing={}
    for id,r in pairs(logic.spawns)do if r.mapId==map then existing[r.networkId or id]=r end end
    local keep={}
    for _,wire in ipairs(wildRows)do
      local r=existing[wire.id]
      if not r then
        r={id='shared_'..wire.id,networkId=wire.id,mapId=map,x=wire.x,y=wire.y,
          species=wire.species,level=wire.level,state=Config.STATE.AVAILABLE,
          surface=wire.surface,encounterKind=wire.encounterKind,visibleSprite=wire.visibleSprite,hiddenEncounter=wire.hiddenEncounter}
        local e=render:makeEntity(game(),r)
        if e then
          if authority and authority.role=='host' then
            local Behavior=V.require('behavior')
            local regions=wire.surface=='WATER' and logic.waterRegions or logic.regions
            local region=V.require('spawn_regions').regionForCell(regions or {},wire.x,wire.y)
            local behavior=wire.hiddenEncounter and (wire.surface=='WATER' and Behavior.WATER_IDLE or Behavior.HIDDEN_GRASS)
              or (wire.surface=='WATER' and Behavior.WATER_WANDER or Behavior.GRASS_WANDER)
            Behavior.attach(e,behavior,region)
            e.visibleSprite=wire.visibleSprite;e.hiddenEncounter=wire.hiddenEncounter
            e.facing=wire.facing or 'down';e.movement.facing=e.facing
          end
          logic.spawns[r.id]=r;logic.entities[r.id]=e
          logic.byMap[map]=logic.byMap[map]or{};table.insert(logic.byMap[map],r.id)
          logic:_attach(e)
        else r=nil end
      end
      if r then
        keep[r.id]=true
        local e=logic.entities[r.id]
        if e then
          e.sharedWild=true
          if authority and authority.role=='guest' then
            e.sharedPose=wire
            e.sharedTargetX=wire.px or wire.x*16;e.sharedTargetY=wire.py or wire.y*16
            e.cellX,e.cellY=wire.x,wire.y
            e.spawnFx=nil -- Remote snapshots are already visible, not new local rolls.
          end
        end
      end
    end
    local remove={}
    for id,r in pairs(logic.spawns)do if r.mapId==map and not keep[id]then remove[#remove+1]=id end end
    for _,id in ipairs(remove)do logic:_despawn(id,true)end
    logic:markOccupancyDirty()
    return true
  end
  function A.remoteSnapshot(map,player,dt)
    local ow=world()
    if not simulation or not ow or not ow.map or map==ow.map.id then return end
    local rows={}
    for _,row in ipairs(simulation.snapshot(map,player,dt)or{})do rows[#rows+1]=row end
    for _,row in ipairs(town.remoteSnapshot(map,player,dt))do rows[#rows+1]=row end
    return rows
  end
  function A.beginEncounter(wire,map)
    if wire.ambient then return false,'not a wild encounter' end
    local ow=world()
    if not authority or not ow or not ow.map or ow.map.id~=map or logic.pendingBattle
      or (ow.busy and ow:busy())then return false,'field unavailable' end
    if logic:isStoryReservedCell(game(),map,wire.x,wire.y)then return false,'story encounter' end
    -- Use the native encounter seam directly, after the host has removed the
    -- shared actor. No second roll and no dependency on a remaining entity.
    local ok,err=GameCompat.startWildBattle(mod.world,wire.species,wire.level,game())
    if ok then logic.pendingBattle={id=wire.id,species=wire.species,level=wire.level}end
    return ok,err
  end
  mod.hooks:wrap('input.step',function(nextFn,g,dt)
    nextFn(g,dt)
    if not authority then return end
    local ow=world();local map=ow and ow.map and ow.map.id
    if map~=lastMap then
      lastMap=map
      if map and cache[map] then A.apply(map,cache[map])end
    end
    town.update(dt)
    if authority.role~='guest' then return end
    for _,e in pairs(logic.entities)do
      if e.sharedPose then
        local amount=math.min(1,math.max(0,dt or 0)*15)
        e.px=e.px+(e.sharedTargetX-e.px)*amount;e.py=e.py+(e.sharedTargetY-e.py)*amount
        Movement.syncLegacyFields(e)
      end
    end
  end)
  return A
end
