local native={POOCHYENA=286,ZIGZAGOON=288,WURMPLE=290,SKITTY=315,WINGULL=309}
local P={speciesFromName=function(name)return native[name]end}
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local get=dofile('lib/gen3/ambient.lua')({get=function()return version end},P)
 if version=='firered'or version=='leafgreen'then
  assert(get('FR_PALLET_TOWN')==16);assert(get('FR_PALLET_TOWN_HOUSE')==52)
  assert(get('CUSTOM_ROUTE')==nil)
 else
  assert(get('EM_LITTLEROOT_TOWN')==286);assert(get('RU_OLDALE_TOWN')==288);assert(get('SA_OLDALE_TOWN')==288)
  assert(get('EM_MOSSDEEP_CITY')==309);assert(get('RS_PLAYER_HOUSE')==315)
 end
end
local custom=dofile('lib/gen3/ambient.lua')({get=function()return 'custom-region'end,layout=function()return'rse'end},P)
assert(custom('EM_LITTLEROOT_TOWN')==286)
print('PASS five native games and explicit RSE layout use native regional ambient species')
