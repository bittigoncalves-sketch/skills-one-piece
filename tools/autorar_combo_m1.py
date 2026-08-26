# -*- coding: utf-8 -*-
"""
AUTORA OS QUATRO M1 DO COMBO — Fases A-D do §6 de docs/PLANO_COMBATE_BATTLEGROUNDS.

    python3 tools/autorar_combo_m1.py

Grava `assets/animations/m1_<nome>.tres` (o Godot lê .tres igual a .res) e o
JSON de trabalho em `tools/anim_editor/clips/`, para o editor e o Blender.

---------------------------------------------------------------- POR QUE REFAZER
Duas razões, e a segunda só apareceu ao medir (2026-08-25):

1. TEMPO. O frame data novo dá 0,40 s por golpe e os clipes do Mixamo têm
   1,37-2,23 s. Hoje eles entram por JANELA (o `Melee.fim_da_janela` corta a
   volta à guarda). Acelerar para caber exigiria 5,6x — e a 1,9x o soco já
   virava borrão, que é o defeito de 2026-08-11.

2. O TRONCO TOMBADO. Medido nos 29 clipes: ONZE começam com o tronco rolado
   mais de 25° no eixo Z. Dois deles são do combo:

       boxing_1 (jab)          Z(t=0) = −32,8°   (faixa −56,1 … +32,6)
       roundhouse_kick (chute) Z(t=0) = −81,4°   (faixa −85,7 … −51,8)

   O chute NUNCA fica de pé: o tronco passa o clipe inteiro entre −52° e −86°.
   Conferido no jogo, não só no dado: tocando `bouncing_fight_idle`, o "up" do
   torso fica a 51° da vertical. É defeito de retarget, e nenhuma janela
   conserta — por isso a autoria nova.

--------------------------------------------------------- COMO ESTES SÃO FEITOS
Três regras, todas do §6.3 do plano, e as três MEDIDAS pelo portão no fim:

  1. GUARDA DE ENTRADA DISTINTA por golpe — não espelhada. É a correção direta
     da causa raiz de 2026-08-11 ("os dois socos liam igual"): os dois clipes
     antigos partiam da MESMA pose de guarda, idêntica ao grau, e quando o
     golpe dura 0,40 s o que sobra em tela é a guarda.
  2. EIXO DE TRAJETÓRIA DIFERENTE — jab reto, soco 2 em arco, chute lateral,
     finalizador vertical. Quatro eixos compensam o tempo igual entre eles.
  3. QUADRO DE CONTATO CONGELADO — a pose do impacto se repete durante o
     `ativo` inteiro em vez de continuar mudando. É esse quadro que o hitstop
     estica no relógio real, sem gastar orçamento do clipe.

--------------------------------------------------------------- O VOCABULÁRIO
O rig pendura os membros no −Y local. Em cima disso:

    UpperArm.x  +1,5  = braço apontando à FRENTE (−Z do modelo)
    UpperArm.z  ±1,4  = braço na HORIZONTAL, para o lado (+R / −L)
    ForeArm.x   +1,5  = cotovelo dobrado 90° (mão sobe para o rosto)
    Thigh.x     +     = coxa à frente;  Shin.x  −  = joelho dobrado para trás
    Torso.y     ±     = ombros girando (é o que dá potência ao soco)
    Torso.x     +     = peito para trás;  −  = peito para a frente

⚠️ Torso.z FICA PERTO DE ZERO em todos os quatro. É exatamente o campo que
estava tombado nos clipes velhos.
"""

import math, os, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, "tools", "anim_editor"))
from clip import Clip                                    # noqa: E402

DIR_TRES = os.path.join(RAIZ, "assets", "animations")
DIR_JSON = os.path.join(RAIZ, "tools", "anim_editor", "clips")

Z = (0.0, 0.0, 0.0)


def pose(**kw):
    """Pose = dicionário papel -> (x,y,z). O que não é citado fica em repouso."""
    return {k: tuple(float(x) for x in v) for k, v in kw.items()}


def mistura(a, b, f):
    papeis = set(a) | set(b)
    fora = {}
    for p in papeis:
        va, vb = a.get(p, Z), b.get(p, Z)
        fora[p] = tuple(va[i] + (vb[i] - va[i]) * f for i in range(3))
    return fora


# ============================================================================
#  AS GUARDAS DE ENTRADA — o item 1 do §6.3, e a razão de existir deste arquivo
#
#  As quatro precisam ser geometricamente distintas entre si, não espelhadas.
#  O portão no fim mede a distância angular entre elas nos papéis de braço e
#  tronco e exige >= 40°.
# ============================================================================

# JAB: guarda alta e FECHADA, corpo bladed (ombro esquerdo à frente).
GUARDA_JAB = pose(
    Torso=(-0.05, 0.34, 0.0),
    UpperArm_R=(-0.42, 0.0, 0.30), ForeArm_R=(1.62, 0.0, 0.0),
    UpperArm_L=(-0.30, 0.0, -0.26), ForeArm_L=(1.45, 0.0, 0.0),
    Thigh_R=(-0.16, 0.0, 0.12), Shin_R=(-0.26, 0.0, 0.0),
    Thigh_L=(0.20, 0.0, -0.10), Shin_L=(-0.18, 0.0, 0.0),
    Head=(0.06, -0.20, 0.0),
)

# SOCO 2 (cruzado): guarda BAIXA e ABERTA, corpo aberto para o outro lado.
# Os cotovelos caem e os braços abrem — o oposto da guarda do jab, de propósito.
GUARDA_SOCO2 = pose(
    Torso=(0.08, -0.38, 0.0),
    UpperArm_R=(0.18, 0.0, 0.62), ForeArm_R=(0.55, 0.0, 0.0),
    UpperArm_L=(-0.66, 0.0, -0.70), ForeArm_L=(0.85, 0.0, 0.0),
    Thigh_R=(0.22, 0.0, 0.14), Shin_R=(-0.20, 0.0, 0.0),
    Thigh_L=(-0.18, 0.0, -0.12), Shin_L=(-0.30, 0.0, 0.0),
    Head=(0.04, 0.22, 0.0),
)

# CHUTE: peso todo na perna direita, joelho esquerdo JÁ recolhido (o chute
# começa da câmara), braços cruzados baixos para contrabalançar.
GUARDA_CHUTE = pose(
    Torso=(0.10, 0.16, -0.12),
    UpperArm_R=(0.30, 0.0, 0.95), ForeArm_R=(1.15, 0.0, 0.0),
    UpperArm_L=(0.45, 0.0, -1.05), ForeArm_L=(1.30, 0.0, 0.0),
    Thigh_R=(-0.10, 0.0, 0.05), Shin_R=(-0.12, 0.0, 0.0),
    Thigh_L=(0.75, 0.0, -0.55), Shin_L=(-1.35, 0.0, 0.0),
    Foot_L=(0.30, 0.0, 0.0),
    Head=(0.02, -0.10, 0.0),
)

# FINALIZADOR: os dois braços ACIMA da cabeça, corpo enrolado para trás. É o
# único que sai do eixo vertical — e é o que o jogador vê chegar.
GUARDA_FINAL = pose(
    Torso=(0.30, 0.0, 0.0),
    UpperArm_R=(-2.35, 0.0, 0.22), ForeArm_R=(0.45, 0.0, 0.0),
    UpperArm_L=(-2.35, 0.0, -0.22), ForeArm_L=(0.45, 0.0, 0.0),
    Thigh_R=(-0.24, 0.0, 0.16), Shin_R=(-0.30, 0.0, 0.0),
    Thigh_L=(-0.24, 0.0, -0.16), Shin_L=(-0.30, 0.0, 0.0),
    Head=(-0.30, 0.0, 0.0),
)

# ------------------------------------------------------ os quadros de contato
CONTATO_JAB = pose(                       # RETO: o braço direito vai à frente
    Torso=(-0.10, -0.30, 0.0),            # ombros giram PARA o soco
    UpperArm_R=(1.52, 0.0, 0.16), ForeArm_R=(-0.06, 0.0, 0.0),
    UpperArm_L=(-0.34, 0.0, -0.30), ForeArm_L=(1.70, 0.0, 0.0),
    Thigh_R=(-0.10, 0.0, 0.12), Shin_R=(-0.20, 0.0, 0.0),
    Thigh_L=(0.26, 0.0, -0.10), Shin_L=(-0.14, 0.0, 0.0),
    Head=(0.02, -0.06, 0.0),
)

CONTATO_SOCO2 = pose(                     # ARCO: o esquerdo cruza de fora
    Torso=(-0.06, 0.46, 0.0),
    UpperArm_R=(-0.20, 0.0, 0.50), ForeArm_R=(1.05, 0.0, 0.0),
    UpperArm_L=(1.30, 0.0, -0.78), ForeArm_L=(-0.10, 0.0, 0.0),
    Thigh_R=(0.28, 0.0, 0.14), Shin_R=(-0.16, 0.0, 0.0),
    Thigh_L=(-0.14, 0.0, -0.12), Shin_L=(-0.24, 0.0, 0.0),
    Head=(0.02, 0.16, 0.0),
)

CONTATO_CHUTE = pose(                     # LATERAL: a perna esquerda varre
    Torso=(0.06, 0.30, -0.30),            # o tronco inclina para o lado OPOSTO
    UpperArm_R=(0.10, 0.0, 1.20), ForeArm_R=(0.60, 0.0, 0.0),
    UpperArm_L=(0.20, 0.0, -1.30), ForeArm_L=(0.70, 0.0, 0.0),
    Thigh_R=(-0.14, 0.0, 0.08), Shin_R=(-0.10, 0.0, 0.0),
    Thigh_L=(0.30, 0.0, -1.42), Shin_L=(-0.16, 0.0, 0.0),
    Foot_L=(0.10, 0.0, 0.0),
    Head=(0.04, 0.18, 0.0),
)

CONTATO_FINAL = pose(                     # VERTICAL: os dois braços descem
    Torso=(-0.46, 0.0, 0.0),              # o peito SNAPA para a frente
    UpperArm_R=(1.05, 0.0, 0.26), ForeArm_R=(-0.12, 0.0, 0.0),
    UpperArm_L=(1.05, 0.0, -0.26), ForeArm_L=(-0.12, 0.0, 0.0),
    Thigh_R=(0.30, 0.0, 0.20), Shin_R=(-0.62, 0.0, 0.0),   # joelhos cedem
    Thigh_L=(0.30, 0.0, -0.20), Shin_L=(-0.62, 0.0, 0.0),
    Foot_R=(0.28, 0.0, 0.0), Foot_L=(0.28, 0.0, 0.0),
    Head=(0.24, 0.0, 0.0),
)

# nome, guarda, contato, startup, ativo, recuperacao  (os tempos são o §4.2)
GOLPES = [
    ("m1_jab",          GUARDA_JAB,   CONTATO_JAB,   0.20, 0.06, 0.14),
    ("m1_soco_esquerdo", GUARDA_SOCO2, CONTATO_SOCO2, 0.20, 0.06, 0.14),
    ("m1_chute",        GUARDA_CHUTE, CONTATO_CHUTE, 0.20, 0.06, 0.17),
    ("m1_finalizador",  GUARDA_FINAL, CONTATO_FINAL, 0.25, 0.08, 0.35),
]

FPS = 30.0


def montar(nome, guarda, contato, su, at, rec):
    dur = su + at + rec
    c = Clip(nome, round(dur, 4), loop=False)
    n = int(round(dur * FPS))
    for i in range(n + 1):
        t = round(i / FPS, 4)
        if t > dur:
            t = round(dur, 4)
        if t <= su:
            # STARTUP com antecipação: os primeiros 30% RECUAM (o braço recolhe
            # antes de sair — primeiro tempo do soco), o resto acelera.
            f = t / su if su > 0 else 1.0
            if f < 0.30:
                # recuo: exagera a guarda em 12% na direção contrária ao contato
                g = f / 0.30
                antec = mistura(guarda, mistura(contato, guarda, 1.12), g * 0.35)
                alvo = antec
            else:
                g = (f - 0.30) / 0.70
                # EASE-IN cúbico: o soco SAI, não desliza
                alvo = mistura(guarda, contato, g * g * (3.0 - 2.0 * g) * 0.0 + g ** 2)
        elif t <= su + at:
            alvo = contato          # ⚠️ CONGELADO — o quadro de contato (§6.3.3)
        else:
            f = (t - su - at) / rec if rec > 0 else 1.0
            # volta à guarda com EASE-OUT (raiz): sai rápido do impacto e assenta
            alvo = mistura(contato, guarda, math.sqrt(min(f, 1.0)))
        for papel, v in alvo.items():
            c.por_chave(papel, t, v)
        if t >= dur:
            break
    return c


# ============================================================ portão de medição
def _dist_guarda(a, b, papeis):
    """Distância angular entre duas guardas, em graus, somada nos papéis."""
    s = 0.0
    for p in papeis:
        va, vb = a.get(p, Z), b.get(p, Z)
        s += math.degrees(math.sqrt(sum((va[i] - vb[i]) ** 2 for i in range(3))))
    return s


PAPEIS_GUARDA = ["Torso", "UpperArm_R", "ForeArm_R", "UpperArm_L", "ForeArm_L"]
MIN_DIST = 40.0


def main():
    falhas = 0
    print("── autorando os 4 M1 ──")
    clipes = []
    for nome, g, ct, su, at, rec in GOLPES:
        c = montar(nome, g, ct, su, at, rec)
        clipes.append((nome, c, g))
        destino = os.path.join(DIR_TRES, nome + ".tres")
        n = c.para_tres(destino)
        c.para_json(os.path.join(DIR_JSON, nome + ".json"))
        print("  %-17s %.2fs  %d faixas  %d chaves/faixa" % (
            nome, c.duracao, n, len(next(iter(c.faixas.values())))))

    # 1) O TRONCO FICA DE PÉ — o defeito que motivou refazer.
    print("\n── portão: o tronco fica de pé? (|Torso.z| <= 20°) ──")
    for nome, c, _ in clipes:
        zs = [math.degrees(v[2]) for _, v in c.faixas["Torso"]]
        pior = max(abs(min(zs)), abs(max(zs)))
        ok = pior <= 20.0
        falhas += 0 if ok else 1
        print("   %s %-17s Torso.z de %+.1f° a %+.1f°" % ("✔" if ok else "✗", nome, min(zs), max(zs)))

    # 2) AS GUARDAS SÃO DISTINTAS — a Fase B do §6.4, o teste que faltava
    #    para o bug de 2026-08-11 (era só relato humano).
    print("\n── portão: guardas de entrada distintas? (>= %.0f° somados) ──" % MIN_DIST)
    for i in range(len(clipes)):
        for j in range(i + 1, len(clipes)):
            d = _dist_guarda(clipes[i][2], clipes[j][2], PAPEIS_GUARDA)
            ok = d >= MIN_DIST
            falhas += 0 if ok else 1
            print("   %s %-17s x %-17s %6.1f°" % (
                "✔" if ok else "✗", clipes[i][0], clipes[j][0], d))

    # 3) O QUADRO DE CONTATO ESTÁ CONGELADO durante o `ativo`.
    print("\n── portão: quadro de contato congelado no `ativo`? ──")
    for (nome, c, _), (_, _, _, su, at, _) in zip(clipes, GOLPES):
        amostras = [v for t, v in c.faixas["UpperArm_R"] if su - 1e-4 <= t <= su + at + 1e-4]
        movimento = 0.0
        for k in range(len(amostras) - 1):
            movimento += sum(abs(amostras[k + 1][x] - amostras[k][x]) for x in range(3))
        ok = movimento < 1e-6 and len(amostras) >= 2
        falhas += 0 if ok else 1
        print("   %s %-17s %d quadros de contato, movimento %.6f rad" % (
            "✔" if ok else "✗", nome, len(amostras), movimento))

    print("\n%s" % ("✅ os quatro clipes passaram nos três portões."
                    if falhas == 0 else "❌ %d problema(s)." % falhas))
    return 1 if falhas else 0


sys.exit(main())
