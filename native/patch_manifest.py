import re

p = 'android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf8').read()

perms = ['INTERNET', 'POST_NOTIFICATIONS', 'VIBRATE', 'USE_FULL_SCREEN_INTENT',
         'RECEIVE_BOOT_COMPLETED', 'WAKE_LOCK', 'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS']
add = ''.join('    <uses-permission android:name="android.permission.%s"/>\n' % x for x in perms)
s = s.replace('<application', add + '    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="کلاریو"', s, count=1)
s = s.replace('<activity', '<activity android:showWhenLocked="true" android:turnScreenOn="true"', 1)
recv = '''        <receiver android:name=".AlarmReceiver" android:exported="false"/>
        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
    </application>'''
s = s.replace('</application>', recv, 1)
# آیکون‌های قابل تعویض (activity-alias)
s = re.sub(r'<intent-filter>\s*<action android:name="android.intent.action.MAIN"\s*/>\s*<category android:name="android.intent.category.LAUNCHER"\s*/>\s*</intent-filter>', '', s, count=1)
s = re.sub(r'android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_blue"', s)
aliases = ''
for n, en in [('blue', 'true'), ('green', 'false'), ('purple', 'false'), ('dark', 'false')]:
    aliases += '''        <activity-alias android:name=".Icon%s" android:targetActivity=".MainActivity" android:enabled="%s" android:exported="true" android:icon="@mipmap/ic_%s" android:label="کلاریو">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity-alias>
''' % (n.capitalize(), en, n)
s = s.replace('</application>', aliases + '    </application>', 1)
open(p, 'w', encoding='utf8').write(s)
print(s)
