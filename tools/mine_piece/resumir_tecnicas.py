#!/usr/bin/env python3
"""Resumo factual de procedimentos de técnica do Mine Piece (descompilado local): valores de
Damage/Range/knockback/effect, duração (o maior limiar de contador antes de `skill = 0`),
entidades criadas, investida (setDeltaMovement) e sub-golpes chamados. Só números e nomes.

    python3 -I tools/mine_piece/resumir_tecnicas.py Nome1 Nome2 ... > saida.json
"""
import json
import os
import re
import sys

P = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/net/mcreator/minepiece/procedures")


def resumo(nome):
    t = open(os.path.join(P, nome + "Procedure.java"), encoding="utf-8").read()
    def vals(chave):
        return sorted(set(re.sub(r"\s+", "", m) for m in re.findall(rf'm_128347_\("{chave}",\s*(.+?)\);', t)))[:8]
    fim = [float(x) for x in re.findall(r'm_128459_\("cnt\d+"\)\s*>=?\s*([\d.]+)\)\s*\{\s*\n\s*entity\.getPersistentData\(\)\.m_128347_\("skill",\s*0\.0\)', t)]
    limiares = sorted(set(float(x) for x in re.findall(r'm_128459_\("cnt\d+"\)\s*(?:<=?|>=?|==)\s*([\d.]+)\)', t)))
    return {
        "linhas": t.count("\n"),
        "dano": vals("Damage"), "alcance": vals("Range"), "empurrao": vals("knockback"),
        "efeito": vals("effect"), "bloco": vals("BlockRange"),
        "fim_ticks": max(fim) if fim else (max(limiares) if limiares else None),
        "limiares": limiares[:12],
        "entidades": sorted(set(re.findall(r"MinepieceModEntities\.([A-Z0-9_]+)", t))),
        "investida": "m_20256_(" in t, "teleporte": "m_6021_(" in t or "m_20324_(" in t,
        "chama": sorted(set(re.findall(r"(\w+)Procedure\.execute", t)) - {
            "RotateEntity", "ReturnEntitySize", "PlayAnimation", "DamageFix", "GetDistance",
            "GetDistanceNearestEnemy", "LogicAttack", "ParticleGenerator", "SetRangedAmmo", "ResetCounter"}),
        "sons": sorted(set(re.findall(r'ResourceLocation\("((?:minepiece|entity|block)[:.][^"]+)"\)', t)))[:6],
    }


if __name__ == "__main__":
    json.dump({n: resumo(n) for n in sys.argv[1:]}, sys.stdout, ensure_ascii=False, indent=1)
