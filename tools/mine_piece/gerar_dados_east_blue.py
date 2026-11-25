#!/usr/bin/env python3
"""Gera `mapas/east_blue/personagens.json` — os dados de JOGO dos personagens do East Blue
(17/10/2026) — a partir da ficha extraída do Mine Piece e da tabela de técnicas abaixo.

    python3 -I tools/mine_piece/gerar_dados_east_blue.py

A tabela de técnicas é a leitura das IAs do mod (`docs/referencias/mine_piece/east_blue/
personagens.json`, campo `ia.*.tecnicas`): chance por decisão (a cada 0,5 s), faixa de
distância, recarga em tiques (20/s), condições. Simplificações declaradas:
  • `level_power >= N` conta como cumprido (no mod o raid sobe o nível dos personagens);
  • `VSStrongEnemy` vira `contra_forte`: o alvo tem ao menos metade da vida máxima do atacante;
  • `!flag1` com vida baixa vira `uma_vez` (uma vez por vez que a vida cai abaixo do limite).
Arquivo editável à mão depois (o dono vai recalibrar tudo).
"""
import json
import os

FICHA = "docs/referencias/mine_piece/east_blue/personagens.json"
SAIDA = "mapas/east_blue/personagens.json"

NOMES = {
    "higuma": "Higuma", "bandit": "Bandido da montanha", "alvida": "Alvida", "pirate": "Pirata",
    "morgan": "Morgan", "helmeppo": "Helmeppo", "marine": "Marinheiro", "coby": "Coby",
    "buggy": "Buggy", "cabaji": "Cabaji", "richie": "Richie", "kuro": "Kuro", "jango": "Jango",
    "sham": "Sham", "buchi": "Buchi", "krieg": "Don Krieg", "gin": "Gin", "sanji_east_blue": "Sanji",
    "fullbody": "Fullbody", "arlong": "Arlong", "kuroobi": "Kuroobi", "hatchan": "Hatchan", "chu": "Chu",
    "smoker": "Smoker", "tashigi": "Tashigi", "alvida_2": "Alvida (Loguetown)", "girl_icecream": "Menina do sorvete",
    "shanks": "Shanks", "benn_beckman": "Benn Beckman", "lucky_roux": "Lucky Roux", "yasopp": "Yasopp",
    "lime_juice": "Lime Juice", "hongo": "Hongo", "gab": "Gab", "bonk_punch": "Bonk Punch",
    "building_snake": "Building Snake", "monster_1": "Monster", "luffy_east_blue": "Luffy",
    "zoro_east_blue": "Zoro", "yosaku": "Yosaku", "jonny": "Johnny",
}
# Chefe = barra no topo da tela (BarrasDeChefes) e sem XP aleatório: XP pela dificuldade.
CHEFES = {"higuma", "alvida", "morgan", "buggy", "kuro", "krieg", "arlong", "smoker", "shanks"}

# Facção (LogicAttackTargetStart): "pirata:<bando>" ataca marinha e outros bandos; "marinha"
# ataca piratas; "aliado" (tag group_1) nunca ataca o jogador sozinho, só revida; "nenhuma"
# ataca todos; "raid:<id>" ataca o jogador e não os do mesmo raid. O JOGADOR é pirata de bando
# próprio (decisão declarada, docs/EAST_BLUE_PLANO.md).
FACCAO_POR_ZONA = {
    "bandidos": "nenhuma", "alvida": "pirata:alvida", "shells_town": "marinha",
    "orange_town": "pirata:buggy", "vila_syrup": "pirata:gato_preto", "baratie": "pirata:krieg",
    "arlong_park": "pirata:arlong", "loguetown": "raid:loguetown", "ruivo": "aliado", "aliados": "aliado",
}
FACCAO_PROPRIA = {"sanji_east_blue": "aliado", "fullbody": "marinha", "coby": "marinha", "helmeppo": "marinha"}

ESPADAS = {"SABER", "CUTLASS", "WADO_ICHIMONJI", "GRIFFON", "DAISENSO", "JITTE", "CAT_CLAWS", "ARM_AXE", "METAL_ROD",
           "TONFA", "LONG_STICK", "THUNDER_STICK"}
ARMAS_DE_FOGO = {"RIFLE", "PISTOL"}

# Técnica do mod → skill do Builder (gerada por tools/mine_piece/criar_tecnicas_east_blue.gd).
def t(skill, chance, dmin=0.0, dmax=64.0, recarga=50, **extra):
    return {"skill": skill, "chance": chance, "distancia_min": dmin, "distancia_max": dmax,
            "recarga": recarga / 20.0, **extra}

TECNICAS = {
    "coby": [t("mpeb_rankyaku", 0.25, dmin=8.0, recarga=50),
             t("mpeb_galaxy_divide", 0.1, dmax=64.0, recarga=200),
             t("mpeb_galaxy_divide", 1.0, recarga=200, vida_abaixo=0.5, uma_vez=True, contra_forte=True)],
    "cabaji": [t("mpeb_fresh_fire", 0.25, dmax=16.0, recarga=50)],
    "richie": [t("mpeb_ataque_por_cima", 0.5, recarga=60), t("mpeb_ataque_veloz", 0.5, dmax=12.0, recarga=50)],
    "kuro": [t("mpeb_shakushi", 0.1, dmax=40.0, recarga=200, contra_forte=True),
             t("mpeb_shakushi", 1.0, dmax=40.0, recarga=200, contra_forte=True, vida_abaixo=0.5, uma_vez=True)],
    "buchi": [t("mpeb_cat_the_funjatta", 0.2, dmax=16.0, recarga=50)],
    "krieg": [t("mpeb_krieg_balas", 0.1, dmax=32.0, recarga=50)],
    "sanji_east_blue": [t("mpeb_chute_sete_mil_tijolos", 0.33, dmax=8.0, recarga=50),
                        t("mpeb_mouton_shoot", 0.1, dmax=24.0, recarga=100),
                        t("mpeb_chute_giratorio", 0.25, dmax=12.0, recarga=100),
                        t("mpeb_concasse", 0.1, dmax=24.0, recarga=200)],
    "arlong": [t("mpeb_uchimizu", 0.01, dmin=4.0, dmax=24.0, recarga=25)],
    "chu": [t("mpeb_uchimizu", 0.25, dmin=4.0, dmax=24.0, recarga=25)],
    "smoker": [t("mpeb_moku_white_blow", 0.5, dmax=32.0, recarga=60),
               t("mpeb_moku_white_vine", 0.2, dmax=24.0, recarga=125),
               t("mpeb_moku_white_launcher", 0.25, dmin=12.0, recarga=125),
               t("mpeb_moku_white_out", 0.125, dmax=32.0, recarga=150)],
    "girl_icecream": [t("mpeb_ataque_veloz", 0.5, recarga=60), t("mpeb_ataque_por_cima", 0.5, dmax=12.0, recarga=50)],
    "shanks": [t("mpeb_haki_do_rei", 1.0, recarga=600, uma_vez_por_combate=True),
               t("mpeb_corte_projetado", 0.25, dmin=8.0, dmax=48.0, recarga=50),
               t("mpeb_investida_de_espada", 0.25, dmax=64.0, recarga=100),
               t("mpeb_griffon_estocada", 0.25, dmin=8.0, dmax=64.0, recarga=175, contra_forte=True),
               t("mpeb_kamusari", 0.1, recarga=250, contra_forte=True),
               t("mpeb_kamusari", 1.0, recarga=250, vida_abaixo=0.5, uma_vez=True)],
    "benn_beckman": [t("mpeb_tiro_forte", 0.7, dmin=6.0, recarga=100), t("mpeb_tiro_forte", 0.2, dmax=6.0, recarga=100)],
    "yasopp": [t("mpeb_tiro_forte", 0.7, dmin=6.0, recarga=100), t("mpeb_tiro_forte", 0.2, dmax=6.0, recarga=100)],
    "lucky_roux": [t("mpeb_lucky_roux_meteoro", 0.1, dmax=16.0, recarga=200),
                   t("mpeb_lucky_roux_investida", 0.25, dmax=24.0, recarga=100)],
    "hongo": [t("mpeb_chute_sete_mil_tijolos", 0.5, dmax=8.0, recarga=50), t("mpeb_narikabura", 0.2, dmin=8.0, recarga=125)],
    "gab": [t("mpeb_narikabura", 0.2, dmin=8.0, recarga=125)],
    "building_snake": [t("mpeb_chute_sete_mil_tijolos", 0.75, dmax=8.0, recarga=50)],
    "luffy_east_blue": [t("mpeb_gomu_rocket", 0.5, dmin=16.0, recarga=75),
                        t("mpeb_haki_do_rei", 1.0, recarga=600, uma_vez_por_combate=True)],
    "zoro_east_blue": [t("mpeb_corte_projetado", 0.5, dmin=8.0, recarga=50),
                       t("mpeb_tatsumaki", 0.1, dmax=36.0, recarga=125),
                       t("mpeb_iai", 0.05, dmax=24.0, recarga=200, contra_forte=True),
                       t("mpeb_sanzen_sekai", 1.0, dmax=24.0, recarga=250, vida_abaixo=0.3, uma_vez=True),
                       t("mpeb_ashura", 1.0, dmax=24.0, recarga=400, vida_abaixo=0.3, uma_vez=True)],
}

# Ataque comum (CalculateAttack): quais variações cada um pode sortear, pelas tags do mod.
def comuns(p):
    tags = set(p["tags"])
    c = ["mpeb_comum_soco" if not espada(p) else "mpeb_comum_corte", "mpeb_comum_forte"]
    if "jumping_attackable" in tags: c.append("mpeb_ataque_salto")
    if "running_attackable" in tags: c.append("mpeb_ataque_investida")
    if "overhead_attackable" in tags: c.append("mpeb_ataque_por_cima")
    if "speed_attackable" in tags: c.append("mpeb_ataque_veloz")
    if arma_de_fogo(p): c.append("mpeb_comum_tiro")
    return c


def espada(p):
    return bool(set(p["itens_citados"]) & ESPADAS)


def arma_de_fogo(p):
    return bool(set(p["itens_citados"]) & ARMAS_DE_FOGO)


def main():
    fichas = json.load(open(FICHA, encoding="utf-8"))["personagens"]
    saida = []
    for p in fichas:
        a = p["atributos"]
        status = next((s for v in p["ia"].values() for s in v["status"]), [-1.0, -1.0, -1.0, -1.0])
        pid = p["id"]
        saida.append({
            "id": pid, "nome": NOMES.get(pid, p["nome"]), "nome_mod": p["nome"], "zona": p["zona"],
            "modelo": f"mp_{pid}",
            # Pele sorteada como no mod (SetTagPirate: steve_pirate1..8).
            "modelos": [f"mp_pirate_pirate{i}" for i in range(1, 9)] if pid == "pirate" else [],
            "chefe": pid in CHEFES,
            "faccao": FACCAO_PROPRIA.get(pid, FACCAO_POR_ZONA[p["zona"]]),
            "vida": a.get("vida_max", 20.0), "armadura": a.get("armadura", 0.0),
            "velocidade": a.get("velocidade", 0.3), "dano_corpo": a.get("dano_de_ataque", 1.0),
            "resistencia_a_empurrao": a.get("resistencia_a_empurrao", 0.0),
            "alcance_de_perseguicao": a.get("alcance_de_perseguicao", 16.0),
            # SetStatus: amplificador do efeito Força / Resistência (−1 = sem efeito).
            "forca": status[0], "resistencia": status[1],
            "altura": p["altura"] or 1.8, "largura": p["largura"] or 0.6,
            "fruta": p["fruta"], "nada": "swim_attackabe" in p["tags"],
            "espada": espada(p), "arma_de_fogo": arma_de_fogo(p),
            "tecnicas": TECNICAS.get(pid, []), "comuns": comuns(p),
        })
    # Os piratas do raid do Arlong: o mesmo Pirata com pele de homem-peixe (steve_fishman1..4).
    base = next(x for x in saida if x["id"] == "pirate")
    peixe = json.loads(json.dumps(base))
    peixe.update({"id": "pirate_fishman", "nome": "Pirata homem-peixe", "zona": "arlong_park",
                  "faccao": "pirata:arlong", "nada": True, "modelo": "mp_pirate_fishman1",
                  "modelos": [f"mp_pirate_fishman{i}" for i in range(1, 5)]})
    saida.append(peixe)
    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with open(SAIDA, "w", encoding="utf-8") as f:
        json.dump({"formato": "skills-one-piece/east-blue", "versao": 1,
                   "origem": "Mine Piece v14 (extração local; arte e números provisórios)",
                   "personagens": saida}, f, ensure_ascii=False, indent="\t")
    print(len(saida), "personagens ->", SAIDA)


if __name__ == "__main__":
    main()
