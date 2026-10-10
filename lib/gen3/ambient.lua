-- Curated peaceful regional residents; native species IDs, no encounter mutation.
return function(GameVersion,Pokemon)
 local towns={PALLET_TOWN=16,VIRIDIAN_CITY=19,PEWTER_CITY=16,CERULEAN_CITY=52,VERMILION_CITY=25,LAVENDER_TOWN=104,CELADON_CITY=133,FUCHSIA_CITY=54,SAFFRON_CITY=52,CINNABAR_ISLAND=58,INDIGO_PLATEAU=16}
 local hoennTowns={LITTLEROOT_TOWN='POOCHYENA',OLDALE_TOWN='ZIGZAGOON',PETALBURG_CITY='WURMPLE',RUSTBORO_CITY='SKITTY',DEWFORD_TOWN='WINGULL',SLATEPORT_CITY='WINGULL',MAUVILLE_CITY='ELECTRIKE',VERDANTURF_TOWN='ROSELIA',FALLARBOR_TOWN='NUMEL',LAVARIDGE_TOWN='NUMEL',FORTREE_CITY='KECLEON',LILYCOVE_CITY='SKITTY',MOSSDEEP_CITY='WINGULL',SOOTOPOLIS_CITY='MARILL',PACIFIDLOG_TOWN='WINGULL',EVER_GRANDE_CITY='TAILLOW'}
 local version=GameVersion.get()
 local hoenn=(GameVersion.layout and GameVersion.layout()=='rse')or version=='ruby'or version=='sapphire'or version=='emerald'
 return function(mapId)
  local map=tostring(mapId):gsub('^FR_',''):gsub('^EM_',''):gsub('^RU_',''):gsub('^SA_',''):gsub('^RS_','')
  local species=hoenn and hoennTowns[map] and Pokemon.speciesFromName(hoennTowns[map]) or not hoenn and towns[map]
  if not species and(map:find('POKECENTER',1,true)or map:find('HOUSE',1,true))then species=hoenn and Pokemon.speciesFromName('SKITTY') or 52 end
  return species
 end
end
