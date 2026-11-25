#!/usr/bin/env python3
"""Gera docs/frutas/SKILLS_FRUTAS_DO_MOD_GERADO.md: uma descrição (>= 10 linhas) por técnica de cada fruta SÓ-DO-MOD do Modo História.

Cada linha vem do CÓDIGO, nada é inventado: a lista de técnicas (nome, tecla, número, custo) sai de `dump_tecnicas_do_mod.gd`; o que a técnica
FAZ sai do procedure Java do mod (`SkillXProcedure` -> procedure do número). O objetivo é INFERIDO do nome e dos efeitos e vem marcado como tal.

Uso:
  godot --headless --path . --script tools/dev_tests/dump_tecnicas_do_mod.gd      # gera tecnicas_do_mod.json em user://
  python3 -I tools/mine_piece/documentar_skills_do_mod.py <tecnicas_do_mod.json> <pasta_dos_procedures_java> [rank_de_visibilidade.txt] > docs/frutas/SKILLS_FRUTAS_DO_MOD_GERADO.md
"""
import json
import os
import re
import sys

TICK = 0.05
VARR = {}


def camel(id_fruta):
    return "".join(p.capitalize() for p in id_fruta.split("_"))


def achar_skill(pasta, id_fruta):
    alvo = "skill" + id_fruta.replace("_", "")
    for f in os.listdir(pasta):
        if f.lower() == alvo + "procedure.java":
            return f
    # nomes com "no" no meio ("okuchi_no_makami" -> "OkuchinoMakami")
    for f in os.listdir(pasta):
        base = f.lower().replace("procedure.java", "")
        if base.startswith("skill") and base.replace("skill", "", 1) == id_fruta.replace("_", "").replace("no", "no"):
            return f
    cand = [f for f in os.listdir(pasta) if f.lower().startswith("skill" + id_fruta.replace("_", "")[:10]) and f.endswith("Procedure.java")]
    return cand[0] if cand else None


def despacho(texto):
    """skill == N -> procedure: o primeiro `XProcedure.execute` depois de cada `skill == N` (aceita blocos aninhados)."""
    mapa = {}
    marcas = [(m.start(), int(m.group(1))) for m in re.finditer(r"skill == (\d+)\.0", texto)]
    for i, (pos, n) in enumerate(marcas):
        fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(texto)
        m = re.search(r"([A-Za-z0-9_]+)Procedure\.execute", texto[pos:fim])
        if m and n not in mapa:
            mapa[n] = m.group(1)
    return mapa


## Equivalências conferidas à mão (nome da técnica no jogo → procedure do mod): o nome japonês do golpe não aparece no inglês do rótulo.
EQUIVALENCIAS = {"Six King Gun": "Rokuogan", "Headbutt": "Headbutt", "Ikoku Sovereignty": "Ikoku", "Raging Tiger": "AITiger"}


def por_nome(pasta, id_fruta, nome):
    if nome in EQUIVALENCIAS and os.path.exists(os.path.join(pasta, EQUIVALENCIAS[nome] + "Procedure.java")):
        return EQUIVALENCIAS[nome]
    """Reserva (APROXIMAÇÃO): procedure cujo nome contém termos do nome da técnica; os que também citam a fruta ganham prioridade."""
    termos = [t.lower() for t in re.findall(r"[A-Za-z]+", nome) if len(t) > 2]
    if not termos:
        return None
    partes = id_fruta.split("_")
    chaves = ["".join(p.capitalize() for p in partes).lower(), partes[-1].lower() if len(partes) > 2 else partes[0].lower()]
    melhor, pontos = None, 0
    for f in os.listdir(pasta):
        if not f.endswith("Procedure.java"):
            continue
        base = f[:-len("Procedure.java")].lower()
        pts = sum(2 for t in termos if t in base)
        if pts == 0:
            continue
        if any(c in base for c in chaves):
            pts += 3
        if pts > pontos:
            melhor, pontos = f[:-len("Procedure.java")], pts
    return melhor if pontos >= 4 else None


def fatos(texto):
    f = {}
    f["dano"] = sorted(set(re.findall(r'"Damage",\s*([^;]+?)\);', texto)))
    f["alcance"] = sorted(set(re.findall(r'"Range",\s*([^;]+?)\);', texto)))
    f["empurrao"] = sorted(set(re.findall(r'"knockback",\s*([^;]+?)\);', texto)))
    f["dano_bloco"] = sorted(set(re.findall(r'"BlockDamage",\s*([^;]+?)\);', texto)))
    f["entidades"] = sorted(set(re.findall(r"MinepieceModEntities\.([A-Z0-9_]+)", texto)))
    f["efeitos_mod"] = sorted(set(re.findall(r"MinepieceModMobEffects\.([A-Z0-9_]+)", texto)))
    f["particulas_mod"] = sorted(set(re.findall(r"MinepieceModParticleTypes\.([A-Z0-9_]+)", texto)))
    f["particulas_cmd"] = sorted(set(re.findall(r"particle (minepiece:[a-z0-9_]+|minecraft:[a-z0-9_]+)", texto)))
    f["sons"] = sorted(set(re.findall(r'new ResourceLocation\("([a-z0-9_.:]+)"\)', texto)))[:6]
    f["chama"] = sorted(set(n for n in re.findall(r"\b([A-Z][A-Za-z0-9]+)Procedure\.execute", texto)))
    f["usa_cnt6"] = "cnt6" in texto.lower()
    f["segurar"] = "PRESS_Z" in texto or "press" in texto.lower()
    cnts = [int(float(x)) for x in re.findall(r'"cnt1"\)\s*[<>=]+\s*(\d+\.?\d*)', texto)]
    f["cnt1_max"] = max(cnts) if cnts else None
    f["teleporte"] = "m_6021_" in texto or "teleport" in texto.lower()
    f["velocidade"] = "m_20256_" in texto or "m_5997_" in texto
    f["invoca"] = bool(f["entidades"])
    f["linhas"] = texto.count("\n")
    return f


def objetivo(nome, f):
    pistas = []
    if f["invoca"]:
        pistas.append("invoca/lança entidades (%s)" % ", ".join(f["entidades"][:4]))
    if f["dano"]:
        pistas.append("causa dano")
    if f["teleporte"]:
        pistas.append("reposiciona o corpo (deslocamento/teleporte)")
    if f["velocidade"]:
        pistas.append("aplica impulso/velocidade")
    if f["efeitos_mod"]:
        pistas.append("aplica efeitos do mod (%s)" % ", ".join(f["efeitos_mod"][:4]))
    return "; ".join(pistas) if pistas else "técnica utilitária/de preparo (sem dano direto no procedure principal)"


## Técnicas NATIVAS do projeto (sem procedure no mod): fatos lidos de `src/combat/buda/flor_de_buda.gd` e `src/combat/zushi/zushi_fujitora.gd`.
NATIVAS = {
    "Flor de Buda": ["**Origem:** extensão autoral do projeto (`flor_de_buda.gd`, número 1001); só vale na forma Buda (Hito Hito Daibutsu transformado) e com o jogador no chão.",
                     "**Tempos:** preparo de 1,2 s, duração total 2,8 s, raio de 10 m, custo 40 e recarga 10 s própria (fora da global do mod).",
                     "**Efeito:** na explosão (fim do preparo) fere todo alvo atacável no raio, com empurrão horizontal de 12 + 3 para cima e atordoamento de 0,4 s; não fere aliados nem tripulação."],
    "Rubbles": ["**Origem:** versão PRÓPRIA do V (`zushi_fujitora.gd`, `RUBBLE = 26`): o Rubble do mod faz as pedras nascerem mas não causam dano aqui (dependem da física da entidade `rubble`).",
                "**Números:** custo 600, recarga 12 s, duração 1,6 s, uma rocha a cada 0,08 s, alcance 40 m, espalhamento 6 m e raio de impacto 2,6 m por rocha.",
                "**Efeito:** chuva de rochas sobre o alvo mirado; cada rocha fere em área ao cair."],
    "Jigoku Tabi": ["**Origem:** poder autoral do Fujitora (`zushi_fujitora.gd`, número 1002, tecla K): 'Viagem ao Inferno'; a pesquisa está em `docs/PESQUISA_FUJITORA_ZUSHI.md`.",
                    "**Números:** custo 450, recarga 14 s, preparo 0,7 s (embainha a espada e o corpo para), duração 1,4 s e raio de 14 m.",
                    "**Efeito:** uma força gravitacional achata tudo ao redor e abre uma cratera no fim; entrada e dano rodam no servidor."],
    "Abare Himatsuri": ["**Origem:** poder autoral do Fujitora (`zushi_fujitora.gd`, número 1003, tecla L): 'Festival Furioso'.",
                        "**Números:** custo 700, recarga 24 s, duração 4,0 s, velocidade 13, a pedra sobe 2,2 m do chão e um meteoro cai a cada 0,2 s.",
                        "**Efeito:** levanta a rocha em que pisa, voa por cima do campo e faz chover meteoros atrás de si; o mais caro e demorado da Zushi."],
}


def descrever(id_fruta, tec, numero, proc, java, vis, desp_txt=""):
    nome, tecla, custo = tec["nome"], tec["tecla"], tec["custo"]
    rec = max(custo * 0.5, 5.0) * TICK
    L = []
    L.append("- **Tecla e custo:** `%s` · custo %.0f de energia · recarga global %.2f s (`max(custo × 0,5; 5) × 0,05`)." % (tecla, custo, rec))
    L.append("- **Procedure do mod:** número %s → `%sProcedure` (%s linhas de Java)." % (numero, proc or "?", java["linhas"] if java else "?"))
    med = VARR.get((id_fruta, nome))
    if not java:
        L.append("- **Recarga:** %.2f s (global do mod)." % rec)
        L.append("- **Despacho do mod desta fruta:** %s." % (desp_txt or "não informado"))
        L.append("- **Fonte não localizada:** o despacho do mod não leva este número a um procedure achável (a técnica pode ser nativa do projeto, ver `src/combat/`).")
        L.append("- **Objetivo (inferido só do nome):** %s." % nome)
        if med:
            L.append("- **Medição (varredura 15/11/2026):** começou=%s, energia gasta=%s, nós criados=%s, dano no alvo a 4 m=%s." % (med["comecou"], med["gasto"], med["nasceu"], med["dano"]))
            L.append("- **Leitura da medição:** %s." % ("a técnica roda e gasta energia como a ficha" if med["comecou"] == "true" else "não começou na varredura (pode exigir forma/pré-condição do mod)"))
        else:
            L.append("- **Medição:** sem linha na varredura (técnica nativa do projeto; ver o teste dedicado).")
        L.append("- **Visibilidade medida:** %s." % ("%.1f%% da imagem muda" % vis if vis is not None else "não coberta na captura de 15/11/2026"))
        for extra in NATIVAS.get(nome, []):
            L.append("- " + extra)
        L.append("- **Camadas visuais genéricas:** carga, rastro da mão, impacto no contato, clímax sem alvo e anel de ativação.")
        return L
    L.append("- **Objetivo (inferido do nome e dos efeitos):** %s — %s." % (nome, objetivo(nome, java)))
    L.append("- **Dano no Java:** %s." % (("; ".join(java["dano"][:4])) if java["dano"] else "sem `Damage` direto neste procedure (o dano pode vir de entidade/procedure chamado)"))
    L.append("- **Alcance/área (Range):** %s." % (("; ".join(java["alcance"][:4])) if java["alcance"] else "não declarado aqui"))
    L.append("- **Empurrão (knockback):** %s." % (("; ".join(java["empurrao"][:4])) if java["empurrao"] else "não declarado aqui"))
    if java["usa_cnt6"]:
        L.append("- **Carga:** usa `cnt6` (carga acumulada), então segurar a tecla amplifica a técnica (multiplicador `1 + cnt6/10`).")
    else:
        L.append("- **Carga:** não usa a carga `cnt6`: o resultado não muda ao segurar a tecla.")
    L.append("- **Entidades criadas:** %s." % (", ".join(java["entidades"]) if java["entidades"] else "nenhuma (efeito direto no jogador/alvos)"))
    L.append("- **Efeitos do mod aplicados:** %s." % (", ".join(java["efeitos_mod"]) if java["efeitos_mod"] else "nenhum efeito próprio do mod neste procedure"))
    parts = list(java["particulas_cmd"]) + [p.lower() for p in java["particulas_mod"]]
    L.append("- **Partículas do mod:** %s." % (", ".join(parts[:6]) if parts else "só as partículas padrão do Minecraft (ou nenhuma)"))
    L.append("- **Sons:** %s." % (", ".join(java["sons"]) if java["sons"] else "não declarados aqui"))
    L.append("- **Duração aproximada:** %s." % (("até o tick %d (≈ %.1f s)" % (java["cnt1_max"], java["cnt1_max"] * TICK)) if java["cnt1_max"] else "não derivável de um contador único (várias fases)"))
    if java["chama"]:
        L.append("- **Chama outros procedures:** %s." % ", ".join(java["chama"][:8]))
    if med:
        L.append("- **Medição (varredura 15/11/2026):** começou=%s, energia gasta=%s, nós criados=%s, dano no alvo a 4 m=%s." % (med["comecou"], med["gasto"], med["nasceu"], med["dano"]))
    L.append("- **Execução no jogo:** a camada Minecraft traduz esse Java (`src/minecraft/gerado/procedures/`), o controlador do mod roda um passo por tick de 0,05 s e o dano passa por `McEntidade.hurt` → `take_damage`.")
    for extra in NATIVAS.get(nome, []):
        L.append("- " + extra)
    if vis is not None:
        L.append("- **Visibilidade medida (15/11/2026):** %.1f%% da imagem muda em relação à cena sem a técnica (%s)." % (vis, "baixa: candidata a reforço visual" if vis < 8 else "legível"))
    else:
        L.append("- **Visibilidade medida:** não coberta na captura de 15/11/2026.")
    L.append("- **Camadas visuais genéricas:** carga (HTCS `PoderDaFruta.carga`), rastro da mão, impacto no contato, clímax sem alvo e o anel de ativação da cor da fruta.")
    return L


def ler_varredura(*caminhos):
    """`  ✅ Nome [Z] começou=true gasto=110 nasceu=2 dano=14 (custo ...)` -> {(fruta, nome): dict}. A fruta vem das linhas `FRUTA x: N golpes`."""
    saida = {}
    for caminho in caminhos:
        if not os.path.exists(caminho):
            continue
        fruta = None
        for l in open(caminho, encoding="utf-8", errors="ignore"):
            m = re.match(r"FRUTA (\S+): \d+ golpes", l)
            if m:
                fruta = m.group(1)
                continue
            m = re.match(r"\s+[✅❌] (.+?)\s+\[(\w)\] começou=(\w+) gasto=(-?\d+) nasceu=(-?\d+) dano=(-?\d+)", l)
            if m and fruta:
                saida[(fruta, m.group(1).strip())] = {"comecou": m.group(3), "gasto": m.group(4), "nasceu": m.group(5), "dano": m.group(6)}
    return saida


def main():
    tecs = json.load(open(sys.argv[1]))
    pasta = sys.argv[2]
    global VARR
    VARR = ler_varredura(*sys.argv[4:])
    vis = {}
    if len(sys.argv) > 3:
        for l in open(sys.argv[3]):
            p = l.split()
            vis[p[1]] = float(p[0].rstrip("%"))
    out = ["# Skills das frutas só-do-mod no Modo História — descrição extraída do código",
           "",
           "> **GERADO** por `tools/mine_piece/documentar_skills_do_mod.py` em 15/11/2026 a partir do jogo (lista de técnicas) e dos procedures Java do mod.",
           "> Nada aqui é inventado: o que a técnica faz vem do Java; o **objetivo** é inferido do nome e dos efeitos e está marcado como tal.",
           "> Para as 5 frutas nativas (Ope, Hie, Moku, Pika, Nikyu) e a Luta, ver `SKILLS_MINE_PIECE_MODO_HISTORIA.md` (escrito à mão, com o visual medido).",
           ""]
    total = 0
    for id_fruta in sorted(tecs):
        arq = achar_skill(pasta, id_fruta)
        desp = {}
        # Frutas Zoan têm um despacho por FORMA (`SkillInuInuWolf…`): junta o de todos os `Skill*Procedure` que citam a fruta.
        token = id_fruta.split("_")[-1] if id_fruta.count("_") >= 2 else id_fruta.replace("_", "")
        for f in sorted(os.listdir(pasta)):
            fl = f.lower()
            if fl.startswith("skill") and fl.endswith("procedure.java") and (token in fl or (arq and f == arq)):
                for n, pr in despacho(open(os.path.join(pasta, f), encoding="utf-8", errors="ignore").read()).items():
                    desp.setdefault(n, pr)
        out.append("## %s" % id_fruta.replace("_", " ").title())
        out.append("")
        out.append("Despacho do mod: `%s` — números mapeados: %s." % (arq or "não encontrado", ", ".join(map(str, sorted(desp))) or "nenhum"))
        out.append("")
        mapa = tecs[id_fruta]["mapa"]
        for tec in tecs[id_fruta]["tecnicas"]:
            numero = mapa.get(tec["tecla"])
            proc = desp.get(int(numero)) if numero is not None else None
            aproximado = False
            if not proc or not os.path.exists(os.path.join(pasta, proc + "Procedure.java")):
                alt = por_nome(pasta, id_fruta, tec["nome"])
                if alt:
                    proc, aproximado = alt, True
            java = None
            if proc:
                p = os.path.join(pasta, proc + "Procedure.java")
                if os.path.exists(p):
                    java = fatos(open(p, encoding="utf-8", errors="ignore").read())
            v = vis.get("%s_%s" % (id_fruta, tec["tecla"]))
            out.append("### %s · %s (`%s`, nº %s)" % (id_fruta, tec["nome"], tec["tecla"], numero))
            out.extend(descrever(id_fruta, tec, numero, (proc + " (aproximado: achado pelo NOME da técnica, o despacho do mod não leva este número a um procedure)") if (proc and aproximado) else proc, java, v, "números " + ", ".join(map(str, sorted(desp))) if desp else ""))
            out.append("")
            total += 1
    out.append("<!-- %d técnicas documentadas -->" % total)
    texto = "\n".join(out)
    # "NomeProcedure": o aviso de aproximação vem DEPOIS do sufixo (antes saía "Nome (aproximado…)Procedure").
    texto = re.sub(r"`([A-Za-z0-9]+) (\(aproximado: [^)]*\))Procedure`", r"`\1Procedure` \2", texto)
    print(texto)


if __name__ == "__main__":
    main()
