#!/usr/bin/env python3
"""Acrescenta a `mapas/east_blue/personagens.json` os personagens do mod que nascem pelas regras de spawn
natural e ainda não têm ficha de jogo (24/10/2026).

    python3 -I tools/mine_piece/extrair_east_blue.py      # 1) ficha extraída (inclui quem nasce por spawn)
    python3 -I tools/mine_piece/gerar_dados_do_mod.py     # 2) este script: só ACRESCENTA ids novos

DECISÃO DO DONO (24/10/2026): habilidade de inimigo = a do mod, fiel; nada do skill builder (limita o que se importa).
Por isso estas fichas NÃO têm tabela de técnicas (`tecnicas: []`, `comuns: []`): quem escolhe e executa é a IA do
mod (`IaDoMod`). Só entram FATOS do mod (atributos, tamanho, modelo, tags, status). Facção = "mod": o cérebro pergunta à
`LogicAttackProcedure` do próprio mod quem pode atacar quem. Declarado como escolha NOSSA (não do mod): `chefe`
(barra de vida no topo) = vida máxima ≥ 300.
Não mexe nos personagens que já existem (a ficha deles pode ter sido recalibrada à mão).
"""
import json
import os

FICHA = "docs/referencias/mine_piece/east_blue/personagens.json"
SAIDA = "mapas/east_blue/personagens.json"
ESPADAS = {"SABER", "CUTLASS", "WADO_ICHIMONJI", "GRIFFON", "DAISENSO", "JITTE", "CAT_CLAWS", "ARM_AXE", "METAL_ROD",
           "TONFA", "LONG_STICK", "THUNDER_STICK", "KIRIBACHI", "YORU", "ENMA", "SHUSUI", "KIKOKU_BLADE", "KITETSU_SANDAI"}
ARMAS_DE_FOGO = {"RIFLE", "PISTOL", "PISTOL_GOLD", "ROCKET_LAUNCHER"}
VIDA_DE_CHEFE = 300.0


def main() -> int:
    dados = json.load(open(SAIDA, encoding="utf-8"))
    ja = {p["id"] for p in dados["personagens"]}
    novos, sem_modelo = [], []
    for p in json.load(open(FICHA, encoding="utf-8"))["personagens"]:
        if p["id"] in ja:
            continue
        m = p["modelo"]
        if not (m.get("geo_existe") and m.get("textura_existe")):
            sem_modelo.append(p["id"])               # corpos invisíveis (spawners) e afins: sem desenho para importar
            continue
        a = p["atributos"]
        status = next((s for v in p["ia"].values() for s in v["status"]), [-1.0, -1.0, -1.0, -1.0])
        itens = set(p["itens_citados"])
        novos.append({
            "id": p["id"], "nome": p["nome"], "nome_mod": p["nome"], "zona": p["zona"],
            "modelo": f"mp_{p['id']}", "modelos": [],
            "chefe": a.get("vida_max", 20.0) >= VIDA_DE_CHEFE,
            "faccao": "mod",
            "vida": a.get("vida_max", 20.0), "armadura": a.get("armadura", 0.0),
            "velocidade": a.get("velocidade", 0.3), "dano_corpo": a.get("dano_de_ataque", 1.0),
            "resistencia_a_empurrao": a.get("resistencia_a_empurrao", 0.0),
            "alcance_de_perseguicao": a.get("alcance_de_perseguicao", 16.0),
            "forca": status[0], "resistencia": status[1],
            "altura": p["altura"] or 1.8, "largura": p["largura"] or 0.6,
            "fruta": p["fruta"], "nada": "minepiece:swim_attackabe" in p["tags"] or "swim_attackabe" in p["tags"],
            "espada": bool(itens & ESPADAS), "arma_de_fogo": bool(itens & ARMAS_DE_FOGO),
            "tecnicas": [], "comuns": [],
        })
    dados["personagens"] += novos
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent="\t")
    print(f"+{len(novos)} personagens (total {len(dados['personagens'])}); sem modelo para importar: {sem_modelo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
