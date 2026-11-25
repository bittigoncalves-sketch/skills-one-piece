"""Quatro bestas marinhas com pele, armature e exportacao reproduzivel.

blender -b --python tools/blender/bestas_mar.py [-- bovina|girafa|javali|serpente]
Coordenadas autorais: Z cima, +Y frente; glTF/Godot: Y cima, -Z frente.
Referencias: imagens fornecidas pelo usuario em 01/10/2026. Cor do javali e
anatomia abaixo da linha d'agua sao interpretacoes. Nenhum asset externo.
"""
import bpy
import bmesh
import json
import math
import shutil
import sys
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art_src/bestas_mar'
OUT.mkdir(parents=True, exist_ok=True)
PARTS = []
RIG = None
TAU = math.tau


def material(name, color, rough=.7, metallic=0):
    # Paleta autoral em sRGB, como os PNG. Principled recebe valores lineares.
    color=tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in color)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Specular IOR Level'].default_value = .25
    return m


def texture(kind, head=False):
    """Atlas deterministico: manchas organicas, rede da girafa, arcos de escamas."""
    n = 1024
    v, u = np.mgrid[0:n, 0:n].astype(np.float32) / n
    wave = (np.sin(u*TAU*5 + np.sin(v*TAU*3)*1.3)
            + .62*np.cos(v*TAU*7 + np.sin(u*TAU*4)*1.4)
            + .32*np.sin((u+v)*TAU*13))
    palettes = {'bovina': ((.88,.9,.78),(.07,.33,.22)),
                'girafa': ((.86,.77,.37),(.39,.30,.105)),
                'javali': ((.64,.67,.55),(.40,.45,.36)),
                'serpente': ((.24,.245,.215),(.16,.17,.155))}
    base, patch = [np.array(c) for c in palettes[kind]]
    rgb = np.ones((n,n,3),np.float32)*base
    if kind == 'bovina':
        mask = np.clip((wave-.28)*18,0,1)
        rgb = rgb*(1-mask[...,None]) + patch*mask[...,None]
    elif kind == 'girafa':
        # Voronoi irregular com espaco creme entre placas, continuo na costura U.
        rng = np.random.default_rng(271)
        d1 = np.ones((n,n),np.float32)*10
        d2 = d1.copy()
        for j in range(9 if not head else 5):
            for i in range(9):
                px = (i+.5+rng.uniform(-.3,.3))/9
                py = (j+.5+rng.uniform(-.3,.3))/(9 if not head else 5)
                dx = np.abs(u-px)
                dx = np.minimum(dx, 1-dx)
                d = np.sqrt(dx*dx + ((v-py)*.8)**2)
                lower = d<d1
                d2 = np.where(lower,d1,np.minimum(d2,d))
                d1 = np.minimum(d1,d)
        mask = np.clip((.026-d1)*180,0,1) if head else np.clip((d2-d1-.009)*220,0,1)
        rgb = rgb*(1-mask[...,None])+patch*mask[...,None]
    elif kind == 'serpente':
        rgb *= (1+wave[...,None]*.07)
    # theta = 2pi*u, front +Y = u .25. Belly panel with scalloped scales.
    belly_width={'bovina':.145,'girafa':.045,'javali':.5,'serpente':.065}[kind]
    belly = np.clip((belly_width-np.abs(u-.25))*70,0,1) if not head else np.zeros_like(u)
    if kind == 'javali' and not head:
        belly = np.ones_like(u)
    rows = 29 if not head else 12
    yy = v*rows
    xx = (u*18 + (np.floor(yy)%2)*.5)%1 - .5
    arc = .8 - .65*np.sqrt(np.maximum(0,1-(xx*2)**2))
    line = np.exp(-((yy%1-arc)/.040)**2)
    scale_color = {'bovina':(.40,.435,.38), 'girafa':(.64,.61,.30),
                   'javali':(.74,.76,.64),'serpente':(.29,.30,.255)}[kind]
    sc = np.ones_like(rgb)*np.array(scale_color)
    sc *= (1-.43*line[...,None])
    if kind=='serpente':
        sc=np.ones_like(rgb)*np.array(scale_color)*(1-.18*np.exp(-((yy%1-.05)/.035)**2))[...,None]
    rgb = rgb*(1-belly[...,None])+sc*belly[...,None]
    rgba = np.concatenate([np.clip(rgb,0,1),np.ones((n,n,1))],axis=2).astype(np.float32)
    image = bpy.data.images.new(f'{kind}_{"cabeca" if head else "pele"}',width=n,height=n)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(OUT / (image.name+'.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    m = material(image.name,(1,1,1))
    tex = m.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    m.node_tree.links.new(tex.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    return m


def finish(obj, mat, weights):
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth=True
    if isinstance(weights,str):
        obj.vertex_groups.new(name=weights).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    else:
        for i, ws in enumerate(weights):
            for name, w in ws.items():
                g = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
                if w>1e-6:
                    g.add([i],w,'REPLACE')
    PARTS.append(obj)
    return obj


def mesh(name, verts, faces, mat, weights, uv=None):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    if uv:
        layer=data.uv_layers.new(name='UVMap')
        for poly in data.polygons:
            us=[uv[data.loops[i].vertex_index][0] for i in poly.loop_indices]
            seam=max(us)-min(us)>.5
            for i in poly.loop_indices:
                a,b=uv[data.loops[i].vertex_index]
                layer.data[i].uv=(a+1 if seam and a<.5 else a,b)
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(data); bm.free()
    return finish(obj,mat,weights)


def ellipsoid(name, loc, scale, mat, bone='cabeca', rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    if rot: o.rotation_euler=rot
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,mat,bone)


def spline(points, steps=5):
    result=[]
    ps=[np.array(p,dtype=float) for p in points]
    for i in range(len(ps)-1):
        a,b,c,d=ps[max(i-1,0)],ps[i],ps[i+1],ps[min(i+2,len(ps)-1)]
        for k in range(steps):
            t=k/steps
            p=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
            result.append((p,i+t))
    result.append((ps[-1],len(ps)-1))
    return result


def tube(name, points, radii, mat, bone='cabeca', sides=16):
    rows=spline([(*p,r) for p,r in zip(points,radii)],5)
    vs=[]; fs=[]; uv=[]
    for i,(p,t) in enumerate(rows):
        tangent=Vector(rows[min(i+1,len(rows)-1)][0][:3])-Vector(rows[max(0,i-1)][0][:3])
        tangent.normalize()
        axis=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))
        x=tangent.cross(axis).normalized(); y=tangent.cross(x).normalized()
        for j in range(sides):
            q=Vector(p[:3])+float(max(p[3],.002))*(x*math.cos(TAU*j/sides)+y*math.sin(TAU*j/sides))
            vs.append(q); uv.append((j/sides,i/(len(rows)-1)))
            if i>0: fs.append(((i-1)*sides+j,(i-1)*sides+(j+1)%sides,i*sides+(j+1)%sides,i*sides+j))
    fs.extend([tuple(reversed(range(sides))),tuple((len(rows)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,mat,bone,uv)


def bone(name,head,tail,parent=None):
    b=RIG.data.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=RIG.data.edit_bones[parent]
    return b


def rig_and_body(kind, mat):
    global RIG
    height={'bovina':10.6,'girafa':14.0,'javali':10.4,'serpente':13.6}[kind]
    width={'bovina':2.05,'girafa':1.65,'javali':2.6,'serpente':1.9}[kind]
    # Espinha do extremo da cauda ate a nuca, com curva continua abaixo d'agua.
    pts=[(0,-10,.55,.035,.06),(.4,-8.5,.7,.30,.35),(.65,-6.6,1.1,.65,.68),
         (.35,-4.5,1.55,1.18,1.05),(0,-2.3,2.15,width*.90,1.55),
         (0,-.9,3.7,width,1.72),(0,-.4,height*.47,width*.91,1.6),
         (0,-.55,height*.65,width*.76,1.35),(0,-.5,height*.82,width*.64,1.1),
         (0,0,height,width*.63,1.03)]
    if kind=='serpente':
        pts[6]=(0,-.7,height*.47,width*1.08,1.8)
        pts[7]=(0,-1.8,height*.65,width*1.02,1.65)
        pts[8]=(0,-1.5,height*.84,width*.87,1.52)
        pts[9]=(0,0,height,width*.81,1.32)
    elif kind=='girafa':
        pts[6]=(0,-.75,height*.47,width*.93,1.48)
        pts[7]=(0,-1.2,height*.65,width*.76,1.25)
        pts[8]=(0,-.9,height*.82,width*.64,1.08)
    bpy.ops.object.armature_add()
    RIG=bpy.context.object; RIG.name='Esqueleto_'+kind
    bpy.ops.object.mode_set(mode='EDIT')
    RIG.data.edit_bones.remove(RIG.data.edit_bones[0])
    bone('raiz',(0,0,0),(0,0,1))
    names=['cauda_04','cauda_03','cauda_02','cauda_01','corpo','pescoco_01','pescoco_02','pescoco_03','pescoco_04','pescoco_05']
    bone('corpo',pts[4][:3],pts[5][:3],'raiz')
    for i in range(3,-1,-1): bone(names[i],pts[i][:3],pts[max(i-1,0)][:3] if i else (0,-10.5,.6),names[i+1])
    for i in range(5,10): bone(names[i],pts[i][:3],pts[min(i+1,9)][:3] if i<9 else (0,.1,height+.5),names[i-1])
    bone('cabeca',(0,0,height),(0,1.5,height+.5),'pescoco_05')
    bone('mandibula',(0,.2,height-.2),(0,1.7,height-.65),'cabeca')
    for sign,label in [(1,'R'),(-1,'L')]:
        bone('nadadeira_'+label,(sign*width*.7,-.8,3.8),(sign*3.3,-1.4,2.9),'pescoco_01')
        bone('ponta_nadadeira_'+label,(sign*3.3,-1.4,2.9),(sign*4.8,-2.1,2.3),'nadadeira_'+label)
    bpy.ops.object.mode_set(mode='OBJECT')
    RIG.show_in_front=True; RIG.data.display_type='OCTAHEDRAL'
    rows=spline(pts,7); vs=[]; fs=[]; uv=[]; weights=[]; sides=64
    for i,(p,t) in enumerate(rows):
        tangent=Vector(rows[min(i+1,len(rows)-1)][0][:3])-Vector(rows[max(i-1,0)][0][:3])
        tangent.normalize()
        normal=Vector((1,0,0)).cross(tangent).normalized()
        # Normal points front at neck; ring theta .25 is belly.
        normal=-normal
        left=int(t); right=min(left+1,len(names)-1); f=t-left
        for j in range(sides):
            theta=TAU*j/sides
            q=Vector(p[:3])+Vector((1,0,0))*float(p[3]*math.cos(theta))+normal*float(p[4]*math.sin(theta))
            vs.append(q); uv.append((j/sides,t/(len(pts)-1)))
            weights.append({names[left]:1-f,names[right]:f} if left!=right else {names[left]:1})
            if i: fs.append(((i-1)*sides+j,i*sides+j,i*sides+(j+1)%sides,(i-1)*sides+(j+1)%sides))
    fs.extend([tuple(reversed(range(sides))),tuple((len(rows)-1)*sides+j for j in range(sides))])
    mesh('Corpo_continuo',vs,fs,mat,weights,uv)
    return height,width


def fin(name, root, tip, span, mat, ribmat, bone_name):
    # Superficie de espessura real; borda ondulada e nervuras em relevo.
    a=Vector(root); b=Vector(tip)
    direction=(b-a).normalized(); side=direction.cross(Vector((0,0,1))).normalized()
    if side.length<.1: side=Vector((1,0,0))
    vs=[]; faces=[]
    for layer in [-1,1]:
        for i in range(13):
            t=i/12; center=a.lerp(b,t)
            w=span*math.sin(math.pi*t)**.75*(1-.38*t)
            for j in range(9):
                s=j/4-1
                vs.append(center+side*w*s+Vector((0,0,layer*.045*math.sin(math.pi*t)+.16*(1-s*s)*math.sin(math.pi*t))))
    count=13*9
    for l in range(2):
        for i in range(12):
            for j in range(8):
                x=l*count+i*9+j; faces.append((x,x+1,x+10,x+9))
    for i in range(12):
        for j in [0,8]:
            x=i*9+j; faces.append((x,x+9,x+9+count,x+count))
    mesh(name,vs,faces,mat,bone_name)
    for s in [-.75,-.35,.1,.55]:
        points=[]
        for t in [.02,.25,.5,.75,.98]:
            w=span*math.sin(math.pi*t)**.75*(1-.38*t)
            points.append(a.lerp(b,t)+side*w*s+Vector((0,0,.10)))
        tube(name+'_nervura',points,[.025,.045,.035,.02,.006],ribmat,bone_name,8)


def eyes(h, x, y, zoff, mats, style='bovina'):
    rx,rz={'bovina':(.33,.37),'girafa':(.26,.15),'javali':(.33,.19),'serpente':(.255,.10)}[style]
    for s in [-1,1]:
        loc=(s*x,y,h+zoff)
        ellipsoid('Orbita',loc,(rx+.055,.105,rz+.045),mats['dark'])
        ellipsoid('Esclera',(s*x,y+.06,h+zoff),(rx,.078,rz),mats['red'] if style=='serpente' else mats['eye'])
        ellipsoid('Pupila',(s*(x-.04),y+.135,h+zoff-.025),(.065 if style!='bovina' else .115,.025,rz*.73),mats['dark'])
        if style=='bovina':
            ellipsoid('Brilho',(s*(x-.07),y+.16,h+zoff+.055),(.028,.01,.033),mats['eye'])
        brow=[(s*(x-rx-.07),y-.015,h+zoff+rz*.55),(s*x,y-.06,h+zoff+rz+.10),(s*(x+rx+.06),y-.20,h+zoff+rz+.14)]
        tube('Arco_orbital',brow,[.075,.14,.055],mats['skin'])


def skull(name,rows,mat,bone_name='cabeca'):
    vs=[]; fs=[]; uv=[]; rs=spline(rows,5); sides=48
    for i,(p,t) in enumerate(rs):
        for j in range(sides):
            th=TAU*j/sides
            a=math.cos(th); b=math.sin(th)
            vs.append((p[2]*math.copysign(abs(a)**.83,a),p[0],p[1]+p[3]*math.copysign(abs(b)**.88,b)))
            uv.append((j/sides,t/(len(rows)-1)))
            if i: fs.append(((i-1)*sides+j,i*sides+j,i*sides+(j+1)%sides,(i-1)*sides+(j+1)%sides))
    fs.extend([tuple(reversed(range(sides))),tuple((len(rs)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,mat,bone_name,uv)


def dental_arch(rows,mat,jaw=False):
    # Raiz de cada dente na superficie real do cranio/mandibula, sem flutuar
    # nos extremos afilados como ocorria com uma fileira linear de cones.
    for s in [-1,1]:
        for i in range(10):
            t=(i+(.42 if jaw else 0))/10
            y=.35+t*2.72
            z=float(np.interp(y,[p[0] for p in rows],[p[1] for p in rows]))
            w=float(np.interp(y,[p[0] for p in rows],[p[2] for p in rows]))
            r=float(np.interp(y,[p[0] for p in rows],[p[3] for p in rows]))
            x=s*w*.89
            z+=r*.59 if jaw else -r*.54
            size=(.27+.24*math.sin(t*math.pi)+(.10 if i%3==1 else 0))*(.85 if jaw else 1)
            end=z+size if jaw else z-size
            tube('Dente_inferior' if jaw else 'Dente_superior',[(x,y,z),(x*.98,y-.01,(z+end)/2),(x*.94,y+.09,end)], [.105,.068,.003],mat,'mandibula' if jaw else 'cabeca',12)


def teeth(h, length, width, mats, count=10, jaw=False):
    for s in [-1,1]:
        for i in range(count):
            t=i/(count-1)
            y=.30+(t+(.045 if jaw else 0))*length
            x=s*width*(1-.5*t)
            z=h-.30-.13*t
            size=.32+.26*math.sin(t*math.pi)+(.11 if i%3==1 else 0)
            if jaw: z-=.77; end=z+size
            else: end=z-size
            tube('Dente',[(x,y,z),(x*.95,y+.035,(z+end)/2),(x*.91,y+.12,end)], [.105,.065,.004],mats['ivory'],'mandibula' if jaw else 'cabeca',12)


def build_head(kind,h,w,m):
    skin=m['head']; plain=m['skin']
    if kind=='bovina':
        ellipsoid('Cranio_bovino',(0,.15,h+.75),(1.83,1.20,1.75),skin)
        ellipsoid('Mandibula',(0,1.10,h-.42),(1.18,.88,.50),plain,'mandibula')
        ellipsoid('Focinho_rosado',(0,1.38,h+.07),(1.26,.70,.82),m['pink'])
        for s in [-1,1]:
            ellipsoid('Narina',(s*.50,2.015,h+.15),(.19,.04,.25),m['dark'],rot=(0,s*.3,0))
            tube('Chifre',[(s*1.38,-.03,h+1.65),(s*2.05,-.13,h+2.12),(s*2.44,-.1,h+2.92),(s*2.15,.02,h+3.52)], [.42,.33,.20,.007],m['ivory'])
            ellipsoid('Orelha',(s*2.03,.1,h+1.04),(.81,.30,.35),plain,rot=(0,s*.20,0))
            ellipsoid('Orelha_interna',(s*2.10,.37,h+1.06),(.53,.045,.19),m['pink'])
        eyes(h,.78,1.15,1.03,m)
        # Argola no plano XZ, aberta visualmente no topo por estar dentro do focinho.
        pts=[(.57*math.cos(t),2.02,h-.32+.64*math.sin(t)) for t in np.linspace(math.pi*.80,math.pi*2.20,36)]
        tube('Argola_dourada',pts,[.13]*len(pts),m['gold'])
        tube('Linha_boca',[(-.8,1.72,h-.57),(0,1.89,h-.72),(.8,1.72,h-.57)],[.045]*3,m['dark'],'mandibula')
    elif kind=='girafa':
        skull('Cranio_girafa',[(-.95,h+.8,.45,.90),(-.35,h+.83,1.07,1.58),
            (.40,h+.55,.90,1.33),(1.35,h-.10,.66,.81),(2.22,h-.49,.77,.51),
            (2.67,h-.55,.68,.40),(2.76,h-.55,.12,.15)],skin)
        ellipsoid('Interior_boca',(0,1.27,h-.96),(.82,1.39,.38),m['mouth'])
        ellipsoid('Mandibula',(0,1.22,h-1.29),(.78,1.47,.30),plain,'mandibula')
        ellipsoid('Focinho',(0,2.40,h-.47),(.80,.46,.45),plain)
        eyes(h,.79,.69,.83,m,'girafa')
        for s in [-1,1]:
            ellipsoid('Narina',(s*.39,2.78,h-.33),(.20,.045,.105),m['dark'],rot=(0,s*.3,0))
            tube('Chifre_coroa',[(s*.64,-.20,h+1.72),(s*.85,-.22,h+2.43),(s*.64,-.37,h+3.15)],[.29,.19,.005],plain)
            tube('Chifre_lateral',[(s*.86,-.20,h+1.47),(s*1.8,-.18,h+1.74),(s*2.40,-.36,h+2.43)],[.33,.27,.004],plain)
            tube('Orelha',[(s*.95,-.20,h+1.03),(s*1.57,-.32,h+.92),(s*1.92,-.62,h+1.26)],[.16,.31,.004],plain)
            # Molares curtos e largos dentro de uma boca aberta, como na imagem.
            for i in range(8):
                t=i/7; y=.32+t*2.0; x=s*(.78-.17*t)
                ellipsoid('Molar',(x,y,h-.77-t*.07),(.145,.145,.21),m['ivory'])
        # Crina posterior: mechas afiladas seguem o pescoco sem preencher a frente.
        for i in range(21):
            t=i/20; z=4.6+t*(h-3.4); y=-1.95+t*.75
            b='pescoco_%02d'%min(5,max(1,int(t*4)+1))
            tube('Mecha_crina',[(0,y,z),(0,y-.85,z-.05),(0,y-1.65,z-1.10)], [.26,.32,.007],m['mane'],b,12)
            for s in [-1,1]:
                tube('Mecha_lateral',[(s*.86,y+.33,z),(s*1.35,y-.15,z-.42),(s*1.55,y-.75,z-1.30)], [.20,.27,.005],m['mane'],b,12)
        for s in [-1,1]:
            for i in range(5):
                x=s*(.18+.17*i)
                tube('Barba',[(x,1.4,h-1.40),(x*1.08,1.38,h-1.80),(x*1.12,1.30,h-2.60+i*.16)],[.08,.085,.003],m['mane'],'mandibula',10)
    elif kind=='javali':
        ellipsoid('Cranio_javali',(0,.1,h+.7),(2.05,1.31,1.65),skin)
        ellipsoid('Mandibula',(0,1.14,h-.43),(1.62,.98,.63),plain,'mandibula')
        ellipsoid('Focinho',(0,1.75,h+.38),(1.30,.73,.87),plain)
        ellipsoid('Disco_nasal',(0,2.32,h+.47),(1.13,.28,.69),m['pink'])
        for s in [-1,1]:
            ellipsoid('Narina',(s*.43,2.585,h+.51),(.235,.055,.28),m['dark'])
            tube('Presa_maior',[(s*1.2,1.22,h-.4),(s*2.15,1.60,h-.10),(s*2.62,1.68,h+.84),(s*2.56,1.55,h+1.50)], [.38,.29,.17,.004],m['ivory'],'mandibula')
            tube('Presa_menor',[(s*1.65,.6,h+.26),(s*2.34,.9,h+.67),(s*2.34,.93,h+1.34)], [.28,.20,.004],m['ivory'])
            tube('Orelha',[(s*1.30,-.04,h+1.70),(s*1.62,-.04,h+2.22),(s*1.97,-.21,h+2.72)], [.27,.42,.006],plain)
            tube('Orelha_interna',[(s*1.40,.19,h+1.87),(s*1.66,.26,h+2.22),(s*1.90,.05,h+2.60)], [.11,.19,.003],m['pink'])
            for i in range(11):
                f=i/10
                tube('Bigode',[(s*(.50+f*.82),1.91-f*.3,h-.29-f*.12),(s*(.80+f*1.28),2.0-f*.37,h-.68-f*.12),(s*(1.15+f*1.47),1.73-f*.4,h-.92+f*.46)], [.09,.12,.003],m['ivory'],'mandibula',10)
            for i in range(6):
                x=s*(.12+i*.20)
                tube('Barba',[(x,1.53,h-.78),(x*1.15,1.57,h-1.2),(x*1.2,1.42,h-1.55+i*.055)],[.1,.11,.004],m['ivory'],'mandibula',10)
        eyes(h,1.14,1.03,1.17,m,'javali')
        for i in range(7):
            x=(i-3)*.21
            tube('Crista',[(x,-.25,h+1.78),(x*1.05,-.37,h+2.46),(x*1.08,-.7,h+2.91-abs(i-3)*.12)], [.20,.19,.004],m['mane'])
    else:
        # Crânio alongado e focinho angular; seção real, sem encaixe de caixas.
        rows=[(-1.2,h+.65,.50,.80),(-.7,h+.65,1.42,1.43),(.15,h+.50,1.65,1.49),
              (.86,h+.17,1.36,1.07),(1.70,h-.27,.96,.69),(2.55,h-.42,.77,.51),
              (3.14,h-.43,.68,.45),(3.24,h-.43,.25,.29)]
        skull('Cranio_serpente',rows,skin)
        ellipsoid('Interior_boca',(0,1.36,h-.78),(1.11,1.61,.22),m['mouth'])
        jaw_rows=[(-.38,h-1.10,.34,.25),(.0,h-1.13,1.20,.31),(.55,h-1.17,1.37,.28),
                  (1.35,h-1.25,1.15,.24),(2.15,h-1.30,.85,.23),(2.87,h-1.29,.71,.22),
                  (3.24,h-1.23,.60,.20),(3.39,h-1.20,.08,.10)]
        skull('Mandibula',jaw_rows,plain,'mandibula')
        eyes(h,.96,1.07,.43,m,'serpente')
        dental_arch(rows,m['ivory']); dental_arch(jaw_rows,m['ivory'],True)
        for s in [-1,1]:
            ellipsoid('Narina',(s*.48,3.02,h-.16),(.12,.095,.085),m['dark'])
            tube('Crista_orbital',[(s*.73,1.04,h+.47),(s*1.02,.60,h+1.0),(s*1.22,-.30,h+1.62)], [.15,.31,.12],plain)
            tube('Ruga_testa',[(s*.25,1.04,h+.86),(s*.46,.68,h+1.27),(s*.38,.10,h+1.9)],[.02,.045,.015],m['dark'])
            tube('Sulco_face',[(s*.64,2.32,h+.05),(s*.94,1.50,h+.25),(s*1.29,.78,h+.55)],[.018,.025,.012],m['dark'])
        # Nadadeira sagital alta na nuca, com membrana e raios claros.
        verts=[]; faces=[]
        for x in [-.065,.065]:
            verts.extend([(x,-.6,h+1.65),(x,-.50,h+4.0),(x,-2.1,h+1.62),(x,-2.45,h-.6),(x,-1.6,h-2.0)])
        faces=[(0,1,2,3,4),(9,8,7,6,5),(0,5,6,1),(1,6,7,2),(2,7,8,3),(3,8,9,4),(4,9,5,0)]
        mesh('Nadadeira_dorsal_cabeca',verts,faces,m['fin'],'cabeca')
        for j in range(7):
            t=j/6
            tube('Raio_dorsal',[(.074,-.62-t*.98,h+1.4-t*3.0),(.074,-.54-t*1.67,h+3.70-t*4.1)],[.04,.035],m['fin_dark'])


def animate():
    RIG.animation_data_create()
    for name in ['repouso','ameaca']:
        action=bpy.data.actions.new(name)
        RIG.animation_data.action=action
        for frame in range(1,82,4):
            t=(frame-1)/80*TAU
            for b in RIG.pose.bones:
                b.rotation_mode='XYZ'; b.rotation_euler=(0,0,0)
                if b.name.startswith('pescoco_'): b.rotation_euler.y=.018*math.sin(t+int(b.name[-2:])*.45)
                if b.name.startswith('cauda_'): b.rotation_euler.x=.085*math.sin(t-int(b.name[-2:])*.65)
                if 'nadadeira' in b.name: b.rotation_euler.y=.07*math.sin(t)*(-1 if b.name.endswith('L') else 1)
                if name=='ameaca':
                    phase=math.sin((frame-1)/80*math.pi)**2
                    if b.name=='mandibula': b.rotation_euler.x=-.42*phase
                    if b.name=='cabeca': b.rotation_euler.x=.10*phase
                b.keyframe_insert(data_path='rotation_euler',frame=frame,group=b.name)
        track=RIG.animation_data.nla_tracks.new(); track.name=name
        track.strips.new(name,1,action)
        RIG.animation_data.action=None
    for tr in RIG.animation_data.nla_tracks: tr.mute=True
    for b in RIG.pose.bones: b.rotation_euler=(0,0,0)


def generate(kind):
    global PARTS
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    PARTS=[]
    colors={'bovina':(.76,.83,.70),'girafa':(.71,.66,.30),'javali':(.65,.69,.57),'serpente':(.23,.25,.22)}
    m={'body':texture(kind),'head':texture(kind,True),'skin':material('Pele_'+kind,colors[kind]),
       'dark':material('Tinta_contornos',(.016,.024,.022)), 'eye':material('Olhos_marfin',(.96,.96,.87),.3),
       'red':material('Olhos_carmim',(.62,.022,.048),.38), 'pink':material('Focinho_interior',(.68,.40,.31) if kind=='bovina' else (.50,.49,.39)),
       'ivory':material('Marfim',(.87,.84,.65),.48),'gold':material('Ouro_argola',(.73,.51,.09),.27,.72),
       'mane':material('Crina',(.47,.29,.105) if kind=='girafa' else (.33,.37,.28)),
       'fin':material('Membrana',(.43,.70,.72) if kind=='serpente' else colors[kind]),
       'fin_dark':material('Nervuras',(.10,.27,.30) if kind=='serpente' else (.22,.33,.26)),
       'mouth':material('Boca_sombra',(.105,.035,.031))}
    h,w=rig_and_body(kind,m['body'])
    build_head(kind,h,w,m)
    for s,label in [(-1,'L'),(1,'R')]:
        fin('Nadadeira_'+label,(s*w*.75,-.8,3.8),(s*(w+3.4),-2.6,2.0),1.12,m['fin'],m['fin_dark'],'nadadeira_'+label)
        fin('Cauda_lobo_'+label,(0,-8.35,.74),(s*1.70,-10.6,.94),.61,m['fin'],m['fin_dark'],'cauda_03')
    # Una todas as superficies: nomes dos grupos e materiais sobrevivem ao join.
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS: o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    obj=bpy.context.object; obj.name='Pele_'+kind
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    obj.parent=RIG
    mod=obj.modifiers.new('Deformacao_esqueleto','ARMATURE'); mod.object=RIG
    # Pontas das nadadeiras recebem mistura, evitando membro rigido no rig.
    for s,label in [(-1,'L'),(1,'R')]:
        base=obj.vertex_groups.get('nadadeira_'+label)
        end=obj.vertex_groups.new(name='ponta_nadadeira_'+label)
        for v in obj.data.vertices:
            if any(g.group==base.index for g in v.groups):
                f=max(0,min(1,(abs(v.co.x)-2.7)/2.2))
                base.add([v.index],1-f,'REPLACE'); end.add([v.index],f,'REPLACE')
    animate()
    scene=bpy.context.scene; scene.render.fps=24; scene.frame_start=1; scene.frame_end=81; scene.frame_set(1)
    bpy.context.view_layer.update()
    # Mede integridade, incluindo resposta de vertices a uma pose da mandibula.
    bad=sum(abs(sum(g.weight for g in v.groups)-1)>.0001 for v in obj.data.vertices)
    assert not bad, f'{bad} vertices sem pesos normalizados'
    deps=bpy.context.evaluated_depsgraph_get()
    rest=[v.co.copy() for v in obj.evaluated_get(deps).data.vertices]
    RIG.pose.bones['mandibula'].rotation_euler.x=-.35
    bpy.context.view_layer.update()
    posed=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    displacement=max((v.co-rest[i]).length for i,v in enumerate(posed.data.vertices))
    assert displacement>.1, 'Mandibula nao deforma a pele'
    RIG.pose.bones['mandibula'].rotation_euler.x=0; bpy.context.view_layer.update()
    bounds=[obj.matrix_world @ Vector(v) for v in obj.bound_box]
    metrics={'vertices':len(obj.data.vertices),'triangulos':sum(len(p.vertices)-2 for p in obj.data.polygons),
             'ossos':len(RIG.data.bones),'vertices_pesos_invalidos':bad,'mandibula_deslocamento_m':displacement,
             'dimensoes_blender_xyz':[max(p[i] for p in bounds)-min(p[i] for p in bounds) for i in range(3)],
             'clips':['repouso','ameaca']}
    (OUT/f'{kind}_medidas.json').write_text(json.dumps(metrics,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); RIG.select_set(True)
    bpy.context.view_layer.objects.active=RIG
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'besta_mar_{kind}.blend'))
    for tr in RIG.animation_data.nla_tracks: tr.mute=False
    dest=OUT/f'besta_mar_{kind}.glb'
    bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,
        export_force_sampling=True,export_skins=True,export_yup=True,export_apply=False,
        export_rest_position_armature=True)
    shutil.copy2(dest,ROOT/'mapas/modelos'/dest.name)
    print('BESTA_EXPORTADA',kind,json.dumps(metrics))


if __name__=='__main__':
    selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for kind in selected or ['bovina','girafa','javali','serpente']:
        generate(kind)
