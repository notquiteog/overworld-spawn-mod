# Outstanding branch consolidation — 2026-10-20

The user requested a snapshot of all unfinished work, consolidation to main and
releases, then explicitly narrowed the AI work: preserve it with AI chat features
off by default. This integration starts at published 2.6.5
`e4e43b80749872c6828f4cd8fe2b803c6e301f04`; later primary-worktree edits are not
silently incorporated. It does not redesign current Gen1/Gen2/Gen3 gameplay.

## Captured remote work

Read-only origin inspection on 2026-10-20 found these four old remote heads:

| Branch under `origin/` | Frozen head | Accounting |
| --- | --- | --- |
| `cursor/ai-npc-dialogue-ce26` | `f27646cc8f145e1c027a14fddd7a008e5e341d28` | Four unique AI feature/documentation commits ported: `d70bfa2b`, `181bb77b`, `0be192d8`, `f27646cc` |
| `cursor/spritecollab-format-investigation-3001` | `a43ecfa943d36820b1e31e834a7a342c43241f9b` | Its five format/reference documents ported; only whitespace normalized in documentation |
| `cursor/pmdcollab-sprite-portraits-d434` | `197837402f5a34f4673e5438d7d615c21960c3d3` | Already included: complete tree equals historical merged `1018d8ee`, parent of `26a246cb` |
| `cursor/bump-version-2.2.0-dd7e` | `26a246cb79903f767970312438a52107825858d2` | Already included: complete tree equals current history root `e66e03d5` |

The current main history and old branches have no common ancestor after the
historical squash. A whole old tree would remove newer fixes and assets. The
integration therefore ports unique changes against 2.6.5, resolves current
exports/manifest in favor of current gameplay, then records the accounted old
heads with an `ours` ancestry merge. That merge records provenance; its tree is
the reviewed port, not a restoration of any old branch snapshot.

## Defaults and bounded integration

AI Dialogues and AI Memory are strictly opt-in booleans. Missing, false, strings
and invalid preferences remain off. Local/custom/cloud providers are optional;
there is no network request, conversation-context build or memory write on the
default-off path. No provider software, model, credential or companion is a hard
dependency. Default species art, gameplay protocols and native Gen3 adapter stay
intact. Gen3 has no new AI NPC hook.

The port repairs branch integration defects: public input-step/key dispatch,
wall-time deadlines, pending-offer/reply ownership, map/session/disposal guards,
launcher cleanup, actual generation naming options, and bounded private memory.
The production secrets path uses public installation-scoped `mod.cache`; the
old branch’s raw filesystem workaround is removed. Tests alone may inject an
explicit temporary-file path. Replies are plain native TextBox text, never code;
prior player turns remain separate chat roles rather than system instructions.
The preserved August design plan is historical provenance, not current test
acceptance or an instruction to implement more features.

## Verification

Official Gen1Recomp 0.3.91 was rechecked immediately before native verification.
Isolated standalone Red/Pewter and Gold/Cherrygrove native runs passed default-off
boot, original NPC dialogue, optional Talk choice, actual native key dispatch,
async HTTP POST to a localhost-only fixed-response stub and native reply boxes.
Eight captures were inspected. Gold uses an ordinary town NPC; the initial
Guide Gent story-tour fixture was excluded. No external model/API credentials,
paid provider or Internet chat request was used. Fixtures use disposable
teleported positions, not player saves. Native Gen3 AI, mobile/touch devices and
remote model response quality are not claimed.

The five original AI test suites, the focused lifecycle/default suite and the
existing sandbox compatibility test pass. A broad standalone scan initially
reported seven unrelated failures; each reproduced in an archived unmodified
2.6.5 baseline: legacy 2.2.0 version expectations, missing old engine paths,
legacy follower-sheet expectations, plus two genuine preexisting audit gaps:
32px HGSS Gen1 sheets can bypass luminance palette handling, and a subset of
water-index entries lacks Gen1 metadata while the PNGs remain present. These
are baseline findings, not newly passing suites or defects introduced by this
AI port; the user narrowed this batch before unrelated repairs. The new
lifecycle test is intentionally tracked despite the repository’s `/tests`
ignore. Packaging excludes tests/tooling/private cache data. Release publication
and final all-mod package verification are coordinated separately.
