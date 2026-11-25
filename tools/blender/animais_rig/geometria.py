"""Geometria dos animais: a malha soldada e as FATIAS que acham pernas, cauda e coluna.

Convenção (igual ao jogo): o bicho olha para -Y no Blender (+Z no Godot). `f` é a
coordenada "para a frente" (f = -y). Lado esquerdo do animal = +X.

Os modelos do pacote são UMA casca fechada depois de soldar os vértices (a divisão
original é só do sombreamento chapado). Fatiar a casca por planos dá contornos
fechados: perto do chão, um por perna; no meio, o tronco; atrás, a cauda.
"""
import bmesh
from mathutils import Vector


def frente(v):
    return -v.y


def preparar_malha(obj):
    """Aplica a escala do arquivo (cm -> m), solda a casca e devolve o objeto.

    UV e normais são por canto no Blender: soldar não perde a textura nem o chapado.
    """
    import bpy
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = obj.data
    # Normais por canto do arquivo (o chapado das faces): a solda as perderia. Guardadas
    # por FACE original (a solda apaga face degenerada — galinha 776 -> 764 — e encurta
    # quadrado que vira triângulo), cada canto novo pega a do canto original mais perto.
    cantos = [[(me.vertices[me.loops[li].vertex_index].co.copy(), me.corner_normals[li].vector.copy())
               for li in poly.loop_indices] for poly in me.polygons]
    bm = bmesh.new()
    bm.from_mesh(me)
    camada = bm.faces.layers.int.new("face_original")
    for f in bm.faces:
        f[camada] = f.index
    antes = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(me)
    bm.free()
    origem = me.attributes["face_original"].data
    normais = []
    for poly in me.polygons:
        orig = cantos[origem[poly.index].value]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            normais.append(min(orig, key=lambda c: (c[0] - co).length_squared)[1])
    me.attributes.remove(me.attributes["face_original"])
    me.normals_split_custom_set(normais)
    me.update()
    return antes, len(me.vertices)


class Contorno:
    """Um laço fechado do corte: centro (média ponderada pelas arestas) e extensões."""

    def __init__(self, segmentos):
        self.segmentos = segmentos            # [(a, b)] Vector
        total = 0.0
        soma = Vector((0, 0, 0))
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for a, b in segmentos:
            comp = (b - a).length
            total += comp
            soma += (a + b) * 0.5 * comp
            for p in (a, b):
                lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
                hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
        self.perimetro = total
        self.centro = soma / total if total > 0 else (lo + hi) * 0.5
        self.lo = lo
        self.hi = hi

    @property
    def ext(self):
        return self.hi - self.lo

    def __repr__(self):
        c = self.centro
        return "Contorno(c=(%.2f,%.2f,%.2f) ext=(%.2f,%.2f,%.2f) p=%.2f)" % (
            c.x, c.y, c.z, self.ext.x, self.ext.y, self.ext.z, self.perimetro)


def fatiar(bm_base, ponto, normal):
    """Contornos do corte da casca pelo plano (ponto, normal)."""
    bm = bm_base.copy()
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-7,
                                 plane_co=ponto, plane_no=normal, clear_outer=False, clear_inner=False)
    arestas = [e for e in res['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
    # Agrupa as arestas do corte pelos vértices em comum.
    por_vert = {}
    for e in arestas:
        for v in e.verts:
            por_vert.setdefault(v.index, []).append(e)
    vistas = set()
    contornos = []
    for e0 in arestas:
        if e0.index in vistas:
            continue
        pilha = [e0]
        grupo = []
        while pilha:
            e = pilha.pop()
            if e.index in vistas:
                continue
            vistas.add(e.index)
            grupo.append((e.verts[0].co.copy(), e.verts[1].co.copy()))
            for v in e.verts:
                for viz in por_vert.get(v.index, []):
                    if viz.index not in vistas:
                        pilha.append(viz)
        if len(grupo) >= 3:
            contornos.append(Contorno(grupo))
    bm.free()
    return contornos


def caixa(obj):
    pts = [v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi
