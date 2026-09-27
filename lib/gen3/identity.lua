-- Visible spawns keep one host-selected identity through drawing, battle and
-- capture. No protocol extension or companion mod is required.
return function(mod)
 local M={};local pending,installed
 local owned=setmetatable({},{__mode='k'})
 local function valid(pid)return type(pid)=='number'and pid==math.floor(pid)and pid>=0 and pid<4294967296 end
 function M.assign(row)
  if not valid(row.personality)then row.personality=love.math.random(0,65535)*65536+love.math.random(0,65535)end
  if type(row.shiny)~='boolean'then
   row.shiny=require('src.core.game3.summary_data').isShiny({personality=row.personality})
  end
  return row
 end
 local function install()
  if installed then return end
  local Bridge=require('src.core.game3.battle_bridge')
  local Battle=require('src.core.game3.battle')
  local wild,start=Bridge.startWild,Battle.start
  Bridge.startWild=function(nativeMod,game,foe,opts)
   local row=pending
   if row and game==mod.world.game and foe.species==row.species and foe.level==row.level then
    local copy={};for k,v in pairs(foe)do copy[k]=v end
    copy.personality=row.personality
    owned[copy]={personality=row.personality,shiny=row.shiny}
    foe=copy
   end
   return wild(nativeMod,game,foe,opts)
  end
  Battle.start=function(opts,...)
   local identity=opts and opts.wild and not opts.link and owned[opts.foe]
   if identity then
    owned[opts.foe]=nil
    local copy={};for k,v in pairs(opts)do copy[k]=v end
    local started=opts.onStarted
    copy.onStarted=function(st)
     local enemy=st and st.enemy and st.enemy.mon
     if enemy and enemy.personality==identity.personality then enemy.isShiny=identity.shiny end
     if started then return started(st)end
    end
    opts=copy
   end
   return start(opts,...)
  end
  installed=true
 end
 function M.begin(row)
  install()
  -- Keep the SDK's healthy-party/warp/active-battle validation. Its descriptor
  -- is enriched only during this call; the exact descriptor follows any
  -- asynchronous transition into Battle.start. Unrelated battles are untouched.
  local previous=pending;pending=row
  local ok,result,err=pcall(mod.world.startWildBattle,mod.world,row.species,row.level)
  pending=previous
  if not ok then return nil,result end
  return result,err
 end
 return M
end
