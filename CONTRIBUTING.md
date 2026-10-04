# Build

Use Windows x64, Python 3.10+ and the LuaJIT revision in `dependencies.json`.
Build LuaJIT with `msvcbuild.bat nogc64` from an x64 Native Tools command prompt.
Place it at `tools/src/LuaJIT/src/luajit.exe`, or set `HD2_LUAJIT` to your compiler.

Run `python scripts/build.py`. The build runs the portable policy, installation,
image-key, native material-lifetime, captured-UI replay and FFI name-clash tests
and produces the standard release ZIP.
It does not install the mod or launch the game. Source builds independently;
the separate Bingus Shared Loader is required only to run it in-game.

`scripts/module.py` constructs the exact standalone resource for megapack builds.
The runtime is locked to the documented game fingerprints and native signatures.
Most tests use synthetic data. The captured-UI replays use
`tests/fixtures/ui_*_25327279.lua`: only the bytes the adapters read from the
ship Armory and a briefing picker in Steam build 25327279, with no identifying
data (the privacy audit scans them). No test writes game memory. Other
live-memory captures and crash dumps stay private.

Only `publication-files.json` entries are public. Run
`python scripts/privacy_audit.py --zip releases/Armory-Preview-Cache-v23.zip --git`
after staging a release to check source, PNG metadata, archives and Git history.
Do not commit local paths, other process captures, dumps, logs, extracted game files,
credentials or personal Git identity. Use CowboyBingus's GitHub noreply identity.
