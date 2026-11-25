"""
Assets 3D das técnicas das LOGIAS (Mine Piece) em .glb — Skills One Piece, 24/11/2026.

Pedido do dono: "gere com o Blender um asset para cada técnica, com base nas imagens do Codex — ex.: Suna Suna, Adaga
de Areia = uma adaga com textura de areia, e ela é disparada".

Rodar (headless):
    blender --background --python tools/blender/logias_assets.py [-- nome1 nome2 ...]   # sem nomes = todos

Saída: assets/mine_piece/frutas/logias_mod/modelos/<nome>.glb (textura embutida; a procedural também fica em
`.../modelos/texturas/<nome>.png` para revisão). O jogo instancia via `src/combat/frutas_do_mod/assets_de_tecnica.gd`.

--------------------------------------------------------------------- EIXOS
O corpo do projétil do mod alinha o +Y do Godot à velocidade (`mc_alinhar_y` em `McCorpoDoMod._process`). O exportador glTF
mapeia +Z(Blender) → +Y(glTF/Godot). Logo, AQUI: a PONTA aponta para +Z do Blender; a origem é o centro do objeto.
Unidade: 1 unidade = 1 BLOCO do Minecraft (o jogo escala por `MundoMinePiece.METROS_POR_BLOCO`).

--------------------------------------------------------------------- REFERÊNCIA
Silhuetas/cores: `art_src/references/logias_codex/<fruta>/tecnicas.png` (conceitos do Codex; não são geometria pronta).
Cada asset abaixo diz de qual painel/técnica vem.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "assets", "mine_piece", "frutas", "logias_mod", "modelos")
TEXTURAS = os.path.join(SAIDA, "texturas")

# Paletas por elemento (cor base clara, cor escura, emissão ou None). Vêm das fichas do Codex.
PALETAS = {
    "areia": {"claro": (0.84, 0.70, 0.45), "escuro": (0.60, 0.46, 0.26), "emissao": None, "rugosa": 0.95, "grao": 0.55},
    "madeira": {"claro": (0.46, 0.33, 0.20), "escuro": (0.24, 0.16, 0.09), "emissao": None, "rugosa": 0.9, "grao": 0.3},
    "magma": {"claro": (1.0, 0.55, 0.12), "escuro": (0.18, 0.05, 0.03), "emissao": (1.0, 0.35, 0.05), "rugosa": 0.8, "grao": 0.6},
    "fogo": {"claro": (1.0, 0.85, 0.35), "escuro": (0.95, 0.30, 0.05), "emissao": (1.0, 0.5, 0.1), "rugosa": 0.6, "grao": 0.35},
    "trevas": {"claro": (0.38, 0.14, 0.55), "escuro": (0.04, 0.02, 0.07), "emissao": (0.45, 0.1, 0.8), "rugosa": 0.5, "grao": 0.25},
    "luz": {"claro": (1.0, 0.97, 0.75), "escuro": (1.0, 0.78, 0.25), "emissao": (1.0, 0.85, 0.35), "rugosa": 0.3, "grao": 0.15},
    "gelo": {"claro": (0.85, 0.96, 1.0), "escuro": (0.35, 0.65, 0.95), "emissao": (0.3, 0.6, 1.0), "rugosa": 0.12, "grao": 0.2},
    "raio": {"claro": (0.9, 0.95, 1.0), "escuro": (0.35, 0.3, 0.9), "emissao": (0.5, 0.6, 1.0), "rugosa": 0.3, "grao": 0.2},
    "fumaca": {"claro": (0.97, 0.97, 1.0), "escuro": (0.6, 0.6, 0.66), "emissao": None, "rugosa": 1.0, "grao": 0.4},
}


# ------------------------------------------------------------------ utilidades
def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def textura(nome, elemento, tamanho=256):
    """Textura procedural do elemento (grão/ruído em duas cores), salva em PNG e devolvida como imagem."""
    p = PALETAS[elemento]
    img = bpy.data.images.new(nome, tamanho, tamanho)
    rng = random.Random(hash(nome) & 0xFFFF)
    px = [0.0] * (tamanho * tamanho * 4)
    escala = 7.0
    for y in range(tamanho):
        for x in range(tamanho):
            u, v = x / tamanho, y / tamanho
            # ruído que se repete nas bordas: soma de ruído tileável aproximado (espelha nas bordas)
            n = noise.fractal(Vector((math.sin(u * math.tau) * escala * 0.16 + 3.0, math.cos(u * math.tau) * escala * 0.16 + 3.0,
                                      math.sin(v * math.tau) * escala * 0.16 + 9.0)), 0.55, 2.0, 4)
            g = rng.random() * p["grao"]
            t = max(0.0, min(1.0, 0.5 + n * 1.2 + (g - p["grao"] * 0.5)))
            i = (y * tamanho + x) * 4
            for c in range(3):
                px[i + c] = p["escuro"][c] + (p["claro"][c] - p["escuro"][c]) * t
            px[i + 3] = 1.0
    img.pixels = px
    os.makedirs(TEXTURAS, exist_ok=True)
    img.filepath_raw = os.path.join(TEXTURAS, nome + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def material(nome, elemento):
    p = PALETAS[elemento]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nos = m.node_tree.nodes
    bsdf = nos["Principled BSDF"]
    tex = nos.new("ShaderNodeTexImage")
    tex.image = textura(nome, elemento)
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = p["rugosa"]
    if p["emissao"]:
        bsdf.inputs["Emission Color"].default_value = (*p["emissao"], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.6
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    return m


def rugosidade(obj, forca, escala=6.0, subdividir=2):
    """Irregularidade da superfície (areia/madeira/rocha): subdivide e desloca por ruído."""
    mod = obj.modifiers.new("Sub", "SUBSURF")
    mod.levels = subdividir
    mod.subdivision_type = "SIMPLE"
    tex = bpy.data.textures.new("rug_" + obj.name, "CLOUDS")
    tex.noise_scale = 1.0 / escala
    d = obj.modifiers.new("Rug", "DISPLACE")
    d.texture = tex
    d.strength = forca
    d.mid_level = 0.5


def uv(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)


def malha_de_pontos(nome, verts, faces):
    me = bpy.data.meshes.new(nome)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(obj)
    for f in me.polygons:
        f.use_smooth = False
    return obj


def lamina_diamante(nome, comprimento, largura, espessura, cintura=0.35):
    """Lâmina de seção em losango, ponta em +Z: base em z=0, ponta em z=comprimento."""
    z1 = comprimento * cintura
    L, E = largura * 0.5, espessura * 0.5
    verts = [(L, 0, 0), (0, E, 0), (-L, 0, 0), (0, -E, 0),          # base (losango)
             (L * 0.9, 0, z1), (0, E * 0.9, z1), (-L * 0.9, 0, z1), (0, -E * 0.9, z1),   # cintura
             (0, 0, comprimento)]                                    # ponta
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        faces.append((i, j, 4 + j, 4 + i))
        faces.append((4 + i, 4 + j, 8))
    faces.append((3, 2, 1, 0))
    return malha_de_pontos(nome, verts, faces)


def cilindro(nome, raio, comprimento, z0=0.0, segmentos=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segmentos, radius=raio, depth=comprimento, location=(0, 0, z0 + comprimento * 0.5))
    o = bpy.context.active_object
    o.name = nome
    return o


def cone(nome, raio, comprimento, z0=0.0, segmentos=6):
    bpy.ops.mesh.primitive_cone_add(vertices=segmentos, radius1=raio, radius2=0.0, depth=comprimento, location=(0, 0, z0 + comprimento * 0.5))
    o = bpy.context.active_object
    o.name = nome
    return o


def esfera(nome, raio, z=0.0, escala=(1, 1, 1), segmentos=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segmentos, ring_count=segmentos // 2, radius=raio, location=(0, 0, z))
    o = bpy.context.active_object
    o.name = nome
    o.scale = escala
    bpy.ops.object.transform_apply(scale=True)
    return o


def caixa(nome, tamanho, local=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=local)
    o = bpy.context.active_object
    o.name = nome
    o.scale = tamanho
    bpy.ops.object.transform_apply(scale=True)
    return o


def juntar(objetos, nome):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objetos:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    bpy.ops.object.join()
    r = bpy.context.active_object
    r.name = nome
    return r


def aplicar_modificadores(obj):
    bpy.context.view_layer.objects.active = obj
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def finalizar(obj, elemento, rug=0.0, esc_rug=6.0):
    if rug > 0:
        rugosidade(obj, rug, esc_rug)
        aplicar_modificadores(obj)
    uv(obj)
    obj.data.materials.clear()
    obj.data.materials.append(material("m_" + obj.name, elemento))
    bpy.ops.object.select_all(action="DESELECT")
    return obj


def exportar(nome):
    os.makedirs(SAIDA, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(SAIDA, nome + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_image_format="AUTO", export_materials="EXPORT")


# ------------------------------------------------------------------ os assets
def suna_adaga():
    """Suna Suna · Desert Dagger (Z). Painel 1 da ficha do Codex: adaga de areia lançada. Lâmina losango de 1,5 bloco, guarda curta, cabo e pomo."""
    lamina = lamina_diamante("lamina", 1.5, 0.26, 0.09, 0.30)
    lamina.location.z = 0.45
    guarda = caixa("guarda", (0.46, 0.12, 0.07), (0, 0, 0.45))
    cabo = cilindro("cabo", 0.055, 0.40, 0.05, 6)
    pomo = esfera("pomo", 0.09, 0.04, segmentos=8)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (lamina,):
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.transform_apply(location=True)
    o = juntar([lamina, guarda, cabo, pomo], "suna_adaga")
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS")
    finalizar(o, "areia", rug=0.025, esc_rug=5.0)


def suna_cimitarra():
    """Suna Suna · Crescent Cutlass (X). Painel 2 da ficha: lâmina em CRESCENTE de areia (a curva leva a frente, +Z; as pontas abertas para trás). Varredura de losangos ao longo de um arco."""
    R, ang0, ang1, passos = 1.15, math.radians(32), math.radians(148), 14
    verts, faces = [], []
    for k in range(passos + 1):
        t = k / passos
        ang = ang0 + (ang1 - ang0) * t
        larg = 0.05 + 0.40 * math.sin(math.pi * t) ** 0.7        # afina nas duas pontas, grossa no meio
        for raio, y in ((R + larg * 0.5, 0.0), (R, 0.055), (R - larg * 0.5, 0.0), (R, -0.055)):
            verts.append((math.cos(ang) * raio, y, math.sin(ang) * raio))
    for k in range(passos):
        a, b = k * 4, (k + 1) * 4
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a + i, a + j, b + j, b + i))
    faces.append((3, 2, 1, 0))
    faces.append((passos * 4, passos * 4 + 1, passos * 4 + 2, passos * 4 + 3))
    o = malha_de_pontos("suna_cimitarra", verts, faces)
    o.location.z = -R * 0.55    # o meio do crescente fica na origem
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True)
    o.select_set(False)
    finalizar(o, "areia", rug=0.025, esc_rug=4.0)


def mori_estaca():
    """Mori Mori · Tree Strike (Z) / I'll Skewer You (V). Painéis 1 e 4: estaca de madeira com raízes. Tronco cônico + 3 raízes laterais."""
    tronco = cone("tronco", 0.20, 1.8, 0.0, 7)
    tronco.location.z = 0.0
    raizes = []
    for i, ang in enumerate((0.0, 2.1, 4.2)):
        r = cone("raiz%d" % i, 0.07, 0.9, 0.0, 5)
        r.location = (math.cos(ang) * 0.16, math.sin(ang) * 0.16, 0.45)
        r.rotation_euler = (math.sin(ang) * 0.35, -math.cos(ang) * 0.35, 0)
        raizes.append(r)
    o = juntar([tronco] + raizes, "mori_estaca")
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS")
    finalizar(o, "madeira", rug=0.02, esc_rug=4.0)


def magu_rocha():
    """Magu Magu · Great Eruption (Z) / Volcanic Explosion (C). Pedra de lava: esferoide irregular de magma com casca escura."""
    o = esfera("magu_rocha", 0.55, 0.0, (1.0, 0.85, 1.15), 12)
    finalizar(o, "magma", rug=0.12, esc_rug=3.0)


def yami_esfera():
    """Yami Yami · Dark Sphere (C). Painel 3: esfera de trevas com cauda. Esfera roxa escura + 'cauda' cônica atrás (−Z)."""
    esf = esfera("nucleo", 0.5, 0.0, segmentos=14)
    cauda = cone("cauda", 0.42, 1.4, -1.4, 8)
    cauda.rotation_euler[0] = math.radians(180)
    cauda.location.z = -0.75
    bpy.context.view_layer.objects.active = cauda
    cauda.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    cauda.select_set(False)
    o = juntar([esf, cauda], "yami_esfera")
    finalizar(o, "trevas", rug=0.05, esc_rug=3.0)


def mera_bola_de_fogo():
    """Mera Mera · Fire Gun / Firefly (painéis 3 e 5): bola de fogo com cauda de chama (cone para trás)."""
    esf = esfera("nucleo", 0.38, 0.0, segmentos=12)
    cauda = cone("cauda", 0.34, 1.1, 0.0, 7)
    cauda.rotation_euler[0] = math.radians(180)
    cauda.location.z = -0.6
    bpy.context.view_layer.objects.active = cauda
    cauda.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    cauda.select_set(False)
    o = juntar([esf, cauda], "mera_bola_de_fogo")
    finalizar(o, "fogo", rug=0.05, esc_rug=3.0)


def pika_lanca_de_luz():
    """Pika Pika · flechas de luz do painel 5 da ficha (Yasakani): dardo de luz de ponta losango, leve e longo."""
    l = lamina_diamante("dardo", 1.7, 0.30, 0.12, 0.25)
    cabo = cilindro("haste", 0.055, 0.55, -0.50, 6)
    o = juntar([l, cabo], "pika_lanca_de_luz")
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS")
    finalizar(o, "luz", rug=0.0)


def mera_punho():
    """Mera Mera · Fire Fist (X). Painel 2 da ficha: o punho de fogo (Hiken), VISTO DE FRENTE-LADO: palma larga, 4 dedos dobrados (cada um = falange que desce + ponta que volta), polegar por cima e uma cauda de chama (cone) atrás. Os nós dos dedos apontam para +Z."""
    partes = [caixa("palma", (0.70, 0.46, 0.50), (0, 0, 0))]
    for i in range(4):
        x = -0.27 + i * 0.18
        partes.append(caixa("falange%d" % i, (0.16, 0.20, 0.30), (x, 0.0, 0.38)))          # nó do dedo, na frente
        partes.append(caixa("ponta%d" % i, (0.15, 0.12, 0.20), (x, -0.20, 0.34)))          # a ponta dobrada para baixo
    partes.append(caixa("polegar", (0.18, 0.16, 0.34), (0.0, 0.26, 0.30)))
    cauda = cone("chama", 0.40, 1.1, 0.0, 7)
    cauda.rotation_euler[0] = math.radians(180)
    cauda.location.z = -0.95
    bpy.context.view_layer.objects.active = cauda
    cauda.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    cauda.select_set(False)
    partes.append(cauda)
    o = juntar(partes, "mera_punho")
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS")
    finalizar(o, "fogo", rug=0.025, esc_rug=4.0)


def mera_sol():
    """Mera Mera · Great Flame Commandment: Flame Emperor (N). Painel 7: o sol de chamas. Esfera grande + 10 raios cônicos."""
    partes = [esfera("nucleo", 0.9, 0.0, segmentos=14)]
    for i in range(10):
        ang = i * math.tau / 10
        r = cone("raio%d" % i, 0.18, 0.7, 0.0, 5)
        r.location = (math.cos(ang) * 1.05, math.sin(ang) * 1.05, 0.0)
        r.rotation_euler = (0, math.radians(90), ang)
        r.rotation_euler = (math.radians(90) * math.sin(ang), -math.radians(90) * math.cos(ang), 0)
        partes.append(r)
    o = juntar(partes, "mera_sol")
    finalizar(o, "fogo", rug=0.06, esc_rug=3.0)


def magu_cao():
    """Magu Magu · Hound Blaze (X) = Inugami Guren: cabeça de cão de magma de boca aberta, focinho para +Z. Crânio, focinho com nariz, mandíbula entreaberta com presas, duas orelhas para trás."""
    partes = [caixa("cranio", (0.78, 0.66, 0.74), (0, 0.05, -0.15)),
              caixa("focinho", (0.46, 0.30, 0.62), (0, 0.0, 0.52)),
              caixa("nariz", (0.22, 0.14, 0.14), (0, 0.10, 0.86))]
    maxilar = caixa("mandibula", (0.42, 0.14, 0.58), (0, -0.30, 0.50))
    maxilar.rotation_euler[0] = math.radians(14)          # boca aberta
    bpy.context.view_layer.objects.active = maxilar
    maxilar.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    maxilar.select_set(False)
    partes.append(maxilar)
    for lado in (-1, 1):
        orelha = cone("orelha", 0.15, 0.55, 0.0, 4)
        orelha.rotation_euler = (math.radians(-35), 0, lado * math.radians(10))
        orelha.location = (lado * 0.28, 0.42, -0.28)
        partes.append(orelha)
        for k in range(3):
            presa = cone("presa", 0.045, 0.18, 0.0, 4)
            presa.rotation_euler[0] = math.radians(180)
            presa.location = (lado * 0.15, -0.14, 0.30 + k * 0.17)
            partes.append(presa)
        olho = caixa("olho", (0.09, 0.07, 0.07), (lado * 0.27, 0.22, 0.21))
        partes.append(olho)
    o = juntar(partes, "magu_cao")
    bpy.ops.object.origin_set(type="ORIGIN_CENTER_OF_MASS")
    finalizar(o, "magma", rug=0.025, esc_rug=3.0)


ASSETS = {f.__name__: f for f in (suna_adaga, suna_cimitarra, mori_estaca, magu_rocha, yami_esfera, mera_bola_de_fogo, pika_lanca_de_luz, mera_punho, mera_sol, magu_cao)}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for nome in (args or list(ASSETS)):
        limpar()
        ASSETS[nome]()
        exportar(nome)
        print("OK", nome)


if __name__ == "__main__":
    main()
