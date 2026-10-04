-- Actual Gen3 catch input/commit path, no live save or renderer dependency.
local n=0
local function eq(a,b,label)assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));n=n+1 end
local pressed,options,hooks={},{overworld_catching=true,catch_throw_key='v',catch_cycle_key='e',catch_throw_combo='b_a',catch_cycle_combo='b_dpad'},{}
local Player={cellX=1,cellY=1,px=16,py=16,facing='right'}
local target={id=1,cellX=2,cellY=1,px=32,py=16,species=19,level=4,terrain='land'}
local S={map='FR_ROUTE_1',spawns={[1]=target},remove=function()end}
local game={phase='field',session={bag={},party={}},input={isDown=function(_,k)return pressed[k]or false end,wasPressed=function()return false end}}
local blocked,battling,menuOpen=false,false,false
local function img(w,h)return{getDimensions=function()return w,h end,setFilter=function()end}end
love={keyboard={isDown=function(k)return pressed[k]or false end},math={random=math.random},graphics={newCanvas=img}}
for _,k in ipairs({'push','pop','setCanvas','clear','setColor','draw','circle','rectangle'})do love.graphics[k]=function()end end
local modules={
 ['src.core.game3.player']=Player,['src.core.game3.map']={current=S.map},
 ['src.core.game3.objects']={blocks=function()return false end},
 ['src.core.game3.collision']={isWalkable=function()return true end,isWater=function()return false end,warpAt=function()return false end},
 ['src.core.game3.pokemon']={types=function()return{1}end,name=function()return'RATTATA'end},
 ['src.core.game3.bag']={get=function(b,id)return b[id]or 0 end,remove=function(b,id)if(b[id]or 0)<1 then return false end;b[id]=b[id]-1;return true end},
 ['src.core.game3.party']={giveMon=function()return true,1,{}end},
 ['src.core.game3.battle.catching']={tryCatch=function()return false,0 end},
 ['src.core.game3.battle']={isActive=function()return battling end},
 ['src.core.game3.runtime']={uiBusy=function()return menuOpen end},
 ['src.core.game3.storage']={ensure=function()return{}end,findOpenSlot=function()return true end},
 ['src.core.game3.safari']={isActive=function()return false end},
 ['src.ui.game3.bag_chrome']={iconImage=function(id)return img(24,24)end},
}
for k,v in pairs(modules)do package.loaded[k]=v end
local mod={exports={},world={game=game},options={get=function(_,k)return options[k]end},hooks={wrap=function(_,k,fn)hooks[k]=fn end},read=function(_,p)local f=assert(io.open(p));local s=f:read('*a');f:close();return s end}
local A={base=1000,sprites={},rows={}}
function A.sprite(id,image,w,h)A.sprites[id]={image=image,w=w,h=h}end
function A.add(id,map,x,y,gid)local a={map=map,graphicsId=gid};A.rows[id]=a;return a end
local C=assert(loadfile('lib/gen3/catching.lua'))()(mod,S,A,function()return blocked end)
local function tick()C.update(game,1/60)end
local function reset(ball)
 pressed={};C.projectile=nil;target.catching=nil;C.cooldown=0;C.resetInput();game.phase='field';blocked=false
 game.session.bag={[ball]=3};C.ball=ball
end
for _,ball in ipairs({1,2,3,4,6,7,8,9,10,11,12})do
 reset(ball);pressed.throw_ball=true;tick();eq(game.session.bag[ball],3,'charge consumes nothing')
 pressed.throw_ball=false;tick();eq(game.session.bag[ball],2,'selected ball consumed once')
 eq(C.projectile.ball,ball,'projectile matches selected ball');eq(C.projectile.actor.graphicsId,51000+ball,'distinct selected art')
end
reset(3);pressed.v=true;tick();pressed.v=false;tick();eq(game.session.bag[3],2,'rebound keyboard throws')
reset(2);hooks['input.key'](function()end,game,{key='v',phase='pressed'});hooks['input.key'](function()end,game,{key='v',phase='released'});tick();tick();eq(game.session.bag[2],2,'sub-frame keyboard tap preserved')
reset(3);pressed.b=true;pressed.a=true;tick();pressed.a=false;tick();eq(game.session.bag[3],2,'combo action release throws')
reset(3);pressed.b=true;pressed.a=true;tick();pressed.b=false;pressed.a=false;tick();eq(game.session.bag[3],3,'modifier release cancels')
reset(3);pressed.v=true;tick();game.phase='menu';tick();game.phase='field';pressed.v=false;tick();eq(game.session.bag[3],3,'menu cancels charge')
reset(3);pressed.v=true;tick();options.catch_throw_key='g';pressed.v=false;tick();eq(game.session.bag[3],3,'rebind cancels charge')
reset(4);game.session.bag[3]=2;pressed.ow_catch_cycle=true;tick();eq(C.ball,3,'logical cycle chooses available ball');pressed.ow_catch_cycle=false;pressed.ow_catch_throw=true;tick();pressed.ow_catch_throw=false;tick();eq(C.projectile.ball,3,'alternate alias uses cycled ball');eq(game.session.bag[4],3,'unselected inventory untouched')
reset(4);game.session.bag[3]=2;Player.moving=true;pressed.b=true;pressed.right=true;tick();eq(C.ball,4,'running does not cycle');eq(game.input:isDown('right'),true,'running does not suppress steering');Player.moving=false
reset(3);local requests=0;S.shared={catching=true,request=function(_,_,req)requests=requests+1;eq(req.ballId,3,'host request carries selection');return true end}
pressed.throw_ball=true;tick();pressed.throw_ball=false;tick();eq(requests,1,'one host reservation');eq(game.session.bag[3],3,'no ball consumed before host grant')
reset(2);S.shared=nil;S.spawns={};pressed.throw_ball=true;tick();pressed.throw_ball=false;tick();eq(game.session.bag[2],2,'empty-field throw uses selected ball');eq(C.projectile.resolved,true,'miss cannot capture or despawn');eq(C.projectile.row.px,48,'tap miss lands two cells ahead')
local painted=0
for _,k in ipairs({'translate','scale','print'})do love.graphics[k]=function()painted=painted+1 end end
options.catch_hud_size=5
battling=true;hooks['render.hud'](function()end,game,{});eq(painted,0,'no field selector over native battle with field phase')
battling=false;menuOpen=true;hooks['render.hud'](function()end,game,{});eq(painted,0,'no selector over native trade/menu')
menuOpen=false;hooks['render.hud'](function()end,game,{});eq(painted>0,true,'selector returns to the playable field')
print('PASS native catch bindings ('..n..' assertions)')
