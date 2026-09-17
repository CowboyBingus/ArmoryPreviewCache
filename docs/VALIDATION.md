# Validation

The maintainer confirmed v16 working in-game, including the previously failing
mission briefing Armor picker. The release uses exactly that tested runtime.
Public policy and adapter tests run offline; private captured-data tests also
verified native keys/crops, blank-atlas provenance, fresh widgets, menu lifetimes,
balanced package leases and the cleared-material crash regression.

Completed thumbnails are retained within a bounded session cache. Asset profiles
persist between launches; rendered pixels do not. This release does not claim
instantaneous first-ever previews or a measured cold-start percentage improvement.

Artwork is generated with the built-in image tool; prompts are in assets/ARTWORK.md.
No raw game memory, crash dump, local process identity or personal path is public.
