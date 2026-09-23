-- All generations publish the same keys. Only the Gen3 overworld art default
-- changes; battle art is never selected or modified here.
return function(mod)
 local schema=assert((loadstring or load)(assert(mod:read('options.lua')),'@wilds/options'))()
 for _,row in ipairs(schema)do
  if row.key=='sprite_style' then row.default='pokemmo' end
 end
 local game=mod.world and mod.world.game
 local buckets={game and game.options,game and game.save and game.save.options}
 for _,options in pairs(buckets)do
  local saved=options.modOptions and options.modOptions[mod.id]
  if saved then
   local aliases={enabled='gen3_visible_wilds',random_encounters='gen3_random_encounters'}
   for key,old in pairs(aliases)do if saved[key]==nil and saved[old]~=nil then saved[key]=saved[old]end end
   if saved.sprite_style==nil and saved.gen3_sprite_art~=nil then saved.sprite_style=saved.gen3_sprite_art=='classic' and 'followers' or 'pokemmo'end
   if saved.follower_count==nil and saved.gen3_follower~=nil then saved.follower_count=saved.gen3_follower and 1 or 0 end
   local runtime=game.mods and game.mods.modOptions
   if runtime then runtime[mod.id]=runtime[mod.id]or{};for k,v in pairs(saved)do runtime[mod.id][k]=v end end
  end
 end
 mod.options:define(schema)
 assert((loadstring or load)(assert(mod:read('lib/InGameOptions.lua')),'@wilds/options_menu'))().install(mod,schema,'WILDS')
 return schema
end
