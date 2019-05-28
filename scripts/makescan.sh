#!/bin/sh

source ./activate

rm -rf build/pyinstaller
mkdir -p build/pyinstaller

cat <<EOF > /dev/null #>build/scan.spec
# -*- mode: python -*-

block_cipher = None


options = [ ('u', None, 'OPTION') ]   # unbuffered output
a = Analysis(['../../src/loader/scan.py'],
             pathex=['/Users/jon/otto/otto/build/pyinstaller'],
             binaries=[],
             datas=[],
             hiddenimports=[],
             hookspath=[],
             runtime_hooks=[],
             excludes=[],
             win_no_prefer_redirects=False,
             win_private_assemblies=False,
             cipher=block_cipher,
             noarchive=False)
pyz = PYZ(a.pure, a.zipped_data,
             cipher=block_cipher)
exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          [],
          name='scan',
          debug=False,
          bootloader_ignore_signals=False,
          strip=False,
          upx=True,
          runtime_tmpdir=None,
          console=True )
EOF

#(cd build/pyinstaller; pyinstaller ../scan.spec) ||

(cd build/pyinstaller; pyinstaller --clean --onefile ../../src/loader/scan.py) ||
    (echo "error running pyinstaller on scan.py" || exit 1) || exit 1
ln -s -f ../build/pyinstaller/dist/scan bin/

exit
