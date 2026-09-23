-- Execute from the repository root with LuaJIT. No live save or profile access.
local checkCount=0
local function eq(actual,expected,label)
 assert(actual==expected,(label or'check')..': got '..tostring(actual)..', expected '..tostring(expected));checkCount=checkCount+1
end
local function read(path)local f=io.open(path,'rb');if not f then return end;local s=f:read('*a');f:close();return s end
local options,hooks={},{}
local Player={cellX=15,cellY=15,px=240,py=240,facing='right'}
local Map={current='FR_ROUTE_1',currentDef=function()return{width=40,height=40}end}
local Objects={forDraw=function()return{}end,blocks=function()return false end}
local Sprites={getDraw=function()end,playerGraphicsId=function()return 1 end}
local game={phase='field',options={modOptions={}},mods={modOptions={}},session={party={{species=1,hp=20},{species=2,hp=20},{species=3,hp=20}},bag={[4]=10},dex={}}}
game.input={isDown=function()return false end,wasPressed=function()return false end}
local battle,talk,catches=0,0,0
local function fakeImage(w,h)return{getDimensions=function()return w,h end,setFilter=function()end}end
local function dimension(bytes,offset)local n=0;for i=offset,offset+3 do n=n*256+bytes:byte(i)end;return n end
_G.love={math={random=math.random},keyboard={isDown=function()return false end},filesystem={newFileData=function(bytes,path)return{bytes=bytes,path=path}end},graphics={}}
for _,key in ipairs({'push','pop','setCanvas','clear','setColor','draw','ellipse','setScissor','setShader','circle','rectangle','print','translate','scale'})do love.graphics[key]=function()end end
love.graphics.newQuad=function(x,y,w,h,iw,ih)assert(x>=0 and y>=0 and w>0 and h>0 and x+w<=iw and y+h<=ih,'quad exceeds sheet');return{}end
love.graphics.newShader=function()return{}end
love.graphics.newImage=function(data)return fakeImage(dimension(data.bytes,17),dimension(data.bytes,21))end
love.graphics.newCanvas=fakeImage
local modules={
 ['src.core.game3.summary_data']={isShiny=function(mon)
   local bit=require('bit');if mon.isShiny~=nil then return mon.isShiny end
   return bit.bxor(mon.otId or 0,mon.otSecretId or 0,bit.rshift(mon.personality or 0,16),bit.band(mon.personality or 0,65535))<8
 end},
 ['src.core.GameVersion']={generation=function()return 3 end},
 ['src.ui.game3.party_menu']={handleInput=function()end},
 ['src.ui.game3.option_rows']={build=function()return{}end,group=function(all)return all end},
 ['src.core.game3.player']=Player,['src.core.game3.map']=Map,['src.core.game3.objects']=Objects,['src.core.game3.ow_sprites']=Sprites,
 ['src.core.game3.collision']={isWalkable=function(x,y)return x>=0 and y>=0 and x<30 and y<40 end,isWater=function(x,y)return x>=30 and x<40 and y>=0 and y<40 end,warpAt=function()return false end,isGrass=function(x)return x<30 end,directionallyImpassable=function()return false end},
 ['src.core.game3.encounters']={ensureLoaded=function()end,tableFor=function()return{land={slots={{species=16,level=4}}},water={slots={{species=129,level=5}}}}end,terrainAt=function(x,y)if x<0 or y<0 or x>=40 or y>=40 then return end;return x>=30 and'water'or'land'end},
 ['src.core.game3.pokemon']={national=function(s)return s end,name=function(s)return'MON'..s end,types=function()return{1,2}end,frontPic=function()return{image=fakeImage(64,64),w=64,h=64}end},
 ['src.core.game3.field']={interact=function()return false end},['src.mods.Gen3Compat']={worldBusy=function()return false end},
 ['src.core.game3.dex']={isCaught=function(dex,s)return dex[s]end},
 ['src.core.game3.bag']={get=function(bag,id)return bag and bag[id]or 0 end,remove=function(bag,id,n)if(bag[id]or 0)<n then return false end;bag[id]=bag[id]-n;return true end},
 ['src.core.game3.party']={giveMon=function(session,species,level)local mon={species=species,level=level,hp=20,maxHp=20};session.party[#session.party+1]=mon;return true,1,mon end},
 ['src.core.game3.battle.catching']={tryCatch=function()return true,4 end,storeCaught=function(session,foe)session.party[#session.party+1]=foe.mon;catches=catches+1;return{success=true}end},
 ['src.core.game3.storage']={ensure=function()return{}end,findOpenSlot=function()return 1,1 end},
 ['src.core.game3.safari']={isActive=function()return false end},['src.mods.Runtime']={emit=function()end},
}
for name,value in pairs(modules)do package.loaded[name]=value end
local mod={id='overworld_wild_spawns',world={game=game,startWildBattle=function()battle=battle+1;return true end,queueScript=function()talk=talk+1 end},exports={},log={info=function()end},read=function(_,path)return read(path)end,options={get=function(_,key)return options[key]end,define=function(_,rows)for _,r in ipairs(rows)do if options[r.key]==nil then options[r.key]=r.default end end;return rows end},hooks={wrap=function(_,key,fn)hooks[key]=fn end}}
assert(loadfile('lib/gen3/init.lua'))()(mod)
local S=mod.exports.gen3
local function count()local n=0;for _ in pairs(S.spawns)do n=n+1 end;return n end
local schema=assert(loadfile('options.lua'))()
eq(#mod.exports.optionSchema,#schema,'same schema count')
eq(options.sprite_style,'pokemmo','Gen3 HGSS default')
eq(schema[2].default,'followers','Gen1/2 GSC default preserved')
S.update(.1);eq(count(),6,'normal density')
for density,n in pairs({low=3,high=10,very_high=16})do options.spawn_density=density;S.update(.1);eq(count(),n,density..' density')end
options.enabled=false;S.update(.1);eq(count(),0,'disable removes wilds')
options.random_encounters=false
local rolls=0;local function roll()rolls=rolls+1;return'roll'end
hooks['encounter.roll'](roll,{}, {terrain='land'});eq(rolls,0,'random disabled even when no visible spawns')
options.water_spawns='classic_encounters';eq(hooks['encounter.roll'](roll,{}, {terrain='water'}),'roll','classic water encounter override')
options.water_spawns='disabled';hooks['encounter.roll'](roll,{}, {terrain='water'});eq(rolls,1,'disabled water blocked')
options.enabled=true;options.spawn_density='low';options.water_spawns='swimming_sprites'
for _,behavior in ipairs({'idle','wander','aggressive','hidden'})do
 for _,b in ipairs({'idle','wander','aggressive','hidden'})do options['enable_'..b]=b==behavior end
 S.update(.1);for _,row in pairs(S.spawns)do eq(row.behavior,behavior,'single selected behavior')end
end
for _,row in pairs(S.spawns)do S.remove(row)end
local target=S.spawn(16,4,16,15,'land',{behavior='idle'})
local C=mod.exports.gen3Catching
local before=#game.session.party
eq(C.throw(game,1),true,'direct throw starts');eq(game.session.bag[4],9,'one ball consumed')
for _=1,8 do C.update(game,.1)end
eq(catches,1,'one native capture stored');eq(#game.session.party,before+1,'party storage changed once');eq(S.spawns[target.id],nil,'caught actor removed')
local guest={role='guest',session='test',catching=true,request=function()return true end}
mod.exports.sharedSpawns.configure(guest);S.update(.1)
eq(count(),0,'guest never generates roster')
eq(S.spawn(16,4,16,15),nil,'guest cannot spawn')
mod.exports.sharedSpawns.apply(Map.current,{{id='host:1',species=16,level=4,x=16,y=15,behavior='hidden',terrain='land',scenery=true}})
eq(count(),1,'guest applies host roster')
local row=next(S.spawns)and select(2,next(S.spawns))
eq(row.behavior,'hidden','wire behavior retained');eq(S.encounter(row),false,'scenery cannot battle')
local beforeBall=game.session.bag[4];eq(C.throw(game,1),false,'scenery cannot be thrown at');eq(game.session.bag[4],beforeBall,'invalid shared throw does not consume')
row.scenery=false;row.behavior='idle';eq(C.throw(game,1),true,'shared throw asks host');eq(game.session.bag[4],beforeBall,'request does not consume before grant')
local accepted,result=mod.exports.sharedSpawns.beginCatch({species=16,level=4,terrain='land',personality=4294967295,shiny=true},Map.current,{ballId=4})
eq(accepted,true,'host grant accepts catch');eq(result.caught,true,'grant uses native capture');eq(game.session.bag[4],beforeBall-1,'grant consumes once');eq(S.spawns[row.id],row,'provider leaves authoritative removal to host')
eq(game.session.party[#game.session.party].personality,4294967295,'capture preserves supplied uint32 PID')
eq(game.session.party[#game.session.party].isShiny,true,'capture preserves supplied native shiny override')
eq(mod.exports.sharedSpawns.canCatch({x=15,y=15,facing='right'},{x=16,y=15},{charge=0},Map.current),true,'host verifies local clear ray')
eq(mod.exports.sharedSpawns.canCatch({x=15,y=15,facing='left'},{x=16,y=15},{charge=0},Map.current),false,'host rejects wrong facing')
eq(mod.exports.sharedSpawns.canCatch({x=15,y=15,facing='right'},{x=16,y=15},{charge=0},'UNKNOWN_MAP'),false,'host rejects unavailable remote map')
mod.exports.sharedSpawns.configure(nil);options.follow_control='pokemon';options.trainer_trail=true;options.follower_count=3;S.update(.1)
eq(Sprites.playerGraphicsId(game)~=1,true,'Pokemon control replaces native art')
local leader=mod.exports.gen3Followers.leader(game)
leader.personality=0;leader.otId=0;leader.otSecretId=0;leader.shiny=false
eq(Sprites.playerGraphicsId(game),mod.exports.resolveGen3Sprite(leader.species,nil,true),'follower derives native shiny from PID and OT')
leader.personality=100;leader.shiny=true
eq(Sprites.playerGraphicsId(game),mod.exports.resolveGen3Sprite(leader.species,nil,false),'legacy shiny field cannot override native identity')
options.follow_control='trainer';eq(Sprites.playerGraphicsId(game),1,'trainer art restored')
local F=mod.exports.gen3Followers;F.select(game,game.session.party[2]);eq(F.leader(game),game.session.party[2],'selected follower leader honored')
local moved=table.remove(game.session.party,2);game.session.party[#game.session.party+1]=moved;eq(F.leader(game),moved,'selection survives party reorder')
local R=assert(loadfile('lib/gen3/rules.lua'))();local get=function(k)return options[k]end
options.water_spawns='classic_encounters';eq(R.visibleTerrain(get,'water'),false,'classic hides visible water')
print('PASS Gen3 settings parity ('..checkCount..' assertions)')
