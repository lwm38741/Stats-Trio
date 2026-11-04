#!/usr/bin/env python3
"""Verify the independent local bundle without installing or launching it."""
import plistlib
import sys
from pathlib import Path


def verify(app):
    contents = app / 'Contents'
    info = plistlib.loads((contents / 'Info.plist').read_bytes())
    identity = info.get('CFBundleIdentifier')
    if identity != 'local.statstrio.app':
        raise ValueError(f'Conflicting bundle identity: {identity}')
    if info.get('CFBundleName') != 'Stats Trio':
        raise ValueError('Unexpected product name')
    if info.get('LSMinimumSystemVersion') != '15.0':
        raise ValueError('Expected macOS minimum 15.0')
    if any(key.startswith('SU') for key in info):
        raise ValueError('Updater configuration must be absent')
    if not (contents / 'MacOS' / info['CFBundleExecutable']).is_file():
        raise ValueError('Missing executable')
    for folder in ['Library/LaunchServices', 'Library/LaunchDaemons', 'Library/LoginItems']:
        if (contents / folder).exists():
            raise ValueError(f'Unexpected embedded helper: {folder}')


if __name__ == '__main__':
    try:
        verify(Path(sys.argv[1]))
        print('Independent bundle verified')
    except (ValueError, OSError, KeyError, IndexError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
