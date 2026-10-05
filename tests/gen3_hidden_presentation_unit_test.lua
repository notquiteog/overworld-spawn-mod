-- Hidden grass/cave encounters must not reuse the underwater shadow marker.
local options={sprite_style='pokedex',water_spawns='silhouettes',wild_silhouettes='off',pokemon_grass_render_mode='above'}
package.preload['src.core.game3.pokemon']=function()return{national=function(s)return s end}end
package.preload['src.core.game3.collision']=function()return{isGrass=function()return true end}end
package.preload['src.core.game3.dex']=function()return{isCaught=function()return true end}end
local current,stack=nil,{}
love={graphics={}}
local g=love.graphics
function g.push()stack[#stack+1]={current}end
function g.pop()current=table.remove(stack)[1]end
function g.setCanvas(c)current=c end
for _,k in ipairs{'clear','setColor','setShader','setScissor'}do g[k]=function()end end
function g.newCanvas(w,h)return{ellipses=0,draws=0,setFilter=function()end}end
function g.ellipse()current.ellipses=current.ellipses+1 end
function g.draw()current.draws=current.draws+1 end
function g.newShader()return{}end
local A={base=810000,sprites={[1]={width=16,height=16,image={},quads={},groundPadding=0}}}
function A.front()return 1 end
function A.sprite(id,image,w,h)A.sprites[id]={image=image,width=w,height=h}end
local mod={options={get=function(_,key)return options[key]end},read=function(_,path)assert(path=='assets/pmdcollab/sprite_table.lua');return'return {}'end}
local P=assert(loadfile('lib/gen3/presentation.lua'))()(mod,A)
local function apply(terrain,behavior)
 local row={species=19,terrain=terrain,behavior=behavior,cellX=1,cellY=1}
 P.apply(row,{session={dex={}}});return row,A.sprites[row.graphicsId].image
end
local land,l=apply('land','hidden')
assert(l.ellipses==0 and l.draws==0,'hidden land must be transparent')
local water,w=apply('water','hidden')
assert(w.ellipses==9 and w.draws==0,'underwater marker retained across every frame')
assert(land.graphicsId~=water.graphicsId,'land and water masks must never share cache entries')
local cave,c=apply('cave','hidden');assert(c.ellipses==0 and c.draws==0,'no underwater marker in caves')
local visible,v=apply('land','idle');assert(v.draws==9 and v.ellipses==0,'visible land art retained')
local again,a=apply('land','hidden');assert(again.graphicsId==land.graphicsId and a.ellipses==0,'water variant cannot contaminate cached grass')
assert(land.behavior=='hidden'and land.terrain=='land','presentation leaves encounter behavior unchanged')
print('PASS Gen3 hidden encounter presentation')
