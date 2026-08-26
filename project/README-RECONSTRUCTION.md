# ERA-LIFE Experiment 2.0 — reconstructed project

This project was rebuilt from `EraLife.pck`. It is not your original project folder —
it is a reconstruction that compiles and boots on Godot **4.4.1** (build `49a5bc7b6`,
the exact version the pck was exported with).

**If you ever find your real project folder, use that instead.** This one is missing
comments and original formatting. Everything functional is here.

---

## Quick start

1. Install **Godot 4.4.1** (not 4.5, not 4.3 — the pck was built with 4.4.1).
2. Open Godot → Import → pick the `project.godot` in this folder.
3. Let it finish importing (first import takes a while — 334 scripts).
4. Press **F5** to run. Start a life, open a pending situation, tap an option.
5. When you're happy: **Project → Export** → your existing Windows preset →
   this regenerates `EraLife.exe` and `EraLife.pck`.
6. Replace the old `EraLife.exe` + `EraLife.pck` with the new pair. Both files
   together — an old exe with a new pck can break in confusing ways.

There is no export preset in this folder (presets live in `export_presets.cfg`, which
is not shipped inside a pck). You'll need to create one: Project → Export → Add →
Windows Desktop. Default settings match what you had.

---

## What was verified

- **334/334 scripts parse with zero errors** under Godot 4.4.1.
- **Project boots headless with no script errors** (`--headless --quit-after 300`).
- **All 12 audio files decode cleanly** and have correct durations.

What was *not* verified: actual gameplay. Booting is not playing. Start a life and
click through a pending situation to confirm the fix behaves.

---

## The bug that was fixed

Selecting a response option did nothing — no popup, no stat change, the situation
stayed in the list.

**Cause:** each pending situation has two IDs. The runtime registry
(`active_popup_contracts`) is keyed by the *source* ID (`pending_illness_84`). The
per-viewer view contract adds a second ID (`view_pending_illness_84_12`).
`PopupViewer._pending_viewer_contract_identity()` prefers `view_contract_id`, and
`MainScene._on_popup_viewer_contract_selected()` then overwrote the canonical `id`
with it before calling `present_contract()`. Every option button was therefore bound
to an ID that `resolve_popup_contract()` could never find, so it returned
`{"success": false, "reason": "contract_not_active"}` — and because the failure path
sets no `popup_text`, the UI skipped the popup branch entirely and showed nothing.

### Three changes were applied

**1. `scenes/MainScene.gd`** — in `_on_popup_viewer_contract_selected`, stop
overwriting `id` with the view ID. The view ID now goes in `view_contract_id` where it
belongs, and `id` keeps the source contract ID.

**2. `Engine/PendingSituationsEngine.gd`** — new `_resolve_source_contract_id()`
normalizes any incoming ID (`view_<source>_<viewer>`, `pending_item:<source>`, or a
registry alias) back to the runtime source ID. Called at the top of
`resolve_pending_contract()`. Cleanup now also erases the ID the UI actually used, and
the report records both `requested_contract_id` and `resolved_contract_id`.

**3. `scenes/MainScene.gd`** — in `_finalize_pending_situation_choice_result_lens`, a
failed resolution now raises a `push_warning()` and shows a popup instead of silently
doing nothing. This matters beyond this bug: *any* failure in the intent → resolve
chain was previously an invisible dead button.

Search for `# FIX:` to find all three.

---

## Known issue not yet fixed

`Engine/GlobalIntentContractEngine.gd` calls `_mark_signature()` on **rejected**
intents too, so once a click fails, repeated identical clicks inside the dedupe window
get swallowed as duplicates — which is why mashing the button also did nothing.
Consider only deduping successful commits.

Separately, `_prune_recent_signatures()` hardcodes a 2000 ms cutoff while the dedupe
check uses `RECENT_DEDUPE_WINDOW_MS`. If that constant is ever raised above 2000 the
two silently disagree.

---

## How the assets were recovered

- **Scripts:** `.gdc` files are zstd-compressed GDScript token buffers. Decompressed,
  then identifiers (XOR 0xB6), constants, and the token stream were decoded and
  rendered back to source using the embedded line/column maps.
- **Audio:** Godot stores imported Vorbis as bare packets with no Ogg container. The
  packets and granule positions were pulled out of the `.oggvorbisstr` resources and
  re-muxed into valid Ogg streams (pages rebuilt with correct CRC32 and granule
  positions).
- **`project.godot`:** decoded from the binary `ECFG` `project.binary`.
- **`scenes/main.scn`:** the exported binary scene, used as-is. Godot reads binary
  `.scn` files directly; you can re-save it as `.tscn` from the editor if you'd rather
  have text.

`branding/EraLifeIcon.png` and `release/eralife_release_public.pub` were shipped
uncompressed in the pck and are the originals.

### Not included

- `export_presets.cfg` (never shipped in a pck — recreate in the editor)
- The `Web/` PWA icon set and `index.manifest.json` (only the compressed `.ctex`
  versions were in the pck; re-add your source PNGs if you export for web again)
- The `eralife-discord-gateway` bot source. Only 35 stray `node_modules/package.json`
  files were in the pck — an export-filter leak. Tighten that filter so dependency
  manifests stop shipping inside your game.
