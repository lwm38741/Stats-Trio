#!/usr/bin/env python3
"""Compile the upstream AppKit frameworks with the installed Apple CLT."""
import os
import hashlib
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/Frameworks'
SDK = subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
CONFIGURATION = os.environ.get('STATS_TRIO_CONFIGURATION', 'Release')


def run(args):
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True)


def framework(name, paths, bridge=None, objects=(), libs=(), language='5'):
    dest = OUT / (name + '.framework')
    module = dest / 'Modules' / (name + '.swiftmodule')
    module.mkdir(parents=True, exist_ok=True)
    resources = dest / 'Resources'
    resources.mkdir(exist_ok=True)
    info = {'CFBundleIdentifier': 'local.statstrio.' + name.lower(),
            'CFBundleName': name, 'CFBundleExecutable': name,
            'CFBundlePackageType': 'FMWK', 'CFBundleVersion': '1'}
    (resources / 'Info.plist').write_bytes(plistlib.dumps(info))
    args = ['xcrun', 'swiftc', '-swift-version', language, '-target', 'arm64-apple-macos15.0',
            '-sdk', SDK, '-enable-testing', '-emit-library', '-emit-module',
            '-module-name', name, '-emit-module-path', module / 'arm64.swiftmodule',
            '-F', OUT, '-o', dest / name, '-Xlinker', '-install_name',
            '-Xlinker', '@rpath/' + name + '.framework/' + name]
    args += ['-I', ROOT / 'build/ClangModules']
    args += ['-O', '-Xlinker', '-dead_strip'] if CONFIGURATION == 'Release' else ['-g', '-Onone']
    if language == '6':
        args += ['-whole-module-optimization']
    args += paths + list(objects) + list(libs)
    digest = hashlib.sha256(repr([str(a) for a in args]).encode())
    for path in paths + list(objects) + ([bridge] if bridge else []):
        digest.update(Path(path).read_bytes())
    # Swift subclasses are not resilient against unrebuilt superclass layout changes.
    for index, flag in enumerate(libs[:-1]):
        if flag == '-framework':
            dependency = OUT / (libs[index + 1] + '.framework') / libs[index + 1]
            if dependency.exists():
                digest.update(dependency.read_bytes())
    stamp = dest / '.input-hash'
    if (dest / name).exists() and stamp.exists() and stamp.read_text() == digest.hexdigest():
        print('Cached ' + name, flush=True)
        return
    run(args)
    stamp.write_text(digest.hexdigest())
    print('Built ' + name, flush=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, header in [('LLDBBridge', 'Kit/lldb/lldb.h'), ('CPUBridge', 'Modules/CPU/bridge.h'),
                         ('SensorBridge', 'Modules/Sensors/bridge.h')]:
        folder = ROOT / 'build/ClangModules' / name
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'bridge.h').write_text('#import <Foundation/Foundation.h>\n#import "' + str(ROOT / header) + '"\n')
        (folder / 'module.modulemap').write_text('module ' + name + ' { header "bridge.h" export * }\n')
    obj = ROOT / 'build/Objects'
    obj.mkdir(exist_ok=True)
    run(['xcrun', 'clang++', '-x', 'objective-c++', '-std=c++17', '-fobjc-arc',
         '-isysroot', SDK, '-mmacosx-version-min=15.0', '-O2', '-IKit/lldb', '-IKit/lldb/include', '-c',
         'Kit/lldb/lldb.m', '-o', obj / 'lldb.o'])
    kit = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'Kit').rglob('*.swift'))
    framework('Kit', kit + ['SMC/Helper/protocol.swift', 'SMC/smc.swift'], 'Kit/lldb/lldb.h',
              [obj / 'lldb.o', 'Kit/lldb/libleveldb.a'], ['-lc++'])
    for name in ['CPU', 'RAM', 'Net', 'Sensors']:
        folder = ROOT / 'Modules' / name
        sources = sorted(str(p.relative_to(ROOT)) for p in folder.glob('*.swift'))
        bridge = None
        objects = []
        libs = ['-framework', 'Kit']
        if name in ['CPU', 'Sensors']:
            sources += ['SMC/smc.swift']
            bridge = 'Modules/' + name + '/bridge.h'
            libs += ['-lIOReport']
        if name == 'Sensors':
            run(['xcrun', 'clang', '-fobjc-arc', '-isysroot', SDK, '-mmacosx-version-min=15.0',
                 '-c', 'Modules/Sensors/reader.m', '-o', obj / 'sensors.o'])
            objects.append(obj / 'sensors.o')
        framework(name, sources, bridge, objects, libs)
        shutil.copy2(folder / 'config.plist', OUT / (name + '.framework/Resources/config.plist'))


if __name__ == '__main__':
    main()
