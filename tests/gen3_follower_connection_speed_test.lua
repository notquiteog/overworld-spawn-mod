-- Public map events must preserve actor identity and the walked path.
local P={cellX=4,cellY=0,px=64,py=0,stepFrames=8,moving=true}
local Map={current='OLD'};local events={};local def={width=5,height=5,connections={north={map='NEW',offset=2}}}
Map.currentDef=function()return def end
local modules={['src.core.game3.player']=P,['src.core.game3.map']=Map,
 ['src.core.game3.collision']={isWalkable=function()return true end,isWater=function()return false end,warpAt=function()end},
 ['src.core.game3.objects']={blocks=function()return false end},['src.core.game3.ow_sprites']={playerGraphicsId=function()return 1 end},
 ['src.core.game3.pokemon']={isEgg=function()return false end},['src.core.game3.summary_data']={isShiny=function()return false end},
 ['src.ui.game3.party_menu']={handleInput=function()end},
 ['src.core.game3.connections']={each=function(d)return{{dir='north',map='NEW',offset=2}}end,sizeOf=function(d)return d.width*2,d.height*2 end}}
for k,v in pairs(modules)do package.loaded[k]=v end
local Actors={rows={}};Actors.add=function(id,map,x,y,gid)local r={map=map,cellX=x,cellY=y,px=x*16,py=y*16};Actors.rows[id]=r;return r end
local mon={species=1,hp=20};local game={session={party={mon}}}
local mod={world={game=game},options={get=function(_,k)if k=='follower_count'then return 1 end end},events={on=function(_,k,fn)events[k]=fn end}}
local F=assert(loadfile('lib/gen3/followers.lua'))()(mod,Actors,{sprite=function()return 2 end},function()return false end)
F.trail={{x=4,y=2,seq=1}};F.sequence=1;F.update(game,1/60)
local row=assert(F.rows[-1]);row.trailSeq=1
F.trail={{x=4,y=2,seq=1},{x=4,y=1,seq=2},{x=4,y=0,seq=3}};F.sequence=3
row.py=48;local before=row.py;F.update(game,1/60)
assert(before-row.py==2,'running cadence must move two pixels per frame')
events['map.exited']();events['map.entered']{via='connection',mapId='NEW',map={width=5,height=6}}
Map.current='NEW';Actors.rows={};local oldx,oldy=row.px,row.py;F.mapChanged(game)
assert(F.rows[-1]==row and Actors.rows[-1]==row,'seam replaced follower identity')
assert(row.px==oldx-32 and row.py==oldy+192,'incorrect offset seam translation')
assert(F.trail[1].x==2 and F.trail[1].y==14,'history not rebased')
P.cellX,P.cellY=2,11;P.px,P.py=32,176;P.moving=false;P.stepFrames=16
F.last={x=2,y=11};F.trail={{x=2,y=14,seq=1},{x=2,y=13,seq=2},{x=2,y=12,seq=3}}
row.px,row.py=32,240;row.trailSeq=1
for i=1,80 do local x,y=row.px,row.py;F.update(game,1/60);assert(math.abs(row.px-x)+math.abs(row.py-y)<=2.001,'catch-up teleported')end
assert(row.py==192,'stopped player prevented catch-up')
events['map.exited']();events['map.entered']{via='warp',mapId='ROOM',map={width=5,height=5}}
F.mapChanged(game);assert(next(F.rows)==nil and #F.trail==0,'warp retained old world trail')
print('PASS Gen3 connected identity, offset history, native run speed, idle catch-up and warp reset')
