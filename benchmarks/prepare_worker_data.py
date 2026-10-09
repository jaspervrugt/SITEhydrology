"""Fetch only approved CAMELS-US daily files from the fixed Zenodo record.

Remote ZIP ranges avoid downloading/extracting all three forcing products.
Every extracted numerical file must match the administrator's SHA-256 pin.
"""
import argparse
import hashlib
import io
import json
import re
import urllib.request
import zipfile
from pathlib import Path

BASE = 'https://zenodo.org/records/15529996/files/'
ZIP_URL = BASE + 'basin_timeseries_v1p2_metForcing_obsFlow.zip?download=1'


class RemoteZip(io.RawIOBase):
    def __init__(self):
        self.pos = 0
        self.size = None
        self.blocks = {}
        self._range(0, 0)

    def _range(self, start, end):
        request = urllib.request.Request(ZIP_URL, headers={
            'Range': f'bytes={start}-{end}', 'Accept-Encoding': 'identity',
            'User-Agent': 'SITE-benchmark-verifier'})
        with urllib.request.urlopen(request, timeout=90) as response:
            expected = re.fullmatch(r'bytes (\d+)-(\d+)/(\d+)',
                                    response.headers.get('Content-Range', ''))
            if response.status != 206 or expected is None:
                raise ValueError('Zenodo must support partial ZIP reads')
            first, last, size = map(int, expected.groups())
            if first != start or last != end or (self.size and self.size != size):
                raise ValueError('Unexpected archive range/version')
            self.size = size
            data = response.read(end - start + 2)
            if len(data) != end - start + 1:
                raise ValueError('Incomplete archive range')
            return data

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else ((self.pos if whence == 1 else self.size) + offset)
        if not 0 <= self.pos <= self.size:
            raise ValueError('Invalid archive position')
        return self.pos

    def tell(self):
        return self.pos

    def read(self, count=-1):
        if count < 0:
            count = self.size - self.pos
        count = min(count, self.size - self.pos)
        if not count:
            return b''
        output = bytearray()
        block_size = 256 * 1024
        while count:
            block = self.pos // block_size
            if block not in self.blocks:
                start = block * block_size
                self.blocks[block] = self._range(start, min(start + block_size, self.size) - 1)
                if len(self.blocks) > 32:
                    del self.blocks[next(iter(self.blocks))]
            offset = self.pos % block_size
            piece = self.blocks[block][offset:offset + count]
            output.extend(piece)
            self.pos += len(piece)
            count -= len(piece)
        return bytes(output)


def prepare(root, pin_file, basin_ids):
    root = Path(root)
    pins = json.loads(Path(pin_file).read_text())['files']
    needed = {k: v for k, v in pins.items() if not k.startswith('daily/')}
    for basin in basin_ids:
        if not re.fullmatch(r'\d{7,8}', str(basin)):
            raise ValueError('Unknown basin identifier')
        padded = str(basin).zfill(8)
        matches = {k: v for k, v in pins.items() if k.startswith('daily/')
                   and Path(k).name.startswith(padded + '_')}
        if len(matches) != 2:
            raise ValueError('Missing approved forcing/discharge pins')
        needed.update(matches)
    pending = {}
    for name, digest in needed.items():
        path = root / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            pending[name] = digest
    archive = None
    try:
        if any(k.startswith('daily/') for k in pending):
            archive = zipfile.ZipFile(RemoteZip())
        for name, digest in pending.items():
            if name.startswith('daily/v1p2/'):
                suffix = name[len('daily/v1p2/'):]
                if suffix.startswith('forcing/'):
                    suffix = 'basin_mean_forcing/' + suffix[len('forcing/'):]
                elif suffix.startswith('streamflow/'):
                    suffix = 'usgs_streamflow/' + suffix[len('streamflow/'):]
                matches = [i for i in archive.infolist()
                           if i.filename.endswith('/' + suffix)]
                if len(matches) != 1 or matches[0].file_size > 10 * 1024 * 1024:
                    raise ValueError('Unexpected archive entry')
                data = archive.read(matches[0])
            else:
                if '/' in name or not re.fullmatch(r'camels_[a-z]+\.txt', name):
                    raise ValueError('Unexpected metadata filename')
                with urllib.request.urlopen(BASE + name + '?download=1', timeout=90) as response:
                    data = response.read(2 * 1024 * 1024)
            if hashlib.sha256(data).hexdigest() != digest:
                raise ValueError(f'Official data differs from approved checksum: {name}')
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            print('Verified data:', name, flush=True)
    finally:
        if archive:
            archive.close()
    # Basin names are display metadata; the scientific attributes are pinned.
    (root / 'camels_name_clean.txt').write_bytes((root / 'camels_name.txt').read_bytes())
    print(f'Worker data ready: {len(basin_ids)} basin(s)', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=Path)
    parser.add_argument('--pins', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    args = parser.parse_args()
    payload = json.loads(args.candidate.read_text())
    records = payload['records']
    if isinstance(records, dict):
        records = [records]
    prepare(args.root, args.pins, sorted({r['basin'] for r in records}))
