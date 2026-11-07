"""Verify native process/window survival and collect actual device render for review.
Flutter widget tests separately exercise navigation. No account or attendance calls.
"""
import subprocess,time,pathlib
out=pathlib.Path('native-captures');out.mkdir(exist_ok=True)
def adb(*args):return subprocess.check_output(['adb',*args])
def screenshot(name):
    (out/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
try:
    adb('install','-r',str(next(pathlib.Path('native-apk').glob('*.apk'))))
    adb('logcat','-c')
    result=adb('shell','am','start','-W','-n','com.nwl.nwl_secret_login/.MainActivity')
    (out/'launch.txt').write_bytes(result)
    time.sleep(10)
    screenshot('01-native-login')
    focus=adb('shell','dumpsys','window','windows').decode(errors='replace')
    (out/'window.txt').write_text(focus)
    assert 'com.nwl.nwl_secret_login' in focus,'App window did not open'
    assert adb('shell','pidof','com.nwl.nwl_secret_login').strip(),'App process exited'
    # Always collect the screenshot first: uiautomator can time out waiting for idle
    # even when Flutter is correctly rendering and widget interactions pass.
    try:
        subprocess.run(['adb','shell','uiautomator','dump','--compressed','/sdcard/window.xml'],timeout=15,check=True,capture_output=True)
        (out/'01-native-login.xml').write_bytes(adb('shell','cat','/sdcard/window.xml'))
    except (subprocess.TimeoutExpired,subprocess.CalledProcessError):
        (out/'accessibility-note.txt').write_text('UIAutomator idle/tree unavailable. Native screenshots and Flutter widget interaction tests are separate evidence.')
    time.sleep(4)
    screenshot('02-native-stable')
    assert adb('shell','pidof','com.nwl.nwl_secret_login').strip(),'App did not remain running'
finally:
    errors=adb('logcat','-d','-s','AndroidRuntime:E','flutter:E').decode(errors='replace')
    (out/'runtime-errors.txt').write_text(errors)
    assert 'FATAL EXCEPTION' not in errors and 'Unhandled Exception' not in errors,errors
