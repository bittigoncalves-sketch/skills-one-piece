"""Marcadores de junta e derivação do rig — o método do Meshy.

No Meshy você posiciona 7 tipos de marcador sobre o modelo (queixo, ombros,
cotovelos, pulsos, virilha, joelhos, tornozelos) e ele deriva o esqueleto. Aqui
é o mesmo: esses 12 pontos são exatamente o que define os 13 papéis do rig do
jogo, com os comprimentos REAIS daquele personagem — em vez das proporções
chutadas do rig canônico.

Convenção de saída (a mesma do jogo, quebrar desalinha do runtime):
  * membro pende em −Y e `rest` fica em zero, como no rig voxel — assim as 28
    animações do Mixamo valem sem retoque
  * `pos` é offset LOCAL ao papel-pai
"""

# (chave, rótulo, par?, cor) — a ordem é a que aparece na lista do editor.
TIPOS = [
    ("queixo",    "Queixo",     False, "#38bdf8"),
    ("ombro",     "Ombros",     True,  "#4ade80"),
    ("cotovelo",  "Cotovelos",  True,  "#4ade80"),
    ("pulso",     "Pulsos",     True,  "#e879f9"),
    ("virilha",   "Virilha",    False, "#e5e7eb"),
    ("joelho",    "Joelhos",    True,  "#fb923c"),
    ("tornozelo", "Tornozelos", True,  "#fb923c"),
]

# Ordem de preenchimento: de cima para baixo, A antes de B.
def slots():
    out = []
    for chave, rotulo, par, cor in TIPOS:
        if par:
            out.append((chave + "_L", rotulo + " A", cor))
            out.append((chave + "_R", rotulo + " B", cor))
        else:
            out.append((chave, rotulo, cor))
    return out


SLOTS = slots()
COR = {k: c for k, _r, c in SLOTS}


def espelhar(chave):
    """Par simétrico de um slot, ou None se ele for único."""
    if chave.endswith("_L"):
        return chave[:-2] + "_R"
    if chave.endswith("_R"):
        return chave[:-2] + "_L"
    return None


def completo(marcas):
    return [k for k, _r, _c in SLOTS if k not in marcas]


# --------------------------------------------------------------- derivação
def derivar_rig(marcas, malha, nome="novo"):
    """Constrói os 13 papéis a partir dos 12 marcadores.

    Levanta ValueError listando o que falta — é melhor recusar do que gerar um
    esqueleto pela metade e só descobrir na hora de animar.
    """
    faltando = completo(marcas)
    if faltando:
        raise ValueError("faltam marcadores: " + ", ".join(faltando))

    m = {k: tuple(v) for k, v in marcas.items()}
    virilha = m["virilha"]
    ombro_meio = _meio(m["ombro_L"], m["ombro_R"])

    def local(ponto, origem):
        return [ponto[0] - origem[0], ponto[1] - origem[1], ponto[2] - origem[2]]

    # Quadril de cada perna: a virilha é um ponto só, então o quadril fica entre
    # ela e o joelho — senão as duas coxas nasceriam no mesmo lugar.
    quadril = {}
    for lado in ("L", "R"):
        j = m["joelho_" + lado]
        quadril[lado] = (virilha[0] + (j[0] - virilha[0]) * 0.55, virilha[1], virilha[2])

    papeis = {}

    def por(papel, pai, pos, comprimento, espessura, tipo="membro"):
        if tipo == "torso":
            caixa = {"size": [espessura * 2.0, comprimento, espessura * 1.2],
                     "offset": [0.0, comprimento * 0.5, 0.0]}
        elif tipo == "cabeca":
            caixa = {"size": [espessura * 2.0, comprimento, espessura * 2.0],
                     "offset": [0.0, comprimento * 0.5, 0.0]}
        elif tipo == "pe":
            caixa = {"size": [espessura * 1.6, comprimento * 0.55, comprimento * 2.0],
                     "offset": [0.0, -comprimento * 0.3, -comprimento * 0.6]}
        else:
            caixa = {"size": [espessura * 2.0, comprimento, espessura * 2.0],
                     "offset": [0.0, -comprimento * 0.5, 0.0]}
        papeis[papel] = {"parent": pai, "pos": pos, "rest": [0.0, 0.0, 0.0], "box": caixa}

    tronco_alt = max(ombro_meio[1] - virilha[1], 1e-3)
    r_tronco = malha.raio_em(virilha[1] + tronco_alt * 0.5) if malha else tronco_alt * 0.35

    # tronco na virilha, subindo até a linha dos ombros
    por("Torso", "", list(virilha), tronco_alt, r_tronco * 0.9, "torso")

    # pescoço e cabeça
    pescoco_y = ombro_meio[1] + (m["queixo"][1] - ombro_meio[1]) * 0.35
    por("Neck", "Torso", local((ombro_meio[0], pescoco_y, ombro_meio[2]), virilha),
        max(m["queixo"][1] - pescoco_y, 1e-3) * 0.6,
        (malha.raio_em(pescoco_y) * 0.4) if malha else tronco_alt * 0.1)
    cabeca_alt = max((malha.tamanho[1] + malha.base[1]) - m["queixo"][1], 1e-3) if malha \
        else tronco_alt * 0.4
    por("Head", "Torso", local(m["queixo"], virilha), cabeca_alt,
        (malha.raio_em(m["queixo"][1] + cabeca_alt * 0.5) * 0.9) if malha else cabeca_alt * 0.4,
        "cabeca")

    for lado in ("L", "R"):
        ombro = m["ombro_" + lado]
        cotovelo = m["cotovelo_" + lado]
        pulso = m["pulso_" + lado]
        joelho = m["joelho_" + lado]
        tornozelo = m["tornozelo_" + lado]

        braco = _dist(ombro, cotovelo)
        antebraco = _dist(cotovelo, pulso)
        coxa = _dist(quadril[lado], joelho)
        canela = _dist(joelho, tornozelo)
        pe_alt = max(tornozelo[1] - (malha.base[1] if malha else 0.0), canela * 0.25)

        r_braco = (malha.raio_em(ombro[1] - braco * 0.5) * 0.28) if malha else braco * 0.22
        r_perna = (malha.raio_em(quadril[lado][1] - coxa * 0.5) * 0.32) if malha else coxa * 0.22

        por("UpperArm_" + lado, "Torso", local(ombro, virilha), braco, r_braco)
        por("ForeArm_" + lado, "UpperArm_" + lado, local(cotovelo, ombro), antebraco, r_braco * 0.85)
        por("Thigh_" + lado, "Torso", local(quadril[lado], virilha), coxa, r_perna)
        por("Shin_" + lado, "Thigh_" + lado, local(joelho, quadril[lado]), canela, r_perna * 0.85)
        por("Foot_" + lado, "Shin_" + lado, local(tornozelo, joelho), pe_alt, r_perna * 0.8, "pe")

    ordem = ["Torso", "Neck", "Head",
             "UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R",
             "Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R"]
    coxa_m = _dist(quadril["L"], m["joelho_L"])
    canela_m = _dist(m["joelho_L"], m["tornozelo_L"])
    return {
        "character": nome,
        "skinned": False,
        "from_markers": True,
        "metrics": {
            "thigh_len": coxa_m,
            "shin_len": canela_m,
            "leg_len": coxa_m + canela_m,
            "upper_arm": _dist(m["ombro_L"], m["cotovelo_L"]),
        },
        "order": ordem,
        "roles": papeis,
        "markers": {k: list(v) for k, v in m.items()},
    }


def _dist(a, b):
    return max(((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5, 1e-4)


def _meio(a, b):
    return ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5)


# ------------------------------------------------------- palpite inicial
def sugerir(malha):
    """Chute inicial pelas proporções humanas, para você só ajustar.

    Colocar 12 marcadores do zero é tedioso; partir de um palpite razoável e
    corrigir é bem mais rápido. As frações são de proporção humana média.
    """
    x0 = malha.centro_x
    y0 = malha.base[1]
    h = malha.tamanho[1]
    z = malha.base[2] + malha.tamanho[2] * 0.5
    larg = malha.tamanho[0]
    return {
        "queixo":      (x0, y0 + h * 0.86, z),
        "ombro_L":     (x0 - larg * 0.17, y0 + h * 0.81, z),
        "ombro_R":     (x0 + larg * 0.17, y0 + h * 0.81, z),
        "cotovelo_L":  (x0 - larg * 0.21, y0 + h * 0.63, z),
        "cotovelo_R":  (x0 + larg * 0.21, y0 + h * 0.63, z),
        "pulso_L":     (x0 - larg * 0.24, y0 + h * 0.47, z),
        "pulso_R":     (x0 + larg * 0.24, y0 + h * 0.47, z),
        "virilha":     (x0, y0 + h * 0.50, z),
        "joelho_L":    (x0 - larg * 0.09, y0 + h * 0.27, z),
        "joelho_R":    (x0 + larg * 0.09, y0 + h * 0.27, z),
        "tornozelo_L": (x0 - larg * 0.09, y0 + h * 0.04, z),
        "tornozelo_R": (x0 + larg * 0.09, y0 + h * 0.04, z),
    }
