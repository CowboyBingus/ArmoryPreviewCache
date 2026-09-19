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
