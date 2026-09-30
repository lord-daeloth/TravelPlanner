"""Build offline Lua + JSON data from a pinned LandSandBoat revision.

Run: python tools/build_data.py [--download]
Requires PyYAML. Cached source files are ignored by Git. No game dependency.
"""
from pathlib import Path
import argparse
import concurrent.futures
import hashlib
import json
import re
import urllib.request
import urllib.parse
import yaml

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'tools' / 'cache'
REVISION = '6c421d33414cf4a7fb3434930def196e4b3a97cb'
BASE = f'https://raw.githubusercontent.com/LandSandBoat/server/{REVISION}/'
LOADER = getattr(yaml, 'CSafeLoader', yaml.SafeLoader)
SCRIPTED_WALKS = {
    'Northern_San_dOria': [(231, 233, 'Chateau access requires national rank/mission progress; certain mission states temporarily block entry.')],
    'Windurst_Walls': [(239, 242, None)], 'Heavens_Tower': [(242, 239, None)],
    'Lower_Delkfutts_Tower': [(184, 157, None)],
    'Middle_Delkfutts_Tower': [(157, 184, None), (157, 158, None)],
    'Upper_Delkfutts_Tower': [(158, 157, None), (158, 179, None)],
    'Stellar_Fulcrum': [(179, 158, None)],
    'The_Garden_of_RuHmet': [(35, 36, 'Chains of Promathia progression and interior access.')],
    'Empyreal_Paradox': [(36, 35, 'Chains of Promathia progression and interior access.')],
}


def read(path):
    return (CACHE / path.replace('/', '__')).read_text(encoding='utf-8')


def document(path):
    return yaml.load(read(path), Loader=LOADER) or {}


def download():
    CACHE.mkdir(exist_ok=True)
    tree = json.load(urllib.request.urlopen(
        f'https://api.github.com/repos/LandSandBoat/server/git/trees/{REVISION}?recursive=1', timeout=60))
    paths = [x['path'] for x in tree['tree'] if x['path'].startswith('data/zones/')
             and x['path'].endswith(('/zone.yaml', '/mobs.yaml'))]
    paths += ['data/enums/zone.yaml', 'sql/zone_settings.sql', 'src/map/utils/zoneutils.cpp',
              'scripts/globals/maws.lua', 'LICENSE']
    paths += [f'scripts/zones/{name}/Zone.lua' for name in SCRIPTED_WALKS]

    def fetch(path):
        target = CACHE / path.replace('/', '__')
        # Refresh all sources together so a build never silently mixes revisions.
        target.write_bytes(urllib.request.urlopen(BASE + urllib.parse.quote(path), timeout=60).read())
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(fetch, paths))
    print(f'Downloaded {len(paths)} source files at {REVISION}')


def normalized(value):
    return re.sub('[^a-z0-9]', '', value.lower())


REGIONS = {
    'SANDORIA': "San d'Oria", 'QUFIMISLAND': 'Qufim Island', 'LITELOR': "Li\'Telor",
    'TULIA': "Tu'Lia", 'TAVNAZIANARCH': 'Tavnazian Archipelago',
    'TAVNAZIAN_MARQ': 'Tavnazian Marquisate', 'WEST_AHT_URHGAN': 'West Aht Urhgan',
    'MAMOOL_JA_SAVAGE': 'Mamool Ja Savagelands', 'HALVUNG': 'Halvung Territory',
    'ARRAPAGO': 'Arrapago Islands', 'ALZADAAL': 'Ruins of Alzadaal',
    'SARUTA_FRONT': 'Sarutabaruta Front', 'ARAGONEAU_FRONT': 'Aragoneu Front',
    'EAST_ULBUKA': 'East Ulbuka', 'UNKNOWN': 'Other Areas',
}
REPLACEMENTS = {
    'dOria': "d'Oria", 'dOraguille': "d'Oraguille", 'PsoXja': "Pso'Xja",
    'AlTaieu': "Al'Taieu", 'HuXzoi': "Hu'Xzoi", 'RuHmet': "Ru'Hmet", 'RuAun': "Ru'Aun",
    'RuLude': "Ru'Lude", 'RuAvitau': "Ru'Avitau", 'VeLugannon': "Ve'Lugannon",
    'RoMaeve': "Ro'Maeve", 'ZiTah': "Zi'Tah", 'FeiYin': "Fei'Yin", 'QuBia': "Qu'Bia",
    'RaKaznar': "Ra'Kaznar", 'Delkfutts': "Delkfutt's", 'Ranperres': "Ranperre's",
    'Ordelles': "Ordelle's", 'Crawlers': "Crawlers'", 'Balgas': "Balga's",
    'Behemoths': "Behemoth's", 'Dragons': "Dragon's", 'Carpenters': "Carpenters'",
    'Ifrits': "Ifrit's", 'Sealions': "Sealion's", 'Ghoyus': "Ghoyu's",
    'Heavens': "Heavens", 'Dhalmels': "Dhalmel's",
    'LaLoff': "La'Loff",
    'Riverne-Site A01': 'Riverne - Site #A01', 'Riverne-Site B01': 'Riverne - Site #B01',
}


def pretty(value):
    value = value.replace('_', ' ')
    for old, new in REPLACEMENTS.items():
        value = value.replace(old, new)
    return value


def lua(value):
    if value is None: return 'nil'
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return repr(value)
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list): return '{' + ', '.join(lua(x) for x in value) + '}'
    return '{' + ', '.join('[' + lua(k) + '] = ' + lua(v) for k, v in value.items()) + '}'


def build():
    ids = document('data/enums/zone.yaml')['values']
    by_normal = {normalized(k): v for k, v in ids.items()}
    names = {int(i): pretty(n) for i, n in re.findall(
        r"VALUES \((\d+),'[^']*',\d+,'([^']+)'\)", read('sql/zone_settings.sql'))}
    regions = {}
    code = read('src/map/utils/zoneutils.cpp').split('auto GetCurrentRegion', 1)[1].split('auto GetCurrentContinent', 1)[0]
    pending = []
    for line in code.splitlines():
        match = re.search(r'case xi::ZoneId::(\w+):', line)
        if match: pending.append(by_normal[normalized(match[1])])
        match = re.search(r'return REGION_TYPE::(\w+);', line)
        if match:
            key = match[1]
            for id_ in pending: regions[id_] = REGIONS.get(key, key.replace('_', ' ').title())
            pending = []
    zones, settings = {}, {}
    for key, id_ in ids.items():
        if key in ('unknown', 'none', 'mordion_gaol', 'gm_home') or id_ not in names or names[id_].isdigit(): continue
        f = CACHE / f'data__zones__{key}__zone.yaml'
        settings[id_] = document(f'data/zones/{key}/zone.yaml') if f.exists() else {}
        zones[id_] = dict(id=id_, key=key, name=names[id_], region=regions.get(id_, 'Other Areas'),
                          average_level=None, enemy_count=0, level_status='unknown', connections=[],
                          source=BASE + f'data/zones/{key}/zone.yaml')
        mf = CACHE / f'data__zones__{key}__mobs.yaml'
        if mf.exists():
            data = document(f'data/zones/{key}/mobs.yaml')
            groups = {}
            for spawn in data.get('spawns', {}).values():
                template = data.get('templates', {}).get(spawn.get('template'), {})
                excluded = {'notorious', 'battlefield', 'fished', 'event', 'called', 'unused'}
                attr = template.get('attributes', {})
                override = spawn.get('attributes', {})
                st = set(attr.get('spawn', {}).get('type', [])) | set(override.get('spawn', {}).get('type', []))
                if excluded.intersection(template.get('type', [])) or 'scripted' in st: continue
                levels = spawn.get('level')
                if not levels: continue
                if isinstance(levels, int): levels = [levels, levels]
                if not isinstance(levels, list) or len(levels) != 2 or min(levels) <= 0: continue
                name = spawn.get('name', spawn.get('template'))
                old = groups.get(name, levels)
                groups[name] = [min(old[0], levels[0]), max(old[1], levels[1])]
            if groups:
                zones[id_].update(average_level=round(sum((a+b)/2 for a,b in groups.values()) / len(groups), 4),
                                  enemy_count=len(groups), level_status='normal_enemies',
                                  level_source=BASE + f'data/zones/{key}/mobs.yaml')
        if 'city' in settings[id_].get('type', []) and not zones[id_]['enemy_count']:
            zones[id_].update(average_level=0, level_status='city_no_normal_enemies')

    def edge(a, b, kind='walk', **kw):
        if a in zones and b in zones and a != b:
            zones[a]['connections'].append(dict(to=b, kind=kind, **kw))

    for id_, data in settings.items():
        destinations = {}
        for key, line in data.get('zonelines', {}).items():
            to = ids.get(line.get('to'))
            if to == id_ or to not in zones: continue
            destinations.setdefault(to, []).append(dict(id=key, position=line.get('from'), arrival=line.get('at')))
        for to, exits in destinations.items():
            edge(id_, to, exits=exits, source=zones[id_]['source'])

    for name, transitions in SCRIPTED_WALKS.items():
        source = f'scripts/zones/{name}/Zone.lua'
        text = read(source)
        for a, b, requirement in transitions:
            assert re.search(r'setPos\([^\n]+,\s*' + str(b) + r'\)', text), (source, b)
            kw = dict(source=BASE + source, note='Adjacent scripted entrance/exit; interact or cross its trigger.')
            if requirement: kw['requirement'] = requirement
            edge(a, b, **kw)

    # Explicit itineraries preserve the vessel zone so "fastest" counts both
    # boarding and disembarking. Dock YAML's voyage is the ARRIVING vessel.
    voyages = [
        ('selbina','ship_bound_for_mhaura','mhaura','boat','Ferry fare and departure schedule.'),
        ('mhaura','ship_bound_for_selbina','selbina','boat','Ferry fare and departure schedule.'),
        ('mhaura','open_sea_route_to_al_zahbi','aht_urhgan_whitegate','boat','Boarding permit, fare and departure schedule.'),
        ('aht_urhgan_whitegate','open_sea_route_to_mhaura','mhaura','boat','Fare and departure schedule.'),
        ('aht_urhgan_whitegate','silver_sea_route_to_nashmau','nashmau','boat','Fare and departure schedule.'),
        ('nashmau','silver_sea_route_to_al_zahbi','aht_urhgan_whitegate','boat','Fare and departure schedule.'),
    ]
    for port, vessel, permit in [('port_san_doria','san_doria_jeuno_airship','Airship pass'),
                                ('port_bastok','bastok_jeuno_airship','Airship pass'),
                                ('port_windurst','windurst_jeuno_airship','Airship pass'),
                                ('kazham','kazham_jeuno_airship','Kazham airship pass')]:
        voyages += [(port,vessel,'port_jeuno','airship',permit + ', fare and departure schedule.'),
                    ('port_jeuno',vessel,port,'airship',permit + ', fare and departure schedule.')]
    for origin, vessel, target, kind, requirement in voyages:
        for a,b in [(origin,vessel),(vessel,target)]:
            edge(ids[a], ids[b], kind, requirement=requirement, source=BASE+f'data/zones/{origin}/zone.yaml')
    for port, vessel, script in [('bibiki_bay', 'manaclipper', 'Bibiki_Bay'), ('carpenters_landing', 'phanauet_channel', 'Carpenters_Landing')]:
        for a,b in [(port,vessel),(vessel,port)]:
            edge(ids[a], ids[b], 'boat', requirement='Ticket and departure schedule; stops are separate sections of the same shore zone.',
                 source=BASE+f'scripts/zones/{script}/Zone.lua')
    for vessel, target in [('ship_bound_for_selbina_pirates','selbina'), ('ship_bound_for_mhaura_pirates','mhaura')]:
        edge(ids[vessel],ids[target],'boat',note='Ferry exit after pirate voyage.',source=BASE+f'data/zones/{vessel}/zone.yaml')
    # Verified fixed WotG maw destinations; introductory random warps excluded.
    for key, target in re.findall(r'\[xi.zone.(\w+)\].*?dest = \{[^}]*,\s*(\d+)\s*\}', read('scripts/globals/maws.lua')):
        edge(ids[key.lower()], int(target), 'portal', requirement='Cavernous Maw unlocked; Wings of the Goddess access. Initial random entry is not modeled.',
             source=BASE+'scripts/globals/maws.lua')

    overrides = json.loads((ROOT/'data'/'overrides.json').read_text())
    for key, update in overrides.get('zones', {}).items(): zones[int(key)].update(update)
    for update in overrides.get('connections', []):
        update = dict(update); origin = update.pop('from')
        found = False
        for e in zones[origin]['connections']:
            if e['to'] == update['to'] and e['kind'] == update.get('kind', 'walk'):
                e.update(update); found = True
        if not found: edge(origin, **{'b': update.pop('to')}, **update)
    # Nodes with complex interior access retain conservative, visible warnings.
    for z in zones.values():
        for e in z['connections']:
            notes = [zones[e['to']].get('access_note'), z.get('access_note')]
            if any(notes) and not e.get('requirement'): e['requirement'] = ' '.join(dict.fromkeys(x for x in notes if x))
        z['connections'].sort(key=lambda e: (e['to'], e['kind']))
    payload = dict(schema=1, revision=REVISION, source='LandSandBoat', zones=zones)
    (ROOT/'data'/'zones.json').write_text(json.dumps(payload, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    lines = ['-- Generated by tools/build_data.py; edit data/overrides.json and rebuild.', '-- LandSandBoat-derived data: GPL-3.0-or-later; see LICENSE-DATA.txt.', 'return {']
    lines += [f'    [{id_}] = {lua(z)},' for id_,z in sorted(zones.items())]
    (ROOT/'data'/'zones.lua').write_text('\n'.join(lines)+'\n}\n', encoding='utf-8')
    manifest = dict(revision=REVISION, zones=len(zones), connections=sum(len(z['connections']) for z in zones.values()),
                    unknown_levels=[z['id'] for z in zones.values() if z['average_level'] is None],
                    no_outgoing_connections=[z['id'] for z in zones.values() if not z['connections']],
                    sources={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(CACHE.iterdir())
                             if f.is_file() and ((f.name.startswith('data__zones__') and f.name.endswith(('__zone.yaml', '__mobs.yaml'))) or f.name in
                             ['data__enums__zone.yaml'] +
                             ['src__map__utils__zoneutils.cpp','scripts__globals__maws.lua','sql__zone_settings.sql','LICENSE']
                             or f.name in [f'scripts__zones__{name}__Zone.lua' for name in SCRIPTED_WALKS])})
    (ROOT/'data'/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    (ROOT/'LICENSE-DATA.txt').write_text(read('LICENSE'), encoding='utf-8')
    print(f"Built {manifest['zones']} zones, {manifest['connections']} directed connections; {len(manifest['unknown_levels'])} unknown enemy averages")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    if args.download: download()
    build()
