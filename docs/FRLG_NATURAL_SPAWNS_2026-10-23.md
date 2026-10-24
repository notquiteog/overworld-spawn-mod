# Native FRLG population and optional-art repair

Engine: official v0.3.96, release commit `0e92b587468c2db7c386f055fc272e6505b0f401` (latest release checked 2026-10-23). Source baseline: Wilds `87dbab57` / 2.6.9. No live player save, shared seed, or released artifact engine was modified.

## Findings and change

Fresh FireRed and LeafGreen already populated Route 1, Viridian Forest and Route 3 at unchanged defaults: six natural actors and six native draw rows each, with visible Pokémon in inspected native and combined Battle Art captures. This does not establish the user's exact failing save/context.

Two concrete defects were reproduced:

* The Gen3 population counted all actors on a map indefinitely. On FireRed Route 3, moving the player fixture from native habitat (34,11) to distant habitat (78,15), without reloading the map, left all six original actors 34–42 cells away. Eight seconds later there were still zero nearby actors. Gen3 now retires offline actors beyond the existing Gen1/2 22-cell Chebyshev distance before the ordinary five-second refill. Nearby actors, active chases, catches, busy native field state and authoritative online rosters are preserved. Shared population policy is unchanged.
* `Actors.front` provides one native frame when optional sheets are absent, and for Pokedex style. Presentation attempted to draw nine distinct quads; the missing second quad aborted the update and could leave graphics state pushed. Presentation now repeats frame zero only when a pose is absent. Actual nine-frame sheets and grounding remain unchanged. The new strict graphics regression fails on baseline and passes after the fix.

No density, habitat, collision, random-encounter, visibility or default behavior setting changes were made. Hidden land behavior intentionally has no visible body.

## Reproducible native fixture

`tests/drivers/native_frlg_natural_spawns.lua` runs through the engine developer driver. It requires an isolated identity ending `-qa`, an actual extracted FRLG cache, `QA_UTIL` and `SHOT_DIR`.

It uses native walkable land at Route 1 (16,16), Viridian Forest (11,12) and Route 3 (34,11), waits for normal population, asserts six natural actors / six native draw rows, captures actual renderings, and verifies directional movement through real input. It never calls `S.spawn`, enables town ambient as evidence, or substitutes encounter tables or drawing functions. With Battle Art available, it checks settled scenes and captures both native and 3D views.

The same-map travel portion explicitly relocates the QA player to the distant native Route 3 patch (78,15); it is a habitat fixture, not a claim of walking the whole route. After normal native frames it requires all six original IDs to disappear from both simulation and renderer, six nearby replacement actors, and six draw rows. It captures the distant patch in native/3D views. Finally, native `Party.giveMon` supplies two healthy party members, and actual `Field.interact` on a naturally populated actor must enter `Battle.isActive()`, retain species/level/personality and remove the actor once. Native Gen3 battle ownership does not change the host `game.phase` to `battle`. The final driver advances the ordinary intro with A input to the native command phase.

Optional-art fixture: make a disposable mod directory symlinking source/artifact root entries except `.git`, `dist` and `assets`. Supply only `assets/pmdcollab/sprite_table.lua` from the original assets. Leave HGSS/follower/water PNGs genuinely absent. Load this directory through a separate engine mod link; set `QA_MISSING_ART=1`. The driver then requires every natural actor on all three routes to resolve a real one-frame native front picture and to obtain a complete nine-pose presentation sheet. No asset API override or fake actors are used.

Scratch runners and exact setup:

* `/home/admin/Projects/.scratch/wilds-frlg-spawn-20261023/setup-native.py`
* `/home/admin/Projects/.scratch/wilds-frlg-spawn-20261023/run-own.py` (`edition`, `standalone|missing-art`, driver path, unique label)
* `/home/admin/Projects/.scratch/frlg-runtime-fixes-20261023/run_case.py` (`combined`, edition, driver path, unique label)

Both runners clone disposable identity/cache views from immutable `.96` seeds. Combined uses all seven mods, including API3 Doubles and Battle Art.

## Evidence and scope

All paths below are under `/home/admin/Projects/.scratch/`; raw screenshots and extracted caches are deliberately not committed.

| Native case | Evidence | Result |
| --- | --- | --- |
| Baseline standalone FR/LG, three actual routes | `wilds-frlg-spawn-20261023/before/{firered,leafgreen}` | Six natural actors each map; inspected visible bodies. Original Route1 viewing cell was corrected to walkable16,16 in the final fixture. |
| Baseline FR same-map travel | `wilds-frlg-spawn-20261023/native/travel-before/firered` | Near6 at entry, near0 after distant relocation; same IDs retained. |
| Repaired FR same-map travel | `wilds-frlg-spawn-20261023/native/travel-after/firered` | Near6 at entry and distant patch; new IDs9–14. |
| Missing optional art standalone FR/LG | `wilds-frlg-spawn-20261023/native/missing-art-final/{firered,leafgreen}` | PASS:18 genuine native-front fallback actors per edition, natural interaction/battle identity, native input. Captures inspected. This run precedes the stricter integrated travel/command-stage assertion. |
| Full-assets combined seven mods FR/LG | `frlg-runtime-fixes-20261023/native/wilds-final-natural2/{firered,leafgreen}` | PASS:three routes, native+3D, movement and natural actor battle identity. This run precedes the integrated travel assertion. |
| Integrated strict travel plus battle command combined FireRed | `frlg-runtime-fixes-20261023/native/wilds-final-travel-command/firered` | PASS:all strict travel assertions, native command phase reached with actual A input, same-identity natural actor battle, zero mod errors/legacy diagnostics. |
| Integrated strict travel combined LeafGreen | `frlg-runtime-fixes-20261023/native/wilds-final-travel/leafgreen` | PASS:oldIDs retired6/newlocal6/draw6, actual native+3D distant captures inspected, same-identity natural interaction; zero mod errors/legacy diagnostics. |

The initial interaction-driver failure incorrectly required `game.phase == 'battle'`; correcting that fixture to actual native battle state resolved it. It was not a production battle-start failure. Release/exact-ZIP acceptance is coordinated separately by the integration owner.

## Focused regressions

Run from repository root using LuaJIT:

```
luajit tests/gen3_presentation_fallback_unit_test.lua
luajit tests/gen3_settings_parity_unit_test.lua
luajit tests/gen3_identity_unit_test.lua
luajit tests/gen3_catch_bindings_unit_test.lua
luajit tests/gen3_ambient_versions_test.lua
```

PASS:35 fallback assertions;90 settings/lifecycle/input assertions; native identity and host off-map simulation;66 catch assertions; regional species parity. Lifecycle checks include 22/23-cell boundary, renderer removal, refill, catch/chase protection, native field lock, unchanged shared-host roster and exactly-once forwarding of native input.step.

Additional passing suites: `gen3_hidden_presentation_unit_test`, `gen3_sprite_grounding_unit_test`, `gen3_underwater_followers_test`, `gen3_follower_footing_test`, `gen3_follower_connection_speed_test`, `gen3_option_screen_test`, `gen3_water_behavior_unit_test` (all under tests, `.lua`).
