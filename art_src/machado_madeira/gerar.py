"""Blender -b --python art_src/machado_madeira/gerar.py. Autoria procedural local."""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'mapas/modelos'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.65):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 return m
wood=mat('Cedro mel',(.43,.19,.065)); light=mat('Madeira corte',(.58,.31,.12)); grain=mat('Veios',(.24,.085,.025)); steel=mat('Aço azul',(.21,.32,.4),.65,.32); edge=mat('Fio polido',(.72,.86,.9),.8,.23); leather=mat('Couro vinho',(.24,.035,.045)); brass=mat('Latão',(.63,.36,.08),.6,.38)
def mesh(name,verts,faces,material):
 m=bpy.data.meshes.new(name); m.from_pydata(verts,[],faces); m.update(); o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o); o.data.materials.append(material); return o
def bevel(o,w=.02):
 mod=o.modifiers.new('Chanfro','BEVEL'); mod.width=w; mod.segments=1
 bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
def box(name,loc,scale,material,w=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(material); bevel(o,w); return o
def cyl(name,z,r,depth,material):
 bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=depth,location=(0,0,z)); o=bpy.context.object; o.name=name; o.data.materials.append(material); bevel(o,.007); return o
def export(id):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_src/machado_madeira'/f'{id}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'{id}.glb'),export_format='GLB',use_selection=True,export_yup=True)
 bpy.ops.object.delete(use_global=False)
# Blender Z -> Godot Y; origem no centro da pega, cabeça +Y, fio +X.
cyl('Cabo facetado',.29,.043,1.02,wood)
for i in range(7): cyl('Faixa couro',-.13+i*.047,.049,.026,leather)
for z in [-.205,.185,.61,.76]: cyl('Anel latão',z,.057,.028,brass)
box('Olhal',(0,0,.72),(.15,.12,.24),steel,.025)
# Cabeça afiada em cunha com silhueta de barba curva facetada.
poly=[(.04,.81),(.20,.88),(.32,.89),(.39,.84),(.42,.70),(.36,.59),(.26,.55),(.22,.61),(.04,.63)]
v=[(x,y,z) for y in [-.055,.055] for x,z in poly]; n=len(poly)
faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
head=mesh('Cabeça barba',v,faces,steel); bevel(head,.014)
# Faixa do fio, espessura afunilada.
outer=[(.38,.94),(.47,.88),(.50,.70),(.43,.54),(.30,.48)]
inner=[(.32,.89),(.39,.84),(.42,.70),(.36,.59),(.26,.55)]
verts=[]
for sign in [-1,1]:
 for (x,z),(ix,iz) in zip(outer,inner): verts.extend([(x,sign*.009,z),(ix,sign*.055,iz)])
faces=[]
for side in [0,10]:
 for i in range(4): faces.append((side+2*i,side+2*i+2,side+2*i+3,side+2*i+1))
for i in range(4): faces.append((2*i,10+2*i,12+2*i,2+2*i))
mesh('Fio claro',verts,faces,edge)
box('Contrapeso',(-.13,0,.72),(.20,.095,.12),steel,.018)
export('machado_lenhador')
for i in range(3):
 o=box(f'Tábua {i+1}',(0,(i-1)*.245,.065+i*.015),(1.2,.22,.105),light,.025)
 # Filetes e nós finos, geometria independente sem textura.
 for k in range(3):
  y=(i-1)*.245+(k-1)*.05
  verts=[(-.53,y,.1275+i*.015),(-.16,y+.008,.1275+i*.015),(.17,y-.006,.1275+i*.015),(.51,y+.006,.1275+i*.015),(.17,y-.010,.1275+i*.015),(-.16,y+.003,.1275+i*.015)]
  mesh('Veio longitudinal',verts,[(5,4,3,2,1,0)],grain)
export('tabuas_madeira')
