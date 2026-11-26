"""Exercise icon installation into generated runners, without a Flutter SDK."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('apply_branding', ROOT / 'scripts/apply_branding.py')
BRANDING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRANDING)
SOURCE = ROOT / 'assets/branding/launcher.webp'
NS = '{http://schemas.android.com/apk/res/android}'


class LauncherBrandingTests(unittest.TestCase):
    def test_generated_android_and_web_use_selected_artwork_after_repeated_application(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            android = root / 'android/app/src/main'
            android.mkdir(parents=True)
            manifest = android / 'AndroidManifest.xml'
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:icon="@mipmap/ic_launcher" android:label="offline_khata_app"><activity android:name=".MainActivity"/></application></manifest>')
            (root / 'web').mkdir()
            for _ in range(2):
                BRANDING.apply_branding(root, SOURCE)
            application = ET.parse(manifest).getroot().find('application')
            self.assertEqual(application.get(NS + 'icon'), '@mipmap/ic_launcher')
            self.assertEqual(application.get(NS + 'roundIcon'), '@mipmap/ic_launcher_round')
            self.assertEqual(application.get(NS + 'label'), 'offline_khata_app')
            self.assertEqual(application.find('activity').get(NS + 'name'), '.MainActivity')
            self.assertIsNotNone(ET.parse(manifest).getroot().find('uses-permission'))
            res = android / 'res'
            self.assertEqual((res / 'drawable-nodpi/sss_launcher_art.webp').read_bytes(), SOURCE.read_bytes())
            for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
                for name in ['ic_launcher', 'ic_launcher_round']:
                    with Image.open(res / f'mipmap-{density}/{name}.png') as image:
                        self.assertEqual(image.size, (size, size))
                        if name.endswith('round'):
                            self.assertEqual(image.getpixel((0, 0))[3], 0)
                with Image.open(res / f'mipmap-{density}/ic_launcher.png') as legacy, Image.open(SOURCE) as source:
                    self.assertEqual(legacy.tobytes(), source.convert('RGB').resize((size, size), Image.Resampling.LANCZOS).tobytes())
            for name in ['ic_launcher', 'ic_launcher_round']:
                adaptive = ET.parse(res / f'mipmap-anydpi-v26/{name}.xml').getroot()
                self.assertEqual(adaptive.tag, 'adaptive-icon')
                self.assertEqual(adaptive.find('foreground').get(NS + 'drawable'), '@drawable/sss_launcher_foreground')
                self.assertEqual(adaptive.find('background').get(NS + 'drawable'), '@drawable/sss_launcher_background')
            for name, size in [('favicon.png', 32), ('icons/Icon-192.png', 192), ('icons/Icon-512.png', 512), ('icons/Icon-maskable-192.png', 192), ('icons/Icon-maskable-512.png', 512)]:
                with Image.open(root / 'web' / name) as image:
                    self.assertEqual(image.size, (size, size))

    def test_selected_mark_stays_inside_adaptive_circle_safe_zone(self):
        with Image.open(SOURCE) as source:
            art = source.convert('RGB').resize((76, 76), Image.Resampling.LANCZOS)
        # The bright ivory/gold mark must survive even the central 66dp circle.
        distances = [((x + 16.5 - 54) ** 2 + (y + 16.5 - 54) ** 2) ** .5
                     for y in range(76) for x in range(76)
                     if art.getpixel((x, y))[0] > 120 and art.getpixel((x, y))[1] > 80]
        self.assertGreater(len(distances), 1000)
        self.assertLessEqual(max(distances), 33)

    def test_missing_generated_runner_fails_instead_of_reporting_success(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                BRANDING.apply_branding(Path(directory), SOURCE)


if __name__ == '__main__':
    unittest.main()
