local F=dofile('lib/sprite_footing.lua')
local scans=0
local data={getDimensions=function()return 32,192 end,getPixel=function(_,x,y)
 local row=y%32;return .2,.2,.2,(x==15 and row<28 and row>10)and 1 or 0
end}
package.loaded['src.render.Assets']={imageData=function()scans=scans+1;return data end}
local def={image='sheet',frameWidth=32,frameHeight=32,frames=6,trueColor=true}
local fixed=F.apply(def);assert(fixed.anchorY==28 and def.anchorY==nil,'ground padding not measured without mutating provider')
assert(F.apply(def).anchorY==28 and scans==1,'measurement not cached')
fixed.anchorY=24;assert(F.apply(fixed)==fixed,'authored/swimming anchor changed')
local empty={getDimensions=data.getDimensions,getPixel=function()return 0,0,0,0 end}
assert(F.measure(empty,32,32,6,true)==nil,'empty frame anchored')
local gray={getDimensions=function()return 16,16 end,getPixel=function(_,x,y)return y>=12 and 1 or .2,0,0,1 end}
assert(F.measure(gray,16,16,1,false)==12,'OBJ transparent color counted as foot')
print('PASS sprite foot baseline, authored anchors, blank frames, OBJ transparency and cache')
