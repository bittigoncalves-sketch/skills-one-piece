"""TAGS de entidade do Mine Piece v14 → mapas/east_blue/tags_de_entidade.json (23/10/2026, E1).

`data/<ns>/tags/entity_types/*.json` do mod (forge:human, forge:woman, minepiece:chivalry,
minepiece:can_use_shave, grupos...). Tag que inclui outra (`#forge:x`) é resolvida aqui. A camada
responde `getType().is(TagKey)` por este arquivo (`McTipoEntidade.is_`). Tags de DANO (forge:combat, forge:animation…) respondem
`DamageSource.is(TagKey)` (`McFonteDeDano.is_`) — sem elas o handler que fere dentro do evento reentra sem fim.

    python3 -I tools/mine_piece/extrair_tags.py
"""
import json
import os

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
SAIDA = os.path.join(os.path.dirname(__file__), "..", "..", "mapas", "east_blue", "tags_de_entidade.json")


def ler(categoria: str) -> dict:
    brutas = {}
    for ns in os.listdir(os.path.join(MOD, "data")):
        pasta = os.path.join(MOD, "data", ns, "tags", categoria)
        if not os.path.isdir(pasta):
            continue
        for f in os.listdir(pasta):
            valores = json.load(open(os.path.join(pasta, f))).get("values", [])
            brutas[f"{ns}:{f[:-5]}"] = [v if isinstance(v, str) else v.get("id") for v in valores]
    return resolvidas(brutas)


def resolvidas(brutas: dict) -> dict:
    def resolver(tag, vistos=()):
        saida = set()
        for v in brutas.get(tag, []):
            if v.startswith("#"):
                if v[1:] not in vistos:
                    saida |= resolver(v[1:], vistos + (tag,))
            else:
                saida.add(v)
        return saida

    return {t: sorted(resolver(t)) for t in sorted(brutas)}


def main() -> None:
    tags = ler("entity_types")
    tags_de_item = ler("items")
    tags_de_bloco = ler("blocks")
    tags_de_dano = ler("damage_type")
    sha = open(os.path.join(MOD, "ORIGEM.sha256")).read().split()[0]
    json.dump({"formato": "skills-one-piece/tags-de-entidade-mine-piece", "versao": 1,
               "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "sha256": sha,
                          "extraido_por": "tools/mine_piece/extrair_tags.py"}, "tags": tags,
               "tags_de_item": tags_de_item, "tags_de_bloco": tags_de_bloco,
               "tags_de_dano": tags_de_dano},
              open(SAIDA, "w"), ensure_ascii=False, indent=1)
    print(f"{len(tags_de_item)} tags de item, {len(tags_de_bloco)} de bloco; {len(tags)} de entidade → {os.path.normpath(SAIDA)}; ex.: forge:human {len(tags.get('forge:human', []))}, "
          f"forge:woman {len(tags.get('forge:woman', []))}, forge:ranged_ammo {len(tags.get('forge:ranged_ammo', []))}")


if __name__ == "__main__":
    main()
