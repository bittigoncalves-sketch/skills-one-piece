#!/usr/bin/env python3
"""Extrai do Mine Piece v14 DESCOMPILADO (só nesta máquina) os dados dos personagens do
East Blue: nome, atributos, alvos, IA, níveis, fruta, tags de ataque, modelo/textura/
animação e tamanho. Gera FATOS (números e nomes), não código do mod.

    python3 -I tools/mine_piece/extrair_east_blue.py [--fonte DIR] [--saida ARQ]

Fonte padrão: ~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14 (Vineflower).
Elenco: os raids 1-8 e EX do East Blue (RaidEastBlue*Procedure), quem nasce no East Blue
(SpawnEastBlueProcedure) e os aliados da saga (Luffy/Zoro/Sanji East Blue, Coby, Yosaku,
Johnny). Pedido do dono, 17/10/2026; plano em docs/EAST_BLUE_PLANO.md.
"""
import argparse
import json
import os
import re
import sys

FONTE = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")

# Zona da ilha (bando) de cada classe. Ordem = ordem dos raids do mod.
ELENCO = {
    "bandidos": ["Higuma", "Bandit"],
    "alvida": ["Alvida", "Pirate"],
    "shells_town": ["Morgan", "Helmeppo", "Marine", "Coby"],
    "orange_town": ["Buggy", "Cabaji", "Richie"],
    "vila_syrup": ["Kuro", "Jango", "Sham", "Buchi"],
    "baratie": ["Krieg", "Gin", "SanjiEastBlue", "Fullbody"],
    "arlong_park": ["Arlong", "Kuroobi", "Hatchan", "Chu"],
    "loguetown": ["Smoker", "Tashigi", "Alvida2", "GirlIcecream"],
    "ruivo": ["Shanks", "BennBeckman", "LuckyRoux", "Yasopp", "LimeJuice", "Hongo", "Gab",
              "BonkPunch", "BuildingSnake", "Monster1"],
    "aliados": ["LuffyEastBlue", "ZoroEastBlue", "Yosaku", "Jonny"],
}

# Atributos vanilla (nomes ofuscados do 1.20.1 → significado).
ATRIBUTOS = {
    "f_22276_": "vida_max", "f_22277_": "alcance_de_perseguicao", "f_22278_": "resistencia_a_empurrao",
    "f_22279_": "velocidade", "f_22280_": "velocidade_de_voo", "f_22281_": "dano_de_ataque",
    "f_22282_": "empurrao_de_ataque", "f_22283_": "velocidade_de_ataque", "f_22284_": "armadura",
    "f_22285_": "dureza_da_armadura",
}
EFEITOS = {"f_19600_": "forca", "f_19606_": "resistencia"}


def ler(caminho):
    with open(caminho, encoding="utf-8", errors="replace") as f:
        return f.read()


def snake(nome):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", "_", nome).lower()


def registro(fonte):
    """Classe → {id de registro, categoria, largura, altura}."""
    texto = ler(os.path.join(fonte, "net/mcreator/minepiece/init/MinepieceModEntities.java"))
    saida = {}
    for m in re.finditer(r'register\(\s*"([a-z0-9_]+)",\s*Builder\.m_20704_\((\w+)Entity::new,\s*MobCategory\.(\w+)\)(.*?)\);', texto, re.S):
        tam = re.search(r"m_20699_\(([\d.]+)F?,\s*([\d.]+)F?\)", m.group(4))
        saida[m.group(2)] = {"id": m.group(1), "categoria": m.group(3),
                             "largura": float(tam.group(1)) if tam else None,
                             "altura": float(tam.group(2)) if tam else None}
    return saida


def frutas(fonte):
    texto = ler(os.path.join(fonte, "net/mcreator/minepiece/procedures/ReturnDevilFruitEatenProcedure.java"))
    mapa = {m.group(1): m.group(2).lower() for m in re.finditer(r"put\((\w+)Entity\.class,.*?ITEM_DEVIL_FRUIT_([A-Z_]+)", texto)}
    generica = set(re.findall(r"instanceof (\w+)Entity\)", texto.split("return !(", 1)[-1]))
    return mapa, generica


def tags(fonte):
    pasta = os.path.join(fonte, "data/minepiece/tags/entity_types")
    saida = {}
    for arq in sorted(os.listdir(pasta)):
        dados = json.loads(ler(os.path.join(pasta, arq)))
        for v in dados.get("values", []):
            saida.setdefault(str(v).split(":")[-1], []).append(arq[:-5])
    return saida


def atributos(texto):
    bloco = texto.split("createAttributes", 1)[-1].split("\n   }", 1)[0]
    return {ATRIBUTOS.get(a, a): float(v) for a, v in re.findall(r"Attributes\.(f_\d+_),\s*([\d.]+)\)", bloco)}


def objetivos(texto):
    saida = []
    for prio, classe in re.findall(r"m_25352_\((\d+),\s*new (\w+)\(", texto):
        saida.append(f"{prio}:{classe}")
    # Contra quem: NearestAttackableTargetGoal(this, X.class
    alvos = re.findall(r"NearestAttackableTargetGoal\(this,\s*(\w+)\.class", texto)
    return saida, sorted(set(alvos))


def ia(fonte, texto):
    procs = re.findall(r"(\w+)Procedure\.execute\(this\.m_9236_\(\), this\)", texto)
    cadeia = {}
    for p in procs:
        arq = os.path.join(fonte, f"net/mcreator/minepiece/procedures/{p}Procedure.java")
        if not os.path.exists(arq):
            continue
        corpo = ler(arq)
        chamados = sorted(set(re.findall(r"(\w+)Procedure\.execute", corpo)))
        status = re.findall(r"SetStatusProcedure\.execute\(entity,\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)", corpo)
        skills = sorted(set(int(float(s)) for s in re.findall(r'"skill",\s*([\d.]+)\)', corpo)))
        cadeia[p] = {"chama": chamados, "linhas": corpo.count("\n"),
                     "status": [list(map(float, s)) for s in status], "skills_fixas": skills,
                     "tecnicas": tecnicas(fonte, corpo)}
    return cadeia


# Faixa do número da técnica → procedimento que despacha (CursedTechniqueOnPotionActiveTick).
FAIXAS = [(3000, 3300, "SkillBaseSkill"), (2000, 3000, "SkillIndigo"), (1900, 2000, "SkillCuriel"),
          (1800, 1900, "SkillSanji"), (1700, 1800, "SkillOden"), (1600, 1700, "SkillRoger"),
          (1500, 1600, "SkillUsopp"), (1400, 1500, "SkillGarp"), (1300, 1400, "SkillCyborg"),
          (1200, 1300, "CallAdmiral"), (1100, 1200, "SkillElizabello"), (1000, 1100, "SkillGiant"),
          (900, 1000, "SkillLunarian"), (800, 900, "SkillSabo"), (700, 800, "SkillFishMan"),
          (600, 700, "SkillCombat"), (500, 600, "SkillMihawk"), (400, 500, "SkillRokushiki"),
          (300, 400, "SkillKaido"), (200, 300, "SkillShanks"), (100, 200, "SkillZoro")]


def _limpar_cond(c):
    c = re.sub(r"\(entity instanceof Mob _mobEnt \? _mobEnt\.m_5448_\(\) : null\)", "ALVO", c)
    c = re.sub(r"\(entity instanceof LivingEntity _livEnt \? _livEnt\.m_21223_\(\) : -1\.0F\)", "VIDA", c)
    c = re.sub(r"\(entity instanceof LivingEntity _livEnt \? _livEnt\.m_21233_\(\) : -1\.0F\)", "VIDA_MAX", c)
    c = re.sub(r'entity\.getPersistentData\(\)\.m_128459_\("(\w+)"\)', r"\1", c)
    c = re.sub(r'entity\.getPersistentData\(\)\.m_128471_\("(\w+)"\)', r"\1", c)
    c = re.sub(r"(\w+)Procedure\.execute\([^)]*\)", r"\1()", c)
    return re.sub(r"\s+", " ", c).strip()


def tecnicas(fonte, corpo):
    """[(número, nível, ticks de recarga, condições)] lidos de `rnd = N; level = L; tick = T`."""
    saida = []
    pilha = []                     # (recuo, condição)
    pendente = ""                  # if que continua na linha seguinte
    atual = {}
    for linha in corpo.split("\n"):
        recuo = len(linha) - len(linha.lstrip())
        t = linha.strip()
        if not t:
            continue
        if pendente:
            pendente += " " + t
            if t.endswith("{"):
                pilha.append((pendente_recuo, _limpar_cond(pendente[4:-3])))
                pendente = ""
            continue
        while pilha and pilha[-1][0] >= recuo:
            pilha.pop()
        if t.startswith("if (") or t.startswith("} else if ("):
            cond = t.split("if (", 1)[1]
            if t.endswith("{"):
                pilha.append((recuo, _limpar_cond(cond[:-3])))
            else:
                pendente, pendente_recuo = "if (" + cond, recuo
            continue
        m = re.match(r"(rnd|level|tick) = ([\d.]+);", t)
        if m:
            atual[m.group(1)] = float(m.group(2))
            if m.group(1) == "tick" and "rnd" in atual:
                saida.append({"numero": int(atual["rnd"]), "nivel": atual.get("level", 0.0), "recarga_ticks": atual["tick"],
                              "condicoes": [c for _, c in pilha if c and not c.startswith("entity != null") and "m_6084_" not in c]})
                atual = {}
    for t in saida:
        t["procedimento"] = resolver(fonte, t["numero"])
    return saida


def resolver(fonte, numero):
    if numero < 50:
        return "fruta"
    for de, ate, proc in FAIXAS:
        if de <= numero < ate:
            arq = os.path.join(fonte, f"net/mcreator/minepiece/procedures/{proc}Procedure.java")
            if not os.path.exists(arq):
                return proc
            texto = ler(arq)
            for alvo in (numero, numero % 100, numero % 50):
                m = re.search(rf"== {alvo}\.0\)[^\n]*\{{?\s*\n\s*(\w+)Procedure\.execute", texto)
                if m:
                    return m.group(1)
            return proc
    return None


def modelo(fonte, classe, texto):
    arq = os.path.join(fonte, f"net/mcreator/minepiece/entity/model/{classe}Model.java")
    saida = {}
    if os.path.exists(arq):
        m = ler(arq)
        for chave, padrao in (("geo", r'"(geo/[^"]+)"'), ("animacao", r'"(animations/[^"]+)"')):
            r = re.search(padrao, m)
            saida[chave] = r.group(1) if r else None
    tex = re.search(r'TEXTURE,\s*"([^"]+)"', texto) or re.search(r'setTexture\("([^"]+)"\)', texto)
    saida["textura"] = f"textures/entities/{tex.group(1)}.png" if tex else None
    for chave in ("geo", "animacao", "textura"):
        if saida.get(chave):
            saida[chave + "_existe"] = os.path.exists(os.path.join(fonte, "assets/minepiece", saida[chave]))
    return saida


def itens_na_mao(texto):
    return sorted(set(re.findall(r"MinepieceModItems\.([A-Z0-9_]+)\.get\(\)", texto)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fonte", default=FONTE)
    ap.add_argument("--saida", default="docs/referencias/mine_piece/east_blue/personagens.json")
    ap.add_argument("--spawn", default="mapas/east_blue/spawn_natural.json",
                    help="regras de spawn natural: todo personagem que nasce por elas e não está no ELENCO entra, "
                         "na zona da regra (a IA e os golpes são os do mod, sem tabela nossa)")
    a = ap.parse_args()
    reg = registro(a.fonte)
    por_id = {v["id"]: k for k, v in reg.items()}
    ja = {c for cs in ELENCO.values() for c in cs}
    if a.spawn and os.path.exists(a.spawn):
        for r in json.load(open(a.spawn, encoding="utf-8"))["entradas"]:
            classe = por_id.get(r["id"])
            if classe and classe not in ja:
                ELENCO.setdefault(r["regra"], []).append(classe)
                ja.add(classe)
    fr, fr_generica = frutas(a.fonte)
    tg = tags(a.fonte)
    lang = json.loads(ler(os.path.join(a.fonte, "assets/minepiece/lang/en_us.json")))
    personagens = []
    faltando = []
    for zona, classes in ELENCO.items():
        for classe in classes:
            arq = os.path.join(a.fonte, f"net/mcreator/minepiece/entity/{classe}Entity.java")
            if not os.path.exists(arq) or classe not in reg:
                faltando.append(classe)
                continue
            texto = ler(arq)
            r = reg[classe]
            obj, alvos = objetivos(texto)
            personagens.append({
                "classe": classe, "id": r["id"], "zona": zona,
                "nome": lang.get(f"entity.minepiece.{r['id']}", classe),
                "categoria_mc": r["categoria"], "largura": r["largura"], "altura": r["altura"],
                "atributos": atributos(texto),
                "objetivos": obj, "ataca": alvos,
                "ia": ia(a.fonte, texto),
                "fruta": fr.get(classe) or ("generica" if classe in fr_generica else None),
                "tags": tg.get(r["id"], []),
                "itens_citados": itens_na_mao(texto),
                "modelo": modelo(a.fonte, classe, texto),
                "loot": os.path.exists(os.path.join(a.fonte, f"data/minepiece/loot_tables/entities/{r['id']}.json")),
            })
    os.makedirs(os.path.dirname(a.saida), exist_ok=True)
    with open(a.saida, "w", encoding="utf-8") as f:
        json.dump({"formato": "skills-one-piece/mine-piece-east-blue", "versao": 1,
                   "fonte": "Mine Piece v14 (descompilado local, sha256 em ORIGEM.sha256)",
                   "personagens": personagens}, f, ensure_ascii=False, indent=1)
    print(f"{len(personagens)} personagens -> {a.saida}")
    if faltando:
        print("FALTANDO:", ", ".join(faltando))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
