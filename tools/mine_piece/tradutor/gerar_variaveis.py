"""Gera `src/minecraft/gerado/variaveis_do_mod.gd` das VARIÁVEIS do Mine Piece (23/10/2026, E1).

`MinepieceModVariables.java` declara três conjuntos com tipo e valor padrão:
  • PlayerVariables (capability do jogador: técnica escolhida, recompensa, fruta, forma, time…);
  • MapVariables e WorldVariables (SavedData do mundo: PvP, raid…).
Cada um vira uma classe interna com os mesmos campos e padrões; `syncPlayerVariables`/`syncData`/
`setDirty` existem (no jogo não há rede a sincronizar aqui). A camada (`Mc`, `McEntidade`) entrega
uma instância por entidade/por mundo.

    tools/mine_piece/.venv/bin/python tools/mine_piece/tradutor/gerar_variaveis.py
"""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
from srg_oficial import mapa, traduzir  # noqa: E402

FONTE = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/net/mcreator/minepiece/"
                           "network/MinepieceModVariables.java")
SAIDA = os.path.join(AQUI, "..", "..", "..", "src", "minecraft", "gerado", "variaveis_do_mod.gd")
TIPOS = {"double": ("float", "0.0"), "float": ("float", "0.0"), "int": ("int", "0"), "boolean": ("bool", "false"),
         "String": ("String", '""'), "ItemStack": ("", "McItem.pilha(null, 0)")}   # ItemStack.EMPTY, não null


def campos(texto: str, classe: str) -> list:
    i = texto.find(f"public static class {classe}")
    corpo = texto[i:]
    fim = corpo.find("\n   }\n")
    corpo = corpo[:fim if fim > 0 else len(corpo)]
    saida = []
    for m in re.finditer(r"^\s{6}public (double|float|int|boolean|String|ItemStack) (\w+)(?: = ([^;]+))?;", corpo, re.M):
        tipo, nome, valor = m.group(1), m.group(2), m.group(3)
        gd_tipo, padrao = TIPOS[tipo]
        if valor is not None and tipo != "ItemStack":
            valor = valor.strip().rstrip("FfDdLl") if tipo in ("double", "float", "int") else valor.strip()
            if tipo in ("double", "float") and re.fullmatch(r"-?\d+", valor):
                valor += ".0"
            padrao = valor
        saida.append((nome, gd_tipo, padrao))
    return saida


def main() -> None:
    texto = traduzir(open(FONTE, encoding="utf-8", errors="replace").read(), mapa())
    linhas = ["# GERADO por tools/mine_piece/tradutor/gerar_variaveis.py de MinepieceModVariables.java — não editar.",
              "class_name McVariaveisDoMod", "extends RefCounted", ""]
    total = 0
    for classe in ("PlayerVariables", "MapVariables", "WorldVariables"):
        cs = campos(texto, classe)
        total += len(cs)
        linhas += [f"class {classe}:", "\textends RefCounted"]
        for nome, tipo, padrao in cs:
            linhas.append(f"\tvar {nome}{(': ' + tipo) if tipo else ''} = {padrao}")
        linhas += ["\tfunc syncPlayerVariables(_e: Variant = null) -> void: pass",
                   "\tfunc syncData(_w: Variant = null) -> void: pass",
                   "\tfunc setDirty() -> void: pass", ""]
    # Regras de jogo do mod (MinepieceModGameRules.java) com o padrão de cada uma: campo → valor.
    regras = {}
    texto_regras = traduzir(open(os.path.join(os.path.dirname(FONTE), "..", "init", "MinepieceModGameRules.java"),
                                 encoding="utf-8", errors="replace").read(), mapa())
    for m in re.finditer(r"Key<(Boolean|Integer)Value> (\w+) = GameRules\.\w+\(\s*\"\w+\",\s*Category\.\w+,\s*\w+\.\w+\(([^)]*)\)",
                         texto_regras, re.S):
        regras[m.group(2).lower()] = m.group(3).strip().lower() if m.group(1) == "Boolean" else int(m.group(3))
    linhas += ["## Regras de jogo do mod (campo em minúsculas → padrão).",
               "const REGRAS := {" + ", ".join(f'&"minepiece:{k}": {v}' for k, v in regras.items()) + "}"]
    open(SAIDA, "w").write("\n".join(linhas) + "\n")
    print(f"{total} variáveis, {len(regras)} regras de jogo → {os.path.normpath(SAIDA)}")


if __name__ == "__main__":
    main()
