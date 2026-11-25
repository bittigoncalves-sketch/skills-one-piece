"""Cobertura do CONTEÚDO do Mine Piece v14 no Skills One Piece — 23/10/2026.

Par do `medir_dependencias_minecraft.py` (o que o mod pede do Minecraft): aqui, o que o mod TEM
(entidades, frutas, itens, estruturas, sons, conquistas) e quanto disso já existe no jogo. Casa
por nome: modelo `mapas/modelos/mp_<id>.glb` / `mpe_<id>.glb`, ficha em
`mapas/east_blue/personagens.json`, fruta em `CatalogoFrutasMinePiece.FICHAS` (+ a Goro).
Casar por nome mede IMPORTAÇÃO, não comportamento: modelo presente ≠ IA/golpes traduzidos.

    python3 -I tools/mine_piece/medir_cobertura.py [--saida ARQ.json]
"""
import argparse
import collections
import json
import os
import re

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
INIT = os.path.join(MOD, "net/mcreator/minepiece/init")
JOGO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def ler(caminho: str) -> str:
    return open(caminho, encoding="utf-8", errors="replace").read()


def registros(arquivo: str) -> list:
    """[(nome, classe, categoria)] dos `register("nome", ...)` de um init do MCreator."""
    texto = ler(os.path.join(INIT, arquivo))
    saida = []
    for m in re.finditer(r'register\(\s*"([a-z0-9_]+)"\s*,\s*([^\n]*)\n?([^\n]*)', texto):
        resto = m.group(2) + m.group(3)
        classe = re.search(r"(\w+)::new", resto)
        cat = re.search(r"MobCategory\.(\w+)", resto)
        saida.append((m.group(1), classe.group(1) if classe else "", cat.group(1) if cat else ""))
    return saida


def tipo_de_entidade(nome: str, cat: str) -> str:
    if re.search(r"ship|boat|sunny|merry|moby|red_force|baratie", nome):
        return "navio"
    if cat == "MISC" or re.search(r"^(entity_|projectile_|bullet|slash|fist|tornado|meteor|ice_|wave)", nome):
        return "projétil/efeito"
    if re.search(r"^(pirate|marine|bandit|citizen|villager|fishman|giant|shark|sea_king|neptunian|"
                 r"pacifista|seastone|dummy|mob)", nome):
        return "mob genérico"
    return "personagem/criatura"


def tipo_de_item(nome: str, classe: str) -> str:
    if nome.endswith("_spawn_egg"):
        return "ovo de spawn"
    if re.search(r"no_mi|devil_fruit|_fruit$", nome):
        return "fruta"
    if re.search(r"_helmet|_chestplate|_leggings|_boots|armor|clothes|coat|hat", nome) or "Armor" in classe:
        return "roupa/armadura"
    if re.search(r"sword|katana|blade|gun|pistol|rifle|cannon|kabuto|staff|spear|axe|bazooka", nome):
        return "arma"
    if re.search(r"ship|boat", nome):
        return "navio (item)"
    if re.search(r"meat|food|sake|rum|bread|cola|fish|onigiri|bento", nome):
        return "comida/bebida"
    return "outro"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", default="")
    args = ap.parse_args()
    modelos = {re.sub(r"^mpe?_", "", os.path.splitext(f)[0]) for f in os.listdir(os.path.join(JOGO, "mapas/modelos"))
               if re.match(r"mpe?_.*\.glb$", f)}
    fichas = json.load(open(os.path.join(JOGO, "mapas/east_blue/personagens.json")))["personagens"]
    com_ficha = {re.sub(r"^mpe?_", "", str(p.get("modelo", ""))) for p in fichas} | {str(p["id"]) for p in fichas}
    catalogo = ler(os.path.join(JOGO, "src/combat/frutas_mine_piece/catalogo.gd"))
    frutas_jogo = set(re.findall(r'"res://src/combat/frutas_mine_piece/(\w+)\.gd"', catalogo)) | {"goro"}

    r = {}
    # Entidades
    ents = registros("MinepieceModEntities.java")
    por_tipo = collections.defaultdict(lambda: [0, 0, 0, []])   # total, modelo, ficha, faltando
    for nome, classe, cat in ents:
        t = tipo_de_entidade(nome, cat)
        base = re.sub(r"_\d+$", "", nome)
        tem_modelo = nome in modelos or base in modelos or any(m.startswith(nome) for m in modelos)
        tem_ficha = nome in com_ficha or base in com_ficha
        d = por_tipo[t]
        d[0] += 1
        d[1] += tem_modelo
        d[2] += tem_ficha
        if not tem_modelo:
            d[3].append(nome)
    r["entidades"] = {t: {"total": d[0], "com_modelo": d[1], "com_ficha_de_personagem": d[2], "sem_modelo": d[3]}
                      for t, d in por_tipo.items()}
    # Frutas (a tag do mod) × executores nativos
    tag = json.load(open(os.path.join(MOD, "data/minepiece/tags/items/devil_fruit.json")))["values"]
    frutas_mod = sorted(v.split(":")[1].replace("item_devil_fruit_", "") for v in tag
                        if isinstance(v, str) and v.split(":")[1] != "item_devil_fruit")   # o genérico não é fruta
    traduzidas = [f for f in frutas_mod if f.split("_")[0] in frutas_jogo]
    r["frutas"] = {"total": len(frutas_mod), "traduzidas": traduzidas,
                   "faltando": [f for f in frutas_mod if f not in traduzidas]}
    # Itens
    itens = registros("MinepieceModItems.java")
    c = collections.Counter(tipo_de_item(n, cl) for n, cl, _ in itens)
    total_itens = ler(os.path.join(INIT, "MinepieceModItems.java")).count("RegistryObject<Item>")
    r["itens"] = {"total": total_itens, "classificados": len(itens), "por_tipo": dict(c.most_common())}
    # Estruturas, sons, conquistas, efeitos
    estruturas = sorted(os.path.splitext(f)[0] for f in os.listdir(os.path.join(MOD, "data/minepiece/structures")))
    r["estruturas"] = {"total": len(estruturas), "importadas": [e for e in estruturas if e in modelos],
                       "faltando": [e for e in estruturas if e not in modelos]}
    sons = os.listdir(os.path.join(MOD, "assets/minepiece/sounds"))
    sons_jogo = {f for _, _, fs in os.walk(os.path.join(JOGO, "assets/mine_piece")) for f in fs if f.endswith(".ogg")}
    r["sons"] = {"total": len(sons), "importados": sorted(set(sons) & sons_jogo)}
    r["conquistas"] = len(os.listdir(os.path.join(MOD, "data/minepiece/advancements")))
    r["efeitos_do_mod"] = ler(os.path.join(INIT, "MinepieceModMobEffects.java")).count("RegistryObject<MobEffect>")

    print("ENTIDADES (283 registradas):")
    for t, d in sorted(r["entidades"].items(), key=lambda x: -x[1]["total"]):
        print(f"  {t:22s} {d['total']:4d}  modelo no jogo {d['com_modelo']:4d}  ficha de personagem {d['com_ficha_de_personagem']:3d}")
    f = r["frutas"]
    print(f"FRUTAS: {len(f['traduzidas'])}/{f['total']} com executor nativo ({', '.join(f['traduzidas'])})")
    print(f"ITENS: {r['itens']['total']} ({r['itens']['classificados']} classificados)  " + ", ".join(f"{k} {v}" for k, v in r["itens"]["por_tipo"].items()))
    e = r["estruturas"]
    print(f"ESTRUTURAS: {len(e['importadas'])}/{e['total']} importadas")
    print(f"SONS: {len(r['sons']['importados'])}/{r['sons']['total']}   CONQUISTAS: {r['conquistas']}   EFEITOS DO MOD: {r['efeitos_do_mod']}")
    if args.saida:
        json.dump(r, open(args.saida, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
