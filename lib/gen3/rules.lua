-- Pure option semantics shared by local and remote native simulation.
local R={density={low=3,normal=6,high=10,very_high=16}}
function R.count(get)return get('enabled')and(R.density[get('spawn_density')]or 6)or 0 end
function R.visibleTerrain(get,terrain)
 local mode=get('water_spawns')
 return terrain~='water' or mode~='disabled'and mode~='classic_encounters'
end
function R.randomAllowed(get,terrain)
 if terrain=='water' then
  local mode=get('water_spawns')
  if mode=='disabled'then return false end
  if mode=='classic_encounters'then return true end
 end
 return get('random_encounters')~=false
end
function R.behavior(get,rng,terrain)
 local pool={}
 for _,name in ipairs({'idle','wander','aggressive','hidden'})do if get('enable_'..name)and not(terrain=='water'and name=='hidden')then pool[#pool+1]=name end end
 return #pool>0 and pool[rng(#pool)]or'idle'
end
function R.behaviorEnabled(get,name,terrain)return not(terrain=='water'and name=='hidden')and get('enable_'..(name or'idle'))~=false end
return R
