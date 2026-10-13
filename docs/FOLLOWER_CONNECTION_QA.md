# Connected follower movement — 2026-10-13

Gen1Recomp 0.3.85, isolated native game profiles, current source loaded.

- Yellow: native Pallet Town → Route 1 connection; same follower object before/after crossing and 70 subsequent frames. Native render inspected.
- Crystal: native New Bark Town → Route 29 connection; same follower object before/after crossing and 70 subsequent frames. Fixes Gen2 environment classification and collision lookup for engine neighbors identified by `id`.
- Emerald: native Oldale Town → Route 103 connection; same actor before/after crossing and 40 subsequent frames. Voxel render inspected. Warps retain fresh-entry reset; connected map events preserve actor identity and translate the recorded path.
- Shared movement regression: active step goals translate with the map, lag uses observed native running cadence, blocked-distance catch-up cannot teleport, and an idle trainer permits the existing trail to drain.
- Gen3 regression: offset seam translation, actor reattachment after ambient reset, bounded running movement, stopped-player catch-up and warp reset. The follower follows recorded waypoints rather than skipping corners toward the latest goal.
- Focused follower suites: 19 passed; Gen3 settings parity also passed (55 assertions). The existing `poke_followers_assets_unit_test.lua` cannot pass in this checkout: its 151 legacy `poke_followers` sheets are absent; HGSS manifest checks pass. No asset changes are part of this fix.

These runs cover one native connection per generation, not every connection, riding/battle lifecycle combination, or edition. Existing Dive, water, healing, battle-return and controller unit suites passed. Native running speed is asserted with engine-shaped movement data; sustained controller-running routes remain an additional integration check.

## Sustained Emerald native-running integration

Additional engine0.3.85 isolated `gen3-emerald-qa` run: Oldale Town (10,8),
native upward running via `Player.tryMove('up', game, true)`, crossing Route103
at frame65. No player coordinate writes during measurement. Twelve cells and
239 follower updates retained the same actor through the seam. Every update
asserted follower displacement at or below native speed times update dt;
observed peak and native running speed both120px/s. After the player fully
stopped, the follower advanced16px and reduced its gap32→16px along the trail.
Native stopped/caught-up captures were inspected. Earlier18-cell trace also
passed, but had already settled by the stopping sample and is not catch-up proof.

Driver and results: workspace `.scratch/follower-running-20261013/emerald.lua`
and `emerald-stop/{run.log,stopped.png,caught-up.png}`. This exercises the native
movement API, not physical held-controller input. One Emerald seam only; Crystal
was not rerun in this bounded follow-up. No production edits, player saves or
release changes; isolated runtime closed.
