"""Fotos de conferência do rig: ossos sobre a malha colorida por região de peso, e
folhas de quadros de cada clipe. Workbench (rápido, sem GPU obrigatória)."""
import colorsys
import os
import subprocess
import bpy
import bmesh
from mathutils import Vector, Matrix


FIXAS = {"cabeca": (0.95, 0.15, 0.15), "pescoco": (0.98, 0.85, 0.1), "peito": (0.15, 0.35, 0.95),
         "quadril": (0.2, 0.75, 0.25), "cauda_1": (0.85, 0.2, 0.85), "cauda_2": (0.55, 0.1, 0.6),
         "cauda_3": (0.3, 0.05, 0.35)}


def _cores(nomes):
    """Cadeia principal com cores fixas (revisão rápida); pernas por matiz."""
    out = {}
    resto = [n for n in sorted(nomes) if n not in FIXAS]
    for i, n in enumerate(resto):
        out[n] = colorsys.hsv_to_rgb((0.05 + i * 0.618034) % 1.0, 0.45, 0.85)
    for n in nomes:
        if n in FIXAS:
            out[n] = FIXAS[n]
    return out


def pintar_regioes(obj):
    """Atributo de cor por vértice = mistura das cores dos ossos pelos pesos."""
    nomes = [g.name for g in obj.vertex_groups]
    cores = _cores(nomes)
    attr = obj.data.color_attributes.get("regiao") or obj.data.color_attributes.new("regiao", 'FLOAT_COLOR', 'POINT')
    idx = {g.index: g.name for g in obj.vertex_groups}
    for v in obj.data.vertices:
        c = Vector((0, 0, 0))
        for g in v.groups:
            c += Vector(cores[idx[g.group]]) * g.weight
        attr.data[v.index].color = (c.x, c.y, c.z, 1.0)
    obj.data.color_attributes.active_color = attr
    return cores


def tubos_dos_ossos(arm, raio):
    """Malha de cones finos no lugar de cada osso (o Workbench não renderiza armature)."""
    bm = bmesh.new()
    for b in arm.data.bones:
        a = arm.matrix_world @ b.head_local
        c = arm.matrix_world @ b.tail_local
        d = c - a
        if d.length < 1e-6:
            continue
        rot = d.normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4()
        m = Matrix.Translation((a + c) * 0.5) @ rot
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=raio * 1.6, radius2=raio * 0.5,
                              depth=d.length, matrix=m)
    me = bpy.data.meshes.new("tubos")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("tubos", me)
    bpy.context.scene.collection.objects.link(ob)
    attr = me.color_attributes.new("regiao", 'FLOAT_COLOR', 'POINT')
    for i in range(len(me.vertices)):
        attr.data[i].color = (1.0, 0.05, 0.05, 1.0)
    ob.show_in_front = True
    return ob


def _cena(res=(640, 480)):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.render.resolution_x, sc.render.resolution_y = res
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.82, 0.86, 0.9)
    cam = sc.camera
    if cam is None:
        cam = bpy.data.objects.new("cam_foto", bpy.data.cameras.new("cam_foto"))
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.data.type = 'ORTHO'
    return sc, cam


VISTAS = {
    "lado": Vector((1, 0, 0)),
    "cima": Vector((0, 0, 1)),
    "tres4": Vector((1, -1, 0.55)).normalized(),
    "tras": Vector((0, 1, 0.15)).normalized(),
}


def _apontar(cam, centro, direcao, tam):
    cam.location = centro + direcao * tam * 4
    up = 'Y' if abs(direcao.z) < 0.99 else 'Y'
    cam.rotation_euler = (-direcao).to_track_quat('-Z', up).to_euler()
    if abs(direcao.z) > 0.99:
        cam.rotation_euler = (0, 0, 0)
    cam.data.ortho_scale = tam


def foto(caminho, centro, tam, vista="lado", res=(640, 480), cor='VERTEX'):
    sc, cam = _cena(res)
    sc.display.shading.color_type = cor
    _apontar(cam, centro, VISTAS[vista], tam)
    sc.render.filepath = caminho
    bpy.ops.render.render(write_still=True)


def montar_folha(arquivos, saida, colunas, rotulos=None, legenda=None):
    """Junta PNGs numa folha (Python do sistema com PIL; o do Blender não tem). `legenda`:
    [(nome, (r, g, b))] desenhada à direita — a cor de cada osso na foto dos pesos."""
    codigo = (
        "import sys,json\n"
        "from PIL import Image, ImageDraw\n"
        "a=json.loads(sys.argv[1]); out=sys.argv[2]; cols=int(sys.argv[3]); rot=json.loads(sys.argv[4])\n"
        "leg=json.loads(sys.argv[5])\n"
        "ims=[Image.open(f).convert('RGB') for f in a]\n"
        "w,h=ims[0].size; rows=(len(ims)+cols-1)//cols; extra=190 if leg else 0\n"
        "F=Image.new('RGB',(w*cols+extra,h*rows),'white')\n"
        "for i,im in enumerate(ims):\n"
        "  if rot: ImageDraw.Draw(im).text((6,6),rot[i],fill=(0,0,0))\n"
        "  F.paste(im,((i%cols)*w,(i//cols)*h))\n"
        "d=ImageDraw.Draw(F)\n"
        "for k,(n,c) in enumerate(leg):\n"
        "  y=10+k*20; d.rectangle([w*cols+8,y,w*cols+26,y+14],fill=tuple(int(255*x) for x in c)); d.text((w*cols+32,y+1),n,fill=(0,0,0))\n"
        "F.save(out)\n")
    import json
    subprocess.run(["python3", "-c", codigo, json.dumps(arquivos), saida, str(colunas), json.dumps(rotulos or []),
                    json.dumps(legenda or [])],
                   check=True, env={k: v for k, v in os.environ.items() if not k.startswith("PYTHON")})
    for f in arquivos:
        os.remove(f)
