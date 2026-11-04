"""Test the exact preview RELEASE APK with disposable emulator-only records."""
import os
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

OUT = pathlib.Path('android-evidence')
OUT.mkdir(exist_ok=True)
PACKAGE = 'com.sss.khatabook.preview'


def adb(*args, binary=False):
    return subprocess.check_output(['adb', *args], timeout=30, text=not binary)


def hierarchy(stage='current'):
    adb('shell', 'uiautomator', 'dump', '/sdcard/window.xml')
    value = adb('shell', 'cat', '/sdcard/window.xml')
    (OUT / (stage + '.xml')).write_text(value)
    return ET.fromstring(value)


def labels(root):
    return ' '.join(' '.join(node.get(k, '') for k in ['text', 'content-desc', 'hint']) for node in root.iter())


def wait_text(text, stage, attempts=20):
    for _ in range(attempts):
        root = hierarchy(stage)
        # A known first-boot emulator-only Launcher ANR can obscure a healthy
        # foreground app. Never dismiss an ANR belonging to SSS Khatabook.
        if stage == 'startup' and any(n.get('resource-id') == 'android:id/alertTitle' and
                n.get('text') == "Pixel Launcher isn't responding" for n in root.iter()):
            close = next((n for n in root.iter() if n.get('resource-id') == 'android:id/aerr_close'), None)
            if close is not None:
                (OUT / 'emulator-launcher-anr.xml').write_text(ET.tostring(root, encoding='unicode'))
                left, top, right, bottom = map(int, re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', close.get('bounds', '')).groups())
                adb('shell','input','tap',str((left+right)//2),str((top+bottom)//2))
                print('ENVIRONMENT: dismissed observed Pixel Launcher ANR dialog; application still requires all core checks')
                time.sleep(1)
                continue
        if text in labels(root):
            (OUT / (stage + '.png')).write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
            return root
        time.sleep(1)
    raise AssertionError('Expected emulator screen missing: ' + stage)


def tap(text, scroll=False):
    for _ in range(8 if scroll else 3):
        root = hierarchy()
        candidates = [n for n in root.iter() if any(text == n.get(k, '') or text in n.get(k, '') for k in ['text', 'content-desc', 'hint'])]
        candidates.sort(key=lambda n: (n.get('clickable') != 'true', n.get('class') != 'android.widget.EditText'))
        for node in candidates:
            bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
            if bounds:
                left, top, right, bottom = map(int, bounds.groups())
                if right > left and bottom > top:
                    adb('shell', 'input', 'tap', str((left + right) // 2), str((top + bottom) // 2))
                    time.sleep(0.5)
                    return
        if scroll:
            size = adb('shell', 'wm', 'size')
            width, height = map(int, re.search(r'(\d+)x(\d+)', size).groups())
            adb('shell', 'input', 'swipe', str(width // 2), str(height * 3 // 4), str(width // 2), str(height // 3), '400')
        time.sleep(0.5)
    raise AssertionError('Emulator control not found: ' + text)


def enter(label, value, field_index=0):
    # UIAutomator's XML omits Flutter's native hintText. Use the observed
    # EditText order only on the already-verified form, never a guessed point.
    root = hierarchy()
    fields = [node for node in root.iter() if node.get('class') == 'android.widget.EditText']
    if len(fields) <= field_index:
        raise AssertionError('Expected editable field missing: ' + label)
    node = fields[field_index]
    left, top, right, bottom = map(int, re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', '')).groups())
    adb('shell', 'input', 'tap', str((left + right) // 2), str((top + bottom) // 2))
    adb('shell', 'input', 'keyevent', '123')
    adb('shell', 'input', 'keyevent', *(['67'] * 20))
    adb('shell', 'input', 'text', value.replace(' ', '%s'))


def launch():
    resolved = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).strip().splitlines()[-1]
    if '/' not in resolved:
        raise AssertionError('Preview activity not resolved')
    result = adb('shell', 'am', 'start', '-W', '-n', resolved)
    (OUT / 'launch.txt').write_text(result)
    if 'Error:' in result or 'Status: ok' not in result:
        raise AssertionError('Android activity did not start')
    wait_text('Dashboard', 'startup', attempts=30)


try:
    adb('logcat', '-c')
    installed = adb('install', '-r', os.environ.get('APK_FILE', 'apk/app-release.apk'))
    if 'Success' not in installed:
        raise AssertionError('Release APK installation failed')
    adb('shell', 'am', 'force-stop', PACKAGE)
    launch()
    tap('Accounts', scroll=True)
    tap('New Account')
    wait_text('New Account', 'account-form')
    enter('Account name', 'Android acceptance account')
    enter('Opening balance', '100.00', field_index=1)
    adb('shell', 'input', 'keyevent', '4')
    tap('Save')
    wait_text('Android acceptance account', 'account-saved')
    adb('shell', 'input', 'keyevent', '4')
    tap('Income', scroll=True)
    wait_text('Add Income', 'income-form')
    enter('Amount', '200')
    adb('shell', 'input', 'keyevent', '4')
    tap('Save Income', scroll=True)
    wait_text('Income saved', 'income-saved')
    adb('shell', 'input', 'keyevent', '4')
    tap('Expenses', scroll=True)
    wait_text('Add Expense', 'expense-form')
    enter('Amount', '50')
    adb('shell', 'input', 'keyevent', '4')
    tap('Save Expense', scroll=True)
    wait_text('Expense saved', 'expense-saved')
    adb('shell', 'input', 'keyevent', '4')
    adb('shell', 'am', 'force-stop', PACKAGE)
    launch()
    wait_text('₹250.00', 'restarted-balance')
    if not adb('shell', 'pidof', PACKAGE).strip():
        raise AssertionError('Android app process exited')
    print('PASS: exact RELEASE APK install/startup, account100 + income200 - expense50 = balance250, saved receipts and persisted balance after process restart on emulator')
finally:
    logs = adb('logcat', '-d')
    (OUT / 'logcat.txt').write_text(logs)
    (OUT / 'final.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    if re.search(r'ANR in com\.sss\.khatabook\.preview|FATAL EXCEPTION|SSS_STARTUP_INITIALIZATION_FAILED|SSS_FRAMEWORK_ERROR|SSS_ASYNC_ERROR|Unhandled Exception', logs):
        raise AssertionError('Android crash/startup error detected; inspect emulator logcat')
