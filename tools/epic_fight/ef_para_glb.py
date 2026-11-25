#!/usr/bin/env python3
"""Epic Fight (animação .json do biped) -> .glb com esqueleto de nomes Mixamo.

Por que glb com nomes Mixamo: o `tools/bake_mixamo.gd` já paga as armadilhas deste projeto (euler contínuo,
repouso dos braços, giro do quadril, abortar com 0 ossos) e lê qualquer glTF cujo esqueleto tenha os nomes do
`MAP`. Em vez de um segundo baker, o Epic Fight vira "um Mixamo a mais".

Formato do EF (medido em biped.json e sword_auto1.json, 10/11/2026):
  * Z para cima, em unidades do modelo (quadril 0,764); o personagem olha para +Y e o lado "R" fica em +X.
  * `transform` de cada junta = matriz 4x4 LOCAL (linha a linha) relativa ao pai, ABSOLUTA, no mesmo formato da
    matriz de repouso da hierarquia; cada junta tem os próprios tempos (segundos).
  * 20 juntas. Não há osso de pé: o `Leg_*` é o joelho. `Hand_*` é o antebraço (fica no cotovelo) e `Tool_*` é a
    mão. `Knee_*`/`Elbow_*` são auxiliares de malha.

Mapeamento (EF -> Mixamo): Root=Hips, Torso=Spine, Chest=Spine1, Head, Shoulder=Shoulder, Arm=Arm,
Hand=ForeArm, Tool=Hand, Thigh=UpLeg, Leg=Leg. O pé é sintético (filho do joelho, sem animação).
Saída LOCAL, fora do git (assets All Rights Reserved).

Uso: ef_para_glb.py <saida_dir> [nome ...]   (sem nomes: todos de biped/combat, living e skill)
"""
import json, math, struct, sys, pathlib

RAIZ = pathlib.Path(__file__).resolve().parents[2]
EF = RAIZ / "art_src/epic_fight_local/assets/epicfight/animmodels"

NOMES = {
    "Root": "mixamorig_Hips", "Torso": "mixamorig_Spine", "Chest": "mixamorig_Spine1", "Head": "mixamorig_Head",
    "Shoulder_R": "mixamorig_RightShoulder", "Arm_R": "mixamorig_RightArm", "Hand_R": "mixamorig_RightForeArm",
    "Tool_R": "mixamorig_RightHand", "Shoulder_L": "mixamorig_LeftShoulder", "Arm_L": "mixamorig_LeftArm",
    "Hand_L": "mixamorig_LeftForeArm", "Tool_L": "mixamorig_LeftHand",
    "Thigh_R": "mixamorig_RightUpLeg", "Leg_R": "mixamorig_RightLeg", "Thigh_L": "mixamorig_LeftUpLeg",
    "Leg_L": "mixamorig_LeftLeg", "Knee_R": "EF_Knee_R", "Knee_L": "EF_Knee_L",
    "Elbow_R": "EF_Elbow_R", "Elbow_L": "EF_Elbow_L",
}
# EF (x, y, z) Z-up, olhando +Y  ->  glTF Y-up olhando +Z, lado R em -X:  x' = -x, y' = z, z' = y   (det = +1)
EF_PARA_GLTF = [[-1, 0, 0], [0, 0, 1], [0, 1, 0]]


def mat(t):
    return [t[0:4], t[4:8], t[8:12], t[12:16]]


def mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def inv_rigido(m):
    r = [[m[j][i] for j in range(3)] for i in range(3)]          # transposta (ortonormal)
    p = [m[i][3] for i in range(3)]
    ip = [-sum(r[i][k] * p[k] for k in range(3)) for i in range(3)]
    return [r[0] + [ip[0]], r[1] + [ip[1]], r[2] + [ip[2]], [0, 0, 0, 1]]


def quat(m):
    """Matriz de rotação (3x3 ou 4x4 normalizada por colunas) -> (x, y, z, w) glTF."""
    cols = []
    for c in range(3):
        n = math.sqrt(sum(m[r][c] ** 2 for r in range(3))) or 1.0
        cols.append([m[r][c] / n for r in range(3)])
    r = [[cols[c][i] for c in range(3)] for i in range(3)]
    tr = r[0][0] + r[1][1] + r[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        q = ((r[2][1] - r[1][2]) / s, (r[0][2] - r[2][0]) / s, (r[1][0] - r[0][1]) / s, 0.25 * s)
    elif r[0][0] > r[1][1] and r[0][0] > r[2][2]:
        s = math.sqrt(1 + r[0][0] - r[1][1] - r[2][2]) * 2
        q = (0.25 * s, (r[0][1] + r[1][0]) / s, (r[0][2] + r[2][0]) / s, (r[2][1] - r[1][2]) / s)
    elif r[1][1] > r[2][2]:
        s = math.sqrt(1 + r[1][1] - r[0][0] - r[2][2]) * 2
        q = ((r[0][1] + r[1][0]) / s, 0.25 * s, (r[1][2] + r[2][1]) / s, (r[0][2] - r[2][0]) / s)
    else:
        s = math.sqrt(1 + r[2][2] - r[0][0] - r[1][1]) * 2
        q = ((r[0][2] + r[2][0]) / s, (r[1][2] + r[2][1]) / s, 0.25 * s, (r[1][0] - r[0][1]) / s)
    n = math.sqrt(sum(v * v for v in q))
    return tuple(v / n for v in q)


def continuo(qs):
    """Mesmo hemisfério da chave anterior (evita a volta longa na interpolação)."""
    out = [qs[0]]
    for q in qs[1:]:
        p = out[-1]
        out.append(tuple(-v for v in q) if sum(a * b for a, b in zip(p, q)) < 0 else q)
    return out


def hierarquia():
    d = json.load(open(EF / "entity/biped.json"))
    return d["armature"]["hierarchy"][0]


def construir(nome_clipe, anim_json, saida):
    raiz = hierarquia()
    nodes, anim_por_junta = [], {x["name"]: x for x in anim_json["animation"]}
    indice = {}

    def novo(n, pai_idx):
        m = mat(n["transform"])
        no = {"name": NOMES.get(n["name"], n["name"]), "translation": [m[0][3], m[1][3], m[2][3]], "rotation": list(quat(m))}
        i = len(nodes)
        nodes.append(no)
        indice[n["name"]] = i
        if pai_idx is not None:
            nodes[pai_idx].setdefault("children", []).append(i)
        for c in n.get("children", []):
            novo(c, i)
        if n["name"].startswith("Leg_"):       # pé sintético no chão, sem animação
            lado = n["name"][-1]
            pe = len(nodes)
            nodes.append({"name": "mixamorig_%sFoot" % ("Right" if lado == "R" else "Left"),
                          "translation": [0.0, 0.0, -0.386], "rotation": [0, 0, 0, 1]})
            nodes[i].setdefault("children", []).append(pe)
            indice["Foot_" + lado] = pe

    novo(raiz, None)
    # nó Armature: leva EF (Z-up) para glTF (Y-up, olhando +Z)
    a = quat([EF_PARA_GLTF[0] + [0], EF_PARA_GLTF[1] + [0], EF_PARA_GLTF[2] + [0]])
    arm_idx = len(nodes)
    nodes.append({"name": "Armature", "rotation": list(a), "children": [0]})

    # mundo de cada junta (no espaço do Armature) para a inverseBindMatrix
    def mundo(i, P, acc):
        n = nodes[i]
        t, q = n["translation"], n["rotation"]
        x, y, z, w = q
        R = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), t[0]],
             [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), t[1]],
             [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), t[2]], [0, 0, 0, 1]]
        W = mm(P, R)
        acc[i] = W
        for c in n.get("children", []):
            mundo(c, W, acc)
    mundos = {}
    mundo(0, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]], mundos)
    juntas = list(range(len(nodes) - 1))

    buf = bytearray()
    views, accs = [], []

    def add(dados, comp, tipo, count, extra=None):
        while len(buf) % 4:
            buf.append(0)
        views.append({"buffer": 0, "byteOffset": len(buf), "byteLength": len(dados)})
        buf.extend(dados)
        a = {"bufferView": len(views) - 1, "componentType": comp, "count": count, "type": tipo}
        if extra:
            a.update(extra)
        accs.append(a)
        return len(accs) - 1

    ibm = bytearray()
    for i in juntas:
        m = inv_rigido(mundos[i])                          # glTF guarda coluna-maior
        for c in range(4):
            for r in range(4):
                ibm += struct.pack("<f", m[r][c])
    ibm_acc = add(bytes(ibm), 5126, "MAT4", len(juntas))

    canais, amostras = [], []
    for nome_ef, x in anim_por_junta.items():
        i = indice.get(nome_ef)
        if i is None:
            continue
        ts = x["time"]
        ms = [mat(t) for t in x["transform"]]
        t_acc = add(struct.pack("<%df" % len(ts), *ts), 5126, "SCALAR", len(ts),
                    {"min": [min(ts)], "max": [max(ts)]})
        qs = continuo([quat(m) for m in ms])
        r_acc = add(b"".join(struct.pack("<4f", *q) for q in qs), 5126, "VEC4", len(qs))
        tr_acc = add(b"".join(struct.pack("<3f", m[0][3], m[1][3], m[2][3]) for m in ms), 5126, "VEC3", len(ms))
        for caminho, acc in (("rotation", r_acc), ("translation", tr_acc)):
            amostras.append({"input": t_acc, "output": acc, "interpolation": "LINEAR"})
            canais.append({"sampler": len(amostras) - 1, "target": {"node": i, "path": caminho}})

    gltf = {
        "asset": {"version": "2.0", "generator": "tools/epic_fight/ef_para_glb.py"},
        "scene": 0, "scenes": [{"nodes": [arm_idx]}], "nodes": nodes,
        "skins": [{"joints": juntas, "inverseBindMatrices": ibm_acc, "skeleton": 0}],
        "animations": [{"name": nome_clipe, "samplers": amostras, "channels": canais}],
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(buf)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(buf) % 4:
        buf.append(0)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + bytes(buf)
    saida.write_bytes(out)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    dest = pathlib.Path(sys.argv[1])
    dest.mkdir(parents=True, exist_ok=True)
    pedidos = sys.argv[2:]
    n = 0
    for pasta in ("combat", "skill", "living"):
        for f in sorted((EF / "animations/biped" / pasta).glob("*.json")):
            if pedidos and f.stem not in pedidos:
                continue
            construir(f.stem, json.load(open(f)), dest / ("ef_%s.glb" % f.stem))
            n += 1
    print("%d clipes -> %s" % (n, dest))


if __name__ == "__main__":
    main()
