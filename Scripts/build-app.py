#!/usr/bin/env python3
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import uuid
import os

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'build/Stats Trio.app'


def copy_image_assets(source_root, destination):
    # Image-set groups can be nested under devices/ and other asset-catalog groups.
    for catalog in source_root.rglob('*.xcassets'):
        for folder in catalog.rglob('*.imageset'):
            data = json.loads((folder / 'Contents.json').read_text())
            image = next((x.get('filename') for x in data.get('images', []) if x.get('filename')), None)
            if image:
                source = folder / image
                shutil.copy2(source, destination / (folder.stem + source.suffix))


def assemble(app):
    contents = app / 'Contents'
    for name in ['MacOS', 'Resources', 'Frameworks']:
        (contents / name).mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / 'Stats/Supporting Files/Info.plist', contents / 'Info.plist')
    notices = contents / 'Resources/Licenses'
    notices.mkdir(parents=True, exist_ok=True)
    for source, name in [
        (ROOT / 'LICENSE', 'Stats-MIT.txt'),
        (ROOT / 'Vendor/StatusTrio/LICENSE', 'StatusTrio-Apache-2.0.txt'),
        (ROOT / 'Vendor/StatusTrio/NOTICE', 'StatusTrio-NOTICE.txt'),
        (ROOT / 'Vendor/StatusTrio/Sources/DDCPrivateAPI/LICENSE-AppleSiliconDDC.txt', 'DDC.txt'),
        (ROOT / 'Kit/lldb/LICENSE.txt', 'LevelDB.txt')
    ]:
        if source.exists():
            shutil.copy2(source, notices / name)
    shutil.copytree(ROOT / 'build/Frameworks', contents / 'Frameworks', dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('.input-hash'))
    for stamp in (contents / 'Frameworks').glob('*.framework/.input-hash'):
        stamp.unlink()
    for folder in (ROOT / 'Stats/Supporting Files').glob('*.lproj'):
        shutil.copytree(folder, contents / 'Resources' / folder.name, dirs_exist_ok=True)
    copy_image_assets(ROOT / 'Stats', contents / 'Resources')
    iconset = app.parent / 'StatsTrio.iconset'
    subprocess.run(['xcrun', 'swift', str(ROOT / 'Scripts/make-icon.swift'), str(iconset)], check=True)
    subprocess.run(['iconutil', '-c', 'icns', '-o', str(contents / 'Resources/StatsTrio.icns'), str(iconset)], check=True)
    args = ['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5', '-target',
            'arm64-apple-macos15.0', '-module-name', 'Stats',
            '-F', str(ROOT / 'build/Frameworks'), '-I', str(ROOT / 'build/ClangModules'), '-o', str(contents / 'MacOS/StatsTrio'),
            '-Xlinker', '-rpath', '-Xlinker', '@executable_path/../Frameworks']
    args += ['-O', '-whole-module-optimization', '-Xlinker', '-dead_strip'] if os.environ.get('STATS_TRIO_CONFIGURATION', 'Release') == 'Release' else ['-g', '-Onone']
    for name in ['Kit', 'CPU', 'RAM', 'Net', 'Sensors', 'TrioEmbedded']:
        args += ['-framework', name]
    sources = [ROOT / 'Stats/AppDelegate.swift', ROOT / 'Stats/Views/CombinedView.swift']
    for folder in ['Stats/Integration', 'Stats/IntegrationCore', 'Stats/Views/Embedded']:
        if (ROOT / folder).exists():
            sources += sorted((ROOT / folder).glob('*.swift'))
    args += [str(p) for p in sources]
    subprocess.run(args, cwd=ROOT, check=True)
    for framework in (contents / 'Frameworks').glob('*.framework'):
        subprocess.run(['codesign', '--force', '--sign', '-', str(framework)], check=True)
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
    subprocess.run(['python3', str(ROOT / 'Scripts/verify-bundle.py'), str(app)], check=True)


def main():
    APP.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.stats-trio-stage-', dir=APP.parent))
    bundle = stage / APP.name
    backup = None
    try:
        assemble(bundle)
        if APP.exists():
            backup = APP.parent / ('.stats-trio-previous-' + uuid.uuid4().hex + '.app')
            APP.rename(backup)
        try:
            bundle.rename(APP)
        except BaseException:
            if backup is not None:
                backup.rename(APP)
            raise
        if backup is not None:
            shutil.rmtree(backup)
        print(APP)
    finally:
        shutil.rmtree(stage)


if __name__ == '__main__':
    main()
