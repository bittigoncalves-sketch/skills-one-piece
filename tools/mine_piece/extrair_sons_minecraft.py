#!/usr/bin/env python3
"""Extrai do Minecraft 1.20.1 LOCAL os sons que as procedures do Mine Piece pedem pelo nome vanilla
(`entity.wither.shoot`...). Fidelidade (AUDITORIA_FIDELIDADE_MINE_PIECE, A7, 26/10/2026): o mod chama o som
do Minecraft; antes o jogo trocava cada um por um som "parecido" do mod.

Lê o índice de assets da versão (`versions/1.20.1/1.20.1.json` → `assets/indexes/<id>.json`), o
`minecraft/sounds.json` (variantes, volume e tom de cada uma) e copia os .ogg de `assets/objects/` para
`assets/mine_piece/visual/sons/mc_<caminho>.ogg` (gitignored, arte do Minecraft nunca vai ao repositório).
Acrescenta `minecraft:<evento>` em `mapas/east_blue/visual_do_mod.json` → "sons": lista de itens, cada um
`"arquivo"` ou `{"n": arquivo, "v": volume, "p": tom, "w": peso}` (campos do sounds.json).

    python3 -I tools/mine_piece/extrair_sons_minecraft.py [--minecraft DIR]
"""
import json
import os
import re
import shutil
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PADRAO = os.path.expanduser("~/Documents/curseforge/minecraft/Install")
VERSAO = "1.20.1"
PROCEDURES = os.path.join(RAIZ, "src", "minecraft", "gerado", "procedures")
SONS = os.path.join(RAIZ, "assets", "mine_piece", "visual", "sons")
VISUAL = os.path.join(RAIZ, "mapas", "east_blue", "visual_do_mod.json")


# Sons que a camada toca por conta própria (não aparecem como texto nas procedures): quebrar bloco (levelEvent 2001).
EXTRAS = ["block.stone.break"]


def eventos_pedidos():
    """Nomes de evento vanilla (`a.b.c`) em linhas de playSound das procedures geradas."""
    achados = set()
    for nome in os.listdir(PROCEDURES):
        if not nome.endswith(".gd"):
            continue
        for linha in open(os.path.join(PROCEDURES, nome), encoding="utf-8"):
            # Comando em texto (`playsound entity.wither.spawn master @a`): o evento vem depois da palavra.
            for m in re.finditer(r'playsound (?:minecraft:)?([a-z_]+(?:\.[a-z_0-9]+)+)', linha):
                achados.add(m.group(1))
            if "laySound" not in linha and "playLocalSound" not in linha:
                continue
            for m in re.finditer(r'"([a-z_]+(?:\.[a-z_0-9]+)+)"', linha):
                achados.add(m.group(1))
    return sorted(achados | set(EXTRAS))


def main():
    pasta = PADRAO
    if "--minecraft" in sys.argv:
        pasta = sys.argv[sys.argv.index("--minecraft") + 1]
    versao = json.load(open(os.path.join(pasta, "versions", VERSAO, VERSAO + ".json")))
    indice = json.load(open(os.path.join(pasta, "assets", "indexes", versao["assetIndex"]["id"] + ".json")))["objects"]

    def objeto(chave):
        h = indice[chave]["hash"]
        return os.path.join(pasta, "assets", "objects", h[:2], h)

    sounds = json.load(open(objeto("minecraft/sounds.json")))
    visual = json.load(open(VISUAL))
    os.makedirs(SONS, exist_ok=True)
    feitos, sem_evento, sem_arquivo = [], [], []
    for ev in eventos_pedidos():
        e = sounds.get(ev)
        if not e:
            sem_evento.append(ev)
            continue
        itens = []
        for s in e["sounds"]:
            s = {"name": s} if isinstance(s, str) else s
            if s.get("type") == "event":      # remete a outro evento; o mod não pede
                continue
            nome = s["name"].replace("minecraft:", "")
            chave = "minecraft/sounds/" + nome + ".ogg"
            if chave not in indice:
                sem_arquivo.append(chave)
                continue
            destino = "mc_" + nome.replace("/", "_")
            shutil.copyfile(objeto(chave), os.path.join(SONS, destino + ".ogg"))
            item = {"n": destino}
            if s.get("volume", 1.0) != 1.0:
                item["v"] = s["volume"]
            if s.get("pitch", 1.0) != 1.0:
                item["p"] = s["pitch"]
            if s.get("weight", 1) != 1:
                item["w"] = s["weight"]
            itens.append(item if len(item) > 1 else destino)
        if itens:
            visual["sons"]["minecraft:" + ev] = itens
            feitos.append(ev)
    visual["origem_minecraft"] = "Minecraft %s local (sounds.json do índice %s)" % (VERSAO, versao["assetIndex"]["id"])
    json.dump(visual, open(VISUAL, "w"), indent=1, ensure_ascii=False)
    print("sons do Minecraft extraídos:", len(feitos))
    print("sem evento no sounds.json (%d):" % len(sem_evento), ", ".join(sem_evento))
    print("sem arquivo no índice (%d):" % len(sem_arquivo), ", ".join(sem_arquivo[:10]))


main()
