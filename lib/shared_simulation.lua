-- Host-only simulation for maps occupied by a guest. It reads map data without
-- loading that map into the host's game, changing collision, or moving players.
local M = {}
function M.new(opts)
  local S={maps={},serial=0}
  local rng=opts.random or math.random
  function S.adopt(map,rows)
    local old=S.maps[map]or{timers={}}
    local keep={}
    for _,r in ipairs(rows)do
      local t={};for k,v in pairs(r)do t[k]=v end
      keep[#keep+1]=t
    end
    old.rows=keep;S.maps[map]=old
  end
  function S.snapshot(map,player,dt)
    local state=S.maps[map]
    if not state then
      local terrain=opts.describe(map)
      if not terrain then return nil end
      state={rows={},timers={},terrain=terrain};S.maps[map]=state
      local occupied={}
      for _=1,200 do
        local x,y=player.x+rng(-10,10),player.y+rng(-8,8)
        local kind=terrain(x,y)
        local key=x..':'..y
        if kind and not occupied[key] and math.abs(x-player.x)+math.abs(y-player.y)>2 then
          local mon=opts.pick(map,kind)
          if mon then
            S.serial=S.serial+1;local id=opts.session..':remote:'..map..':'..S.serial
            state.rows[#state.rows+1]={id=id,x=x,y=y,px=x*16,py=y*16,facing='down',moving=false,
              terrain=kind,surface=kind=='water' and 'WATER' or 'GRASS',encounterKind=kind=='water' and 'water' or 'grass',
              species=mon.species,level=mon.level,visibleSprite=true,hiddenEncounter=false}
            occupied[key]=true;if #state.rows>=(opts.count or 6)then break end
          end
        end
      end
    end
    state.terrain=state.terrain or opts.describe(map)
    local dirs={{0,-1,'up'},{0,1,'down'},{-1,0,'left'},{1,0,'right'}}
    for _,r in ipairs(state.rows)do
      r.px=r.px or r.x*16;r.py=r.py or r.y*16
      local tx,ty=r.x*16,r.y*16
      local dx,dy=tx-r.px,ty-r.py;local distance=math.abs(dx)+math.abs(dy)
      if distance>.01 then
        local part=math.min(1,dt*36/distance);r.px=r.px+dx*part;r.py=r.py+dy*part;r.moving=true
        local timer=state.timers[r.id..':frame']or 0;timer=(timer+dt*60)%16;state.timers[r.id..':frame']=timer
        r.phase=opts.nativeFrames and timer or (math.floor(timer/8)%2)
      else
        r.moving=false;state.timers[r.id]=(state.timers[r.id]or(1+rng()*2))-dt
        if state.timers[r.id]<=0 and state.terrain then
          state.timers[r.id]=1+rng()*2
          local d=dirs[rng(4)];local x,y=r.x+d[1],r.y+d[2]
          local free=state.terrain(x,y)==r.terrain and not(x==player.x and y==player.y)
          for _,other in ipairs(state.rows)do if other~=r and other.x==x and other.y==y then free=false end end
          if free then r.x,r.y,r.facing=x,y,d[3]end
        end
      end
    end
    return state.rows
  end
  return S
end
return M
