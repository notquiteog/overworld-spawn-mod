-- Isolated native fixture: original overworld/2D/1ST review plus selected-sheet
-- ownership through the public package asset API. Never writes a player save.
return function(game)
 dofile(assert(os.getenv('WILDS_MOD_ROOT'))..'/tests/gen3_hidden_grass_driver.lua')(game)
 local ex=assert(game.mods.exports.overworld_wild_spawns)
 local options=game.mods.modOptions.overworld_wild_spawns or{}
 game.mods.modOptions.overworld_wild_spawns=options
 local style,water=options.sprite_style,options.water_spawns
 local cases={{'hgss',19,'land',32},{'swimmer',129,'water',16}}
 local dir=assert(os.getenv('SHOT_DIR'))
 options.sprite_style='pokemmo';options.water_spawns='swimming_sprites'
 for _,case in ipairs(cases)do
  local id=assert(ex.resolveGen3Sprite(case[2],case[3],false))
  local spr=assert(ex.gen3Actors.sprites[id])
  assert(spr.frameCount==9 and spr.width==case[4] and spr.height==case[4],'native front fallback replaced selected '..case[1])
  local data=spr.image:newImageData();local file=assert(io.open(dir..'/'..case[1]..'-api-sheet.png','wb'))
  file:write(data:encode('png'):getString());file:close();data:release()
  print('[PASS native public asset sheet]',case[1],spr.width,spr.height,spr.frameCount)
 end
 options.sprite_style,options.water_spawns=style,water
 print('[PASS Wilds native asset API]',require('src.core.GameVersion').get())
end
