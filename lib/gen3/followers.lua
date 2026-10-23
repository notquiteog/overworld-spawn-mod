-- Followers trace cells really traversed by the native player. Replacing the
-- player's graphics leaves scripts, collision, map connections and saves native.
return function(mod,Actors,Presentation,busy)
 local Player=require('src.core.game3.player')
 local Map=require('src.core.game3.map')
 local Collision=require('src.core.game3.collision')
 local Objects=require('src.core.game3.objects')
 local Sprites=require('src.core.game3.ow_sprites')
 local Pokemon=require('src.core.game3.pokemon')
 local SummaryData=require('src.core.game3.summary_data')
 local function egg(mon)return Pokemon.isEgg and Pokemon.isEgg(mon)or mon.isEgg or mon.egg end
 local F={trail={},rows={}}
 local function identity(mon)return table.concat({tostring(mon.species),tostring(mon.personality or''),tostring(mon.otId or'')},':')end
 if mod.save and mod.save.get then F.selected=mod.save:get('gen3_selected_follower')end
 local original=Sprites.playerGraphicsId
 local function mounted()
  local m=mod.find and mod.find('DRAMATIC_SKY_RIDE');local ex=m and m.exports
  return ex and ex.isMounted and ex.isMounted()
 end
 function F.leader(game)
  local party=game and game.session and game.session.party or{}
  for _,mon in ipairs(party)do if F.selected==identity(mon)and(mon.hp or 0)>0 and not egg(mon) then return mon end end
  for _,mon in ipairs(party)do if(mon.hp or 0)>0 and not egg(mon) then return mon end end
 end
 function F.controlled(game)
  return mod.options:get('follow_control')=='pokemon' and not mounted()and not Player.surfing and not Player.underwater and F.leader(game)
 end
 Sprites.playerGraphicsId=function(game)
  local mon=F.controlled(game)
  return mon and Presentation.sprite(mon.species,nil,SummaryData.isShiny(mon))or original(game)
 end
 function F.reset()
  for id in pairs(F.rows)do Actors.rows[id]=nil end
  F.rows={};F.trail={};F.last=nil;F.sequence=0;F.runSpeed=nil;F.runLocomotion=nil;F.idleStepFrames=nil
 end
 -- The engine event identifies genuine walking connections. Coordinate
 -- transforms come from its public connection API, never from a guessed
 -- player delta (the entry event precedes the seam step).
 local exited,pending
 if mod.events and mod.events.on then
  mod.events:on('map.exited',function()exited=Map.currentDef and Map.currentDef()end)
  mod.events:on('map.entered',function(ev)
   pending=nil
   if ev and ev.via=='connection' and exited then
    local C=require('src.core.game3.connections')
    for _,c in ipairs(C.each(exited))do if c.map==ev.mapId then
     local w,h=C.sizeOf(exited)
     local x,y
     -- localPos clips along the strip; derive the same unrestricted frame.
     local nw,nh=C.sizeOf(ev.map)
     x=c.dir=='west'and nw or c.dir=='east'and-w or -(c.offset or 0)
     y=c.dir=='north'and nh or c.dir=='south'and-h or -(c.offset or 0)
     pending={x=x,y=y};break
    end end
   end
   exited=nil
  end)
 end
 function F.mapChanged()
  local shift=pending;pending=nil
  if not shift then F.reset();return end
  for _,c in ipairs(F.trail)do c.x,c.y=c.x+shift.x,c.y+shift.y end
  if F.last then F.last.x,F.last.y=F.last.x+shift.x,F.last.y+shift.y end
  for id,row in pairs(F.rows)do
   row.px,row.py=row.px+shift.x*16,row.py+shift.y*16
   row.cellX,row.cellY=row.cellX+shift.x,row.cellY+shift.y
   row.map=Map.current;Actors.rows[id]=row
  end
 end
 local function safe(c)
  return c and Collision.isWalkable(c.x,c.y)and not Collision.isWater(c.x,c.y)
   and not Collision.warpAt(c.x,c.y)and not Objects.blocks(c.x,c.y)
 end
 function F.update(game,dt)
  -- Dive owns its composite swimmer sprite. Underwater paths are not land
  -- trails and must not be replayed by followers after surfacing.
  if Player.underwater then F.reset();return end
  local at={x=Player.cellX,y=Player.cellY}
  local last=F.last
  if last and(last.x~=at.x or last.y~=at.y)then
   if math.abs(last.x-at.x)+math.abs(last.y-at.y)>2 then F.reset()
   else F.sequence=(F.sequence or 0)+1;last.seq=F.sequence;F.trail[#F.trail+1]=last end
  end
  F.last=at
  while #F.trail>256 do table.remove(F.trail,1)end
  local speed=960/math.max(1,tonumber(Player.stepFrames)or 16)
  local locomotion=mounted()and'mounted'or Player.biking and'bike'or Player.surfing and'water'or'foot'
  if F.runLocomotion~=locomotion then
   F.runSpeed=nil;F.runLocomotion=locomotion
   F.idleStepFrames=not Player.moving and (Player.ordinaryStepFrames and Player.ordinaryStepFrames(false)or 16)or nil
  end
  if Player.moving then F.idleStepFrames=nil end
  if F.idleStepFrames then speed=960/math.max(1,F.idleStepFrames)end
  if Player.moving and not Player.jumping then F.runSpeed=math.max(F.runSpeed or speed,speed)end
  local desired={};local controlled=F.controlled(game)
  local rideMod=mod.find and mod.find('DRAMATIC_SKY_RIDE');local ride=rideMod and rideMod.exports
  local showMounted=ride and ride.shouldShowFollowers and ride.shouldShowFollowers()
  local mountedSlot=mounted()and ride and ride.gen3 and ride.gen3.slot
  if(not mounted()or showMounted)and not Player.surfing then
   local count=math.max(0,math.min(6,tonumber(mod.options:get('follower_count'))or 1))
   local ordered={};local leader=F.leader(game)
   if leader then ordered[1]=leader end
   for _,mon in ipairs(game.session and game.session.party or{})do if mon~=leader then ordered[#ordered+1]=mon end end
   local ridden=mountedSlot and game.session.party[mountedSlot]
   for _,mon in ipairs(ordered)do
    if #desired>=count then break end
    if mon~=ridden and(mon.hp or 0)>0 and not egg(mon) and mon~=controlled then desired[#desired+1]={mon=mon,gid=Presentation.sprite(mon.species,nil,SummaryData.isShiny(mon))}end
   end
   if controlled and mod.options:get('trainer_trail')then table.insert(desired,1,{gid=original(game),trainer=true})end
  end
  local keep={}
  for i,entry in ipairs(desired)do
   local id=-i;local c=F.trail[#F.trail-(i-1)*2]
   if c and entry.gid and (F.rows[id] or safe(c))then
    local row=F.rows[id]
    if not row then row=Actors.add(id,Map.current,c.x,c.y,entry.gid);row.trailSeq=c.seq end
    -- Follow each traversed corner instead of cutting diagonally across walls.
    local destination=c
    if row.trailSeq and c.seq then
     for _,point in ipairs(F.trail)do if point.seq>row.trailSeq and point.seq<=c.seq then destination=point;break end end
    end
    c=destination
    row.graphicsId=entry.gid;row.mon=entry.mon;row.trainer=entry.trainer;row.moving=false
    local dx,dy=c.x*16-row.px,c.y*16-row.py;local dist=math.abs(dx)+math.abs(dy)
    if dist>.1 and not busy()then
     local behind=math.abs((Player.px or Player.cellX*16)-row.px)+math.abs((Player.py or Player.cellY*16)-row.py)>i*32+16
     local pace=behind and math.max(speed,F.runSpeed or speed)or speed
     local part=math.min(1,dt*pace/dist);row.px=row.px+dx*part;row.py=row.py+dy*part;row.moving=true
     row.facing=math.abs(dx)>math.abs(dy)and(dx>0 and'right'or'left')or(dy>0 and'down'or'up')
    end
    if math.abs(row.px-c.x*16)+math.abs(row.py-c.y*16)<.1 then row.trailSeq=c.seq end
    row.cellX=math.floor((row.px+8)/16);row.cellY=math.floor((row.py+8)/16)
    row.animClock=(row.animClock or 0)+(row.moving and dt*60 or 0);keep[id]=row
   end
  end
  for id in pairs(F.rows)do if not keep[id]then Actors.rows[id]=nil end end
  F.rows=keep
 end
 local function setOption(game,key,value)
  local options=(game.save and game.save.options)or game.options
  if not options or not game.mods then return end
  options.modOptions=options.modOptions or{};options.modOptions[mod.id]=options.modOptions[mod.id]or{};options.modOptions[mod.id][key]=value
  game.mods.modOptions=game.mods.modOptions or{};game.mods.modOptions[mod.id]=game.mods.modOptions[mod.id]or{};game.mods.modOptions[mod.id][key]=value
  require('src.mods.Runtime').emit('mod.options_changed',{mod=mod.id,key=key,value=value})
  if game.writeOptions then game:writeOptions()elseif game.persistOptions then game:persistOptions()end
 end
 function F.select(game,mon)
  F.selected=mon and identity(mon)or nil
  if mod.save and mod.save.set then mod.save:set('gen3_selected_follower',F.selected)end
  if mon then
   if(tonumber(mod.options:get('follower_count'))or 0)<1 then setOption(game,'follower_count',1)end
  else setOption(game,'follower_count',0);setOption(game,'follow_control','trainer')end
  F.reset()
 end
 -- Game3 owns its native party actions and does not emit ui.party.submenu.
 -- Compose at handleInput, keeping every action another mod has contributed.
 local Menu=require('src.ui.game3.party_menu')
 local input=Menu.handleInput
 Menu.handleInput=function(buttons,...)
  local game=mod.game
  local label=Menu.ACTIONS and Menu.ACTIONS[Menu.actionCursor or 1]
  local mon=Menu._party and Menu._party[Menu.cursor or 1]
  if Menu.mode=='action'and not Menu._battle and(label=='FOLLOW'or label=='DISMISS')and buttons:wasPressed('a')then
   if label=='FOLLOW'and mon and(mon.hp or 0)>0 then F.select(game,mon)else F.select(game,nil)end
   Menu.mode='list';return
  end
  local result=input(buttons,...)
  local normalActions=false;for _,action in ipairs(Menu.ACTIONS or{})do if action=='SWITCH'then normalActions=true end end
  if Menu.mode=='action'and not Menu._battle and normalActions and mon and(mon.hp or 0)>0 and not egg(mon) then
   local rows={}
   for _,action in ipairs(Menu.ACTIONS or{})do if action~='FOLLOW'and action~='DISMISS'then rows[#rows+1]=action end end
   local active=F.leader(game)==mon and(tonumber(mod.options:get('follower_count'))or 0)>0
   table.insert(rows,math.max(1,#rows),active and'DISMISS'or'FOLLOW');Menu.ACTIONS=rows
  end
  return result
 end
 return F
end
