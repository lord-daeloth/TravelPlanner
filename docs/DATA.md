# Data sources and limitations

Zone names, connections and ordinary-enemy levels are derived from [LandSandBoat](https://github.com/LandSandBoat/server/tree/6c421d33414cf4a7fb3434930def196e4b3a97cb), pinned to revision `6c421d33414cf4a7fb3434930def196e4b3a97cb`. BG Wiki was unavailable during data collection and is not the source of this release's dataset.

- `data/zones.lua`: runtime table keyed by numeric zone ID, with name, region, connections, average level, sample count and source URLs.
- `data/zones.json`: readable equivalent for inspection and other tools.
- `data/overrides.json`: reviewed corrections, region labels, access cautions and server-specific adjustments; applied after source import.
- `data/manifest.json`: source revision, source hashes, counts, zones with unknown levels and zones with no known outgoing connections.

The catalog has **295 zones and 522 directed connections**. It includes expansion and instance zones even when the source supplies no routable entrance. GM/test placeholders are excluded where identified. The connection set combines physical zone lines, reviewed adjacent scripted entrances, standard ferry/airship itineraries and fixed unlocked WotG Maw destinations. It does **not** claim exhaustive coverage of NPC/event entrances, missions, battlefield entry, Home Points, Survival Guides, teleport spells, outpost warps or CatsEyeXI custom travel. A no-route result means **no route in the available graph and selected options**.

Region assignments come from LandSandBoat's `GetCurrentRegion`, supplemented by explicit overrides for later areas. The **Other Areas** group preserves zones lacking a more specific assignment. **Escha / Reisenjima** is a convenience grouping.

Enemy levels come from per-zone `mobs.yaml`. For each ordinary enemy name/template, combine its observed spawn ranges into a minimum/maximum, take that range's midpoint, then average the midpoints with equal weight per enemy name. Notorious monsters, battlefield mobs, fished enemies, event mobs, called mobs, unused mobs and scripted-only spawns are excluded. This approximates a normal-enemy wiki table; it is not weighted by spawn population or aggro behavior. **74 zones have unknown averages**, mainly battlefields/instances and unimplemented content. Empty or unavailable data is not automatically considered safe.

These are **LandSandBoat levels, not verified CatsEyeXI levels**. Retail-era high-level monsters and server-specific changes can affect rankings. Access notes are conservative, manually reviewed cautions and are not an exhaustive inventory of prerequisites. The addon does not inspect mission/key-item ownership.

The graph treats a zone as one node. Disconnected map sections, one-way interior drops, gates, elevators and local terrain can make a sequence of zone names impractical from a particular entrance. Complex dungeon routes show access cautions, but this addon is a zone-sequence planner, not an intra-zone navigator. Exit coordinates retained in the dataset are raw game coordinates, not map-grid directions.

LandSandBoat-derived data is distributed under **GPL-3.0-or-later**; the license is in `LICENSE-DATA.txt`. Source URLs and the importer preserve attribution and reproducibility. TravelPlanner's newly written Lua and tooling are also available under GPL-3.0-or-later.
