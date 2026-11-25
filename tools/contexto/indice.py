#!/usr/bin/env python3
"""Índice vetorial do SKILLS ONE PIECE — onde está o código e quanto ele pesa.

Só biblioteca padrão: nada para instalar, nada para baixar.

  python3 tools/contexto/indice.py buscar "aparo riposte"      # onde está o código de X
  python3 tools/contexto/indice.py buscar "vida hud" --area interface -n 5
  python3 tools/contexto/indice.py buscar "por que tela cinza" --docs   # só documentos
  python3 tools/contexto/indice.py construir                    # refaz índice + docs/contexto/INDICE.md
  python3 tools/contexto/indice.py verificar                    # contextos com caminho morto ou velhos

COMO FUNCIONA
  • Cada arquivo vira TRECHOS com linha: no GDScript, o cabeçalho e cada `func`/`class`
    (com os comentários `##` de cima); no Markdown, cada seção de título.
  • Cada trecho vira um vetor TF-IDF (tf = 1 + log n; idf = log((N+1)/(df+1)) + 1;
    normalizado). Nome do arquivo e da função contam em dobro. Identificadores são
    partidos (`receber_acerto` → receber, acerto; `BarraHud` → barra, hud) e acentos saem,
    então "animação" acha `animacao`.
  • A busca é cosseno com um empurrão pequeno da RELEVÂNCIA do arquivo (×1,0 a ×1,3):
    em empate de texto, o arquivo central vem antes.
  • Terminações do português são reduzidas (aparo/aparar/aparou → apar), e trecho
    minúsculo pesa menos que a função que trata o assunto.
  • Acha por PALAVRA, não por sentido: "defesa" não acha "guarda". Na dúvida, busque
    os dois termos.

RELEVÂNCIA (1 a 5, por arquivo de código) — fórmula reproduzível, não opinião:
    0,55·fan-in + 0,20·tamanho + 0,15·testes + 0,10·entrada   (cada termo em log, 0–1)
  fan-in  = quantos OUTROS arquivos de jogo citam o arquivo (class_name ou res://)
  testes  = quantos tools/dev_tests/test_*.gd o citam
  entrada = autoload do project.godot, cena principal ou orquestrador de modo
  Faixas por posição: 5 = 5% do topo, 4 = 10% seguintes, 3 = 20%, 2 = 30%, 1 = o resto.

O índice fica em tools/contexto/.cache/ (fora do git e do Godot) e é refeito sozinho
quando algum arquivo fica mais novo que ele.
"""
from __future__ import annotations

import argparse
import math
import os
import pickle
import re
import sys
import time
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
CACHE = RAIZ / "tools" / "contexto" / ".cache" / "indice.pkl"
MAPA = RAIZ / "docs" / "contexto" / "INDICE.md"
VERSAO = 4   # mudar quando o formato do cache (ou a tokenização) mudar

EXTENSOES = {".gd", ".gdshader", ".py", ".sh", ".md"}
PASTAS_FORA = {".godot", ".claude", "disabled", "art_src", "__pycache__", "graphify-out",
               ".git", "build", ".cache"}
CAMINHOS_FORA = ("multimodal/cache/", "tools/anim_editor/studio/.godot/", "docs/historico/",
                 "docs/contexto/INDICE.md")   # o mapa é SAÍDA daqui: indexá-lo refaria o índice a cada busca

# Área de cada caminho: primeiro prefixo que casar. Ordem importa (mais específico antes).
AREAS = [
    ("src/combat/direcional/", "historia"),
    ("src/historia/", "historia"),
    ("src/editor_mapa/", "mundo"),
    ("src/world/", "mundo"),
    ("mapas/", "mundo"),
    ("src/bosses/", "bosses"),
    ("src/combat/", "combate"),
    ("src/items/", "combate"),
    ("src/effects/", "frutas"),
    ("SkillSystem.gd", "frutas"),
    ("FruitPassiveSystem.gd", "frutas"),
    ("TreeAndFruitGenerator.gd", "frutas"),
    ("src/anim/", "personagem"),
    ("src/characters/", "personagem"),
    ("src/customizacao/", "personagem"),
    ("CharacterBuilder.gd", "personagem"),
    ("CharacterAnimator.gd", "personagem"),
    ("VoxelMeshes.gd", "personagem"),
    ("network/", "rede"),
    ("src/ui/", "interface"),
    ("src/fx/", "visual"),
    ("src/audio/", "visual"),
    ("VFX/", "visual"),
    ("src/player/", "nucleo"),
    ("src/mechanics/", "nucleo"),
    ("src/match/", "nucleo"),
    ("src/entities/", "nucleo"),
    ("src/utils/", "nucleo"),
    ("autoload/", "nucleo"),
    ("Player.gd", "nucleo"),
    ("Main.gd", "nucleo"),
    ("src/tests/", "ferramentas"),
    ("test_", "ferramentas"),          # sondas soltas na raiz (test_peer, test_spawner...)
    ("tools/", "ferramentas"),
    ("multimodal/", "ferramentas"),
]
# Documentos: por nome (pasta ou prefixo do arquivo). O resto é "geral".
AREAS_DOCS = [
    ("docs/combat/", "historia"), ("MODO_HISTORIA", "historia"), ("PLANO_COMBATE_HISTORIA", "historia"),
    ("docs/frutas/", "frutas"), ("PLANO_FRUTAS", "frutas"), ("AUDITORIA_FRUTAS", "frutas"),
    ("PLANO_MERA", "frutas"), ("PLANO_BARA", "frutas"), ("EXECUCAO_BARA", "frutas"),
    ("ESTUDO_MERA", "frutas"), ("GEAR2", "frutas"),
    ("BOSS_", "bosses"), ("PLANO_BOSS", "bosses"),
    ("COMBATE_", "combate"), ("PLANO_COMBATE_", "combate"), ("ESTILOS_DE_LUTA", "combate"),
    ("ESTILO_PACIFISTA", "combate"), ("MODOS_DE_COMBATE", "combate"), ("YORU", "combate"),
    ("PLANO_YORU", "combate"), ("EXECUCAO_YORU", "combate"), ("PLANO_EQUILIBRIO", "combate"),
    ("ANIMACOES_MIXAMO", "personagem"), ("ESQUELETO", "personagem"), ("PERSONAGEM_BASE", "personagem"),
    ("PLANO_ANIMACAO", "personagem"), ("CUSTOMIZACAO", "personagem"), ("DIRECOES", "personagem"),
    ("MOVIMENTO", "nucleo"), ("ARQUITETURA_PLAYER", "nucleo"), ("RELATORIO_PLAYER", "nucleo"),
    ("MECANICAS", "nucleo"), ("RODADA_E_PLACAR", "nucleo"),
    ("PLANO_VISUAL", "visual"), ("REVISAO_QUALIDADE", "visual"), ("AUDITORIA_FASE6", "visual"),
    ("HOSPEDAR", "rede"), ("EXPORTAR", "rede"),
    ("MODO_CELULAR", "interface"),
    ("VALIDACAO", "ferramentas"), ("AGENTES", "ferramentas"), ("docs/contexto/", "geral"),
]
NOMES_DAS_AREAS = {
    "nucleo": "Núcleo e jogador",
    "combate": "Combate da arena",
    "frutas": "Frutas e técnicas",
    "personagem": "Personagem, rig e animação",
    "historia": "Modo História",
    "mundo": "Mundo e editor de mapa",
    "bosses": "Chefes e IA",
    "rede": "Rede e multiplayer",
    "interface": "Interface e HUD",
    "visual": "Visual, VFX e áudio",
    "ferramentas": "Ferramentas, testes e pipeline",
    "geral": "Geral",
}
# Arquivos centrais SEM comentário de cabeçalho: resumo escrito aqui, para o mapa não
# ficar em branco justo nos mais importantes. Manter curto e conferir quando mudarem.
RESUMOS_FIXOS = {
    "Player.gd": "O jogador: casca que liga entrada, movimento, câmera, combate, rede e apresentação "
                 "(partição em docs/ARQUITETURA_PLAYER.md)",
}
# Cenas principais e orquestradores de modo: pouco citados por nome, mas são a porta.
ENTRADAS_EXTRAS = {"Main.gd", "src/historia/ModoHistoria.gd", "src/editor_mapa/EditorDeMapa.gd",
                   "src/ui/MainMenu.gd", "Player.gd"}

PALAVRAS_VAZIAS = set("""
de da do das dos que o a os as e em no na nos nas um uma uns umas para pra por com sem
se ao aos ou mas mais menos como quando onde porque pois ja nao sim eh foi ser esta
este esse essa isto isso aqui ali la tem ter cada todo toda todos todas so sao era
sobre entre ate depois antes ainda tambem muito pouco mesmo mesma outro outra
func var const if else elif return for in and or not true false null self pass
extends class static await match while break continue signal void float int bool
string array dictionary res export onready tool super get set new of the to is it
""".split())

_CAMEL = re.compile(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])")
_PALAVRA = re.compile(r"[A-Za-z0-9]+")


def _sem_acento(texto: str) -> str:
    return unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode("ascii")


# Terminações de verbo e de nome do português, da mais longa para a mais curta.
_SUFIXOS = ("amente", "ando", "endo", "indo", "ados", "adas", "idos", "idas", "ado", "ada",
            "ido", "ida", "ar", "er", "ir", "ou", "am", "em", "ei", "a", "o", "e")


def _raiz(t: str) -> str:
    """Redução LEVE, igual na consulta e no texto: aparo/aparar/aparou/aparando → apar;
    golpes → golp. Raiz mínima de 4 letras, para "vida" não virar "vid" nem "caso" casar
    com "casa". Não é um stemmer de verdade — é o bastante para achar a mesma palavra."""
    if len(t) > 4 and t.endswith("oes"):
        t = t[:-3] + "ao"
    elif len(t) > 4 and t.endswith("s") and not t.endswith("ss"):
        t = t[:-1]
    for suf in _SUFIXOS:
        if t.endswith(suf) and len(t) - len(suf) >= 4:
            return t[:-len(suf)]
    return t


def tokens(texto: str) -> list[str]:
    saida = []
    for bruta in _PALAVRA.findall(_sem_acento(texto)):
        for parte in _CAMEL.split(bruta):
            t = parte.lower()
            if len(t) < 2 or t.isdigit() or t in PALAVRAS_VAZIAS:
                continue
            saida.append(_raiz(t))
    return saida


def area_de(rel: str) -> str:
    if rel.endswith(".md"):
        for prefixo, area in AREAS_DOCS:
            if rel.startswith(prefixo) or Path(rel).name.startswith(prefixo):
                return area
        return "geral"
    for prefixo, area in AREAS:
        if rel.startswith(prefixo):   # arquivo solto só casa na RAIZ ("Player.gd" ≠ "src/x/Player.gd")
            return area
    if rel.endswith((".sh", ".py")):
        return "ferramentas"
    return "nucleo" if "/" not in rel else "geral"


def arquivos() -> list[Path]:
    lista = []
    for pasta, subpastas, nomes in os.walk(RAIZ):
        subpastas[:] = [s for s in subpastas if s not in PASTAS_FORA]
        for nome in nomes:
            p = Path(pasta) / nome
            rel = p.relative_to(RAIZ).as_posix()
            if p.suffix in EXTENSOES and not rel.startswith(CAMINHOS_FORA):
                lista.append(p)
    return sorted(lista)


# ------------------------------------------------------------------ trechos
_DECL_GD = re.compile(r"^(static\s+func|func|class)\s+([A-Za-z_][A-Za-z0-9_]*)")
_TITULO_MD = re.compile(r"^(#{1,4})\s+(.*)")
_FUNC_SH = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")
_DEF_PY = re.compile(r"^(def|class)\s+([A-Za-z_][A-Za-z0-9_]*)")


def trechos(rel: str, linhas: list[str]) -> list[tuple[int, int, str]]:
    """(linha inicial, linha final, símbolo), 1-based e inclusivo."""
    if rel.endswith(".md"):
        marcas = [(i, m.group(2).strip()) for i, l in enumerate(linhas) if (m := _TITULO_MD.match(l))]
    else:
        padrao = _DECL_GD if rel.endswith((".gd", ".gdshader")) else _DEF_PY if rel.endswith(".py") else _FUNC_SH
        marcas = []
        for i, l in enumerate(linhas):
            m = padrao.match(l)
            if m:
                inicio = i
                while inicio > 0 and linhas[inicio - 1].lstrip().startswith("##"):
                    inicio -= 1   # a documentação da função fica com ela
                marcas.append((inicio, m.group(m.re.groups)))   # o nome é o último grupo
    if not marcas or marcas[0][0] > 0:
        marcas.insert(0, (0, "(cabeçalho)"))
    saida = []
    for k, (inicio, simbolo) in enumerate(marcas):
        fim = marcas[k + 1][0] - 1 if k + 1 < len(marcas) else len(linhas) - 1
        if fim >= inicio and any(l.strip() for l in linhas[inicio:fim + 1]):
            saida.append((inicio + 1, fim + 1, simbolo))
    return saida


def resumo(rel: str, linhas: list[str]) -> str:
    """Primeira frase útil do cabeçalho (comentário do topo, docstring ou título)."""
    if rel.endswith(".md"):
        for l in linhas:
            if l.startswith("#"):
                return l.lstrip("#").strip()[:110]
        return ""
    if rel in RESUMOS_FIXOS:
        return RESUMOS_FIXOS[rel]
    # Só o TOPO (20 linhas): o cabeçalho costuma vir depois de `extends` e de um ou outro
    # `const … preload` (medido: linhas 4–8). Comentário mais abaixo é do meio do código e
    # não descreve o arquivo (AutoDummy: linha 134; BossVisual: 85).
    for l in linhas[:20]:
        s = l.strip()
        if s.startswith(('"""', "'''")):
            return s.strip("\"' ")[:110] if len(s) > 6 else ""
        if not s.startswith("#") or s.startswith("#!"):
            continue
        s = s.lstrip("#").strip()
        if not s or set(s) <= set("=-─·*~ ") or s.lower().startswith(("warning-ignore", "gdlint")):
            continue
        return s[:110]
    return ""


# ------------------------------------------------------------------ construir
def construir() -> dict:
    t0 = time.time()
    lista = arquivos()
    docs_por_arquivo = {}
    textos = {}
    for p in lista:
        rel = p.relative_to(RAIZ).as_posix()
        try:
            texto = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        textos[rel] = texto

    # --- relevância (só código de jogo e ferramentas; .md fica fora do mapa)
    codigo = [r for r in textos if r.endswith(".gd")]
    classe_de = {}
    for r in codigo:
        m = re.search(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", textos[r], re.M)
        if m:
            classe_de[r] = m.group(1)
    palavras_de = {r: set(_PALAVRA.findall(textos[r])) for r in codigo}
    caminhos_de = {r: set(re.findall(r"res://([^\"'\s)]+)", textos[r])) for r in codigo}
    testes = [r for r in codigo if r.startswith("tools/dev_tests/test_")]
    projeto = (RAIZ / "project.godot").read_text(encoding="utf-8")
    autoloads = set(re.findall(r'"\*?res://([^"]+)"', projeto))
    # Autoload é citado pelo NOME global (`GameFlow.start_story()`), não por class_name.
    for nome, caminho in re.findall(r'^([A-Za-z_][A-Za-z0-9_]*)="\*?res://([^"]+)"', projeto, re.M):
        classe_de.setdefault(caminho, nome)

    fan_in, n_testes = Counter(), Counter()
    for alvo in codigo:
        classe = classe_de.get(alvo)
        for quem in codigo:
            if quem == alvo:
                continue
            cita = (classe is not None and classe in palavras_de[quem]) or alvo in caminhos_de[quem]
            if not cita:
                continue
            if quem in testes:
                n_testes[alvo] += 1
            elif not quem.startswith("tools/"):
                fan_in[alvo] += 1

    def norm(valores: dict) -> dict:
        maior = max((math.log1p(v) for v in valores.values()), default=1.0) or 1.0
        return {k: math.log1p(v) / maior for k, v in valores.items()}

    linhas_de = {r: textos[r].count("\n") + 1 for r in textos}
    candidatos = [r for r in codigo if not r.startswith("tools/dev_tests/")]
    f_n = norm({r: fan_in[r] for r in candidatos})
    t_n = norm({r: linhas_de[r] for r in candidatos})
    s_n = norm({r: n_testes[r] for r in candidatos})
    nota = {}
    for r in candidatos:
        entrada = 1.0 if (r in autoloads or r in ENTRADAS_EXTRAS) else 0.0
        nota[r] = 0.55 * f_n[r] + 0.20 * t_n[r] + 0.15 * s_n[r] + 0.10 * entrada
    ordem = sorted(candidatos, key=lambda r: -nota[r])
    faixa = {}
    cortes = [(0.05, 5), (0.15, 4), (0.35, 3), (0.65, 2), (1.01, 1)]
    for i, r in enumerate(ordem):
        pos = (i + 1) / len(ordem)
        faixa[r] = next(f for limite, f in cortes if pos <= limite)

    # --- vetores
    registros = []   # (rel, inicio, fim, simbolo, area, tipo)
    contagens = []
    for rel, texto in textos.items():
        linhas = texto.split("\n")
        area = area_de(rel)
        tipo = "doc" if rel.endswith(".md") else "teste" if rel.startswith("tools/dev_tests/") else "codigo"
        nome = tokens(Path(rel).stem)
        for inicio, fim, simbolo in trechos(rel, linhas):
            c = Counter(tokens("\n".join(linhas[inicio - 1:fim])))
            for t in nome + tokens(simbolo):
                c[t] += 2   # nome do arquivo e do símbolo pesam em dobro
            if not c:
                continue
            registros.append((rel, inicio, fim, simbolo, area, tipo, sum(c.values())))
            contagens.append(c)
        docs_por_arquivo[rel] = resumo(rel, linhas)
    n = len(contagens)
    df = Counter(t for c in contagens for t in c)
    idf = {t: math.log((n + 1) / (d + 1)) + 1.0 for t, d in df.items()}
    postings = defaultdict(list)
    for i, c in enumerate(contagens):
        pesos = {t: (1.0 + math.log(v)) * idf[t] for t, v in c.items()}
        norma = math.sqrt(sum(w * w for w in pesos.values())) or 1.0
        for t, w in pesos.items():
            postings[t].append((i, round(w / norma, 5)))

    indice = {
        "versao": VERSAO, "criado": time.time(), "trechos": registros, "idf": idf,
        "postings": dict(postings), "resumo": docs_por_arquivo, "linhas": linhas_de,
        "faixa": faixa, "fan_in": dict(fan_in), "testes": dict(n_testes), "classe": classe_de,
    }
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    with open(CACHE, "wb") as f:
        pickle.dump(indice, f, protocol=pickle.HIGHEST_PROTOCOL)
    escrever_mapa(indice)
    print(f"índice: {len(textos)} arquivos, {n} trechos, {len(idf)} termos em {time.time() - t0:.1f} s")
    print(f"mapa:   {MAPA.relative_to(RAIZ)}")
    return indice


def _mais_novo() -> float:
    return max((p.stat().st_mtime for p in arquivos()), default=0.0)


def carregar() -> dict:
    if CACHE.exists():
        with open(CACHE, "rb") as f:
            indice = pickle.load(f)
        if indice.get("versao") == VERSAO and CACHE.stat().st_mtime >= _mais_novo():
            return indice
        print("(índice desatualizado — refazendo)", file=sys.stderr)
    return construir()


# ------------------------------------------------------------------ buscar
def buscar(consulta: str, n: int, area: str | None, so_docs: bool, sem_docs: bool, com_testes: bool) -> None:
    indice = carregar()
    q = Counter(tokens(consulta))
    if not q:
        print("consulta vazia depois de tirar palavras comuns")
        return
    pontos = defaultdict(float)
    for t, v in q.items():
        w_q = (1.0 + math.log(v)) * indice["idf"].get(t, 0.0)
        for i, w in indice["postings"].get(t, ()):
            pontos[i] += w_q * w
    trechos_ = indice["trechos"]
    faixa = indice["faixa"]
    resultado = []
    for i, p in pontos.items():
        rel, inicio, fim, simbolo, area_t, tipo, tamanho = trechos_[i]
        if area and area_t != area:
            continue
        if so_docs and tipo != "doc" or sem_docs and tipo == "doc":
            continue
        if tipo == "teste" and not com_testes and not so_docs:
            continue
        f = faixa.get(rel, 3)
        # Trecho minúsculo (acessor de uma linha) pesa menos: com o cosseno, o nome da função
        # sozinho dominava o vetor e ganhava da função que trata o assunto (0,63 com 3 termos,
        # 0,82 com 10, ~1 acima de 30).
        curto = 0.5 + 0.5 * (1.0 - math.exp(-tamanho / 10.0))
        resultado.append((p * curto * (1.0 + 0.075 * (f - 1)), rel, inicio, fim, simbolo, area_t, tipo, f))
    resultado.sort(key=lambda x: -x[0])
    if not resultado:
        print("nada encontrado — tente sinônimos (o índice acha por palavra, não por sentido)")
        return
    vistos = Counter()
    mostrados = 0
    for nota, rel, inicio, fim, simbolo, area_t, tipo, f in resultado:
        if vistos[rel] >= 2:
            continue   # no máximo 2 trechos por arquivo: variedade antes de profundidade
        vistos[rel] += 1
        estrelas = "★" * f if tipo == "codigo" else ("doc" if tipo == "doc" else "teste")
        print(f"{nota:5.3f}  {rel}:{inicio}-{fim}  {simbolo}  [{area_t} {estrelas}]")
        r = indice["resumo"].get(rel, "")
        if r and vistos[rel] == 1:
            print(f"       {r}")
        mostrados += 1
        if mostrados >= n:
            break


# ------------------------------------------------------------------ mapa
def escrever_mapa(indice: dict) -> None:
    faixa, linhas, resumo_ = indice["faixa"], indice["linhas"], indice["resumo"]
    fan_in, testes, classe = indice["fan_in"], indice["testes"], indice["classe"]
    por_area = defaultdict(list)
    for rel in faixa:
        por_area[area_de(rel)].append(rel)
    total_linhas = sum(linhas[r] for r in faixa)
    saida = [
        "# Índice do código — onde está e quanto pesa",
        "",
        "> **Gerado** por `python3 tools/contexto/indice.py construir` — não edite à mão (a próxima",
        "> construção apaga). Para achar código por assunto: `python3 tools/contexto/indice.py buscar \"...\"`.",
        "",
        f"{len(faixa)} arquivos `.gd` de jogo e ferramentas ({total_linhas:,} linhas; sem `tools/dev_tests/`),"
        .replace(",", "."),
        "agrupados pela área do contexto (`docs/contexto/<area>.md`).",
        "",
        "**Relevância ★1–★5** = 0,55·fan-in + 0,20·tamanho + 0,15·testes + 0,10·entrada (log, 0–1),",
        "em faixas por posição (★5 = 5% do topo). **fan-in** = arquivos de jogo que o citam;",
        "**testes** = `test_*.gd` que o citam. Arquivo com ★ alto e 0 testes é risco: muita gente",
        "depende dele e nada o vigia.",
        "",
        "| área | arquivos | linhas | ★5 | ★4 |",
        "|---|---:|---:|---:|---:|",
    ]
    ordem_areas = [a for a in NOMES_DAS_AREAS if a in por_area]
    for a in ordem_areas:
        rs = por_area[a]
        saida.append(f"| [{NOMES_DAS_AREAS[a]}](#{a}) | {len(rs)} | {sum(linhas[r] for r in rs)} | "
                     f"{sum(1 for r in rs if faixa[r] == 5)} | {sum(1 for r in rs if faixa[r] == 4)} |")
    for a in ordem_areas:
        rs = sorted(por_area[a], key=lambda r: (-faixa[r], -fan_in.get(r, 0), r))
        saida += ["", f"## {NOMES_DAS_AREAS[a]} <a id=\"{a}\"></a>", "",
                  f"Contexto: [`{a}.md`](agentes/{a}.md) (agentes) · [`{a}.md`](pessoas/{a}.md) (pessoas)", "",
                  "| ★ | arquivo | linhas | fan-in | testes | o que é |", "|---|---|---:|---:|---:|---|"]
        for r in rs:
            nome = f"`{r}`" + (f" ({classe[r]})" if r in classe and classe[r] != Path(r).stem else "")
            texto = resumo_.get(r, "").replace("|", "\\|")
            saida.append(f"| {faixa[r]} | {nome} | {linhas[r]} | {fan_in.get(r, 0)} | {testes.get(r, 0)} | {texto} |")
    MAPA.parent.mkdir(parents=True, exist_ok=True)
    MAPA.write_text("\n".join(saida) + "\n", encoding="utf-8")


# ------------------------------------------------------------------ verificar
_CAMINHO_CITADO = re.compile(r"`([A-Za-z0-9_./-]+\.(?:gd|md|sh|py|tres|tscn|json|gdshader))(?::\d+)?`|\]\(([^)#\s]+)\)")


def verificar() -> int:
    contextos = [RAIZ / "PROJECT_CONTEXT.md"] + sorted((RAIZ / "docs" / "contexto").rglob("*.md"))
    problemas = 0
    indice = carregar()
    todos = [p.relative_to(RAIZ).as_posix() for p in arquivos()] + list(indice["faixa"])
    for ctx in contextos:
        if not ctx.exists() or ctx == MAPA:
            continue
        rel_ctx = ctx.relative_to(RAIZ).as_posix()
        texto = ctx.read_text(encoding="utf-8")
        for m in _CAMINHO_CITADO.finditer(texto):
            alvo = m.group(1) or m.group(2)
            if alvo.startswith(("http", "mailto:")) or "*" in alvo or "<" in alvo:
                continue
            candidatos = [ctx.parent / alvo, RAIZ / alvo, RAIZ / "docs" / alvo]
            achou = any(c.exists() for c in candidatos)
            if not achou and "/" not in alvo:   # nome solto: vale se existir em algum lugar
                achou = any(r == alvo or r.endswith("/" + alvo) for r in todos) \
                    or any(RAIZ.glob(f"**/{alvo}"))
            if not achou:
                print(f"CAMINHO MORTO  {rel_ctx}: {alvo}")
                problemas += 1
        # velho: a área mudou depois do contexto (só os contextos de área)
        area = ctx.stem if ctx.parent.name in ("agentes", "pessoas") else None
        if area in NOMES_DAS_AREAS:
            do_ctx = ctx.stat().st_mtime
            mudados = [r for r in indice["faixa"] if area_de(r) == area and (RAIZ / r).stat().st_mtime > do_ctx]
            if mudados:
                print(f"VELHO?         {rel_ctx}: {len(mudados)} arquivo(s) da área mudaram depois dele "
                      f"(ex.: {mudados[0]})")
    print("ok" if problemas == 0 else f"{problemas} caminho(s) morto(s)")
    return 1 if problemas else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("buscar", help="onde está o código de X")
    b.add_argument("consulta", nargs="+")
    b.add_argument("-n", type=int, default=10)
    b.add_argument("--area", choices=sorted(NOMES_DAS_AREAS))
    b.add_argument("--docs", action="store_true", help="só documentos")
    b.add_argument("--sem-docs", action="store_true", help="só código")
    b.add_argument("--testes", action="store_true", help="incluir tools/dev_tests/")
    sub.add_parser("construir", help="refaz o índice e o mapa docs/contexto/INDICE.md")
    sub.add_parser("verificar", help="caminhos mortos e contextos mais velhos que a área")
    a = ap.parse_args()
    if a.cmd == "buscar":
        buscar(" ".join(a.consulta), a.n, a.area, a.docs, a.sem_docs, a.testes)
    elif a.cmd == "construir":
        construir()
    else:
        return verificar()
    return 0


if __name__ == "__main__":
    sys.exit(main())
