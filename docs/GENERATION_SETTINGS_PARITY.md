# Generation settings parity — implementation inventory

All three generations use the 24 stable keys in `options.lua`. The native Gen3
adapter loads that schema and changes only `sprite_style`'s default to HGSS
(`pokemmo`). Gen1/Gen2 retain GSC (`followers`). These are overworld sprites;
Wilds does not replace battle pictures, battle backgrounds or interface art.
Legacy `gen3_visible_wilds`, `gen3_sprite_art`, `gen3_follower` and
`gen3_random_encounters` values migrate when the corresponding shared key is
absent. Existing shared choices take precedence.

| Settings | Gen1/Gen2 implementation | Native Gen3 implementation |
| --- | --- | --- |
| `enabled`, `spawn_density` | Shared population and region logic | Live roster rebuild; 3/6/10/16 target wilds; replenishes after encounters |
| `random_encounters` | Shared encounter hook | Native encounter hook, independent of current visible roster |
| `water_spawns` | Shared water display/spawn rules | Swimming/levitating sheets, dark markers, tinted silhouettes, classic-only or disabled water encounters |
| `cave_spawns` | Reachability and mixed scenery rules | Native floor reachability and directional barriers; Mixed admits disconnected scenery that cannot battle or be caught |
| `town_pokemon` | Kanto and curated Johto ambient systems | Peaceful Kanto towns, houses and centers; native text interaction; no battle/capture |
| `enable_idle`, `enable_wander`, `enable_aggressive`, `enable_hidden` | Shared behavior state machines | Selected behavior pool, glance/roam/chase/marker behavior; live owner roster rebuild |
| `sprite_style` | Shared four art providers | GSC, HGSS, Pokedex and PMDCollab; shipped-sheet fallbacks for missing art |
| `sprite_fade`, `wild_silhouettes`, `pokemon_grass_render_mode` | Shared renderer/provider presentation | Cached native sprite variants for opacity, caught-dex silhouettes and grass immersion; variants are also consumed by optional renderers |
| `follow_control`, `trainer_trail`, `follower_count` | Shared follower/control core | Native player graphic replacement, safe traversed-cell history, up to six party trailers and trainer trailer; native party FOLLOW/DISMISS selects a persistent mon identity |
| `overworld_catching` | Generation-specific catch compatibility | Native bag removal, native mon creation, catch odds, party/PC storage and dex registration |
| `catch_throw_key`, `catch_cycle_key`, `catch_throw_combo`, `catch_cycle_combo` | Shared bindings/input | Live keyboard and logical-button bindings; charging controls 2–6 cell range; ball switching; conflicting desktop cycle key falls back |
| `catch_hud_size` | Shared catching HUD | Live scale 0–10; 0 hides presentation without disabling throws |
| `dev_overlay` | Per-Pokemon world labels | Native HUD roster with behavior, facing and map cells |

The native settings page edits the same saved keys as Mod Manager. Native
simulation requires no other mod. Ride and alternate-renderer integration is
optional. Followers stay suppressed during surf/flight and honor Ride's public
`shouldShowFollowers()` policy on a ground mount.

## Shared-world authority

Guests never populate or move authoritative wilds. Host snapshots carry exact
species, level, pose, behavior, ambient/scenery and hidden status. The remote host
simulation reads native map layouts without changing the host's current map.
Host density, water and behavior settings also apply to remote rosters.

Direct catching uses a reserved host claim. `authority.request(map,id,action)`
receives `{action='catch',ballId,charge}`. The host validates facing, 2–6 cell
range and a clear native collision ray through `sharedSpawns.canCatch`.
Unavailable remote map data fails closed. The grant calls
`sharedSpawns.beginCatch(wire,map,action)` and receives `accepted,result`, where
`result` contains `caught`, `shakes` and `message`. A rejected grant consumes
nothing. An accepted grant consumes exactly one ball; only a successful capture
commits authoritative removal. Failure releases the reservation. Wilds does not
locally remove a shared actor before the host commits its roster change.

This contract is implemented in all three generations and is enabled only when
Online advertises `authority.catching=true`. Gen1/2 retain fractional meter
quality locally while the wire charge encodes rounded range; a grant must match
the pending throw and the player must still be facing from its original cell.
`catchDenied(map,id,reason)` clears pending UI immediately. Full party/PC storage,
special catching sessions and unavailable native constructors reject the grant
without consuming a ball. Shared results use the existing projectile/wobble as
presentation only; its failure cannot refund an already resolved capture.

## Verification and remaining depth differences

`luajit tests/gen3_settings_parity_unit_test.lua` exercises schema/defaults,
real roster density, live behavior choices, random/water rules, capture
bookkeeping, guest authority, host catch validation, selected follower identity,
and trainer restoration with engine-contract doubles. This is a logic test,
not an in-game visual or controller verification.

`shared_catching_parity_unit_test.lua` passes 104 assertions using official 0.3.1
Gen1/2 catch, Pokémon construction, and box-storage modules. It checks requests,
public provider grants, exact inventory/storage/dex effects, replay rejection,
full boxes, failed rolls, native collision rays and the actual throw-release
interception. All 17 focused capture/settings test files pass after these
changes. The Gen3 logic suite now has 53 assertions.

All native modules compile. An earlier 26-file focused legacy/settings regression run
passes 22 files. All four failures reproduce on clean HEAD: a missing Gen2
PartyMenu engine fixture, an older Gen1 HGSS luminance expectation, and two tests
that assert obsolete `2.2.0` version strings. No live profiles were used.

All 24 settings now have native behavior. Some Gen1 presentation depth remains
outside this native implementation: PMDCollab uses native nine-frame directional
poses rather than its full variable-duration walk/idle sequence; follower/town
interaction uses native text rather than portrait/mood/recall submenus; Dev
Overlay is a roster readout rather than labels above individual Pokemon. Gen3
cave identification uses the current named cave/tunnel/Mt./Victory Road map
families; remote cave rosters use collision-safe encounter tiles rather than a
full remote reachability flood. The conservative remote catch ray can reject
unclassified native tiles. Gameplay, all-map art coverage, multi-controller
input and long-running multiplayer capture behavior remain release QA items.

Gen3 followers use native `SummaryData.isShiny`, including PID/OT-derived
shininess and the engine's `isShiny` override. Direct captures preserve a supplied
32-bit personality, recalculate its native nature/ability/gender/stats, and keep
an explicitly supplied shiny appearance with that native override when the
catching trainer's OT differs. Native Wilds does not currently generate shiny
identities when populating its roster; ordinary offline direct catches retain
the native capture constructor's PID roll. A roster-wide shiny encounter roll
and export-level PID/OT identity across multiple trainers are not implemented.

Native sprite records now expose optional `groundPadding`, computed once from the
lowest opaque footprint across every animation frame. Grass-cut/faded variants
inherit that baseline. PMD authored anchors and hidden markers provide explicit
zero; this metadata requires no companion mod. Seven grounding assertions pass.
