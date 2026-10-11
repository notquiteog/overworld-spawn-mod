local P={cellX=2,cellY=2};local native={};local Sprites={playerGraphicsId=function()return native end}
local Menu={handleInput=function()end};local mon={species=1,hp=20};local options={follow_control='pokemon',follower_count=1}
local modules={['src.core.game3.player']=P,['src.core.game3.map']={current='QA'},
 ['src.core.game3.collision']={isWalkable=function()return true end,isWater=function()return false end,warpAt=function()end},
 ['src.core.game3.objects']={blocks=function()return false end},['src.core.game3.ow_sprites']=Sprites,
 ['src.core.game3.pokemon']={isEgg=function()return false end},['src.core.game3.summary_data']={isShiny=function()return false end},
 ['src.ui.game3.party_menu']=Menu}
for k,v in pairs(modules)do package.loaded[k]=v end
local actors={rows={}};actors.add=function(id,_,x,y,gid)local r={px=x*16,py=y*16,graphicsId=gid};actors.rows[id]=r;return r end
local game={session={party={mon}}};local mod={options={get=function(_,k)return options[k]end},world={game=game}}
local F=assert(loadfile('lib/gen3/followers.lua'))()(mod,actors,{sprite=function()return 99 end},function()return false end)
assert(F.controlled(game)==mon and Sprites.playerGraphicsId(game)==99)
options.follow_control='trainer';F.trail={{x=1,y=2}};F.update(game,1/60);assert(actors.rows[-1])
P.underwater=true;options.follow_control='pokemon'
assert(not F.controlled(game) and Sprites.playerGraphicsId(game)==native,'native diver replaced')
F.update(game,1/60);assert(next(F.rows)==nil and next(actors.rows)==nil and #F.trail==0 and F.last==nil)
P.surfing=true;P.underwater=false;assert(not F.controlled(game),'native Surf replaced')
P.surfing=false;assert(F.controlled(game)==mon,'land control failed to resume')
print('PASS native Dive sprite, hidden followers, discarded underwater trail and land resumption')
