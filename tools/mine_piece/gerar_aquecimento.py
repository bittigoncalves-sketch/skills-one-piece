#!/usr/bin/env python3
"""Gera mapas/east_blue/aquecimento_de_procedures.json (04/11/2026).

A camada Minecraft carrega cada procedure do mod com `load()` na PRIMEIRA vez que ela é pedida (Mc.proc). No meio da partida isso vira um
engasgo: medido 12,4 ms (LogicAttackProcedure) + 3,7 ms (GetEntityByUUIDProcedure) num único quadro, ao primeiro tick do EntityActiveProcedure.
Este script calcula, SEM abrir o jogo, o conjunto de procedures que os handlers de evento (mapas/east_blue/eventos_do_mod.json) podem chamar,
direta ou indiretamente, para o jogo carregá-las na tela de carregamento (Mc.aquecer).

Rodar de novo (gatilho): sempre que o tradutor regerar src/minecraft/gerado/procedures/ ou o eventos_do_mod.json mudar.
    python3 -I tools/mine_piece/gerar_aquecimento.py
"""
import json, os, re, sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROCS = os.path.join(RAIZ, "src/minecraft/gerado/procedures")
EVENTOS = os.path.join(RAIZ, "mapas/east_blue/eventos_do_mod.json")
SAIDA = os.path.join(RAIZ, "mapas/east_blue/aquecimento_de_procedures.json")

todos = {f[:-3] for f in os.listdir(PROCS) if f.endswith(".gd")}
rx = re.compile(r'Mc\.proc\(&"(\w+)"\)|\b(\w+Procedure)\.(?:execute|on)\w*\(')
dep = {}
for n in todos:
    with open(os.path.join(PROCS, n + ".gd"), encoding="utf-8") as f:
        dep[n] = {m.group(1) or m.group(2) for m in rx.finditer(f.read())} & todos

with open(EVENTOS, encoding="utf-8") as f:
    eventos = json.load(f)["eventos"]
raizes = sorted({par[0] for lst in eventos.values() for par in lst} & todos)

visto, pilha = set(), list(raizes)
while pilha:
    n = pilha.pop()
    if n in visto:
        continue
    visto.add(n)
    pilha.extend(dep[n])

saida = {"gerado_por": "tools/mine_piece/gerar_aquecimento.py", "raizes": len(raizes), "procedures": sorted(visto)}
with open(SAIDA, "w", encoding="utf-8") as f:
    json.dump(saida, f, indent=1)
    f.write("\n")
print("handlers:", len(raizes), "| procedures a aquecer:", len(visto), "->", os.path.relpath(SAIDA, RAIZ))
