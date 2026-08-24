# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['BS2_Randomizer_Installer.py'],
    pathex=[],
    binaries=[],
    datas=[('Archipelago_Combined.rb', '.'), ('Scene_Title_Archipelago.rb', '.'), ('steam_acheivement_stub.rb', '.'), ('ap_location_pool.json', '.')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='BS2_Archipelago_Installer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
