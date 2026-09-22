-- Town Pokemon share the host's roster and native pose, just like wilds, but
-- remain peaceful NPCs. Guests draw snapshots and never run their wander AI.
local V=...
local Ambient=V.require('ambient_pokemon')
return function(mod,manager,makeWorld)
  local A={};local authority,cache,remote,serial=nil,{},{},0
  local function game()return mod.world.game end
  local function collect(owner,map)
    local rows={}
    for npc in pairs(owner.active)do
      if npc.mapId==map then
        if not npc.sharedAmbientId then
          serial=serial+1;npc.sharedAmbientId=authority.session..':ambient:'..serial
        end
        rows[#rows+1]={id=npc.sharedAmbientId,ambient=true,species=npc.ambientSpecies,level=1,
          x=npc.cellX,y=npc.cellY,px=npc.px,py=npc.py,facing=npc.facing,moving=npc.moving,
          phase=npc.walkPhase and npc:walkPhase()or 0,progress=npc.progress or 0,
          targetX=npc.targetX,targetY=npc.targetY,stepFlip=npc.stepFlip,
          wanders=npc.ambientBehavior=='WANDER',visibleSprite=true}
      end
    end
    return rows
  end
  local function apply(owner,ow,rows,guest)
    local existing,keep={},{}
    for npc in pairs(owner.active)do existing[npc.sharedAmbientId or npc]=npc end
    for _,row in ipairs(rows)do
      local npc=existing[row.id]
      if not npc then
        npc=owner:_makeNpc(game(),ow,row.species,row.x,row.y,row.wanders and 'WANDER'or'IDLE')
        if npc then
          npc.mapId=ow.map.id;npc.sharedAmbientId=row.id
          owner.active[npc]=true
          table.insert(ow.npcs,npc);table.insert(ow.entities,npc)
          if guest then
            npc.update=function()end
            npc.facePlayer=function()end -- A guest's local talk must not turn a shared NPC.
            npc.walkPhase=function(self)return self.sharedAmbientPose.phase or 0 end
          end
          npc.cellX,npc.cellY=row.x,row.y;npc.px,npc.py=row.px,row.py
          npc.targetX,npc.targetY=row.targetX,row.targetY
          npc.progress=row.progress;npc.moving=row.moving;npc.facing=row.facing;npc.stepFlip=row.stepFlip
        end
      end
      if npc then
        keep[npc]=true
        if guest then npc.sharedAmbientPose=row end
      end
    end
    local remove={};for npc in pairs(owner.active)do if not keep[npc]then remove[#remove+1]=npc end end
    for _,npc in ipairs(remove)do owner:removeNpc(ow,npc)end
    owner.activeMapId=ow.map.id
  end
  function A.configure(config,ow)
    authority=config;cache={};remote={};serial=0
    manager.sharedAuthority=config
    manager:clearAll(ow);manager.activeMapId=nil
    if ow then manager:spawnForMap(game(),ow)end
  end
  function A.snapshot(ow)
    if not authority or not ow then return {}end
    return collect(manager,ow.map.id)
  end
  function A.apply(map,rows,ow)
    cache[map]=rows
    -- A freshly published native local pose supersedes any off-map simulation.
    if ow and ow.map.id==map then remote[map]=nil;apply(manager,ow,rows,authority.role=='guest')end
  end
  function A.enter(ow)
    if ow and cache[ow.map.id]then apply(manager,ow,cache[ow.map.id],authority.role=='guest')end
  end
  function A.remoteSnapshot(map,player,dt)
    if not authority or authority.role~='host'then return {}end
    local state=remote[map]
    if not state then
      local ow=makeWorld(map,player);if not ow then return {}end
      local owner=Ambient.new(mod,{render=manager.render,logic=manager.logic,follower=manager.follower})
      if cache[map]then apply(owner,ow,cache[map],false)else owner:spawnForMap(game(),ow)end
      state={owner=owner,world=ow,clock=0};remote[map]=state
    end
    state.world.player.cellX,state.world.player.cellY=player.x,player.y
    state.clock=state.clock+math.max(0,math.min(.25,dt))*60
    while state.clock>=1 do
      state.clock=state.clock-1
      for npc in pairs(state.owner.active)do npc:update(state.world.map,state.world.entities)end
    end
    return collect(state.owner,map)
  end
  function A.update(dt)
    if not authority or authority.role~='guest'then return end
    for npc in pairs(manager.active)do
      local row=npc.sharedAmbientPose
      if row then
        local amount=math.min(1,math.max(0,dt or 0)*15)
        npc.px=npc.px+(row.px-npc.px)*amount;npc.py=npc.py+(row.py-npc.py)*amount
        npc.cellX,npc.cellY=row.x,row.y;npc.facing=row.facing;npc.moving=row.moving
        npc.progress=row.progress;npc.stepFlip=row.stepFlip
      end
    end
  end
  return A
end
