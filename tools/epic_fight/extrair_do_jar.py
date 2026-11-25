#!/usr/bin/env python3
"""Extrai do jar do Epic Fight (Minecraft 1.21.1 NeoForge) só o que o jogo converte:
animações, armadura, modelos de item e as tabelas de arma/habilidade em data/.

SAÍDA LOCAL, FORA DO GIT (assets do mod são "All Rights Reserved"; decisão do dono, 10/11/2026).
Uso: extrair_do_jar.py [JAR] [DESTINO]   -- padrão: art_src/epic_fight_local/
"""
import sys, zipfile, pathlib
RAIZ = pathlib.Path(__file__).resolve().parents[2]
JAR = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else next(
    pathlib.Path.home().glob("Documents/curseforge/minecraft/Instances/Mods desejados/mods/epic-fight-*.jar"))
DEST = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else RAIZ / "art_src" / "epic_fight_local"
PREFIXOS = ("assets/epicfight/animmodels/", "assets/epicfight/models/item/", "assets/epicfight/textures/item/",
            "data/epicfight/capabilities/", "data/epicfight/skill_parameters/", "data/epicfight/recipe/")
n = 0
with zipfile.ZipFile(JAR) as z:
    for info in z.infolist():
        if info.is_dir() or not info.filename.startswith(PREFIXOS):
            continue
        alvo = DEST / info.filename
        alvo.parent.mkdir(parents=True, exist_ok=True)
        alvo.write_bytes(z.read(info))
        n += 1
print(f"{n} arquivos de {JAR.name} -> {DEST}")
