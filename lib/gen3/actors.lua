-- Per-mod native FireRed actors. Presentation reads a snapshot; it never ticks
-- movement. Objects.forDraw is shared by the native and Battle Art renderers.
return function(mod, base)
 local Objects=require('src.core.game3.objects')
 local Sprites=require('src.core.game3.ow_sprites')
 local Map=require('src.core.game3.map')
 local A={rows={},sprites={},base=base}
 local previous=Objects.forDraw
 Objects.forDraw=function(...)
  local rows=previous(...)
  for _,row in pairs(A.rows)do if row.map==Map.current and row.visible~=false then rows[#rows+1]=row end end
  return rows
 end
 local get=Sprites.getDraw
 Sprites.getDraw=function(id) return A.sprites[id] or get(id) end
 function A.sprite(id,image,w,h,frames,groundPadding,groundPaddingByFrame)
  local iw,ih=image:getDimensions();local q={}
  for i=0,(frames or 1)-1 do q[i]=love.graphics.newQuad(0,i*h,w,h,iw,ih)end
  local spr={image=image,quads=q,width=w,height=h,frameCount=frames or 1,inanimate=(frames or 1)==1}
  -- Optional renderers ground visible feet per frame. Masks retain the original
  -- frame anchors; explicit hops/flight are provided by actor movement.
  if groundPadding==nil and image.newImageData then
   local ok,data=pcall(image.newImageData,image)
   if ok and data and data.getPixel then
    local padding=h
    groundPaddingByFrame={}
    for frame=0,(frames or 1)-1 do
     for y=h-1,0,-1 do
      local opaque=false
      for x=0,w-1 do local _,_,_,a=data:getPixel(x,frame*h+y);if a>=.5 then opaque=true;break end end
      if opaque then groundPaddingByFrame[frame]=h-1-y;padding=math.min(padding,h-1-y);break end
     end
    end
    groundPadding=padding<h and padding or 0
    if data.release then data:release()end
   end
  end
  spr.groundPadding=groundPadding
  spr.groundPaddingByFrame=groundPaddingByFrame
  A.sprites[id]=spr;return spr
 end
 function A.add(id,map,x,y,graphics)
  local row={id=id,localId=base+id,map=map,cellX=x,cellY=y,px=x*16,py=y*16,
   graphicsId=graphics,animClock=0,stepFrames=16,stepFlip=false,moving=false,facing='down',visible=true,passable=true,def={elevation=0}}
  A.rows[id]=row;return row
 end
 function A.clear() A.rows={}end
 function A.front(species)
  local id=base+species
  if A.sprites[id]then return id end
  local pic=require('src.core.game3.pokemon').frontPic(species)
  if not pic then return nil end
  local canvas=love.graphics.newCanvas(24,24)
  love.graphics.push('all');love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0)
  love.graphics.setColor(1,1,1,1);love.graphics.draw(pic.image,0,0,0,24/pic.w,24/pic.h)
  love.graphics.pop();canvas:setFilter('nearest','nearest');A.sprite(id,canvas,24,24,1)
  return id
 end
 function A.dispose()
  A.clear();A.sprites={}
  -- Do not remove another mod's wrapper if it loaded later.
 end
 return A
end
