"""Validação ENet cosmética: servidor publica, cliente recebe e não pode forjar."""
from pathlib import Path
import subprocess, os, tempfile, time
root=Path(__file__).resolve().parents[2]
godot=subprocess.check_output([str(root/'find_godot.sh')],text=True).strip()
logs=root/'art_src/validation/alimentacao'
with tempfile.TemporaryDirectory(prefix='sop-alimentacao-rede-') as tmp:
    env=dict(os.environ,XDG_DATA_HOME=tmp,XDG_CONFIG_HOME=tmp,XDG_CACHE_HOME=tmp)
    cmd=[godot,'--headless','--path',str(root),'--script','tools/dev_tests/test_alimentacao_rede.gd','--']
    with (logs/'rede_servidor.log').open('w') as a,(logs/'rede_cliente.log').open('w') as b:
        server=subprocess.Popen(cmd+['--servidor'],env=env,stdout=a,stderr=subprocess.STDOUT)
        client=None
        try:
            for _ in range(60):
                if 'REDE_PRONTA' in (logs/'rede_servidor.log').read_text(): break
                if server.poll() is not None: raise RuntimeError('servidor encerrou antes de ficar pronto')
                time.sleep(.05)
            client=subprocess.Popen(cmd+['--cliente'],env=env,stdout=b,stderr=subprocess.STDOUT)
            assert server.wait(timeout=25)==0
            assert client.wait(timeout=25)==0
        finally:
            for p in [server,client]:
                if p and p.poll() is None: p.kill();p.wait()
    for name in ['rede_servidor.log','rede_cliente.log']:
        text=(logs/name).read_text()
        assert 'FALHOU' not in text and 'SCRIPT ERROR' not in text, text
        for line in text.splitlines():
            if line.startswith('REDE_'): print(line)
