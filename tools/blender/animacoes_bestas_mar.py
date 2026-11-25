"""Clipes autorais dos rigs marinhos. Editável; bake em .blend e exportação GLB.

blender -b --python tools/blender/animacoes_bestas_mar.py
Atualiza só animações: preserva malha, pesos, materiais e cabeça anime.
Também chamado pelo gerador canônico bestas_mar.py.
"""
import bpy
import math
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_src/bestas_mar"
CLIPES = {"idle": 4.0, "dormindo": 5.0, "nadando_walk": 2.4,
          "mergulhando": 2.4, "nadando_submerso": 2.6, "emergindo": 2.4,
          "nadando_run": 1.1, "irritado": 1.6, "atacando": 1.5,
          "recebendo_dano": .65, "disparando_ataque": 2.0, "comendo": 3.2,
          "repouso": 4.0, "ameaca": 1.6,
          "boiando": 4.0, "andando_terra": 2.4, "correndo_terra": 1.1}
LOOPS = {"idle", "dormindo", "nadando_walk", "nadando_run", "nadando_submerso", "comendo", "repouso",
         "boiando", "andando_terra", "correndo_terra"}

# ---------------------------------------------------------------------------
# POSTURA DEITADA (08/10/2026, pedido do dono: "na terra, quando a besta estiver
# dormindo, ela deve estar com o corpo completamente deitado, e o corpo deve estar
# deitado quando estiver nadando no mar também; inspiração focas e leões-marinhos").
# A coluna do pescoço, que fica em pé, dobra para a frente até a horizontal: a dobra
# fica repartida entre corpo e os dois primeiros pescoços (sem vinco na pele), a cauda
# compensa o corpo (senão subiria) e a raiz desce até a barriga encostar. Ângulos
# conferidos na prévia (tools/blender/previa_poses_bestas.py, vistas 3/4, perfil e
# topo). É a GEOMETRIA do corpo no chão, igual nas quatro espécies: não leva o `peso`
# da espécie (com ele a bovina não deitaria e a serpente dobraria demais); o movimento
# por cima (respiração, remada, arrasto) é que leva.
DEITADA = {"corpo": (-.35, 0, 0), "cauda_01": (.35, 0, 0), "pescoco_01": (-.75, 0, 0),
           "pescoco_02": (-.35, 0, 0), "pescoco_03": (.1, 0, 0), "pescoco_04": (.2, 0, 0),
           "cabeca": (.35, 0, 0)}
NADADEIRA_DEITADA = (.9, 0, .6)    # z vezes o lado: abertas para os lados e para trás
# A cabeça da serpente é bem maior e mais longa (o crânio do anime): deitada, o focinho
# apontava para o chão; ela ergue mais a cabeça.
CABECA_DEITADA = {"serpente": .55}
# Quanto a cabeça desce para apoiar no chão ao dormir (a da serpente é grande: desce menos).
APOIO_DA_CABECA = {"serpente": .3}
RAIZ_DEITADA = -.75               # local Y da raiz = cima (medido: barriga a ~0,1 m do chão)
# Andando em terra ela fica ERETA, como antes (correção do dono no mesmo dia: "as
# bestas devem ficar eretas quando andam em terra como antes"): só dormir e nadar deitam.
DEITADOS = {"dormindo", "nadando_walk", "nadando_run", "mergulhando", "nadando_submerso",
            "emergindo"}


def base_deitada(osso, lado, especie):
    if osso.startswith("nadadeira_"):
        return (NADADEIRA_DEITADA[0], 0.0, NADADEIRA_DEITADA[2] * lado)
    x, y, z = DEITADA.get(osso, (0.0, 0.0, 0.0))
    if osso == "cabeca":
        x += CABECA_DEITADA.get(especie, 0.0)
    return (x, y, z)


def pulso(u, inicio, pico, fim):
    if u <= inicio or u >= fim:
        return 0.0
    v = (u - inicio) / (pico - inicio) if u < pico else (fim - u) / (fim - pico)
    return v * v * (3 - 2 * v)


def pose(nome, osso, u, especie):
    nome = {"repouso": "idle", "ameaca": "irritado"}.get(nome, nome)
    t = u * math.tau
    x = y = z = 0.0
    local = [0.0, 0.0, 0.0]
    n = int(osso[-2:]) if osso.startswith(("pescoco_", "cauda_")) else 0
    peso = {"bovina": .85, "girafa": 1.05, "javali": .95, "serpente": 1.15}[especie]
    if osso == "corpo":
        x = .012 * math.sin(t)
    if osso.startswith("pescoco_"):
        z = .018 * math.sin(t - n * .5)
    if osso.startswith("cauda_"):
        z = .04 * math.sin(t - n * .65)
    lado = -1 if osso.endswith("L") else 1
    if "nadadeira" in osso:
        y = lado * .045 * math.sin(t)

    raiz_x = 0.0          # inclinação do corpo todo (nariz para baixo < 0), sem `peso`
    if nome == "dormindo":
        # Foca dormindo na areia: barriga no chão, cabeça apoiada, corpo em meia-lua
        # (pescoço e cauda curvados para o mesmo lado) e a respiração lenta.
        if osso == "corpo": x = .02 * math.sin(t); z = 0.0
        apoio = APOIO_DA_CABECA.get(especie, 1.0)
        if osso.startswith("pescoco_"):
            x = {3: -.14, 4: -.22}.get(n, 0.0) * apoio + .006 * math.sin(t - n * .3)
            z = {2: .22, 3: .2, 4: .1}.get(n, 0.0)
        if osso == "cabeca": x = -.16 * apoio + .012 * math.sin(t)
        if osso.startswith("cauda_"): z = .14 + .012 * math.sin(t - n)
        if "nadadeira" in osso: y = 0.0; x = -.08
    elif nome in ("nadando_walk", "nadando_run"):
        # Leão-marinho na superfície: corpo na horizontal, cabeça erguida para fora,
        # cauda ondulando de lado, nadadeiras dianteiras em remada ("voando").
        rapido = nome == "nadando_run"
        amp = .25 if rapido else .14
        if osso.startswith("cauda_"): z = amp * math.sin(t - n * .7)
        if osso.startswith("pescoco_"):
            x = ({3: .08, 4: .1} if rapido else {3: .15, 4: .25}).get(n, 0.0)
            z = amp * .18 * math.sin(t - n * .35)
        if osso == "cabeca": x = 0.0 if rapido else -.15
        if osso == "corpo": z = amp * .25 * math.sin(t); x = .03 * math.sin(2 * t)
        if "nadadeira" in osso:
            x = (.3 if rapido else 0.0) + (.55 if rapido else .35) * math.sin(t)
            y = lado * .15 * math.sin(t + 1.2)
    elif nome in ("mergulhando", "nadando_submerso", "emergindo"):
        # Mergulho de foca: o nariz desce, o corpo alonga (cabeça em linha), remadas
        # largas e lentas embaixo d'água; na subida o nariz aponta para cima e a
        # cabeça volta a sair.
        blend = u * u * (3 - 2 * u)
        if nome == "mergulhando":
            submerso, raiz_x = blend, -.5 * math.sin(math.pi * min(1.0, u * 1.25))
        elif nome == "emergindo":
            submerso, raiz_x = 1 - blend, .45 * math.sin(math.pi * min(1.0, u * 1.15))
        else:
            submerso = 1.0
        cabeca_fora = 1.0 - submerso
        if osso.startswith("pescoco_"):
            x = {3: .15 * cabeca_fora, 4: .25 * cabeca_fora - .12 * submerso}.get(n, 0.0)
            z = .03 * math.sin(t - n * .4)
        if osso == "cabeca": x = -.15 * cabeca_fora + .05 * submerso
        if osso.startswith("cauda_"): z = .17 * math.sin(t - n * .7)
        if osso == "corpo": z = .04 * math.sin(t)
        if "nadadeira" in osso:
            x = .25 * submerso + .6 * math.sin(t)
            y = lado * .2 * math.sin(t + 1.2)
    elif nome in ("andando_terra", "correndo_terra"):
        # Andar em terra ERETA: o movimento que o nado tinha antes de deitar (corpo em
        # pé, cauda e pescoço ondulando de lado, nadadeiras remando).
        rapido = nome == "correndo_terra"
        amp = .25 if rapido else .13
        if osso.startswith("cauda_"): z = amp * math.sin(t - n * .7)
        if osso.startswith("pescoco_"):
            x = -.12 if rapido else -.045
            z = amp * .25 * math.sin(t - n * .35)
        if osso == "corpo": z = amp * .30 * math.sin(t)
        if "nadadeira" in osso:
            y = lado * (.08 + (.38 if rapido else .22) * math.sin(t - .5))
            x = .13 * math.cos(t)
    elif nome == "boiando":
        # Foca "de garrafa": em pé na água, só a cabeça e o pescoço para fora, as
        # nadadeiras fazendo pequenos círculos para se manter.
        if osso == "corpo": x = .02 * math.sin(t)
        if "nadadeira" in osso:
            x = .12 * math.sin(t)
            y = lado * (.1 + .12 * math.cos(t))
    elif nome == "irritado":
        p = pulso(u, .03, .5, 1)
        if osso.startswith("pescoco_"): x = .045 * p
        if osso == "cabeca": z = .14 * math.sin(t * 2) * p; x = .13 * p
        if osso == "mandibula": x = -.55 * p
        if "nadadeira" in osso: y = lado * .35 * p
        if osso.startswith("cauda_"): z = .15 * math.sin(t * 2 - n) * p
    elif nome == "atacando":
        preparar = pulso(u, 0, .24, .43)
        impacto = pulso(u, .3, .52, .83)
        corpo, primeiro, demais = {"bovina": (-.12, 1.2, .1), "girafa": (-.25, .9, .2),
                                    "javali": (-.25, 1.2, 0), "serpente": (-.12, 1.2, .1)}[especie]
        if osso.startswith("pescoco_"):
            x = .10 * preparar - (primeiro if n == 1 else demais) * impacto / peso
        if osso == "cabeca": x = .12 * preparar - .25 * impacto / peso
        if osso == "mandibula": x = -.55 * pulso(u, .15, .40, .56)
        if "nadadeira" in osso: y = lado * (.25 * preparar - .2 * impacto)
        if osso == "corpo": x = corpo * impacto / peso
        if osso.startswith("cauda_"): z = .13 * math.sin(t - n) * impacto
    elif nome == "recebendo_dano":
        p = pulso(u, 0, .23, 1)
        if osso.startswith("pescoco_"): x = .08 * p; z = .055 * p
        if osso == "cabeca": x = .25 * p; z = -.12 * p
        if osso == "mandibula": x = -.3 * p
        if osso == "corpo": x = .1 * p
        if "nadadeira" in osso: y = lado * .24 * p
    elif nome == "disparando_ataque":
        carga = pulso(u, .02, .45, .61)
        soltar = pulso(u, .45, .57, .92)
        if osso.startswith("pescoco_"): x = .05 * carga - .10 * soltar
        if osso == "cabeca": x = .12 * carga - .22 * soltar
        if osso == "mandibula": x = -.65 * pulso(u, .13, .52, .84)
        if "nadadeira" in osso: y = lado * .18 * carga
    elif nome == "comendo":
        if osso.startswith("pescoco_"): x = -.15 + .012 * math.sin(t * 3 - n * .2)
        if osso == "cabeca": x = -.22 + .035 * math.sin(t * 3)
        if osso == "mandibula": x = -.10 - .16 * (.5 + .5 * math.sin(t * 3))
        if osso.startswith("cauda_"): z *= .4
    base = base_deitada(osso, lado, especie) if nome in DEITADOS else (0.0, 0.0, 0.0)
    if osso == "raiz":
        # A raiz carrega só a postura (descer até o chão, inclinar o corpo todo).
        if nome in DEITADOS:
            local = [0.0, RAIZ_DEITADA, 0.0]
        return (raiz_x, 0.0, 0.0), local
    return (base[0] + x * peso, base[1] + y * peso, base[2] + z * peso), local


def criar(rig, especie):
    rig.animation_data_clear()
    rig.animation_data_create()
    bpy.context.scene.render.fps = 30
    for nome, duracao in CLIPES.items():
        action = bpy.data.actions.new(nome)
        # Nomes de ação iguais já existentes ganham .001; a trilha exportada mantém nome canônico.
        rig.animation_data.action = action
        fim = round(duracao * 30)
        for frame in range(fim + 1):
            for b in rig.pose.bones:
                b.rotation_mode = "XYZ"
                b.rotation_euler, b.location = pose(nome, b.name, frame / fim, especie)
                b.keyframe_insert(data_path="rotation_euler", frame=frame, group=b.name)
                if b.name == "raiz":
                    # A raiz desce/sobe nas posturas deitadas: sem esta chave a posição
                    # ficava só na prévia e o GLB saía com o corpo flutuando 1,1 m.
                    b.keyframe_insert(data_path="location", frame=frame, group=b.name)
        track = rig.animation_data.nla_tracks.new()
        track.name = nome
        track.strips.new(nome, 0, action)
        rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks: track.mute = True
    for b in rig.pose.bones:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
    bpy.context.scene.frame_set(0)
    bpy.context.scene.frame_end = 150


def atualizar(especie):
    fonte = OUT / f"besta_mar_{especie}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(fonte))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    criar(rig, especie)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(fonte))
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in bpy.data.objects:
        if o.type == "MESH": o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    for track in rig.animation_data.nla_tracks: track.mute = False
    dest = OUT / f"besta_mar_{especie}.glb"
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="NLA_TRACKS", export_nla_strips=True,
        export_force_sampling=True, export_skins=True, export_yup=True, export_apply=False,
        export_rest_position_armature=True)
    shutil.copy2(dest, ROOT / "mapas/modelos" / dest.name)
    medidas = OUT / f"{especie}_medidas.json"
    dados = json.loads(medidas.read_text())
    dados["clips"] = list(CLIPES)
    medidas.write_text(json.dumps(dados, indent=2) + "\n")
    print("ANIMACOES_BESTA_OK", especie, list(CLIPES), flush=True)


if __name__ == "__main__":
    tipos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for especie in tipos or ["bovina", "girafa", "javali", "serpente"]:
        atualizar(especie)
