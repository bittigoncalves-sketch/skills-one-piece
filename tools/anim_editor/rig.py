"""Rig de 13 papéis, cinemática direta e caixas — sem dependência externa.

Só a biblioteca padrão: a máquina não tem numpy nem lib 3D, e o editor precisa
abrir em qualquer lugar. Para 13 ossos, Python puro dá conta de sobra.

Convenções (as MESMAS do jogo — mudar aqui desalinha do runtime):
  * frente = -Z
  * membro pende em -Y; girar +X leva a ponta para a frente
  * rotação é Euler XYZ, aplicada na ordem Z*Y*X (igual ao Basis do Godot)
"""

import json
import math
import os

# Os 13 papéis canônicos. Espelha BodyScanner.ROLES.
PAPEIS = [
    "Torso", "Neck", "Head",
    "UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R",
    "Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R",
]

# Hierarquia canônica, usada quando o personagem NÃO tem ossos e o editor
# precisa criá-los. Espelha RigContrato.PAI (src/anim/RigContrato.gd).
#
# ⚠️ "Head" é filho de "Neck", não de "Torso" — é a árvore real do base.scn e do
# buggy.scn. Declarar Torso aqui fazia a rotação do pescoço entrar DUAS VEZES na
# cabeça (até 64° de rotação parasita). Ver docs/AUDITORIA_ANIMACAO.md, achado 7.
PAI_CANONICO = {
    "Torso": "", "Neck": "Torso", "Head": "Neck",
    "UpperArm_L": "Torso", "ForeArm_L": "UpperArm_L",
    "UpperArm_R": "Torso", "ForeArm_R": "UpperArm_R",
    "Thigh_L": "Torso", "Shin_L": "Thigh_L", "Foot_L": "Shin_L",
    "Thigh_R": "Torso", "Shin_R": "Thigh_R", "Foot_R": "Shin_R",
}


# --------------------------------------------------------------- álgebra 3x3
def mat_ident():
    return (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)


def mat_mul(a, b):
    return tuple(
        a[r * 3 + 0] * b[0 * 3 + c] + a[r * 3 + 1] * b[1 * 3 + c] + a[r * 3 + 2] * b[2 * 3 + c]
        for r in range(3) for c in range(3)
    )


def mat_vec(m, v):
    return (
        m[0] * v[0] + m[1] * v[1] + m[2] * v[2],
        m[3] * v[0] + m[4] * v[1] + m[5] * v[2],
        m[6] * v[0] + m[7] * v[1] + m[8] * v[2],
    )


def euler_para_mat(e):
    """Euler XYZ na ordem do Godot: Basis = Rz * Ry * Rx."""
    sx, cx = math.sin(e[0]), math.cos(e[0])
    sy, cy = math.sin(e[1]), math.cos(e[1])
    sz, cz = math.sin(e[2]), math.cos(e[2])
    rx = (1, 0, 0, 0, cx, -sx, 0, sx, cx)
    ry = (cy, 0, sy, 0, 1, 0, -sy, 0, cy)
    rz = (cz, -sz, 0, sz, cz, 0, 0, 0, 1)
    return mat_mul(mat_mul(rz, ry), rx)


# ------------------------------------------------------------------- o rig
class Rig:
    """Perfil de um personagem: papéis, hierarquia, poses de repouso e caixas."""

    def __init__(self, dados):
        self.personagem = dados.get("character", "?")
        self.skinnado = bool(dados.get("skinned", False))
        self.metricas = dados.get("metrics", {})
        self.papeis = dados["roles"]
        self.ordem = dados.get("order") or list(self.papeis.keys())

    # Hierarquia REAL deste personagem (papel -> pai). É ela, e não a canônica,
    # que monta o caminho da faixa na exportação — um modelo pode ter o pescoço
    # e outro não.
    @property
    def pais(self):
        return {p: self.papeis[p].get("parent", "") for p in self.papeis}

    # -- carga ------------------------------------------------------------
    @staticmethod
    def de_arquivo(caminho):
        with open(caminho, encoding="utf-8") as f:
            return Rig(json.load(f))

    @staticmethod
    def canonico(nome="novo", perna=0.60, braco=0.30):
        """Cria os 13 ossos do zero, para personagem que ainda não tem rig.

        Proporções derivadas do rig voxel do jogo (VoxelMeshes._build_skeleton),
        para o esqueleto novo já nascer compatível com as animações existentes.
        """
        coxa = perna * 0.5
        canela = perna * 0.5
        ua = braco
        papeis = {
            "Torso":      _osso("",           (0, 0.98, 0),        (0.50, 0.60, 0.34), (0, 0, 0)),
            "Neck":       _osso("Torso",      (0, 0.34, 0),        (0.16, 0.10, 0.16), (0, 0.05, 0)),
            # (0, 0.20, 0) = os 0,54 de antes MENOS os 0,34 do Neck: a cabeça
            # passou a pendurar no pescoço, então a posição vira relativa a ele.
            "Head":       _osso("Neck",       (0, 0.20, 0),        (0.42, 0.42, 0.40), (0, 0, 0)),
            "UpperArm_L": _osso("Torso",      (-0.32, 0.20, 0),    (0.16, ua, 0.16),   (0, -ua / 2, 0)),
            "ForeArm_L":  _osso("UpperArm_L", (0, -ua, 0),         (0.145, ua, 0.145), (0, -ua / 2, 0)),
            "UpperArm_R": _osso("Torso",      (0.32, 0.20, 0),     (0.16, ua, 0.16),   (0, -ua / 2, 0)),
            "ForeArm_R":  _osso("UpperArm_R", (0, -ua, 0),         (0.145, ua, 0.145), (0, -ua / 2, 0)),
            "Thigh_L":    _osso("Torso",      (-0.14, -0.32, 0),   (0.19, coxa, 0.19), (0, -coxa / 2, 0)),
            "Shin_L":     _osso("Thigh_L",    (0, -coxa, 0),       (0.17, canela, 0.17), (0, -canela / 2, 0)),
            "Foot_L":     _osso("Shin_L",     (0, -canela, 0),     (0.19, 0.11, 0.30), (0, -0.05, -0.06)),
            "Thigh_R":    _osso("Torso",      (0.14, -0.32, 0),    (0.19, coxa, 0.19), (0, -coxa / 2, 0)),
            "Shin_R":     _osso("Thigh_R",    (0, -coxa, 0),       (0.17, canela, 0.17), (0, -canela / 2, 0)),
            "Foot_R":     _osso("Shin_R",     (0, -canela, 0),     (0.19, 0.11, 0.30), (0, -0.05, -0.06)),
        }
        return Rig({
            "character": nome,
            "skinned": False,
            "metrics": {"thigh_len": coxa, "shin_len": canela, "leg_len": perna, "upper_arm": ua},
            "order": PAPEIS,
            "roles": papeis,
        })

    # -- cinemática -------------------------------------------------------
    def pose(self, rotacoes):
        """Resolve a pose. Devolve {papel: (matriz_global, posicao_global)}.

        `rotacoes` mapeia papel -> (x, y, z) em radianos, somado à pose de
        repouso — mesma semântica do ProceduralAnimator.
        """
        out = {}
        for papel in self.ordem:
            info = self.papeis[papel]
            pai = info.get("parent", "")
            rest = info.get("rest", (0, 0, 0))
            extra = rotacoes.get(papel, (0.0, 0.0, 0.0))
            local = euler_para_mat((rest[0] + extra[0], rest[1] + extra[1], rest[2] + extra[2]))
            pos_local = tuple(info.get("pos", (0, 0, 0)))
            if pai and pai in out:
                m_pai, p_pai = out[pai]
                m = mat_mul(m_pai, local)
                p = tuple(p_pai[i] + mat_vec(m_pai, pos_local)[i] for i in range(3))
            else:
                m = local
                p = pos_local
            out[papel] = (m, p)
        return out

    def caixas(self, pose):
        """Cantos das caixas de cada osso, já no espaço do mundo.

        Devolve [(papel, [8 vértices], profundidade_media)] para o renderizador
        ordenar por profundidade.
        """
        saida = []
        for papel, (m, p) in pose.items():
            box = self.papeis[papel].get("box")
            if not box:
                continue
            sx, sy, sz = [c * 0.5 for c in box["size"]]
            ox, oy, oz = box.get("offset", (0, 0, 0))
            cantos = []
            for dx in (-sx, sx):
                for dy in (-sy, sy):
                    for dz in (-sz, sz):
                        v = mat_vec(m, (ox + dx, oy + dy, oz + dz))
                        cantos.append((p[0] + v[0], p[1] + v[1], p[2] + v[2]))
            saida.append((papel, cantos))
        return saida


def caminho(papel, pais=None):
    """"Head" -> "Torso/Neck/Head". Espelha RigContrato.caminho().

    O caminho da faixa TEM que ser hierárquico: é o que faz o clipe resolver na
    árvore do personagem e, por consequência, exportar para glTF/Blender. Com o
    caminho plano antigo ("Head:rotation") 12 das 13 faixas apontavam para lugar
    nenhum. Ver docs/AUDITORIA_ANIMACAO.md, achado 1.
    """
    tabela = pais if pais is not None else PAI_CANONICO
    partes = [papel]
    p = tabela.get(papel, "")
    while p:
        partes.insert(0, p)
        p = tabela.get(p, "")
    return "/".join(partes)


def _osso(pai, pos, size, offset):
    return {
        "parent": pai,
        "pos": list(pos),
        "rest": [0.0, 0.0, 0.0],
        "box": {"size": list(size), "offset": list(offset)},
    }


def listar_rigs(pasta):
    idx = os.path.join(pasta, "index.json")
    if os.path.exists(idx):
        with open(idx, encoding="utf-8") as f:
            return json.load(f).get("characters", [])
    return sorted(
        n[:-5] for n in os.listdir(pasta)
        if n.endswith(".json") and n != "index.json"
    )
