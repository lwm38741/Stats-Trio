import contextlib
import io
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FrameworkCacheTests(unittest.TestCase):
    def test_recompiles_subclass_when_parent_framework_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            helpers = runpy.run_path(str(ROOT / 'Scripts/build-frameworks.py'))
            build = helpers['framework']
            build.__globals__['ROOT'] = root
            build.__globals__['OUT'] = root / 'Frameworks'
            base = root / 'Base.swift'
            child = root / 'Child.swift'
            base.write_text('import Foundation\nopen class Parent: NSObject { public var value = 1 }\n')
            child.write_text('import Kit\npublic class Child: Parent {}\n')
            build('Kit', [str(base)])
            build('CPU', [str(child)], libs=['-framework', 'Kit'])
            with contextlib.redirect_stdout(io.StringIO()) as unchanged:
                build('CPU', [str(child)], libs=['-framework', 'Kit'])
            self.assertIn('Cached CPU', unchanged.getvalue())
            base.write_text('import Foundation\nopen class Parent: NSObject { public var value = 1; public var extra = 2 }\n')
            build('Kit', [str(base)])
            with contextlib.redirect_stdout(io.StringIO()) as changed:
                build('CPU', [str(child)], libs=['-framework', 'Kit'])
            self.assertIn('Built CPU', changed.getvalue())
