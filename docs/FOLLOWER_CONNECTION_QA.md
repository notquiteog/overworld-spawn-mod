# Connected follower movement — 2026-10-13

Gen1Recomp 0.3.85, isolated native game profiles, current source loaded.

- Yellow: native Pallet Town → Route 1 connection; same follower object before/after crossing and 70 subsequent frames. Native render inspected.
- Crystal: native New Bark Town → Route 29 connection; same follower object before/after crossing and 70 subsequent frames. Fixes Gen2 environment classification and collision lookup for engine neighbors identified by `id`.
- Emerald: native Oldale Town → Route 103 connection; same actor before/after crossing and 40 subsequent frames. Voxel render inspected. Warps retain fresh-entry reset; connected map events preserve actor identity and translate the recorded path.
- Shared movement regression: active step goals translate with the map, lag uses observed native running cadence, blocked-distance catch-up cannot teleport, and an idle trainer permits the existing trail to drain.
- Gen3 regression: offset seam translation, actor reattachment after ambient reset, bounded running movement, stopped-player catch-up and warp reset. The follower follows recorded waypoints rather than skipping corners toward the latest goal.
- Focused follower suites: 19 passed; Gen3 settings parity also passed (55 assertions). The existing `poke_followers_assets_unit_test.lua` cannot pass in this checkout: its 151 legacy `poke_followers` sheets are absent; HGSS manifest checks pass. No asset changes are part of this fix.

These runs cover one native connection per generation, not every connection, riding/battle lifecycle combination, or edition. Existing Dive, water, healing, battle-return and controller unit suites passed. Native running speed is asserted with engine-shaped movement data; sustained controller-running routes remain an additional integration check.
