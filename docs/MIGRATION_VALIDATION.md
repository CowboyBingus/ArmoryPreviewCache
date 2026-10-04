Supports Helldivers 2 Steam build 25480438 / EXE 1.8.46015.0.

Offline source, package and read-only module checks passed. In live play on this
build caching works, and the v23 update gate ran in real play on 2026-10-04 (all
mods installed, no errors, thumbnails worked). Live play measured 0.017 ms per
frame in missions and 0.040 ms on the ship, where the cost depends on the
screens open. The v23 short-visit handoff, the pattern/attachment refresh on
back-out and multiplayer have not been confirmed in game. The 21 external live
checks did not write game memory or installed files.

Public source excludes raw memory captures and private session recordings.
Install with the game closed, then Purge / Deploy in one mod manager.
Use Bingus Shared Loader v18 or newer.
