#!/usr/bin/env python3
"""Contratos e captura opcional: python3 tools/validar_bestas_mar.py --capturar.

Não modifica o catálogo ou mapa vivo. Progresso/config ficam em diretório XDG
temporário. Logs integrais e resultado.json permanecem na pasta de validação.
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
OUT = ROOT / "art_src/validation/bestas_mar"
ERRORS = re.compile(r"ERROR:|SCRIPT ERROR|SHADER ERROR|^FAIL |^\s+FALHA ", re.M)
MODELS = ("bovina", "girafa", "javali", "serpente")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capturar", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    godot = subprocess.check_output([str(ROOT / "find_godot.sh")], text=True).strip()
    protected = [ROOT / "mapas/historia/baseplate.json", ROOT / "mapas/modelos/catalogo.json"]
    before = {str(path.relative_to(ROOT)): sha(path) for path in protected}
    results = {"captura": "Não executada (usar --capturar com display GPU)."}
    failure = None

    def run(name, command, env, marker):
        log_path = OUT / (name + ".log")
        # Grava diretamente: mesmo timeout preserva tudo que a engine emitiu.
        with log_path.open("w") as log_file:
            try:
                p = subprocess.run(command, cwd=ROOT, env=env, stdout=log_file,
                                   stderr=subprocess.STDOUT, timeout=240)
            except subprocess.TimeoutExpired as error:
                raise RuntimeError(f"{name}: tempo excedido; ver {log_path}") from error
        log = log_path.read_text(errors="replace")
        if p.returncode or ERRORS.search(log) or marker not in log:
            raise RuntimeError(f"{name}: erro ou conclusão ausente; ver {log_path}")
        results[name] = "PASS"
        print("PASS", name)

    try:
        with tempfile.TemporaryDirectory(prefix="sop-bestas-mar-") as tmp:
            env = dict(os.environ, XDG_DATA_HOME=tmp + "/data",
                       XDG_CONFIG_HOME=tmp + "/config", SOP_PORTA="24884")
            # ResourceLoader (loja) precisa enxergar a mesma versão que o
            # GLTFDocument (teste estrutural) depois de reexportar os modelos.
            run("importacao", [godot, "--headless", "--path", str(ROOT),
                               "--editor", "--import"], env, "[ DONE ]")
            run("contratos", [godot, "--headless", "--path", str(ROOT), "--script",
                              "tools/dev_tests/test_bestas_mar.gd"], env, "BESTAS DO MAR: TUDO OK")
            if args.capturar:
                if not (env.get("DISPLAY") or env.get("WAYLAND_DISPLAY")):
                    raise RuntimeError("Captura requer DISPLAY ou WAYLAND_DISPLAY real.")
                driver = "x11" if env.get("DISPLAY") else "wayland"
                expected = [OUT / f"{kind}_{view}.png" for kind in MODELS for view in ("corpo", "rosto")]
                expected += [OUT / (name + ".png") for name in ("bovina_esqueleto", "galeria_mar", "editor_loja", "serpente_repouso", "serpente_ameaca")]
                # Invalida evidências antigas para não confundi-las com esta execução.
                for image in expected:
                    image.unlink(missing_ok=True)
                run("captura", [godot, "--display-driver", driver, "--audio-driver", "Dummy",
                                "--no-focus", "--path", str(ROOT), "--script",
                                "tools/bestas_mar_preview.gd"], env, "BESTAS_MAR_PREVIEW_OK")
                for image in expected:
                    if not image.is_file() or image.stat().st_size < 1000:
                        raise RuntimeError(f"Captura ausente ou vazia: {image.name}")
                results["imagens"] = [p.name for p in expected]
        for kind in MODELS:
            if sha(ROOT / f"art_src/bestas_mar/besta_mar_{kind}.glb") != sha(ROOT / f"mapas/modelos/besta_mar_{kind}.glb"):
                raise RuntimeError(f"Exportação e modelo da loja diferem: {kind}")
        results["exportacoes_iguais"] = True
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        failure = str(error)
    finally:
        unchanged = all(path.exists() and sha(path) == before[str(path.relative_to(ROOT))] for path in protected)
        results["mapa_e_catalogo_preservados"] = unchanged
        if not unchanged:
            failure = (failure + "; " if failure else "") + "mapa ou catálogo vivo foi alterado"
        results["resultado"] = "FAIL" if failure else "PASS"
        if failure:
            results["erro"] = failure
        (OUT / "resultado.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    if failure:
        raise SystemExit("FAIL " + failure)
    print("PASS BESTAS DO MAR — logs e evidências em", OUT)


if __name__ == "__main__":
    main()
