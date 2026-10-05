-- Source-driver fixture only: use an isolated *-qa profile and imported FireRed.
return function(game)
 assert(love.filesystem.getSaveDirectory():match('%-qa$'),'isolated QA profile required')
 local U=dofile('tests/drivers/util.lua');local dir=os.getenv('SHOT_DIR')
 local update=game.update;game.update=function(self,dt)self.input:reset();return require('src.mods.Runtime').call('core.update',update,self,dt)end
 game:_handleBootAction({action='new_game',start={map='FR_PALLET_TOWN',x=7,y=8,facing='down'}})
 local V=game.mods.exports.BATTLE_ART_VOXEL_FORK.lib;local C=V.require('Gen3Integration')
 local Map=require('src.core.game3.map');local Player=require('src.core.game3.player')
 assert(Map.load(nil,game,'FR_ROUTE_1',{x=14,y=16,facing='up'}));U.wait(20)
 local space=require('src.core.game3.scripting.space');space.runOnFrame=function()end;local vm=space.getVm();if vm then vm:halt(true)end;require('src.ui.game3.message').reset()
 local ex
 for _,e in pairs(game.mods.exports)do if e.gen3Actors then ex=e end end
 assert(ex,'wilds missing');local S=ex.gen3;local A=ex.gen3Actors;local d=Map.currentDef();local Collision=require('src.core.game3.collision')
 local cells={}
 for y=3,d.height-3 do for x=3,d.width-3 do if Collision.isGrass(x,y)and Collision.isGrass(x+1,y)and Collision.isGrass(x,y+1)then cells[#cells+1]={x=x,y=y}end end end
 local c=assert(cells[math.floor(#cells/2)],'grass fixture missing');Player.reset(c.x,c.y+2,'up');Player.setVisible(true);U.wait(10)
 ex.sharedSpawns.configure({role='guest',session='grass-repro',request=function()end})
 U.wait(3)
 ex.sharedSpawns.apply(Map.current,{{id='test-hidden',species=19,level=3,x=c.x,y=c.y,terrain='land',behavior='hidden'},{id='test-visible',species=16,level=3,x=c.x+1,y=c.y,terrain='land',behavior='idle'}})
 V.require('DayNight').setting:setIndex(1,game);C.setLevel(3,game);U.wait(40)
 print('[fixture]',c.x,c.y,Player.cellX,Player.cellY)
 for _,r in pairs(S.spawns)do print('[actor]',r.behavior,r.graphicsId,r.visible);local spr=A.sprites[r.graphicsId];local data=spr.image:newImageData();local n=0;for y=0,spr.height-1 do for x=0,spr.width-1 do local rr,g,b,a=data:getPixel(x,y);if a>.05 then n=n+1 end end end;print('[opaque]',r.behavior,n);local f=assert(io.open(dir..'/'..r.behavior..'-sheet.png','wb'));f:write(data:encode('png'):getString());f:close()end
 U.shot(game,dir..'/overview.png')
 local input=game.input;local oldDown=input.isDown;local held='right'
 input.isDown=function(self,key)if key==held then return true end;return false end
 U.wait(20);held=nil;U.wait(8);input.isDown=oldDown
 print('[walked]',Player.cellX,Player.cellY);assert(Player.cellX~=c.x,'walking did not advance player')
 U.shot(game,dir..'/walked.png')
 C.setLevel(0,game);U.wait(5);U.shot(game,dir..'/native.png')
 C.setLevel(6,game);C.yaw=0;C.pitch=0;U.wait(10);U.shot(game,dir..'/first.png')
 ex.sharedSpawns.configure(nil);love.event.quit()
end
