"""FICHA DO MOD por entidade do Mine Piece v14 → mapas/east_blue/entidades_do_mod.json (23/10/2026, E1).

Lê as classes `entity/*Entity.java` (desofuscadas por `srg_oficial.py`) e o registro
`init/MinepieceModEntities.java`. Por entidade:
  • id de registro, categoria (MobCategory) e classe;
  • `baseTick`: as procedures chamadas TODO tick (a IA de verdade: `AIArlongProcedure`…);
  • `finalizeSpawn`: as procedures ao nascer (`SetTagPirateProcedure`…);
  • `hurt`: tipos de dano a que é imune (`source.is(DamageTypes.DROWN) ? false : …`);
  • escala do corpo (`getDimensions(...).scale(1.42F)`);
  • atributos de `createAttributes` (vida, armadura, velocidade…);
  • metas de IA (`goalSelector`/`targetSelector.addGoal(prioridade, new XGoal(...))`) e as procedures que as
    protegem (`canUse() { return super.canUse() && LogicAttackTargetProcedure.execute(entity) }`).

    python3 -I tools/mine_piece/extrair_entidades.py
"""
import json
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from srg_oficial import mapa, traduzir  # noqa: E402

MOD = os.path.expanduser("~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14")
SRC = os.path.join(MOD, "net/mcreator/minepiece")
SAIDA = os.path.join(AQUI, "..", "..", "mapas", "east_blue", "entidades_do_mod.json")


def corpo_do_metodo(t: str, assinatura: str) -> str:
    """Texto do método (do `{` ao `}` correspondente) cuja declaração casa `assinatura` (regex)."""
    m = re.search(assinatura, t)
    if not m:
        return ""
    i = t.find("{", m.end() - 1)
    nivel = 0
    for j in range(i, len(t)):
        if t[j] == "{":
            nivel += 1
        elif t[j] == "}":
            nivel -= 1
            if nivel == 0:
                return t[i:j + 1]
    return ""


def metas(t: str) -> list:
    saida = []
    corpo = corpo_do_metodo(t, r"void registerGoals\(\)\s*\{")
    for m in re.finditer(r"this\.(goalSelector|targetSelector)\.addGoal\(\s*(\d+),\s*new (\w+)\(", corpo):
        # O trecho até o próximo addGoal: as procedures que protegem a meta (canUse/canContinueToUse).
        fim = corpo.find(".addGoal(", m.end())
        trecho = corpo[m.end():fim if fim > 0 else len(corpo)]
        saida.append({"seletor": "alvo" if m.group(1) == "targetSelector" else "acao", "prioridade": int(m.group(2)),
                      "meta": m.group(3), "procedures": sorted(set(re.findall(r"(\w+Procedure)\.execute", trecho)))})
    return saida


def dados_sincronizados(texto):
    """`defineSynchedData`: {NOME: valor inicial} — TEXTURE, ANIMATION, SHOOT, DATA_mode… (o estado que o mod sincroniza)."""
    saida = {}
    for nome, valor in re.findall(r"\.(?:m_135372_|define)\((\w+),\s*([^;]+?)\);", texto):
        v = valor.strip()
        if v in ("true", "false"):
            saida[nome] = v == "true"
        elif v.startswith('"'):
            saida[nome] = v.strip('"')
        else:
            try:
                saida[nome] = float(v) if "." in v else int(v)
            except ValueError:
                saida[nome] = 0
    return saida


def main() -> None:
    srg = mapa()
    registro = {}
    texto = open(os.path.join(SRC, "init/MinepieceModEntities.java"), encoding="utf-8", errors="replace").read()
    for m in re.finditer(r'register\(\s*"([a-z0-9_]+)",\s*Builder\.\w+\((\w+)::new,\s*MobCategory\.(\w+)', texto):
        registro[m.group(2)] = (m.group(1), m.group(3))
    entidades = {}
    pasta = os.path.join(SRC, "entity")
    for f in sorted(os.listdir(pasta)):
        caminho = os.path.join(pasta, f)
        if not os.path.isfile(caminho) or not f.endswith("Entity.java"):
            continue
        classe = f[:-5]
        if classe not in registro:
            continue
        t = traduzir(open(caminho, encoding="utf-8", errors="replace").read(), srg)
        ident, categoria = registro[classe]
        atributos = {}
        for a, v in re.findall(r"builder\.add\(Attributes\.(\w+),\s*([-\d.]+)\)", t):
            atributos[a.lower()] = float(v)
        for a, v in re.findall(r"builder\.add\(\(Attribute\)MinepieceModAttributes\.(\w+)\.get\(\),\s*([-\d.]+)\)", t):
            atributos["minepiece:" + a.lower()] = float(v)
        escala = re.search(r"getDimensions\(Pose \w+\)\s*\{\s*return super\.getDimensions\(\w+\)\.scale\(([\d.]+)F\)", t)
        hurt = corpo_do_metodo(t, r"boolean hurt\(DamageSource \w+, float \w+\)\s*\{")
        base = re.search(r"public class \w+ extends (\w+)", t)
        entidades[ident] = {
            "classe": classe, "categoria": categoria, "base": base.group(1) if base else "",
            # Ganchos da CLASSE (projéteis): tick próprio, acertou entidade, acertou bloco.
            "tick_classe": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"public void tick\(\)\s*\{")),
            "ao_acertar_entidade": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"void onHitEntity\(")),
            "ao_acertar_bloco": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"void onHitBlock\(")),
            "tick": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"void baseTick\(\)\s*\{")),
            "dados": dados_sincronizados(t),
            "ao_nascer": re.findall(r"(\w+Procedure)\.execute", corpo_do_metodo(t, r"SpawnGroupData finalizeSpawn\(")),
            "imune_a": sorted(set(d.lower() for d in re.findall(r"DamageTypes\.(\w+)", hurt))),
            "escala": float(escala.group(1)) if escala else 1.0,
            "atributos": atributos,
            "metas": metas(t),
        }
    sha = open(os.path.join(MOD, "ORIGEM.sha256")).read().split()[0]
    json.dump({"formato": "skills-one-piece/entidades-mine-piece", "versao": 1,
               "origem": {"mod": "MinePiece-ver14-forge-1.20.1.jar", "sha256": sha,
                          "extraido_por": "tools/mine_piece/extrair_entidades.py"}, "entidades": entidades},
              open(SAIDA, "w"), ensure_ascii=False, indent=1)
    com_ia = sum(1 for e in entidades.values() if e["tick"])
    print(f"{len(entidades)} entidades → {os.path.normpath(SAIDA)}; {com_ia} com procedure no baseTick")
    for ident in ("arlong", "pirate", "buchi", "zoro_east_blue", "girl_icecream"):
        e = entidades.get(ident, {})
        print(f"  {ident}: tick {e.get('tick')}, nascer {e.get('ao_nascer')}, imune {e.get('imune_a')}, escala {e.get('escala')}, "
              f"{len(e.get('atributos', {}))} atributos, {len(e.get('metas', []))} metas")


if __name__ == "__main__":
    main()
