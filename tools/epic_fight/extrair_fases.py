#!/usr/bin/env python3
"""Epic Fight: tabela de FASES dos ataques (Animations.java) -> assets/epic_fight/fases.json (LOCAL, fora do git).

Os tempos de ataque do Epic Fight NÃO estão em data/: moram no Java (`gameasset/Animations`). Este script
decompila só essa classe com o Vineflower (o jar do mod usa nomes Mojang; não precisa remapear) e lê cada
`X = builder.nextAccessor("biped/...", accessor -> new <Tipo>(...) ...)`.

Regra de leitura (conferida em AttackAnimation/ComboAttackAnimation/AirSlashAnimation/DashAttackAnimation):
  * 4 números  (transição, antecipação, contato, recuperação)            -> pré-atraso = antecipação
  * 5 números  (transição, antecipação, pré-atraso, contato, recuperação)
  * `new Phase(...)`: 5 = (início, antecipação, contato, recuperação, fim); 6 = (início, antecipação, pré-atraso, contato, recuperação, fim)
  A JANELA DE DANO é [pré-atraso, contato]; `recuperação`/`fim` fecham o golpe. Tudo em segundos DO CLIPE (a velocidade
  real do clipe é `BASIS_ATTACK_SPEED` × a do jogador; ver `basis_speed`).

Uso: extrair_fases.py [JAR] [SAIDA.json]
"""
import json, re, subprocess, sys, tempfile, pathlib, zipfile

RAIZ = pathlib.Path(__file__).resolve().parents[2]
JAR = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else next(
    pathlib.Path.home().glob("Documents/curseforge/minecraft/Instances/Mods desejados/mods/epic-fight-*.jar"))
SAIDA = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else RAIZ / "assets/epic_fight/fases.json"
VINEFLOWER = pathlib.Path.home() / "dev/biblioteca-de-mecanicas/ferramentas/vineflower-1.12.0.jar"

NUM = r"(-?\d+(?:\.\d+)?)F"
TIPOS_ATAQUE = ("ComboAttackAnimation", "AttackAnimation", "AirSlashAnimation", "DashAttackAnimation",
                "MountAttackAnimation", "RangedAttackAnimation", "BasicMultipleAttackAnimation")


def decompilar() -> str:
    with tempfile.TemporaryDirectory() as t:
        t = pathlib.Path(t)
        (t / "cls").mkdir(); (t / "out").mkdir()
        with zipfile.ZipFile(JAR) as z:
            for n in z.namelist():
                if n.startswith("yesman/epicfight/gameasset/Animations") and n.endswith(".class"):
                    z.extract(n, t / "cls")
        subprocess.run(["java", "-jar", str(VINEFLOWER), str(t / "cls"), str(t / "out")],
                       check=True, capture_output=True)
        return (t / "out/yesman/epicfight/gameasset/Animations.java").read_text()


def bloco_por_acessor(src: str):
    marcas = [(m.start(), m.group(1), m.group(2)) for m in
              re.finditer(r'(\w+)\s*=\s*builder\.nextAccessor\(\s*"([^"]+)"', src)]
    for i, (ini, nome, caminho) in enumerate(marcas):
        fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(src)
        yield nome, caminho, src[ini:fim]


def floats_iniciais(args: str):
    """Números `0.1F` no começo da lista de argumentos (até o primeiro argumento que não é número/bool)."""
    out = []
    for tok in re.split(r",\s*", args.strip()):
        m = re.fullmatch(NUM, tok.strip())
        if m:
            out.append(float(m.group(1)))
        elif tok.strip() in ("true", "false"):
            continue
        else:
            break
    return out


def fase_de(nums, tem_pre):
    if tem_pre:
        a, p, c, r = nums[0], nums[1], nums[2], nums[3]
    else:
        a, p, c, r = nums[0], nums[0], nums[1], nums[2]
    return {"antecipacao": a, "pre_atraso": p, "contato": c, "recuperacao": r}


def analisar(bloco: str):
    m = re.search(r"new (\w+)\(", bloco)
    if not m or m.group(1) not in TIPOS_ATAQUE:
        return None
    tipo = m.group(1)
    resto = bloco[m.end():]
    fases = []
    if "new Phase(" in bloco:
        for pm in re.finditer(r"new Phase\(([^;]*?)(?:,\s*(?:InteractionHand|\(\(Humanoid|null|Colliders|ColliderPreset|new )|\))", bloco):
            nums = floats_iniciais(pm.group(1))
            if len(nums) == 5:
                fases.append({"inicio": nums[0], "antecipacao": nums[1], "pre_atraso": nums[1], "contato": nums[2],
                              "recuperacao": nums[3], "fim": nums[4]})
            elif len(nums) == 6:
                fases.append({"inicio": nums[0], "antecipacao": nums[1], "pre_atraso": nums[2], "contato": nums[3],
                              "recuperacao": nums[4], "fim": nums[5]})
        trans = floats_iniciais(resto.split("accessor", 1)[0]) or [0.0]
        transicao = trans[0]
    else:
        # os argumentos vão até o primeiro item que não é número: contamos os floats iniciais
        nums = floats_iniciais(resto)
        if len(nums) < 4:
            return None
        transicao = nums[0]
        tem_pre = len(nums) >= 5
        f = fase_de(nums[1:], tem_pre)
        f["inicio"] = 0.0
        f["fim"] = f["recuperacao"]
        fases.append(f)
    d = {"tipo": tipo, "transicao": transicao, "fases": fases}
    if "InteractionHand.OFF_HAND" in bloco.split(".addProperty", 1)[0]:
        d["mao"] = "esquerda"
    cm = re.search(r"ColliderPreset\.(\w+)", bloco)
    if cm:
        d["collider"] = cm.group(1).lower()
    jm = re.search(r"\)\.(toolR|toolL|rootJoint|head|chest|torso|legR|legL|thighR|thighL)\b", bloco)
    if jm:
        d["junta"] = jm.group(1)
    sm = re.search(r"BASIS_ATTACK_SPEED,\s*" + NUM, bloco)
    if sm:
        d["basis_speed"] = float(sm.group(1))
    stuns = re.findall(r"StunType\.(\w+)", bloco)
    if stuns:
        d["stun"] = stuns
    dm = re.findall(r"DAMAGE_MODIFIER,\s*ValueModifier\.(\w+)\(" + NUM, bloco)
    if dm:
        d["dano"] = [{"op": o, "valor": float(v)} for o, v in dm]
    ms = re.findall(r"MAX_STRIKES_MODIFIER,\s*ValueModifier\.(\w+)\(" + NUM, bloco)
    if ms:
        d["max_strikes"] = [{"op": o, "valor": float(v)} for o, v in ms]
    im = re.findall(r"IMPACT_MODIFIER,\s*ValueModifier\.(\w+)\(" + NUM, bloco)
    if im:
        d["impacto"] = [{"op": o, "valor": float(v)} for o, v in im]
    an = re.findall(r"ARMOR_NEGATION_MODIFIER,\s*ValueModifier\.(\w+)\(" + NUM, bloco)
    if an:
        d["anula_armadura"] = [{"op": o, "valor": float(v)} for o, v in an]
    return d


def main():
    src = decompilar()
    tabela = {}
    ignorados = 0
    for nome, caminho, bloco in bloco_por_acessor(src):
        d = analisar(bloco)
        if d is None:
            ignorados += 1
            continue
        d["id"] = nome
        tabela[caminho.removeprefix("biped/")] = d
    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_text(json.dumps({"fonte": JAR.name, "ataques": tabela}, indent=1, ensure_ascii=False))
    print(f"{len(tabela)} ataques -> {SAIDA}  ({ignorados} animações sem fase de ataque ignoradas)")


if __name__ == "__main__":
    main()
