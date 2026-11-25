#!/usr/bin/env python3 -I
"""Modelos de entidade ESCRITOS À MÃO em Java (`CubeListBuilder`, sem GeckoLib) → `visual_do_mod.json: modelos_java`.

Para cada id: renderer → classe `Model…` → `createBodyLayer()` (peças aninhadas, caixas com `texOffs`/`addBox`, pose de
translação e rotação) e a textura do `getTextureLocation`. O desenho em runtime é `McVisual._modelo_java`.
Ordem de regeração do `visual_do_mod.json`: extrair_visual → extrair_sons_minecraft → extrair_particulas_minecraft →
extrair_invisiveis → extrair_modelos_de_efeito → ESTE.

Uso:  python3 -I tools/mine_piece/extrair_modelos_java.py [tree_root entity_ball …]
"""
import json
import re
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
FONTE = Path.home() / "dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/net/mcreator/minepiece/client"
JAR = Path.home() / "server_onepiece/mods/MinePiece-ver14-forge-1.20.1.jar"
SAIDA = RAIZ / "mapas/east_blue/visual_do_mod.json"
PASTA_TEX = RAIZ / "assets/mine_piece/visual/entidades"
PADRAO = ["tree_root", "entity_ball"]

# Nomes ofuscados (SRG) do Minecraft 1.20.1 usados por `createBodyLayer`.
ADD_CHILD = "m_171599_"       # addOrReplaceChild
TEX_OFFS = "m_171514_"        # texOffs
ADD_BOX = "m_171488_"         # addBox
POSE_OFFSET = "m_171419_"     # PartPose.offset
POSE_OFFSET_ROT = "m_171423_"  # PartPose.offsetAndRotation
MIRROR = "m_171480_"          # mirror


def snake_para_renderer(id_):
    return "".join(p.capitalize() for p in id_.split("_")) + "Renderer.java"


def numeros(s):
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?(?:E-?\d+)?", s)]


def analisar_camada(java, com_espelho=False):
    corpo = java[java.index("createBodyLayer"):]
    m_tam = re.search(r"LayerDefinition\.m_171565_\(meshdefinition,\s*(\d+),\s*(\d+)\)", corpo)
    tex_w, tex_h = int(m_tam.group(1)), int(m_tam.group(2))
    partes, vistas = [], {}
    padrao = re.compile(
        r"PartDefinition\s+(\w+)\s*=\s*(\w+)\." + ADD_CHILD + r'\(\s*"(\w+)",\s*(CubeListBuilder\.[^;]*?),\s*(PartPose\.[^;]*?)\);', re.S)
    for m in padrao.finditer(corpo):
        var, pai_var, nome, cubos, pose = m.groups()
        pai = vistas.get(pai_var, "")
        vistas[var] = nome
        caixas, u, v, espelho = [], 0.0, 0.0, False
        for chamada in re.finditer(r"\." + TEX_OFFS + r"\(([^)]*)\)|\." + MIRROR + r"\((true|false)\)|\." + ADD_BOX + r"\(([^;]*?)new CubeDeformation\(([^)]*)\)\)", cubos, re.S):
            if chamada.group(1) is not None:
                u, v = numeros(chamada.group(1))[:2]
            elif chamada.group(2) is not None:
                espelho = chamada.group(2) == "true"
            else:
                x, y, z, w, h, d = numeros(chamada.group(3))[:6]
                caixa = [u, v, x, y, z, w, h, d, numeros(chamada.group(4))[0]]
                if com_espelho:
                    caixa.append(espelho)        # 10º item: UV espelhada (CubeListBuilder.mirror)
                caixas.append(caixa)
        if MIRROR in cubos and not com_espelho:
            print(f"  aviso: {nome} usa mirror (ignorado)")
        n = numeros(pose.split("(", 1)[1])
        pos = n[:3]
        rot = n[3:6] if POSE_OFFSET_ROT in pose else [0.0, 0.0, 0.0]
        partes.append({"nome": nome, "pai": pai, "pos": pos, "rot": rot, "caixas": caixas})
    return {"tex_w": tex_w, "tex_h": tex_h, "partes": partes}


def main():
    ids = sys.argv[1:] or PADRAO
    z = zipfile.ZipFile(JAR)
    dados = json.loads(SAIDA.read_text())
    saida = dados.setdefault("modelos_java", {})
    PASTA_TEX.mkdir(parents=True, exist_ok=True)
    for id_ in ids:
        r = (FONTE / "renderer" / snake_para_renderer(id_)).read_text()
        modelo = re.search(r"new (Model\w+)\(", r).group(1)
        textura = re.search(r'getTextureLocation.*?textures/entities/(\w+)\.png', r, re.S).group(1)
        camada = analisar_camada((FONTE / "model" / f"{modelo}.java").read_text())
        camada["textura"] = textura
        camada["modelo"] = modelo
        # `RenderLayer` extra com outra textura (ex.: gelo sobre a raiz): só registrado, o desenho usa a base.
        extras = re.findall(r"LAYER_TEXTURE\s*=\s*new ResourceLocation\(\"minepiece:textures/entities/(\w+)\.png", r)
        camada["camadas_extras"] = extras
        for tex in [textura] + extras:
            (PASTA_TEX / f"{tex}.png").write_bytes(z.read(f"assets/minepiece/textures/entities/{tex}.png"))
        saida[id_] = camada
        caixas = sum(len(p["caixas"]) for p in camada["partes"])
        print(f"{id_}: {modelo}, {len(camada['partes'])} peças, {caixas} caixas, textura {textura} {camada['tex_w']}x{camada['tex_h']}, extras {extras}")
    SAIDA.write_text(json.dumps(dados, indent=1, ensure_ascii=False))



if __name__ == "__main__":
    main()
