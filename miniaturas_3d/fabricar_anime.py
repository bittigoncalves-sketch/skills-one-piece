"""Consolidação e verificação local da nova malha. Não usa bibliotecas externas.

Usa apenas bpy/bmesh/mathutils/numpy incluídos no Blender instalado.
"""
import argparse
import json
import struct
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector

p=argparse.ArgumentParser();p.add_argument('--nome',required=True)
p.add_argument('--altura',type=float,default=120);p.add_argument('--voxel',type=float,default=.10)
p.add_argument('--render',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
root=Path(__file__).resolve().parent/(a.nome+'_anime')
scene=bpy.context.scene
bpy.context.preferences.filepaths.save_version=0
coll=bpy.data.collections['FIGURA_AUTORAL']
bpy.ops.object.select_all(action='DESELECT')
for o in coll.objects:o.select_set(True)
bpy.context.view_layer.objects.active=next(iter(coll.objects))
bpy.ops.object.convert(target='MESH');bpy.ops.object.join();o=bpy.context.object
o.name=a.nome.upper()+'_ANIME_VOLUME'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
z0=min(v.co.z for v in o.data.vertices);z1=max(v.co.z for v in o.data.vertices)
scale=a.altura/(z1-z0)
for v in o.data.vertices:v.co.z-=z0;v.co*=scale
for ob in bpy.data.collections['ESTUDIO'].objects:
    ob.location.z-=z0;ob.location*=scale
    if ob.type=='CAMERA':ob.data.ortho_scale*=scale
    if ob.type=='LIGHT':ob.data.size*=scale;ob.data.energy*=scale*scale
bm=bmesh.new();bm.from_mesh(o.data)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
mod=o.modifiers.new('Uniao volumetrica','REMESH');mod.mode='VOXEL';mod.voxel_size=a.voxel
mod.use_smooth_shade=True;mod.use_remove_disconnected=False
bpy.ops.object.modifier_apply(modifier=mod.name)
mod=o.modifiers.new('Acabamento','SMOOTH');mod.factor=.25;mod.iterations=2
bpy.ops.object.modifier_apply(modifier=mod.name)
bm=bmesh.new();bm.from_mesh(o.data);bm.verts.ensure_lookup_table()
seen=set();components=[];dust=[]
for v in bm.verts:
    if v.index in seen:continue
    stack=[v];seen.add(v.index);ids=[]
    while stack:
        q=stack.pop();ids.append(q.index)
        for e in q.link_edges:
            w=e.other_vert(q)
            if w.index not in seen:seen.add(w.index);stack.append(w)
    lo=[min(bm.verts[i].co[j] for i in ids) for j in range(3)]
    hi=[max(bm.verts[i].co[j] for i in ids) for j in range(3)]
    if len(ids)<=16 and max(hi[j]-lo[j] for j in range(3))<a.voxel*.6:
        dust.extend(bm.verts[i] for i in ids)
    else:components.append({'vertices':len(ids),'min_mm':lo,'max_mm':hi})
removed=len(dust)
if dust:bmesh.ops.delete(bm,geom=dust,context='VERTS')
components.sort(key=lambda c:c['vertices'],reverse=True)
z0=min(v.co.z for v in bm.verts);z1=max(v.co.z for v in bm.verts)
adjust=a.altura/(z1-z0)
for v in bm.verts:
    v.co.z-=z0
    if v.co.z<a.voxel*.3:v.co.z=0
    v.co*=adjust
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bad_edges=sum(not e.is_manifold for e in bm.edges)
bad_faces=sum(f.calc_area()<1e-10 for f in bm.faces)
volume=bm.calc_volume(signed=True)
bm.to_mesh(o.data);bm.free();o.data.update()
coords=np.empty((len(o.data.vertices),3),dtype=np.float32)
o.data.vertices.foreach_get('co',coords.ravel())
dims=coords.max(axis=0)-coords.min(axis=0)
report={'personagem':a.nome,'altura_provisoria_mm':a.altura,'dimensoes_xyz_mm':dims.tolist(),
        'voxel_mm':a.voxel,'componentes':components,'arestas_nao_manifold':bad_edges,
        'faces_degeneradas':bad_faces,'volume_mm3':volume,'residuos_numericos_vertices_removidos':removed,
        'criterio_residuo':f'ate 16 vertices e dimensao maxima menor que {a.voxel*.6:g} mm',
        'malha_fechada_conectada':len(components)==1 and bad_edges==0 and bad_faces==0 and volume>0,
        'suportes':False,'espessuras_minimas_validadas':False,'impressao_fisica_validada':False,
        'fidelidade_visual_aprovada_pelo_usuario':False}
o.data.materials.clear();m=bpy.data.materials.new('Resina neutra');m.diffuse_color=(.44,.47,.51,1);m.use_nodes=True
bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.44,.47,.51,1);bs.inputs['Roughness'].default_value=.67
o.data.materials.append(m)
for poly in o.data.polygons:poly.material_index=0;poly.use_smooth=True
scene['estado']='REVISAO ANIME; validacao digital em validacao_anime.json'
bpy.ops.wm.save_as_mainfile(filepath=str(root/(a.nome+'_anime_volume.blend')))
if report['malha_fechada_conectada']:
    o.data.calc_loop_triangles();n=len(o.data.loop_triangles)
    index=np.empty((n,3),dtype=np.int32);o.data.loop_triangles.foreach_get('vertices',index.ravel())
    points=coords[index];normal=np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0])
    lengths=np.linalg.norm(normal,axis=1)
    assert np.all(lengths>1e-10), 'Triangulacao degenerada'
    normal/=lengths[:,None]
    dtype=np.dtype([('normal','<f4',(3,)),('vertices','<f4',(3,3)),('attribute','<u2')])
    data=np.zeros(n,dtype=dtype);data['normal']=normal;data['vertices']=points
    path=root/f'{a.nome}_anime_{a.altura:g}mm.stl'
    with path.open('wb') as f:
        f.write(b'Codex native terminal | original anime mesh | mm | no supports'.ljust(80,b'\0'))
        f.write(struct.pack('<I',n));data.tofile(f)
    del data,normal,points,index
    # Reabrir e verificar o arquivo efetivamente entregue.
    with path.open('rb') as f:
        f.seek(80);count=struct.unpack('<I',f.read(4))[0];readback=np.fromfile(f,dtype=dtype,count=count)
    assert path.stat().st_size==84+50*count
    assert np.isfinite(readback['vertices']).all()
    read_dims=readback['vertices'].max(axis=(0,1))-readback['vertices'].min(axis=(0,1))
    assert abs(float(read_dims[2])-a.altura)<.01
    assert np.allclose(read_dims,dims,atol=.001)
    report['stl']={'arquivo':path.name,'triangulos':count,'bytes':path.stat().st_size,
                   'dimensoes_verificadas_mm':read_dims.tolist(),'leitura_binaria_verificada':True}
    print('STL_EXPORTADO',json.dumps(report['stl']),flush=True)
else:print('STL_BLOQUEADO_POR_TOPOLOGIA',flush=True)
(root/'validacao_anime.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
print('VALIDACAO',json.dumps(report),flush=True)
if a.render:
    scene.render.filepath=str(root/'volume_frente.png');bpy.ops.render.render(write_still=True)
    cam=scene.camera;cam.location=(-100*scale,300*scale,160*scale)
    cam.rotation_euler=(Vector((0,0,a.altura*.52))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(root/'volume_costas.png');bpy.ops.render.render(write_still=True)
