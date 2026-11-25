#!/usr/bin/env python3
"""Um comando: python3 tools/validar_praia.py [--capturar].
Isola progresso/config e portas; preserva logs e reprova erros mesmo com exit 0.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art_src/validation/praia'
parser = argparse.ArgumentParser()
parser.add_argument('--capturar', action='store_true')
args = parser.parse_args()
OUT.mkdir(parents=True, exist_ok=True)
godot = subprocess.check_output([str(ROOT / 'find_godot.sh')], text=True).strip()
mapa = ROOT / 'mapas/historia/baseplate.json'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
antes = sha(mapa)
resultados = {}

def executar(nome, comando, env):
    p = subprocess.run(comando, cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
    log = p.stdout + p.stderr
    (OUT / (nome + '.log')).write_text(log)
    if p.returncode or re.search(r'ERROR:|SCRIPT ERROR|SHADER ERROR|^FAIL ', log, re.M):
        print(log)
        raise SystemExit('FAIL ' + nome)
    resultados[nome] = 'PASS'
    print('PASS ' + nome)

with tempfile.TemporaryDirectory(prefix='sop-praia-') as tmp:
    env = dict(os.environ, XDG_DATA_HOME=tmp+'/data', XDG_CONFIG_HOME=tmp+'/config', SOP_PORTA='24860')
    executar('contratos', [godot, '--headless', '--path', str(ROOT), '--script', 'tools/dev_tests/test_praia_oceano.gd'], env)
    if args.capturar:
        driver = 'x11' if env.get('DISPLAY') else 'wayland'
        env['SOP_PRAIA_QUADROS'] = tmp+'/quadros'
        executar('captura', [godot, '--display-driver', driver, '--audio-driver', 'Dummy', '--no-focus', '--path', str(ROOT), '--script', 'tools/praia_preview.gd', '--', '--ondas'], env)
        from PIL import Image, ImageChops, ImageStat
        frames = [Image.open(p).convert('RGB') for p in sorted(Path(env['SOP_PRAIA_QUADROS']).glob('*.png'))]
        if len(frames) != 36:
            raise SystemExit('FAIL captura incompleta da animação')
        frames[0].save(OUT/'ondas.webp', save_all=True, append_images=frames[1:], duration=83, loop=0, quality=82, method=4)
        resultados['animacao'] = {'quadros': len(frames), 'passo_segundos': 1/12}
        a = Image.open(OUT/'04_ondas_t0.png').convert('RGB').crop((100, 430, 1150, 700))
        b = Image.open(OUT/'05_ondas_t2.png').convert('RGB').crop((100, 430, 1150, 700))
        delta = ImageChops.difference(a, b)
        dados = delta.get_flattened_data() if hasattr(delta, 'get_flattened_data') else delta.getdata()
        fracao = sum(max(rgb) > 3 for rgb in dados) / (delta.width * delta.height)
        resultados['ondas_2s'] = {'pixels_alterados_percentual': round(fracao*100, 2), 'delta_rgb_medio': sum(ImageStat.Stat(delta).mean)/3}
        if fracao < .05:
            raise SystemExit('FAIL superfície sem variação visível entre 0 e 2 s')
        print('PASS movimento do mar: %.2f%% dos pixels da amostra mudaram em 2 s' % (fracao*100))
    else:
        resultados['captura'] = 'Não executada (usar --capturar com display GPU)'
if sha(mapa) != antes:
    raise SystemExit('FAIL mapa vivo foi alterado')
if sha(ROOT/'art_src/praia/areia_praia_low_poly.glb') != sha(ROOT/'mapas/modelos/areia_praia_low_poly.glb'):
    raise SystemExit('FAIL exportação e modelo da loja diferem')
resultados['mapa_preservado'] = antes
(OUT/'resultado.json').write_text(json.dumps(resultados, indent=2, ensure_ascii=False)+'\n')
print('PASS PRAIA — logs e capturas em', OUT)
