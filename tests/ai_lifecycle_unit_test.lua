-- Current SDK ownership/input/private-cache regressions, no network traffic.
package.path='./?.lua;./?/init.lua;'..package.path
local opts={ai_dialogues=true,ai_memory=true}
local cacheBytes,storage={},{}
local clock=10
love={timer={getTime=function()return clock end},keyboard={isDown=function()return false end}}
package.loaded['src.core.GameVersion']={get=function()return 'red'end,generation=function()return 1 end}
local modules={};local V={mod={id='overworld_wild_spawns',options={get=function(_,k)return opts[k]end},
 cache={read=function(_,k)return cacheBytes[k]end,write=function(_,k,v)cacheBytes[k]=v;return true end},
 log={info=function()end,warn=function()end}}}
function V.require(n)if modules[n]==nil then modules[n]=assert(loadfile('lib/'..n..'.lua'))(V)end;return modules[n]end
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local Config=V.require('ai/config')
check(Config.saveSecrets({openai_api_key='test-private-key'}),'public private cache write')
Config.resetCache();check(Config.loadSecrets().openai_api_key=='test-private-key','public cache roundtrip')
check(cacheBytes['wilds_ai/provider_secrets.json']~=nil,'fixed scoped cache key')
V.mod.cache.write=function()return false end
check(not Config.saveSecrets({openai_api_key='fail'}),'write failure surfaced, not pcall success')
Config.resetCache();check(Config.loadSecrets().openai_api_key=='test-private-key','failed write retains prior bytes')
local Memory=V.require('ai/memory');local g1,g2={},{}
Memory.append(V.mod,g1,'sameNPC','user','hello')
check(#Memory.getTurns(V.mod,g2,'sameNPC')==0,'RAM memory does not cross games/playthroughs')
for i=1,50 do Memory.append(V.mod,g1,'npc'..i,'user','hello')end
for i=1,12 do Memory.append(V.mod,g1,'sameNPC','user','turn')end
check(#Memory.getTurns(V.mod,g1,'sameNPC')==6,'turn cap')
local Prompt=V.require('ai/prompt')
check(not Prompt.systemPrompt({priorTurns={{role='user',text='PRIVATE_UNTRUSTED'}}}):find('PRIVATE_UNTRUSTED',1,true),'history not promoted into system instructions')
local Input=V.require('ai/input');local done,top
local game={input={wasPressed=function()return false end},stack={push=function(_,s)top=s end,pop=function()top=nil end}}
check(Input.prompt(V.mod,game,{maxLen=4},function(v)done=v end)=='keyboard','desktop prompt selected')
top:onKeyPressed('a');top:onKeyPressed('b');top:onKeyPressed('space');top:onKeyPressed('c');top:onKeyPressed('d')
check(top.text=='ab c','real engine onKeyPressed receives text and enforces limit')
top:onKeyPressed('backspace');top:onKeyPressed('return')
check(done=='ab' and top==nil,'native key dispatch confirms once and pops own state')
local result;Input.prompt(V.mod,game,{},function(v)result=v or 'cancelled'end);top:onKeyPressed('escape')
check(result=='cancelled' and not top,'escape cancels')
local Dialogue=V.require('ai/dialogue');local d=Dialogue.new(V.mod,{})
local map={id='PEWTER_CITY'};local ow={map=map,player={}};game.overworld=ow;ow.game=game
local cancelled,polls,presented=0,0,{}
local provider={poll=function()polls=polls+1;return{status='pending'}end,cancel=function()cancelled=cancelled+1 end}
local function active()d._active={provider=provider,handle={},game=game,ow=ow,map=map,ctx={npcId='npc'},userMessage='hi',started=clock,timeout=28}end
function d:_present(_,_,text)presented[#presented+1]=text end
active();ow.map={id='OTHER'};d:tick();check(not d._active and cancelled==1 and polls==0,'map transition cancels without polling or presenting')
ow.map=map;active();opts.ai_dialogues=false;d:tick();check(not d._active and cancelled==2,'disable cancels outstanding request')
opts.ai_dialogues=true;active();clock=40;d:tick();check(not d._active and cancelled==3,'wall-clock timeout independent of CPU usage')
clock=10;active();provider.poll=function()return{status='success',text='Hello'}end
local oldBusy=V.require('game_compat').followerInteractionBusy;V.require('game_compat').followerInteractionBusy=function()return true end
d:tick();check(d._active and d._active.result and #presented==0,'reply waits until native thinking box is dismissed')
V.require('game_compat').followerInteractionBusy=function()return false end
d:tick();check(not d._active and presented[1]=='Hello','reply presented after native UI releases ownership')
V.require('game_compat').followerInteractionBusy=oldBusy
active();d:uninstall();check(not d._active and cancelled==4,'uninstall releases request')
d._pendingOffer={game=game,ow=ow,npc={},map=map};ow.map={};d:processPendingOffer();check(not d._pendingOffer,'stale offer dropped across map change')
local ai=V.require('ai/init').new(V.mod,{})
opts.ai_dialogues=false;local complete
ai:devProbe({useMock=true,onDone=function(ok)complete=ok end})
for i=1,4 do ai:tick()end
check(complete,'explicit dev probe polls even when production feature is off')
local owned={wildsAiInput=V.mod.id,onKeyPressed=function(_,key)result=key end}
game.stack.top=function()return owned end
check(ai:handleKey(game,{phase='pressed',key='t'}) and result=='t','public key hook routes only owned screen')
owned.wildsAiInput='another_mod';check(not ai:handleKey(game,{phase='pressed',key='x'}),'other screens retain native input ownership')
game.overworld=nil;check(not d:sameScene(game,ow,map),'title/quit without live world does not pass scene guard')
opts.ai_dialogues=nil;opts.ai_memory=nil
check(not Config.enabled(V.mod) and not Config.memoryEnabled(V.mod),'missing AI master/memory defaults off')
opts.ai_dialogues='true';opts.ai_memory='true'
check(not Config.enabled(V.mod) and not Config.memoryEnabled(V.mod),'invalid string AI preferences remain off')
check(not ai:devProbe({useMock=false}),'real exported probe cannot bypass disabled master')
local schema=assert(loadfile('options.lua'))()
for _,row in ipairs(schema)do if row.key=='ai_dialogues' or row.key=='ai_memory' then check(row.default==false,'schema '..row.key..' defaults off')end end
print('ai_lifecycle_unit_test: PASS '..checks..' checks')
