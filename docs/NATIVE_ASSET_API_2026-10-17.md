# Native Gen3 packaged artwork loading — 2026-10-17

The native picture loader used `love.filesystem.newFileData`, which the mod
sandbox blocks. Its protected call hid the failure and selected HGSS, PMD and
swimmer sheets fell back to ordinary front portraits. It now uses the public
`mod.assets:image` reader, which resolves the mod's packaged paths through the
engine. Missing artwork still uses the existing native fallback. No settings,
encounter rules, gameplay, source sprites, version or release metadata changed.

The existing sandbox compatibility test reproduces the old defect and now
passes. The Gen3 settings fixture now blocks direct filesystem access and checks
actual public asset use:56 assertions pass. Manifest targets, game compatibility,
catch input and hidden-grass presentation tests also pass.

Official Gen1Recomp0.3.89 (latest checked2026-10-17), Linux native NVIDIA/LÖVE:
`tests/gen3_asset_api_driver.lua` passes with all seven coordinated mods loaded
from separate repositories. An isolated copied FireRed QA profile and separate
engine mods directory keep normal saves and other workers' profiles untouched.
The driver uses the original hidden-grass fixture, Route1 grass cell(18,15),
player(18,17) facing up, voxel3, original2D and first-person6. Player walking
advances to(19,17). Hidden land is0 opaque pixels and visible idle art127 pixels.
Both public selected-sheet checks pass: HGSS Rattata32x32×9 and swimming
Magikarp16x16×9; the broken fallback would be24x24×1. Process exited0.

Overview, native2D, first-person and both exported sheet captures were inspected;
selected directional art appears and hidden grass has no underwater marker.
The first-person view is close to a native NPC and does not certify camera
framing. Evidence: session scratch `platform-audit/wilds-firered/`.
No Android/iOS/Windows execution or other four native editions were performed
for this narrow fix. It removes a cross-platform sandbox API defect; it is not
proof that every feature works on every device.
