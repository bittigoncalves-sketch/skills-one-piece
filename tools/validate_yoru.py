#!/usr/bin/env python3
"""Valida gameplay, rig e ENet da Yoru. Exige Godot e sockets locais liberados."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get('GODOT', '/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64')
LOGS = Path(os.environ.get('YORU_LOGS', '/tmp/yoru-validation'))
LOGS.mkdir(parents=True, exist_ok=True)
failed = []
for index, name in enumerate(('test_yoru_rig', 'test_yoru_combat', 'test_yoru_sweep', 'test_espada_yoru', 'test_player_rig', 'test_arena')):
    env = dict(os.environ, SOP_PORTA=str(24770+index*2), XDG_DATA_HOME='/tmp/yoru-validation-data')
    log = LOGS / (name+'.log')
    with log.open('w') as out:
        result = subprocess.run([GODOT,'--headless','--path',str(ROOT),'--script','tools/dev_tests/'+name+'.gd'], env=env,stdout=out,stderr=subprocess.STDOUT,timeout=60)
    success = result.returncode == 0 and 'SCRIPT ERROR:' not in log.read_text()
    print(('PASS ' if success else 'FAIL ')+name+' '+str(log), flush=True)
    if not success: failed.append(name)
result = subprocess.run([sys.executable,str(ROOT/'tools/dev_tests/test_yoru_network.py')],cwd=ROOT,timeout=90)
if result.returncode: failed.append('network')
print('YORU validation failures:',failed)
sys.exit(bool(failed))
