package.loaded['src.core.game3.objects']={forDraw=function()return {}end}
package.loaded['src.core.game3.ow_sprites']={getDraw=function()end}
package.loaded['src.core.game3.map']={}
love={graphics={newQuad=function()return {}end}}
local A=dofile('lib/gen3/actors.lua')({},100)
local image={getDimensions=function()return 32,64 end,newImageData=function()return{getPixel=function(_,x,y)return 0,0,0,(x==10 and y%32<28)and 1 or 0 end,release=function()end}end}
local s=A.sprite(1,image,32,32,2)
assert(s.drawOffY==4 and s.groundPadding==4 and s.groundPaddingByFrame[0]==4,'native and voxel follower feet differ')
local water=A.sprite(2,image,32,32,2,0)
assert(water.drawOffY==0 and water.groundPadding==0,'authored immersion lost')
print('PASS Gen3 native/voxel shared feet and authored water baseline')
