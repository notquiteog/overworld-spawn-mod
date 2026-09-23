-- Native nine-frame art and presentation variants. Variants are baked sheets,
-- so every renderer consuming OwSprites.getDraw sees the same fade and masks.
return function(mod,Actors)
 local Pokemon=require('src.core.game3.pokemon')
 local Collision=require('src.core.game3.collision')
 local Dex=require('src.core.game3.dex')
 local cache,nextId={},Actors.base+10000
 local pmd=assert((loadstring or load)(assert(mod:read('assets/pmdcollab/sprite_table.lua'))))()
 local P={}
 local function imageAt(path)
  local bytes=mod:read(path);if not bytes then return end
  local ok,img=pcall(function()return love.graphics.newImage(love.filesystem.newFileData(bytes,path))end)
  if ok then img:setFilter('nearest','nearest');return img end
 end
 local function register(key,image,w,h,rows,anchorX,anchorY)
  if not image then return end
  local iw,ih=image:getDimensions()
  local outW,outH=w,h
  if anchorY then outH=math.max(h,math.ceil(h+16-anchorY));outW=math.max(w,math.ceil(2*math.max(anchorX,w-anchorX)))end
  local c=love.graphics.newCanvas(outW,outH*9)
  love.graphics.push('all');love.graphics.setCanvas(c);love.graphics.clear(0,0,0,0);love.graphics.setColor(1,1,1,1)
  for i,row in ipairs(rows)do
   love.graphics.setScissor(0,(i-1)*outH,outW,outH)
   love.graphics.draw(image,love.graphics.newQuad(0,row*h,w,h,iw,ih),anchorX and outW/2-anchorX or 0,(i-1)*outH+(anchorY and outH-anchorY or 0))
  end
  love.graphics.pop();c:setFilter('nearest','nearest');nextId=nextId+1;Actors.sprite(nextId,c,outW,outH,9,anchorY and 0 or nil);cache[key]=nextId;return nextId
 end
 function P.sprite(species,terrain,shiny)
  species=tonumber(species);if not species then return end
  local style=mod.options:get('sprite_style')or'pokemmo'
  local variant=shiny and 'shiny'or'normal'
  local water=terrain=='water' and mod.options:get('water_spawns')=='swimming_sprites'
  local key=species..':'..style..':'..variant..':'..tostring(water)
  if cache[key]then return cache[key]end
  local nat=Pokemon.national and Pokemon.national(species)or species
  if water then
   for _,kind in ipairs({'swimming','levitates'})do
    local img=imageAt(('assets/generated/water_runtime/%s/%03d-%s.png'):format(kind,nat,variant))
    if img then return register(key,img,16,16,{0,1,2,3,3,4,4,5,5})end
   end
  end
  if style=='pokedex' then cache[key]=Actors.front(species);return cache[key]end
  if style=='pmdcollab' then
   local meta=pmd[nat]and(pmd[nat][variant]or pmd[nat].normal)
   if meta then
    local img=imageAt(meta.rel)
    if img then
     local b,n=meta.walkCycleBase,meta.walkFrameCount
     local gid=register(key,img,meta.frameWidth,meta.frameHeight,{b,b+n,b+2*n,b+1,b+math.floor(n/2),b+n+1,b+n+math.floor(n/2),b+2*n+1,b+2*n+math.floor(n/2)},meta.anchorX,meta.anchorY)
     return gid
    end
   end
  end
  if style=='pokemmo' or style=='pmdcollab' then
   local img=imageAt(('assets/hgss/%d-%s-9.png'):format(nat,variant))or imageAt(('assets/hgss/%d-normal-9.png'):format(nat))
   if img then return register(key,img,32,32,{0,1,2,3,4,5,6,7,8})end
  end
  local img=imageAt(('assets/enhanced_overworld/poke_followers/follower_%03d_%s.png'):format(nat,variant))or imageAt(('assets/enhanced_overworld/poke_followers/follower_%03d_normal.png'):format(nat))
  if img then return register(key,img,16,16,{0,1,2,3,3,4,4,5,5})end
  cache[key]=Actors.front(species);return cache[key]
 end
 local shader
 function P.apply(row,game)
  local gid=P.sprite(row.species,row.terrain,row.shiny);if not gid then return end
  local waterMode=mod.options:get('water_spawns')
  local hidden=row.behavior=='hidden' or row.terrain=='water' and waterMode=='hidden_silhouettes'
  local mask=mod.options:get('wild_silhouettes')
  local silhouette=not row.ambient and (mask=='all' or mask=='undiscovered'and not Dex.isCaught(game.session and game.session.dex,row.species))
  silhouette=silhouette or row.terrain=='water'and waterMode=='silhouettes'
  local alpha=not row.ambient and mod.options:get('sprite_fade')=='faded' and .55 or 1
  local cut=mod.options:get('pokemon_grass_render_mode')=='immersed' and Collision.isGrass and Collision.isGrass(row.cellX,row.cellY)and 5 or 0
  local key=gid..':'..tostring(hidden)..':'..tostring(silhouette)..':'..alpha..':'..cut
  if not cache[key]then
   local spr=Actors.sprites[gid];local w,h=spr.width,spr.height
   local c=love.graphics.newCanvas(w,h*9)
   love.graphics.push('all');love.graphics.setCanvas(c);love.graphics.clear(0,0,0,0)
   if hidden then
    love.graphics.setColor(.12,.18,.22,.7)
    for i=0,8 do love.graphics.ellipse('fill',w/2,i*h+h-4,6,2.5)end
   else
    if silhouette then
     shader=shader or love.graphics.newShader('vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) { return vec4(color.rgb, Texel(tex, tc).a * color.a); }')
     love.graphics.setShader(shader);love.graphics.setColor(.12,.18,.22,alpha)
    else love.graphics.setColor(1,1,1,alpha)end
    for i=0,8 do
     love.graphics.setScissor(0,i*h,w,h-cut)
     love.graphics.draw(spr.image,spr.quads[i],0,i*h)
    end
   end
   love.graphics.pop();c:setFilter('nearest','nearest');nextId=nextId+1;Actors.sprite(nextId,c,w,h,9,hidden and 0 or spr.groundPadding,not hidden and spr.groundPaddingByFrame or nil);cache[key]=nextId
  end
  row.graphicsId=cache[key]
 end
 return P
end
