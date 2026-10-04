# v23

- A short visit keeps its thumbnails: the visible tiles are kept as soon as they have rendered, instead of only after the whole category finishes. Backing out early no longer discards the visit.
- The offscreen items are kept later, when the rest of the category finishes, without capturing the visible tiles again.
- Warm visits allocate no extra texture, and thumbnail registry reads are skipped on ticks where no handoff can happen.
- Frames where nothing the thumbnail work uses has changed skip it and allocate nothing. Before, every frame re-read the whole Armory grid (113-117 KB of garbage per frame measured in game while thumbnails were generating).
- With tiles bound, the check before the game update reads them only after a full update or a state change, instead of 7 reads per tile every frame.
- The 50 ms asset step reuses its last reading while nothing it uses has changed and it has nothing left to load or retry.
- Memory is polled every 50 ms only while low memory can change what the mod does (menus, prewarm, held packages or images, a low-memory trip); elsewhere, such as in missions, every 2 seconds.
- Each frame checks the update thread once instead of twice, and the memory guard reads the clock only while it trips or recovers.
- The per-frame image step no longer creates a function every frame, and the clock and memory readings no longer allocate.
- The learned profile is encoded for a save only after it changed, instead of every 5 seconds outside the menu.
- Errors from the game's update and shutdown, or from other mods, reach the game unchanged with their original traceback, so they no longer look like errors in this mod.
- An error from the game's update or a mod below now pauses the mod: it hands every thumbnail back to the game, releases its asset leases and resumes after 60 clean updates. Eight errors in a burst still stop it.
- An error in the mod's own shutdown work can no longer prevent the shutdown callbacks of the game and other mods.
- The shutdown status keeps the first failure (`stopped after: <reason>`); plain `stopped` now means nothing failed.
- When the mod stops itself, the log keeps the reason and the update it happened on (`disabled_reason`, `disabled_frame`).
- Every Windows function the mod calls is declared under a private name, so another mod's different prototype can no longer stop the mod from starting, and mods loaded later keep their own prototypes.
- `ArmoryPreviewCache.ini` is read on the first update, because reading it while the game loaded resources could miss an existing file. The log reports `settings=file` or `settings=defaults`.
- The game build check uses the shared runtime's module hashes, read once per session for every mod.
- The log adds `image_grid_hits`, `image_visible_retained` and gate counters (`image_gated_ticks`, `image_full_*`, `image_prune_*`, `state_refreshes`, `policy_steps_skipped`, `policy_steps_full`).
- `verify_gate=1` in `ArmoryPreviewCache.ini` (diagnostic, off by default) also does the full read on skipped frames and logs any difference (`image_gate_misses`, `image_prune_misses`, `policy_gate_misses`).
- Licensed under the Zero-Clause BSD license (0BSD).
- Offline tests cover these changes, and the update gate ran in real play on 2026-10-04 with all mods installed, without errors and with thumbnails working. The short-visit handoff and a `verify_gate=1` session are not yet checked in game.

# v22.1

- Documentation-only release: the mod is identical to v22 (same compiled resource).
- Rewrites the install notes packaged with the mod and the README status: one current status line instead of the compatibility-candidate and test-build notes left from the game-build update. Caching works in live play; a category's thumbnails are kept once every preview in it has rendered.
- Lists one loader requirement, Bingus Shared Loader v18.

# v22

- Update relocated native addresses and texture allocation guards for Steam build 25480438.
- Preserve equipment preview caching and preload behavior.
- Offline builds and package checks pass; live gameplay validation remains pending.

# v21

- Update compatibility for game build 25327279.
- Restore equipment-list detection and asset preloading.
- Refresh the supported equipment lookup tables.

# v19

- Disable routine diagnostic file writes by default.
- Save learned profiles after menu interaction ends or during shutdown.
- Skip thumbnail-data reads in gameplay states while preserving startup prewarming and cleanup.
- Offline regression checks cover this update; live frame-time verification remains pending.

# v18

- Detects a weapon's applied pattern or attachment change from the configured
  slots the preview queue reports, and retires that crop at once. The tile stops
  showing the previous appearance on the first frame of the back-out instead of
  after the whole grid finishes re-rendering.
- Hands a retired widget back to the native pipeline: the game's working atlas is
  restored, the request invalidated and the spinner shown, so the item's own
  render appears as soon as that card composes.
- Logs `image_changed_items` (crops retired this tick) and `image_reappeared`
  (cumulative retirements). Missing or unchanged configurations keep serving
  their crop, and cache eviction now also restores the widgets it drops.

# v17

- Refreshes a cached preview when the native pipeline re-renders it. Changing a
  weapon's pattern or attachment keeps the same thumbnail request identity, so
  the previously retained pixels were served forever and the tile never updated.
- Logs `image_rendered_items` (ready items whose crop a native re-render
  supersedes) and `image_refreshed` (crops replaced by a newer render).
- Keeps every existing guard: blank hand-off regions are still rejected,
  presentation during regeneration is unchanged, and the eight-atlas budget is
  unchanged.

# v16.1

- Moves logs to `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`.
- Requires Bingus Shared Loader v14 for the shared log folder.
