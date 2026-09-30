"""Build a deterministic install ZIP and checksum using Python's standard library."""
from pathlib import Path
import hashlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    'TravelPlanner.lua', 'controller.lua', 'planner.lua', 'data/zones.lua',
    'README.md', 'CHANGELOG.md', 'LICENSE', 'LICENSE-DATA.txt',
    'docs/DATA.md', 'docs/DEVELOPMENT.md',
)


def build():
    source = (ROOT / 'TravelPlanner.lua').read_text(encoding='utf-8')
    match = re.search(r"addon\.version\s*=\s*'([0-9]+\.[0-9]+\.[0-9]+)'", source)
    if not match:
        raise ValueError('addon.version must be a three-part numeric version')
    version = match.group(1)
    inputs = {name: (ROOT / name).read_text(encoding='utf-8').encode('utf-8') for name in FILES}
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    target = dist / f'TravelPlanner-v{version}.zip'
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, content in sorted(inputs.items()):
            entry = zipfile.ZipInfo(f'TravelPlanner/{name}', date_time=(2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, content)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == {f'TravelPlanner/{name}' for name in FILES}
        for name, content in inputs.items():
            assert archive.read(f'TravelPlanner/{name}') == content
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_suffix('.zip.sha256').write_text(f'{digest}  {target.name}\n', encoding='ascii')
    print(f'Built and verified {target.name}: {len(FILES)} files, {target.stat().st_size:,} bytes')
    print(f'SHA-256: {digest}')
    return target


if __name__ == '__main__':
    build()
