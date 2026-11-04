import importlib.util
import plistlib
from pathlib import Path
import subprocess
import tempfile
import unittest
import runpy
import json
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class BundleVerificationTests(unittest.TestCase):
    def test_failed_compile_preserves_previous_bundle(self):
        helpers = runpy.run_path(str(ROOT / 'Scripts/build-app.py'))
        main = helpers['main']
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Stats/Supporting Files').mkdir(parents=True)
            (root / 'Stats/Supporting Files/Info.plist').write_bytes(b'new-info')
            (root / 'build/Frameworks').mkdir(parents=True)
            app = root / 'build/Stats Trio.app'
            (app / 'Contents').mkdir(parents=True)
            previous = app / 'Contents/Info.plist'
            previous.write_bytes(b'previous-info')
            main.__globals__['ROOT'] = root
            main.__globals__['APP'] = app
            with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, 'compiler')):
                with self.assertRaises(subprocess.CalledProcessError):
                    main()
            self.assertEqual(previous.read_bytes(), b'previous-info')

    def test_nested_asset_is_packaged(self):
        helpers = runpy.run_path(str(ROOT / 'Scripts/build-app.py'))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            asset = root / 'source/Assets.xcassets/devices/imacPro.imageset'
            asset.mkdir(parents=True)
            (asset / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'device.png'}]}))
            (asset / 'device.png').write_bytes(b'original-image-bytes')
            output = root / 'output'
            output.mkdir()
            helpers['copy_image_assets'](root / 'source', output)
            self.assertEqual((output / 'imacPro.png').read_bytes(), b'original-image-bytes')

    def test_rejects_original_identity_and_accepts_independent_bundle(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder) / 'Stats Trio.app'
            contents = app / 'Contents'
            (contents / 'MacOS').mkdir(parents=True)
            (contents / 'MacOS' / 'StatsTrio').write_text('fixture')
            info = {'CFBundleIdentifier': 'eu.exelban.Stats',
                    'CFBundleName': 'Stats Trio', 'CFBundleExecutable': 'StatsTrio',
                    'LSMinimumSystemVersion': '15.0'}
            def run():
                (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
                return subprocess.run(['python3', str(ROOT / 'Scripts/verify-bundle.py'), str(app)],
                                      text=True, capture_output=True)
            result = run()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('eu.exelban.Stats', result.stderr)
            info['CFBundleIdentifier'] = 'local.statstrio.app'
            self.assertEqual(run().returncode, 0)
            info['SUFeedURL'] = 'https://example.invalid/update'
            self.assertNotEqual(run().returncode, 0)


if __name__ == '__main__':
    unittest.main()
