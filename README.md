# TravelPlanner

An **Ashita v4 addon for Final Fantasy XI** that plans routes between zones and shows where to go next. Built for use on CatsEyeXI; the bundled world data comes from LandSandBoat. No network connection or Python installation is required in-game.

[Download the latest release](https://github.com/lord-daeloth/TravelPlanner/releases/latest) · [Report an issue](https://github.com/lord-daeloth/TravelPlanner/issues)

## Features

- Choose a starting zone or use your current zone.
- Filter each zone selector by region and text search, with an **All** regions option.
- Choose **Fastest** for the fewest zone changes or **Least dangerous** for the lowest average enemy level across the route.
- Walk by default, with optional boats, airships and unlocked Cavernous Maw connections.
- Review access requirements and optionally exclude flagged connections.
- Expand to plan and review the complete route; collapse to see your current and next zone.
- Advance automatically as you zone and replan if you leave the route.
- Hide automatically during cutscenes and restore your previous window mode afterward.

## Installation

1. Download **TravelPlanner-v1.0.1.zip** from the [latest release](https://github.com/lord-daeloth/TravelPlanner/releases/latest). Use the attached addon ZIP rather than GitHub's automatically generated source archive.
2. Extract it into your `Ashita/addons/` directory. The result should be `Ashita/addons/TravelPlanner/TravelPlanner.lua`.
3. In game, run:

```text
/addon load TravelPlanner
/tp show
```

To update, replace the addon files with the new release and run `/addon reload TravelPlanner`. Preferences are stored separately in Ashita's per-character settings directory.

## Planning a route

1. Enable **Start in current zone**, or turn it off and choose a starting zone.
2. Select a destination using its region dropdown and optional search filter.
3. Choose a routing mode and any optional connection types.
4. Select **Plan route**, then **Collapse** if you only need the next step.

Region and search filters apply together and do not silently change an existing selection. Changing route options clears the previous plan. A manually chosen starting zone can be used to preview a trip before you travel there. Routes are kept for the current session; preferences persist per character.

| Command | Action |
| --- | --- |
| `/tp` | Toggle the window |
| `/tp show` / `/tp hide` | Show or hide the window |
| `/tp expand` / `/tp collapse` | Switch window mode |
| `/tp plan` | Plan using the current selections |
| `/tp clear` | Clear the route |

`/travelplanner` also accepts all of these commands. Manually hiding the window keeps it hidden after a cutscene.

## How routes are scored

**Fastest** minimizes zone changes, not walking distance or elapsed time. Boarding and leaving a boat or airship count separately; departure waits are not modeled.

**Least dangerous** minimizes the average of the zone-average enemy levels, including the starting zone and destination. Every zone has equal weight; a zone cannot repeat, and ties prefer fewer changes. This can intentionally choose longer detours through low-level zones. It does not minimize the strongest monster you might encounter.

The search runs incrementally to keep the interface responsive. Until it finishes, results are labeled **best found**. You may select **Use best found route** to stop early. Beginning travel freezes the chosen route so re-optimizing the average does not send you back through zones already visited.

## Data and limitations

The bundled dataset contains **295 zones and 522 directed connections**. Enemy averages exclude notorious monsters and scripted/event-only enemies. **74 zones have unknown averages**; these are marked and scored conservatively as 150 rather than treated as safe.

- LandSandBoat data may differ from CatsEyeXI's levels, available content and custom travel.
- A zone sequence does not model exact walking directions, disconnected map sections, one-way interior drops or every locked door.
- Requirement notes are not exhaustive and are not checked against your character's missions or key items.
- NPC/event entrances and special travel are not exhaustively covered. “No route” means no route in the available data with the selected options.

See [data sources and limitations](docs/DATA.md) for the averaging method, provenance, coverage and editable overrides.

## Development and credits

[Development instructions](docs/DEVELOPMENT.md) cover rebuilding data, running the LuaJIT tests and creating release ZIPs. [Changelog](CHANGELOG.md) lists release changes.

World data is derived from [LandSandBoat](https://github.com/LandSandBoat/server). TravelPlanner and its derived data are distributed under **GPL-3.0-or-later**; see [LICENSE](LICENSE) and [LICENSE-DATA.txt](LICENSE-DATA.txt).
