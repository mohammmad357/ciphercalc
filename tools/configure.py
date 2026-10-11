"""Customize freshly generated Flutter shells; never edits user files."""
from pathlib import Path
import struct
import zlib

root = Path('generated')
manifest = root/'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text().replace('android:label="ciphercalc"', 'android:label="CipherCalc" android:allowBackup="false" android:fullBackupContent="false"')
manifest.write_text(text)
info = root/'ios/Runner/Info.plist'
info.write_text(info.read_text().replace('<string>Ciphercalc</string>', '<string>CipherCalc</string>'))

def png(size):
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            u, v = x/size, y/size
            color = (16,23,37)
            if .25<u<.75 and .16<v<.84:
                color = (32,44,62)
                if .31<u<.69 and .23<v<.38: color=(101,228,213)
                for a in (.32,.46,.60):
                    for b in (.47,.61,.75):
                        if a<u<a+.075 and b<v<b+.075: color=(101,228,213)
            rows.extend(color)
    def chunk(name,data):
        return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')

for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    (root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png').write_bytes(png(size))
icons=root/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
import json
for icon in json.loads((icons/'Contents.json').read_text())['images']:
    if 'filename' in icon:
        size=round(float(icon['size'].split('x')[0])*float(icon['scale'].rstrip('x')))
        (icons/icon['filename']).write_bytes(png(size))
print('Configured CipherCalc labels, icon and Android backup settings')
