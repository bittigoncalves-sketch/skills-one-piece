#!/usr/bin/env python3
"""Testa a derivação de rig por marcadores, sem abrir janela.

Roda: python3 tools/anim_editor/test_rigger.py
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import markers                       # noqa: E402
from clip import Clip                # noqa: E402
from mesh import Malha, listar_malhas  # noqa: E402
from rig import PAPEIS, Rig          # noqa: E402

falhas = []


def checa(cond, msg):
    if not cond:
        falhas.append(msg)
        print("   ✗ " + msg)
    return cond


def main():
    malhas = listar_malhas(os.path.join(AQUI, "meshes"))
    if not malhas:
        print("✗ sem malhas — rode: godot --headless --path . -s tools/export_mesh.gd")
        return 1

    for nome in malhas:
        print("\n===== %s =====" % nome)
        m = Malha.de_arquivo(os.path.join(AQUI, "meshes", nome + ".json"))
        print("   %d voxels, %.2f m" % (len(m.pontos), m.altura))

        # marcadores incompletos têm que RECUSAR, não gerar meio esqueleto
        try:
            markers.derivar_rig({"queixo": (0, 1, 0)}, m, nome)
            checa(False, "aceitou marcadores incompletos")
        except ValueError:
            pass

        marcas = markers.sugerir(m)
        checa(len(marcas) == 12, "sugestão devolveu %d marcadores (esperado 12)" % len(marcas))

        rig = Rig(markers.derivar_rig(marcas, m, nome))
        checa(len(rig.papeis) == 13, "rig com %d ossos (esperado 13)" % len(rig.papeis))
        for p in PAPEIS:
            checa(p in rig.papeis, "faltou o papel %s" % p)

        # pais antes dos filhos, senão a cinemática direta resolve errado
        vistos = set()
        for papel in rig.ordem:
            pai = rig.papeis[papel].get("parent", "")
            checa(not pai or pai in vistos, "%s vem antes do pai %s" % (papel, pai))
            vistos.add(papel)

        pose = rig.pose({})
        def y(p):
            return pose[p][1][1]

        checa(y("Head") > y("Torso"), "cabeça não ficou acima do quadril")
        checa(y("UpperArm_R") > y("Torso"), "ombro não ficou acima do quadril")
        checa(y("ForeArm_R") < y("UpperArm_R"), "cotovelo não ficou abaixo do ombro")
        checa(y("Shin_R") < y("Thigh_R"), "joelho não ficou abaixo do quadril")
        checa(y("Foot_R") < y("Shin_R"), "pé não ficou abaixo do joelho")
        checa(abs(y("Foot_R") - m.base[1]) < m.altura * 0.2, "pé longe do chão")

        met = rig.metricas
        razao = met["shin_len"] / max(met["thigh_len"], 1e-6)
        print("   coxa %.3f  canela %.3f  (razão %.0f%%)" % (
            met["thigh_len"], met["shin_len"], razao * 100))
        checa(0.6 < razao < 1.5, "proporção coxa/canela fora do razoável: %.2f" % razao)

        # tem que aguentar um clipe real do Mixamo sem estourar
        cam = os.path.join(AQUI, "clips", "hurricane_kick.json")
        if os.path.exists(cam):
            c = Clip.de_json(cam)
            po = rig.pose(c.amostrar(0.6))
            checa(len(po) == 13, "clipe do Mixamo não resolveu os 13 ossos")
            checa(len(rig.caixas(po)) == 13, "caixas não saíram para todos os ossos")

    print("\n================================")
    if falhas:
        print("❌ %d falha(s)" % len(falhas))
        return 1
    print("✅ DERIVAÇÃO POR MARCADORES OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
