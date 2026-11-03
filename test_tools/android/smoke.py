"""Emulator-only startup evidence. No production accounts or financial records."""
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

OUT = pathlib.Path('android-evidence')
OUT.mkdir(exist_ok=True)


def adb(*args, binary=False):
    return subprocess.check_output(['adb', *args], timeout=30, text=not binary)


try:
    adb('logcat', '-c')
    adb('install', '-r', 'apk/app-debug.apk')
    adb('shell', 'am', 'force-stop', 'com.example.offline_khata_app')
    launch = adb('shell', 'am', 'start', '-W', '-n', 'com.example.offline_khata_app/.MainActivity')
    (OUT / 'launch.txt').write_text(launch)
    if 'Error:' in launch or 'Status: ok' not in launch:
        raise AssertionError('Android activity did not start')
    found = False
    for _ in range(30):
        adb('shell', 'uiautomator', 'dump', '/sdcard/window.xml')
        hierarchy = adb('shell', 'cat', '/sdcard/window.xml')
        (OUT / 'startup.xml').write_text(hierarchy)
        root = ET.fromstring(hierarchy)
        labels = ' '.join(node.get('text', '') + ' ' + node.get('content-desc', '') for node in root.iter())
        if 'Dashboard' in labels and 'Could not open local records' not in labels:
            found = True
            break
        time.sleep(1)
    if not found:
        raise AssertionError('Dashboard not found in Android accessibility hierarchy; startup is not certified')
    if not adb('shell', 'pidof', 'com.example.offline_khata_app').strip():
        raise AssertionError('Android app process exited')
    print('PASS: APK install, Activity start, dashboard visibility and process survival on emulator')
finally:
    logs = adb('logcat', '-d')
    (OUT / 'logcat.txt').write_text(logs)
    (OUT / 'startup.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    if re.search(r'FATAL EXCEPTION|SSS_STARTUP_INITIALIZATION_FAILED|SSS_FRAMEWORK_ERROR|SSS_ASYNC_ERROR|Unhandled Exception', logs):
        raise AssertionError('Android crash/startup error detected; inspect emulator logcat')
