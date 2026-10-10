-- An intentionally invisible spawn body is not a broken sprite provider.
local warns,binds,poses=0,0,0
local modules={debug_log={warn=function()warns=warns+1 end},movement={syncLegacyFields=function()end},config={},
 render_diagnostics={honestDepthActive=function()return false end},
 water_display={needsWaterShadowPresentation=function()return false end},
 water_shadow_renderer={installDrawHook=function()end,MODE={NONE='none'}}}
local V={require=function(n)return assert(modules[n],n)end}
local A=assert(loadfile('lib/voxel_adapter.lua'))(V)
local adapter=A.new({world={}});adapter.present=true;adapter.voxelActive=true
local hidden=true;local sprite={def={},resolveImage=function()end}
local entity={px=0,py=0,cellX=0,cellY=0,sprite=sprite,nativeSpriteRenderer=true,
 render={isBodyVisible=function()return not hidden end,bindWorldBillboard=function(_,e)binds=binds+1;e.pokemonRenderer=A.POKEMON_NATIVE;e.worldBillboardReady=true end},
 pose=function(self)poses=poses+1;return hidden and nil or self.sprite,0,0 end}
for i=1,90 do assert(adapter:updateEntity(entity))end
assert(warns==0 and binds==0 and poses==0,'hidden choreography was probed or logged as failure')
assert(not entity.render2DFallback and not entity.voxelDisabled and entity.pokemonRenderer=='HIDDEN')
hidden=false;assert(adapter:updateEntity(entity));assert(binds==1 and poses==1 and warns==0,'body did not resume native rendering')
entity.pose=function()error('real provider failure')end;assert(not adapter:updateEntity(entity));assert(warns==1 and entity.render2DFallback,'genuine failure was hidden')
print('PASS intentional hidden body, no repeated mesh/probe work, native resume and real-error fallback')
