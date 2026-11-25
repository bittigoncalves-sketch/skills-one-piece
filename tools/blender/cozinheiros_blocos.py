"""Superfícies em degraus quadrados, solicitadas em 15/10/2026.

Voxeliza volumes autorais ANTES do skin: faces externas, sem cubos internos.
Os pesos são atribuídos depois aos vértices resultantes, preservando as juntas.
"""
import math
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

VOLUMES = {}
# Lado da célula dos volumes em bloco. 0,018 é o dos cinco cozinheiros originais; o
# Sanji refeito (17/10/2026) usa células maiores, mais voxel, como o Barba Negra e a Nami.
CONFIG = {'cel': .018}


def limpar():
    VOLUMES.clear()


def passo(nome):
    if any(k in nome for k in ('Pupila','Brilho','Barba','Espiral')):
        return .003
    if any(k in nome for k in ('Olho','Iris','Palpebra','Sobrancelha','Boca','Botão','Brinco','Costura')):
        return .006
    if any(k in nome for k in ('Franja','Cabelo','Bigode','Rosto','Nariz','Orelha','Polegar','Palma')):
        return CONFIG['cel']
    if any(k in nome for k in ('Index','Middle','Ring','Little')):
        return .006
    if nome.startswith('Utensilio'):
        return .018
    return CONFIG['cel']


def converter(obj, nome, osso, pesos):
    # Placas e mechas são blocos desenhados, com bordas próprias: não rasterizar.
    if nome.startswith(('Placa','Mecha','Contorno','Bloco')):
        VOLUMES[obj.name]=(set(),0,osso,pesos)
        return
    mesh=obj.data
    verts=[v.co.copy() for v in mesh.vertices]
    polys=[tuple(p.vertices) for p in mesh.polygons]
    bvh=BVHTree.FromPolygons(verts,polys)
    cell=passo(nome)
    lo=[math.floor(min(v[a] for v in verts)/cell)-1 for a in range(3)]
    hi=[math.ceil(max(v[a] for v in verts)/cell)+1 for a in range(3)]
    occupied=set()
    # Nearest surface + signed normal: all source volumes are closed, including
    # the Solidify panels. The small shell preserves thin eyelids and stitching.
    for x in range(lo[0],hi[0]):
        for y in range(lo[1],hi[1]):
            for z in range(lo[2],hi[2]):
                p=Vector(((x+.5)*cell,(y+.5)*cell,(z+.5)*cell))
                hit,normal,_,distance=bvh.find_nearest(p)
                if hit is not None and (distance<cell*.28 or (p-hit).dot(normal)<-1e-7):
                    occupied.add((x,y,z))
    VOLUMES[obj.name]=(occupied,cell,osso,pesos)
    reconstruir(obj,occupied,cell,occupied)


def reconstruir(obj, occupied, cell, union):
    newverts=[]; faces=[]
    # One face per cell: avoids T-junction cracks when an elbow bends.
    for axis in range(3):
        u=(axis+1)%3; v=(axis+2)%3
        for sign in (-1,1):
            slices={}
            for c in occupied:
                neighbor=list(c); neighbor[axis]+=sign
                if tuple(neighbor) not in union:
                    plane=c[axis]+(1 if sign>0 else 0)
                    slices.setdefault(plane,set()).add((c[u],c[v]))
            for plane,cells in slices.items():
                while cells:
                    a,b=min(cells)
                    width=1
                    while width<1 and (a+width,b) in cells: width+=1
                    height=1
                    while height<1 and all((a+i,b+height) in cells for i in range(width)): height+=1
                    for i in range(width):
                        for j in range(height): cells.remove((a+i,b+j))
                    idx=len(newverts)
                    for du,dv in ((0,0),(width,0),(width,height),(0,height)):
                        p=[0.,0.,0.]; p[axis]=plane*cell; p[u]=(a+du)*cell; p[v]=(b+dv)*cell
                        newverts.append(p)
                    face=(idx,idx+1,idx+2,idx+3)
                    faces.append(face if sign>0 else tuple(reversed(face)))
    replacement=bpy.data.meshes.new(obj.name+'_quadrados')
    replacement.from_pydata(newverts,[],faces); replacement.update()
    old=obj.data
    obj.data=replacement
    bpy.data.meshes.remove(old)


def unir_volumes(objects):
    """Union of the body volumes. Last layer wins, as clothing over skin.

    Removes coincident/internal faces between cuffs, sleeves, hair and skin;
    tiny eyes/stitches retain their finer grid and independent surface.
    """
    owners={}
    bulk=[]
    for obj in objects:
        occupied,cell,_,_=VOLUMES[obj.name]
        if cell != CONFIG['cel']:
            continue
        bulk.append(obj)
        for c in occupied: owners[c]=obj.name
    union=set(owners)
    cells_by_name={obj.name:set() for obj in bulk}
    for c,name in owners.items(): cells_by_name[name].add(c)
    for obj in bulk:
        _,cell,bone,pesos=VOLUMES[obj.name]
        mat=obj.data.materials[0]
        reconstruir(obj,cells_by_name[obj.name],cell,union)
        obj.data.materials.append(mat)
        obj.vertex_groups.clear()
        if pesos:
            for v in obj.data.vertices:
                for b,w in pesos(v.co).items():
                    if w>0:
                        group=obj.vertex_groups.get(b) or obj.vertex_groups.new(name=b)
                        group.add([v.index],w,'REPLACE')
        elif obj.data.vertices:
            obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,'REPLACE')
