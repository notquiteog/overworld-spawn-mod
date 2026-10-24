-- Optional sheets may be absent in standalone/mobile archives. Exercise the
-- real presentation baker with the same single-frame shape as Actors.front.
local count=0
local function eq(a,b,label)assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));count=count+1 end
local function image(w,h)return{getDimensions=function()return w,h end,setFilter=function()end}end
local draws,depth={},0
_G.love={graphics={}}
for _,key in ipairs{'setCanvas','clear','setColor','setScissor','setShader','ellipse'}do love.graphics[key]=function()end end
love.graphics.push=function()depth=depth+1 end
love.graphics.pop=function()depth=depth-1 end
love.graphics.newCanvas=image
love.graphics.newShader=function()return{}end
love.graphics.draw=function(_,quad,x,y)assert(quad,'presentation drew a missing frame');draws[#draws+1]={quad=quad,y=y}end
package.loaded['src.core.game3.pokemon']={national=function(s)return s end}
package.loaded['src.core.game3.collision']={isGrass=function()return true end}
package.loaded['src.core.game3.dex']={isCaught=function()return false end}
local options={sprite_style='pokemmo',water_spawns='swimming_sprites'}
local missing=0
local mod={read=function()return'return {}'end,options={get=function(_,k)return options[k]end},assets={image=function()missing=missing+1;error('optional sheet absent')end}}
local Actors={base=810000,sprites={}}
function Actors.sprite(id,canvas,w,h,n,padding,byFrame)
 local q={};for i=0,n-1 do q[i]={frame=i}end
 Actors.sprites[id]={image=canvas,width=w,height=h,quads=q,groundPadding=padding,groundPaddingByFrame=byFrame}
end
function Actors.front(species)
 local id=Actors.base+species
 if not Actors.sprites[id]then Actors.sprite(id,image(24,24),24,24,1,3,{[0]=3})end
 return id
end
local P=assert(loadfile('lib/gen3/presentation.lua'))()(mod,Actors)
local row={species=16,terrain='land',behavior='idle',cellX=1,cellY=1}
eq(P.sprite(16,'land',false),Actors.base+16,'missing optional sheets use native front')
P.apply(row,{session={dex={}}})
eq(missing>0,true,'optional asset absence exercised')
eq(#draws,9,'static native picture baked into all animation poses')
local first=Actors.sprites[Actors.base+16].quads[0]
for i,d in ipairs(draws)do eq(d.quad,first,'static fallback frame '..i);eq(d.y,(i-1)*24,'static pose position '..i)end
eq(depth,0,'graphics stack restored')
eq(Actors.sprites[row.graphicsId].groundPadding,3,'native front ground anchor preserved')
options.sprite_style='pokedex';draws={};local row2={species=19,terrain='land',behavior='wander'}
P.apply(row2,{session={dex={}}});eq(#draws,9,'explicit Pokedex style supports nine presentation poses')
-- Genuine animation sheets must retain their distinct directional frames.
local real=Actors.base+25;Actors.sprite(real,image(16,144),16,16,9,0)
local original=P.sprite;P.sprite=function()return real end;draws={}
P.apply({species=25,terrain='land',behavior='wander'},{session={dex={}}})
for i,d in ipairs(draws)do eq(d.quad,Actors.sprites[real].quads[i-1],'animated frame retained '..i)end
P.sprite=original
options.sprite_fade='faded';options.wild_silhouettes='all';options.pokemon_grass_render_mode='immersed';draws={}
P.apply({species=19,terrain='land',behavior='idle',cellX=1,cellY=1},{session={dex={}}})
eq(#draws,9,'fallback also supports silhouette fade and grass clipping')
eq(depth,0,'variant graphics stack restored')
print('PASS Gen3 presentation optional-sheet fallback ('..count..' assertions)')
