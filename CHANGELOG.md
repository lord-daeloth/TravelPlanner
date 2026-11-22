# Changelog

## 1.1.0 — 2026-11-21

- Add six palette presets and two independent dark-background-friendly accent selectors, saved per character.
- Remember independent expanded and collapsed window positions per character.
- Add an independent dark ImGui theme with cyan/violet accents and a gradient header rule.
- Separate planning controls and the journey into two scrollable panels.
- Display numbered route cards with current/visited states, level summaries and access tooltips.
- Redesign the compact window with clearer current/next-stop labels and remaining zone changes.
- Keep the existing routing, cutscene hiding and login-screen hiding behavior.

## 1.0.2 — 2026-09-30

- Set addon author to Daeloth.
- Hide on title/character-selection screens and while no in-world player is available.
- Preserve cutscene hiding without suppressing the window for the map or ordinary in-game menus.

## 1.0.1 — 2026-09-30

First public GitHub release, including the cutscene-visibility update.

- Plan routes from a selected zone or the current zone to a destination.
- Filter zone lists by region and search text.
- Find the fewest zone changes or the lowest average enemy level across a route.
- Enable optional boats, airships and Cavernous Maw connections, with access notes.
- Follow progress in expanded or collapsed mode and replan when off route.
- Automatically hide during cutscenes and restore the prior visibility state afterward.
- Bundle an offline dataset of 295 zones and 522 directed connections.
- Include reproducible data tooling and LuaJIT routing/integration tests in the source repository.

Known data and navigation limitations are documented in [docs/DATA.md](docs/DATA.md).
