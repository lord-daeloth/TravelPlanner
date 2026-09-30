# Development

Run these commands from the repository root. Python is not required to use the addon.

## Rebuild the dataset


Python 3 and PyYAML are only needed for development:

```powershell
python -m pip install PyYAML
python tools/build_data.py --download
```

The importer downloads the pinned source files, builds the Lua and JSON tables and records coverage in the manifest. After editing `data/overrides.json`, reuse the cache:

```powershell
python tools/build_data.py
```

Zone overrides are keyed by string zone ID and can set `average_level`, `region`, `level_status`, `level_source` or `access_note`. Connection overrides use `from`, `to`, and `kind` (`walk`, `boat`, `airship`, `portal`), plus optional `requirement`, `note`, `source` or `disabled`. An override updates matching directed edges or adds one if absent. Add both directions explicitly when appropriate. Reload the addon after rebuilding.

## Validation

```powershell
python -m pip install --target tools/vendor lupa
python tests/run_tests.py
```

The suite compiles the Lua under LuaJIT 2.1, compares minimum-average routes against an independent exhaustive oracle on 200 random graphs, checks real-data routes and connection integrity, exercises progression/off-route behavior, and runs the addon callbacks against strict Ashita/ImGui stubs. These checks do not replace an in-game render and zoning test.

## Build a release ZIP

```powershell
python tools/build_release.py
```

This reads the version from `TravelPlanner.lua` and writes `dist/TravelPlanner-v<VERSION>.zip` plus its SHA-256 checksum. The ZIP contains a top-level `TravelPlanner/` folder and an explicit list of runtime/documentation files. Source code, tooling and tests remain available in the repository and GitHub source archives. Download caches, vendored Python packages and local settings are never packaged.
