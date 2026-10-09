"""Unpack the administrator-pinned scientific archive; reject path escapes."""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path, PurePosixPath


def unpack(archive, pin_file, destination):
    archive, destination = Path(archive), Path(destination)
    pin = json.loads(Path(pin_file).read_text())
    if hashlib.sha256(archive.read_bytes()).hexdigest() != pin['sha256']:
        raise ValueError('Scientific core checksum mismatch')
    with zipfile.ZipFile(archive) as source:
        names = source.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate archive paths')
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name:
                raise ValueError('Unsafe archive path')
            if path.parts[0] != 'SAGEhydrology':
                raise ValueError('Unexpected core directory')
        source.extractall(destination)
    root = destination / 'SAGEhydrology'
    manifest = json.loads((root / 'core-files.json').read_text())
    for name, expected in manifest.items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
            raise ValueError('Scientific dependency differs')
    return root


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('archive', type=Path)
    parser.add_argument('--pin', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    print(unpack(args.archive, args.pin, args.destination))
