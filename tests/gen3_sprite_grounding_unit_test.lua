local count=0
local function eq(a,b,label)assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));count=count+1 end
package.loaded['src.core.game3.objects']={forDraw=function()return{}end}
package.loaded['src.core.game3.ow_sprites']={getDraw=function()end}
package.loaded['src.core.game3.map']={current='FR_ROUTE_1'}
love={graphics={newQuad=function()return{}end}}
local released,reads=0,0
local function sheet(feet)
 return {getDimensions=function()return 2,#feet*4 end,newImageData=function()
  reads=reads+1
  return {getPixel=function(_,x,y)local frame=math.floor(y/4)+1;return 1,1,1,y%4==feet[frame]and 1 or 0 end,
   release=function()released=released+1 end}
 end}
end
local A=assert(loadfile('lib/gen3/actors.lua'))()({},810000)
local first=A.sprite(1,sheet({1,2,1}),2,4,3)
eq(first.groundPadding,1,'all-frame baseline uses lowest opaque footprint')
eq(released,1,'temporary CPU readback released')
eq(reads,1,'one CPU readback per newly registered sheet')
-- Cropped grass art has higher visible feet but retains its unmasked baseline.
local masked=A.sprite(2,sheet({0,0,0}),2,4,3,first.groundPadding)
eq(masked.groundPadding,1,'masked art retains original ground plane')
eq(reads,1,'inherited baseline avoids another GPU readback')
eq(A.sprite(3,sheet({1,1,1}),2,4,3,0).groundPadding,0,'authored PMD/marker anchor accepts explicit zero')
eq(A.sprite(4,sheet({-1,-1,-1}),2,4,3).groundPadding,0,'empty sheet has safe zero padding')
print('PASS native sprite grounding '..count..' assertions')
