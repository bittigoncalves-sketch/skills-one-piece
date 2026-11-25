#!/usr/bin/env python3
"""Itens de arma do Epic Fight (jar 21.17.3.1, MC 1.21.1) → `assets/epic_fight/itens.json` + texturas em `assets/epic_fight/itens/`.

Dano e velocidade de ataque NÃO estão nos JSON do mod: vêm do Java (decompilado com Vineflower, receita em `docs/CHECKPOINT_EPIC_FIGHT.md`):
  `TieredWeaponItem.createAttributes(tier, dano, vel, modVel)` = dano + `tier.getAttackDamageBonus()`, vel + `vanillaTierToLevel(tier)` × modVel;
  adaga (1,0 / −1,6), lança (3,0 / −2,8), tachi e espada longa (4,0 / −2,8), montante (11,0 + tier / −2,85 − 0,05 × nível), uchigatana (6,0 / −2,0, 1625 de durabilidade),
  luva (2,0 / 0,0, 1625), bokken (`SwordItem.createAttributes(WOOD, 3, −2,4)`). O jogador tem 1,0 de dano e 4,0 de velocidade base.
Impacto, max_strikes e anulação de armadura saem de `data/epicfight/capabilities/weapons/<item>.json` (comum e `two_hand`).
Tiers 1.21.1: madeira (59 usos, +0, nível 0), pedra (131, +1, 1), ferro (250, +2, 2), ouro (32, +0, 0), diamante (1561, +3, 3), netherite (2031, +4, 4).
Uso: `python3 -I tools/epic_fight/extrair_itens.py` (depois de `extrair_do_jar.py`). Saída fora do git (assets All Rights Reserved)."""
import json, shutil, zipfile
from pathlib import Path
raiz = Path(__file__).resolve().parents[2]
origem = raiz / "art_src/epic_fight_local"
destino = raiz / "assets/epic_fight"
tex = origem / "assets/epicfight/textures/item"
caps = origem / "data/epicfight/capabilities/weapons"
TIER = {"wooden": ("WOOD", 59, 0.0, 0), "stone": ("STONE", 131, 1.0, 1), "iron": ("IRON", 250, 2.0, 2), "golden": ("GOLD", 32, 0.0, 0),
        "diamond": ("DIAMOND", 1561, 3.0, 3), "netherite": ("NETHERITE", 2031, 4.0, 4)}
# categoria → (dano base, velocidade base, modificador de velocidade por nível)
BASE = {"dagger": (1.0, -1.6, 0.0), "spear": (3.0, -2.8, 0.0), "tachi": (4.0, -2.8, 0.0), "longsword": (4.0, -2.8, 0.0), "greatsword": (11.0, -2.85, -0.05)}
JAR = Path.home() / "Documents/curseforge/minecraft/Instances/Mods desejados/mods/epic-fight-21.17.3.1-mc1.21.1-neoforge.jar"
# Sons (`EpicFightItemCapabilityPresets` + `EpicFightSounds`): golpe = swingSound da categoria (padrão WHOOSH; adaga WHOOSH_SMALL, montante WHOOSH_BIG = whoosh_hard, lança WHOOSH_ROD);
# impacto = BLADE_HIT (3 variações), madeira BLUNT_HIT (3), pedra BLUNT_HIT_HARD (`WeaponCapabilityPresets.registerPreset`).
SOM_DO_GOLPE = {"dagger": "whoosh_small", "greatsword": "whoosh_hard", "spear": "whoosh_rod"}
# Empunhadura padrão com a mão livre (`DEFAULT_1H/2H_WIELD_STYLE`): adaga e espada (bokken) a uma mão; o resto a duas — e então valem os atributos `two_hand`.
ESTILO_PADRAO = {"dagger": "ONE_HAND", "sword": "ONE_HAND", "bokken": "ONE_HAND"}
ALCANCE_EXTRA = {"greatsword": 1.0, "spear": 1.0}                          # `.reach(1.0F)` do preset
if JAR.exists():
    (destino / "sons").mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(JAR) as z:
        for n in z.namelist():
            if n.startswith("assets/epicfight/sounds/entity/") and n.endswith(".ogg"):
                (destino / "sons" / Path(n).name).write_bytes(z.read(n))
itens = {}
(destino / "itens").mkdir(parents=True, exist_ok=True)
for arq in sorted(caps.glob("*.json")):
    nome = arq.stem
    d = json.loads(arq.read_text())
    tipo = str(d.get("type", "")).split(":")[-1]
    material = nome.split("_")[0] if nome.split("_")[0] in TIER else None
    categoria = nome.split("_", 1)[1] if material else nome
    if material:
        _, usos, bonus, nivel = TIER[material]
        dano_b, vel_b, mod = BASE[categoria]
        dano, vel, dur = dano_b + bonus, vel_b + nivel * mod, usos
    elif nome == "uchigatana":
        dano, vel, dur, categoria = 6.0, -2.0, 1625, "uchigatana"
    elif nome == "glove":
        dano, vel, dur, categoria = 2.0, 0.0, 1625, "fist"
    elif nome == "bokken":
        dano, vel, dur, categoria = 3.0, -2.4, 59, "bokken"
    else:
        continue
    atr = d.get("attributes", {})
    comum = atr.get("common", atr.get("one_hand", {}))          # uma mão (ou única); adaga e lança têm `one_hand` + `two_hand`
    duas = atr.get("two_hand")
    png = tex / (nome + ".png")
    if png.exists():
        shutil.copyfile(png, destino / "itens" / png.name)
    gui = tex / (nome + "_gui.png")                  # ícone 16×16 do mod (inventário/barra); a luva e a adaga usam o mesmo sprite
    if gui.exists():
        shutil.copyfile(gui, destino / "itens" / gui.name)
    estilo = ESTILO_PADRAO.get(categoria, "TWO_HAND")
    efetivo = {"impacto": comum.get("impact"), "max_strikes": comum.get("max_strikes"), "anula_armadura": comum.get("armor_negation", 0.0)}
    if estilo == "TWO_HAND" and duas:
        for k_mod, k in (("impact", "impacto"), ("max_strikes", "max_strikes"), ("armor_negation", "anula_armadura")):
            if k_mod in duas:
                efetivo[k] = duas[k_mod]
    if material == "wooden" or nome == "bokken":
        impacto_som = ["blunt_hit1", "blunt_hit2", "blunt_hit3"]
    elif material == "stone":
        impacto_som = ["blunt_hit_hard"]
    else:
        impacto_som = ["blade_hit1", "blade_hit2", "blade_hit3"]
    itens[nome] = {"estilo_padrao": estilo, "atributos": efetivo, "som_golpe": SOM_DO_GOLPE.get(categoria, "whoosh"), "som_impacto": impacto_som,
                   "alcance_extra": ALCANCE_EXTRA.get(categoria, 0.0), "tipo_mod": tipo, "categoria": categoria, "material": material or nome, "dano_atributo": dano, "dano_total": 1.0 + dano,
                   "velocidade_atributo": round(vel, 4), "velocidade_total": round(4.0 + vel, 4), "durabilidade": dur,
                   "impacto": comum.get("impact"), "max_strikes": comum.get("max_strikes"), "anula_armadura": comum.get("armor_negation", 0.0),
                   "duas_maos": duas, "textura": ("itens/" + png.name) if png.exists() else "",
                   "textura_gui": ("itens/" + gui.name) if gui.exists() else (("itens/" + png.name) if png.exists() else "")}
# Receitas de fabricação (`data/epicfight/recipe/*.json`: `crafting_shaped` 3×3 com ingredientes vanilla) → `receitas.json`: id do item → {padrao, chaves, resultado}.
receitas = {}
for arq in sorted((origem / "data/epicfight/recipe").glob("*.json")):
    r = json.loads(arq.read_text())
    receitas[arq.stem] = {"tipo": str(r.get("type", "")).split(":")[-1], "padrao": r.get("pattern", []), "chaves": r.get("key", {}), "resultado": str(r.get("result", {}).get("id", "")).split(":")[-1],
                          "quantidade": int(r.get("result", {}).get("count", 1))}
(destino / "receitas.json").write_text(json.dumps({"fonte": "Epic Fight 21.17.3.1 — data/epicfight/recipe", "receitas": receitas}, indent=1, ensure_ascii=False))
(destino / "itens.json").write_text(json.dumps({"fonte": "Epic Fight 21.17.3.1 (MC 1.21.1) — Java + data/epicfight/capabilities/weapons", "itens": itens}, indent=1, ensure_ascii=False))
print(len(itens), "itens →", destino / "itens.json")
