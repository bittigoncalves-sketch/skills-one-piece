"""Areia low poly modular. Blender --background --python tools/blender/areia_praia.py.
Autoria em metros, Y para cima; margem seca em -Z, descida ao mar em +Z.
As bordas X casam entre cópias, sem ruído aleatório nas costuras.
"""
import bpy
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rng = random.Random(300926)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
verts, faces = [], []
NX, NZ = 16, 12
for j in range(NZ + 1):
    t = j / NZ
    for i in range(NX + 1):
        u = i / NX
        x, z = (u - .5) * 32, (t - .5) * 24
        # Bordas fixas e perfil suave: módulos se juntam em X e rotação é livre.
        if 0 < i < NX and 0 < j < NZ:
            x += rng.uniform(-.45, .45)
            z += rng.uniform(-.3, .3)
        y = .6 - 1.4 * t + .30 * math.sin(math.pi*t) * math.sin(math.tau*u)**2
        y += .07 * math.sin(3*math.tau*u + 2*t) * math.sin(math.pi*u) * math.sin(math.pi*t)
        verts.append((x, -z, y))  # Blender Z-up -> export GLB Y-up
for j in range(NZ):
    for i in range(NX):
        a = j*(NX+1)+i; b = a+1; c = a+NX+1; d = c+1
        # Vistos de cima (Blender +Z); alternar diagonais evita faixas regulares.
        faces.extend([(a,c,b),(b,c,d)] if (i+j)%2 else [(a,c,d),(a,d,b)])
top_count = len(faces)
# Contorno horário visto no X/Z do Godot; laterais e fundo fecham o volume.
border = list(range(NX+1)) + [j*(NX+1)+NX for j in range(1,NZ+1)]
border += [NZ*(NX+1)+i for i in range(NX-1,-1,-1)]
border += [j*(NX+1) for j in range(NZ-1,0,-1)]
bottom = []
for index in border:
    x,y,_ = verts[index]; bottom.append(len(verts)); verts.append((x,y,-1.2))
for k,a in enumerate(border):
    n=(k+1)%len(border); b=border[n]; c=bottom[k]; d=bottom[n]
    faces.extend([(a,b,c),(b,d,c)])
faces.append(tuple(bottom))
mesh=bpy.data.meshes.new('Areia_triangulada');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Areia_praia_low_poly',mesh);bpy.context.collection.objects.link(obj)
colors=[(.72,.52,.29),(.76,.56,.32),(.79,.60,.36),(.74,.54,.31),(.81,.63,.39)]
for n,col in enumerate(colors):
    mat=bpy.data.materials.new('Areia_%d'%n);mat.diffuse_color=(*col,1);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1)
    bs.inputs['Roughness'].default_value=.94
    mesh.materials.append(mat)
for p in mesh.polygons:
    p.use_smooth=False
    p.material_index=rng.choices(range(5),[1,3,8,3,1])[0] if p.index<top_count else 0
uv=mesh.uv_layers.new(name='UVMap')
for p in mesh.polygons:
    for li in p.loop_indices:
        x,y,z=mesh.vertices[mesh.loops[li].vertex_index].co
        uv.data[li].uv=((x+16)/32,(-y+12)/24)
bpy.context.view_layer.objects.active=obj;obj.select_set(True)
# Recalcular normais também garante fundo/laterais para colisão côncava Godot.
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
source=ROOT/'art_src/praia';source.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'areia_praia.blend'))
bpy.ops.export_scene.gltf(filepath=str(source/'areia_praia_low_poly.glb'),export_format='GLB',use_selection=True,export_yup=True)
print('AREIA_EXPORTADA',len(verts),'vertices',top_count,'triangulos no topo')
