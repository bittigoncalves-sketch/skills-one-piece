#!/usr/bin/env python3
"""Equipamento PADRÃO das entidades do Mine Piece v14 (30/10/2026).

No mod, a entidade já nasce com itens postos no CONSTRUTOR da classe Java:
    this.setItemSlot(EquipmentSlot.MAINHAND, new ItemStack(MinepieceModItems.RIFLE.get()));
(Yasopp e Benn Beckman: fuzil; Helmeppo: pistola; Charlos, Curiel, Izo, Nero, Van Augur: também). O jogo instancia
personagens pela ficha e esse equipamento se perdia — o Helmeppo, "arma_de_fogo" na ficha, ficava de mãos vazias.

Lê `entity/*Entity.java` do mod descompilado (fonte local, fora do git) e grava `mapas/east_blue/equipamento_padrao.json`:
    {"formato": ..., "entidades": {"helmeppo": {"MAINHAND": "pistol"}, ...}}
O id vem de `entidades_do_mod.json` (classe Java → id de registro); o item, de `MinepieceModItems.java`
(constante → nome de registro). Só dados: quem aplica é `PersonagemMinePiece`."""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import FONTE

RAIZ = Path(__file__).resolve().parents[2]
JAVA = Path(FONTE) / "net/mcreator/minepiece"
SAIDA = RAIZ / "mapas/east_blue/equipamento_padrao.json"
ENTIDADES = RAIZ / "mapas/east_blue/entidades_do_mod.json"

LINHA = re.compile(r"this\.m_8061_\(\s*EquipmentSlot\.(\w+),\s*new ItemStack\(\(ItemLike\)MinepieceModItems\.(\w+)\.get\(\)\)\s*\)")
ITEM = re.compile(r'RegistryObject<[^>]*>\s+(\w+)\s*=\s*REGISTRY\.register\(\s*"([a-z0-9_]+)"')


def main():
    nomes = dict(ITEM.findall((JAVA / "init/MinepieceModItems.java").read_text()))
    dados = json.loads(ENTIDADES.read_text())
    ent = dados.get("entidades", dados)
    por_classe = {str(f.get("classe")): ident for ident, f in ent.items() if isinstance(f, dict)}
    saida = {}
    perdidos = []
    for arq in sorted((JAVA / "entity").glob("*Entity.java")):
        classe = arq.stem
        achados = LINHA.findall(arq.read_text())
        if not achados:
            continue
        ident = por_classe.get(classe)
        if ident is None:
            perdidos.append(classe)
            continue
        slots = {}
        for slot, const in achados:
            if const in nomes:
                slots[slot] = nomes[const]
        if slots:
            saida[ident] = slots
    SAIDA.write_text(json.dumps({"formato": "skills-one-piece/equipamento_padrao", "versao": 1,
                                 "origem": "entity/*Entity.java (construtor) + init/MinepieceModItems.java", "entidades": saida},
                                indent="\t", ensure_ascii=False) + "\n")
    de_fogo = {i: s for i, s in saida.items() if s.get("MAINHAND") in ("rifle", "pistol", "pistol_gold", "rocket_launcher", "senriku")}
    print(f"{len(saida)} entidades com equipamento padrão; {len(de_fogo)} com arma de fogo na mão: {sorted(de_fogo)}")
    if perdidos:
        print(f"sem id em entidades_do_mod.json ({len(perdidos)}): {perdidos[:8]}")


if __name__ == "__main__":
    main()
