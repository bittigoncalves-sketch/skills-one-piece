#!/usr/bin/env python3
"""Epic Fight: dados de jogo (não-arte) -> assets/epic_fight/*.json  (LOCAL, fora do git).

Depois de `extrair_do_jar.py` (que põe tudo em art_src/epic_fight_local/) e de `extrair_fases.py` (fases.json).
Gera, para o jogo ler sem conhecer o formato do mod:
  armas.json       categorias de arma -> materiais (impacto, golpes), clipes de combo/dash/airslash, locomoção, collider
  atordoamento.json tipos de stun do mod -> o que o jogo faz (hitstun/knockdown em segundos) — ver MAPA abaixo
  reacoes.json     clipes de reação (hit_*, knockdown, guarda) com duração
  estamina.json    máximo, regeneração, espera, fórmula de peso + custo das habilidades (skill_parameters)
  trilhas.json     janela do rastro (junta + tempo) por golpe
  habilidades.json parâmetros das 44 habilidades + as de arma com fases
  armaduras.json   peso e stun_armor (só as 3 do Stray existem no mod)
Números de estamina vieram de PlayerPatch/EpicFightAttributes decompilados (máx. 15, regen 1,0, espera 30 ticks).
"""
import json, pathlib, re

RAIZ = pathlib.Path(__file__).resolve().parents[2]
LOCAL = RAIZ / "art_src/epic_fight_local"
DADOS = LOCAL / "data/epicfight"
ANIM = LOCAL / "assets/epicfight/animmodels/animations/biped"
SAIDA = RAIZ / "assets/epic_fight"

# stun do mod -> segundos de hitstun/knockdown no jogo (decisão de projeto; o mod usa ticks e o "impacto" da arma).
# SHORT é o tranco do M1 rápido (0,35 s, já usado em Melee.COMBO_RAPIDO); KNOCKDOWN reaproveita o derrubar_com_animacao.
MAPA_STUN = {
    "NONE": {"hitstun": 0.0, "derruba": 0.0, "empurra": False},
    "SHORT": {"hitstun": 0.35, "derruba": 0.0, "empurra": True},
    "LONG": {"hitstun": 0.80, "derruba": 0.0, "empurra": True},
    "HOLD": {"hitstun": 0.60, "derruba": 0.0, "empurra": False},
    "KNOCKDOWN": {"hitstun": 0.80, "derruba": 2.0, "empurra": True},
    "NEUTRALIZE": {"hitstun": 1.20, "derruba": 0.0, "empurra": False},
    "FALL": {"hitstun": 0.80, "derruba": 1.2, "empurra": True},
}


def jlido(p):
    return json.loads(pathlib.Path(p).read_text())


def duracao(clip_json: pathlib.Path) -> float:
    d = jlido(clip_json)
    return round(max((max(j["time"]) for j in d["animation"] if j.get("time")), default=0.0), 4)


def armas():
    cats = {}
    for f in sorted((DADOS / "capabilities/weapons").glob("*.json")):
        d = jlido(f)
        tipo = d.get("type", "").split(":")[-1]
        material = f.stem.rsplit("_", 1)[0] if "_" in f.stem else f.stem
        attrs = d.get("attributes", {})
        base = attrs.get("common") or attrs.get("one_hand") or {}
        cats.setdefault(tipo, {"materiais": {}})["materiais"][material] = {
            "impacto": base.get("impact"), "max_strikes": base.get("max_strikes", 1),
            "anula_armadura": base.get("armor_negation", 0.0),
            "duas_maos": attrs.get("two_hand")}
    clipes = sorted(p.stem for p in (ANIM / "combat").glob("*.json"))
    vivos = sorted(p.stem for p in (ANIM / "living").glob("*.json"))
    prefixos = {"fist": ["fist"], "sword": ["sword"], "longsword": ["longsword", "longsword_liechtenauer"],
                "greatsword": ["greatsword"], "spear": ["spear", "spear_onehand", "spear_twohand"],
                "tachi": ["tachi"], "uchigatana": ["uchigatana"], "dagger": ["dagger", "dagger_dual"], "axe": ["axe"]}
    for tipo, pref in prefixos.items():
        c = cats.setdefault(tipo, {"materiais": {}})
        c["combo"] = [x for x in clipes if any(re.fullmatch(p + r"_auto\d+", x) for p in pref)]
        c["dash"] = [x for x in clipes if any(x == p + "_dash" for p in pref)]
        c["airslash"] = [x for x in clipes if any(x == p + "_airslash" for p in pref)]
        c["locomocao"] = [x for x in vivos if tipo in x and re.match(r"(hold|walk|run)_", x)]
    colliders = {"sword": [3, 0.4, 0.4, 0.7], "longsword": [3, 0.2, 0.4, 0.85], "greatsword": [3, 0.3, 0.5, 1.0],
                 "spear": [3, 0.6, 0.6, 1.0], "tachi": [3, 0.2, 0.4, 1.05], "uchigatana": [5, 0.4, 0.4, 0.7],
                 "dagger": [3, 0.4, 0.4, 0.6], "fist": [3, 0.4, 0.4, 0.4]}   # n caixas, largura, altura, comprimento (ColliderPreset)
    for k, v in colliders.items():
        cats.setdefault(k, {"materiais": {}})["collider_obb"] = v
    return cats


def reacoes():
    out = {}
    for pasta in ("combat", "skill"):
        for f in sorted((ANIM / pasta).glob("*.json")):
            if re.match(r"(hit_|knockdown|guard_|neutralize|fall)", f.stem):
                out[f"{pasta}/{f.stem}"] = {"duracao": duracao(f)}
    return out


def estamina():
    custos = {}
    for f in sorted((DADOS / "skill_parameters").glob("*.json")):
        d = jlido(f)
        if "consumption" in d:
            custos[f.stem] = d["consumption"]
    return {
        "maximo": 15.0, "regeneracao": 1.0, "espera_ticks": 30, "ticks_por_segundo": 20,
        "regeneracao_por_tick": "maximo*0.01*(1+(e/(maximo-e*0.5))^2)*regeneracao, só depois da espera",
        "custo_pelo_peso": "custo*((peso/40-1)*atenuacao+1), atenuacao = regra WEIGHT_PENALTY/100",
        # roll/step/knockdown_wakeup são a ESTAMINA (Resource.STAMINA no DodgeSkill); o resto de `consumption` é a
        # ENERGIA DE ARMA (carrega ao acertar; golpes especiais) ou parâmetro de passiva — não é estamina.
        "custos": {k: v for k, v in custos.items() if k in ("roll", "step", "knockdown_wakeup")},
        "energia_de_arma": {k: v for k, v in custos.items() if k not in ("roll", "step", "knockdown_wakeup", "demolition_leap")},
        "guarda_penalidade": jlido(DADOS / "skill_parameters/guard.json"),
        "guarda_impacto": jlido(DADOS / "skill_parameters/impact_guard.json")}


def trilhas():
    out = {}
    for pasta in ("combat", "skill"):
        for f in sorted((ANIM / pasta / "data").glob("*.json")):
            d = jlido(f)
            if d.get("trail_effects"):
                out[f"{pasta}/{f.stem}"] = d["trail_effects"]
    return out


def habilidades():
    out = {}
    for f in sorted((DADOS / "skill_parameters").glob("*.json")):
        out[f.stem] = jlido(f)
    return out


def armaduras():
    return {f.stem: jlido(f).get("attributes", {}) for f in sorted((DADOS / "capabilities/armors").glob("*.json"))}


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    pacotes = {"armas": armas(), "atordoamento": MAPA_STUN, "reacoes": reacoes(), "estamina": estamina(),
               "trilhas": trilhas(), "habilidades": habilidades(), "armaduras": armaduras()}
    for nome, dados in pacotes.items():
        (SAIDA / f"{nome}.json").write_text(json.dumps(dados, indent=1, ensure_ascii=False))
        print(f"{nome}.json  ({len(dados)} entradas)")


if __name__ == "__main__":
    main()
