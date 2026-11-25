"""SRG → nome oficial da Mojang para o Minecraft 1.20.1 (23/10/2026).

O JAR de produção do Mine Piece chama o Minecraft por nomes SRG (`m_20256_`, `f_19853_`): a
medição por nome (setDeltaMovement, explode...) não via nada. Junta os dois mapeamentos que o
instalador do Forge deixa no disco:
  • mcp_config (tsrg2):  classe/membro ofuscado → SRG
  • Mojang (proguard):   classe/membro oficial  → ofuscado
e devolve {srg: nome oficial}. Sobrecargas com nomes diferentes viram "a|b".

    from srg_oficial import mapa; m = mapa()   # cache em ~/.cache/skills-one-piece/srg_1.20.1.json
"""
import json
import os
import re

TSRG = "/home/gabriel-bitti/server_onepiece/libraries/de/oceanlabs/mcp/mcp_config/1.20.1-20230612.114412/" \
       "mcp_config-1.20.1-20230612.114412-mappings.txt"
MOJANG = "/home/gabriel-bitti/Documents/curseforge/minecraft/Install/libraries/net/minecraft/client/" \
         "1.20.1-20230612.114412/client-1.20.1-20230612.114412-mappings.txt"
CACHE = os.path.expanduser("~/.cache/skills-one-piece/srg_1.20.1.json")


PRIMITIVOS = {"int": "I", "long": "J", "float": "F", "double": "D", "boolean": "Z", "byte": "B", "char": "C",
              "short": "S", "void": "V"}


def _mojang():
    """Membros da Mojang por chave ofuscada: método (classe, nome, descritor) e campo (classe, nome)
    → nome oficial. Descritor convertido para tipos OFUSCADOS para casar com o tsrg2."""
    classes = {}                                    # oficial → ofuscado (com /)
    for linha in open(MOJANG, encoding="utf-8"):
        m = re.match(r"(\S+) -> (\S+):", linha)
        if m:
            classes[m.group(1)] = m.group(2).replace(".", "/")

    def tipo(t: str) -> str:
        dims = t.count("[]")
        base = t.replace("[]", "")
        d = PRIMITIVOS.get(base) or "L" + classes.get(base, base.replace(".", "/")) + ";"
        return "[" * dims + d

    membros = {}
    atual = None
    for linha in open(MOJANG, encoding="utf-8"):
        if linha.startswith("#"):
            continue
        if not linha.startswith(" "):
            m = re.match(r"(\S+) -> (\S+):", linha)
            atual = m.group(2).replace(".", "/") if m else None
            continue
        if atual is None:
            continue
        m = re.match(r"\s+(?:\d+:\d+:)?(\S+) ([\w$<>]+)\((.*)\)(?::\d+:\d+)? -> ([\w$<>]+)", linha)
        if m:
            args = "".join(tipo(a) for a in m.group(3).split(",") if a)
            membros[(atual, m.group(4), "(" + args + ")" + tipo(m.group(1)))] = m.group(2)
            continue
        m = re.match(r"\s+(\S+) ([\w$]+) -> ([\w$]+)", linha)
        if m:
            membros[(atual, m.group(3))] = m.group(2)
    return membros


def mapa() -> dict:
    if os.path.exists(CACHE):
        return json.load(open(CACHE))
    moj = _mojang()
    saida = {}
    classe = None
    for linha in open(TSRG, encoding="utf-8"):
        if linha.startswith("tsrg2"):
            continue
        if not linha.startswith("\t"):
            classe = linha.split()[0]
            continue
        if linha.startswith("\t\t"):
            continue                                 # parâmetros
        partes = linha.split()
        if len(partes) == 4:                         # método: obf desc srg id
            chave, srg = (classe, partes[0], partes[1]), partes[2]
        else:                                        # campo: obf srg id
            chave, srg = (classe, partes[0]), partes[1]
        if not re.fullmatch(r"[mf]_\d+_", srg):
            continue
        nome = moj.get(chave)
        if nome:
            saida.setdefault(srg, set()).add(nome)
    final = {k: "|".join(sorted(v)) for k, v in saida.items()}
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump(final, open(CACHE, "w"))
    return final


def traduzir(texto: str, m: dict) -> str:
    return re.sub(r"\b[mf]_\d+_\b", lambda x: m.get(x.group(0), x.group(0)).split("|")[0], texto)


if __name__ == "__main__":
    m = mapa()
    print(len(m), "nomes;", {k: m.get(k) for k in ["m_20256_", "m_128459_", "m_7654_", "m_20299_", "m_255391_"]})
