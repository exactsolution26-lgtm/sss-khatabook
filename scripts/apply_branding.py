"""Install the approved K + rupee icon after `flutter create` generates runners."""
from pathlib import Path
import argparse
import shutil
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw

ANDROID = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID)


def apply_branding(root: Path, source: Path) -> None:
    with Image.open(source) as original:
        icon = original.convert('RGB')
    if icon.width != icon.height or icon.width < 192:
        raise ValueError('Launcher artwork must be square and at least 192 pixels')
    android = root / 'android/app/src/main'
    web = root / 'web'
    if not (android / 'AndroidManifest.xml').is_file() and not web.is_dir():
        raise FileNotFoundError('Generate Android or Web runners with flutter create first')
    if (android / 'AndroidManifest.xml').is_file():
        res = android / 'res'
        artwork = res / 'drawable-nodpi/sss_launcher_art.webp'
        artwork.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, artwork)
        for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
            folder = res / f'mipmap-{density}'
            folder.mkdir(parents=True, exist_ok=True)
            small = icon.resize((size, size), Image.Resampling.LANCZOS)
            small.save(folder / 'ic_launcher.png')
            mask = Image.new('L', (size, size))
            ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
            rounded = small.convert('RGBA')
            rounded.putalpha(mask)
            rounded.save(folder / 'ic_launcher_round.png')
        drawable = res / 'drawable'
        drawable.mkdir(parents=True, exist_ok=True)
        # 108dp adaptive layer, 16dp inset: keep the selected mark inside the
        # central safe area while leaving the opaque image edges outside masks.
        (drawable / 'sss_launcher_foreground.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="http://schemas.android.com/apk/res/android" android:inset="16dp">
    <bitmap android:src="@drawable/sss_launcher_art" android:gravity="fill" />
</inset>
''')
        adaptive = res / 'mipmap-anydpi-v26'
        adaptive.mkdir(parents=True, exist_ok=True)
        xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/sss_launcher_background" />
    <foreground android:drawable="@drawable/sss_launcher_foreground" />
</adaptive-icon>
'''
        # Solid background also fills the outer parallax area of adaptive icons.
        (drawable / 'sss_launcher_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#00543B" />
</shape>
''')
        for name in ['ic_launcher', 'ic_launcher_round']:
            (adaptive / f'{name}.xml').write_text(xml)
        manifest = android / 'AndroidManifest.xml'
        tree = ET.parse(manifest)
        application = tree.getroot().find('application')
        if application is None:
            raise ValueError('Android application element missing')
        application.set(f'{{{ANDROID}}}icon', '@mipmap/ic_launcher')
        application.set(f'{{{ANDROID}}}roundIcon', '@mipmap/ic_launcher_round')
        tree.write(manifest, encoding='utf-8', xml_declaration=True)
    if web.is_dir():
        for name, size in [('favicon.png', 32), ('icons/Icon-192.png', 192),
                           ('icons/Icon-512.png', 512), ('icons/Icon-maskable-192.png', 192),
                           ('icons/Icon-maskable-512.png', 512)]:
            target = web / name
            target.parent.mkdir(parents=True, exist_ok=True)
            # Maskable web icons use generous padding for the same selected mark.
            image = icon
            if 'maskable' in name:
                image = Image.new('RGB', (640, 640), '#00543B')
                image.paste(icon.resize((512, 512), Image.Resampling.LANCZOS), (64, 64))
            image.resize((size, size), Image.Resampling.LANCZOS).save(target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    apply_branding(args.project_root, Path(__file__).resolve().parents[1] / 'assets/branding/launcher.webp')
    print('Applied approved K + rupee launcher branding')
