#!/usr/bin/env python3
"""Build only the Swift source closure of the embedded Trio entry point."""
from pathlib import Path
import re
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / 'Vendor/StatusTrio/Sources/StatusTrioCore'


def source_closure():
    excluded = {'App/AppDelegate.swift', 'App/AppEnvironment.swift', 'UI/StatusBarController.swift',
                'App/UpdaterManager.swift', 'App/UpdateFallbackUserDriver.swift',
                'App/UpdateSourceFallback.swift', 'App/PrivilegedHelperManager.swift'}
    files = {}
    for p in CORE.rglob('*.swift'):
        relative = str(p.relative_to(CORE))
        if relative in excluded:
            continue
        if relative.startswith('Telemetry/') and p.name != 'TelemetryConsent.swift':
            continue
        if relative.startswith('UI/Settings/') and p.name not in ['AppMetadata.swift', 'DevelopmentBuildPresentation.swift']:
            continue
        files[p] = p.read_text()
    declarations = {}
    extensions = {}
    for p, s in files.items():
        for name in re.findall(r'^(?:(?:public|private|internal|final|indirect|nonisolated)\s+)*(?:struct|enum|class|protocol|typealias|func|let|var)\s+(\w+)', s, re.M):
            declarations.setdefault(name, set()).add(p)
        for name in re.findall(r'^extension\s+(\w+)', s, re.M):
            extensions.setdefault(name, set()).add(p)
    selected = {p for p in files if p.parent.name == 'Embedding'}
    while True:
        tokens = set(re.findall(r'\b[A-Za-z_]\w*\b', '\n'.join(files[p] for p in selected)))
        added = set().union(*(declarations.get(t, set()) | extensions.get(t, set()) for t in tokens))
        if added <= selected:
            break
        selected |= added
    return sorted(selected)


def main():
    helpers = runpy.run_path(str(ROOT / 'Scripts/build-frameworks.py'))
    run, framework, sdk = helpers['run'], helpers['framework'], helpers['SDK']
    croot = ROOT / 'Vendor/StatusTrio/Sources/DDCPrivateAPI'
    module = ROOT / 'build/ClangModules/DDCPrivateAPI'
    module.mkdir(parents=True, exist_ok=True)
    (module / 'module.modulemap').write_text('module DDCPrivateAPI { header "' + str(croot / 'include/DDCPrivateAPI.h') + '" export * }\n')
    obj = ROOT / 'build/Objects/ddc.o'
    run(['xcrun', 'clang', '-fobjc-arc', '-isysroot', sdk, '-mmacosx-version-min=15.0',
         '-I', croot / 'include', '-c', croot / 'DDCPrivateAPI.m', '-o', obj])
    sources = source_closure()
    (ROOT / 'build/trio-included-sources.txt').write_text('\n'.join(str(p.relative_to(CORE)) for p in sources))
    print(f'Embedding {len(sources)} Trio source files', flush=True)
    framework('TrioEmbedded', [str(p) for p in sources], objects=[obj],
              libs=['-framework', 'IOKit', '-framework', 'CoreAudio', '-framework', 'CoreDisplay'], language='6')
    shutil.copytree(CORE / 'Resources', ROOT / 'build/Frameworks/TrioEmbedded.framework/Resources', dirs_exist_ok=True)


if __name__ == '__main__':
    main()
