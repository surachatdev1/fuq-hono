"""Offline native cold-start and demo navigation. No login credentials or live POST."""
import subprocess,time,pathlib,xml.etree.ElementTree as ET,re
out=pathlib.Path('native-captures');out.mkdir(exist_ok=True)
def adb(*args):return subprocess.check_output(['adb',*args])
def capture(name):
    adb('shell','uiautomator','dump','/sdcard/window.xml')
    xml=adb('shell','cat','/sdcard/window.xml')
    (out/(name+'.xml')).write_bytes(xml)
    (out/(name+'.png')).write_bytes(adb('exec-out','screencap','-p'))
    return ET.fromstring(xml)
def node(tree,label):
    for n in tree.iter('node'):
        if label in n.get('text','') or label in n.get('content-desc',''):return n
    return None
try:
    adb('install','-r','native-apk/app-debug.apk')
    adb('logcat','-c')
    adb('shell','am','start','-W','-n','com.nwl.nwl_secret_login/.MainActivity')
    time.sleep(8)
    tree=capture('01-login')
    focus=adb('shell','dumpsys','window','windows').decode(errors='replace')
    assert 'com.nwl.nwl_secret_login' in focus,'App window did not start'
    for attempt in range(5):
        n=node(tree,'ทดลองใช้งานก่อนเข้าสู่ระบบ')
        if n is not None:
            x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
            adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));break
        adb('shell','input','swipe','520','1800','520','650','450');time.sleep(1)
        tree=capture('02-login-scroll')
    else:raise AssertionError('Demo action unavailable in accessibility tree')
    time.sleep(2);tree=capture('03-today')
    assert node(tree,'วันนี้ของคุณ') is not None,'Demo today did not open'
    n=node(tree,'สถานที่')
    if n is not None:
        x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
        adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));time.sleep(1)
        capture('04-places')
finally:
    errors=adb('logcat','-d','-s','AndroidRuntime:E','flutter:E').decode(errors='replace')
    (out/'runtime-errors.txt').write_text(errors)
    assert 'FATAL EXCEPTION' not in errors and 'Unhandled Exception' not in errors,errors
