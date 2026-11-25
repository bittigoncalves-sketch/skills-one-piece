"""Reconstrução autoral local. Nenhuma dependência de repositórios ou serviços.

Executar pelo terminal do Codex, com Blender local em factory-startup.
Todas as formas orgânicas são superfícies contínuas construídas neste arquivo.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix
from mathutils.geometry import tessellate_polygon

ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--personagem',choices=['david','rebecca'],required=True)
parser.add_argument('--render',action='store_true')
parser.add_argument('--close',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
PARTS=[]
M={}


def mat(name,color,metal=0,rough=.55):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal
    bs.inputs['Roughness'].default_value=rough
    M[name]=m


for name,color,metal in [
    ('pele',(0.53,.275,.22),0),('pele_r',(.58,.68,.64),0),
    ('jaqueta',(.95,.61,.012),.05),('faixa',(.43,.62,.60),.15),
    ('interior',(.095,.25,.45),.1),('pano',(.055,.105,.15),0),
    ('preto',(.014,.019,.027),0),('cabelo',(.018,.010,.016),0),
    ('menta',(.34,.64,.51),0),('cabelo_sombra',(.20,.42,.33),0),
    ('aco',(.22,.26,.30),.65),('aco_claro',(.48,.56,.58),.7),
    ('borracha',(.027,.033,.041),0),('azul',(.024,.09,.40),.35),
    ('azul_luz',(.055,.20,.62),.25),('rosa',(.61,.075,.245),0),
    ('branco',(.80,.83,.77),0),('iris',(.12,.075,.035),0),
    ('laranja',(.95,.23,.024),.1),('ouro',(.67,.39,.09),.6),
    ('base',(.08,.10,.12),.2)]: mat(name,color,metal)


def mesh(name,vs,fs,material,smooth=True,sub=0):
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    me.materials.append(M[material])
    for p in me.polygons: p.use_smooth=smooth
    if sub:
        mod=o.modifiers.new('Refinamento da superfície','SUBSURF'); mod.levels=sub
    PARTS.append(o); return o


def interp(rings,z):
    if z<=rings[0][0]: return rings[0][1:]
    if z>=rings[-1][0]: return rings[-1][1:]
    i=next(i for i in range(len(rings)-1) if rings[i][0]<=z<=rings[i+1][0])
    a,b=rings[i],rings[i+1]; t=(z-a[0])/(b[0]-a[0]); result=[]
    for j in range(1,len(a)):
        p=rings[max(0,i-1)]; q=rings[min(len(rings)-1,i+2)]
        m0=(b[j]-p[j])/(b[0]-p[0]); m1=(q[j]-a[j])/(q[0]-a[0])
        value=(2*t**3-3*t*t+1)*a[j]+(t**3-2*t*t+t)*(b[0]-a[0])*m0
        value+=(-2*t**3+3*t*t)*b[j]+(t**3-t*t)*(b[0]-a[0])*m1
        result.append(value)
    return result


def g(v,c,s): return math.exp(-((v-c)/s)**2)


def skin(name,rings,material,detail=None,nz=100,nt=96):
    """Anéis z,cx,cy,rx,ry interpolados; detalhes deslocam a própria superfície."""
    vs=[]; fs=[]
    for i in range(nz+1):
        z=rings[0][0]+(rings[-1][0]-rings[0][0])*i/nz
        cx,cy,rx,ry=interp(rings,z)
        for j in range(nt):
            t=j*math.tau/nt; x=cx+rx*math.cos(t); y=cy+ry*math.sin(t)
            if detail: x,y,z1=detail(x,y,z,t,cx,cy,rx,ry)
            else: z1=z
            vs.append((x,y,z1))
    for i in range(nz):
        for j in range(nt):
            a=i*nt+j; b=i*nt+(j+1)%nt; fs.append((a,b,b+nt,a+nt))
    fs.append(tuple(reversed(range(nt))))
    fs.append(tuple(nz*nt+j for j in range(nt)))
    return mesh(name,vs,fs,material)


def curve(name,pts,r,material,radii=None):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=10
    c.bevel_depth=r; c.bevel_resolution=3; c.use_fill_caps=True
    s=c.splines.new('BEZIER'); s.bezier_points.add(len(pts)-1)
    for i,(p,co) in enumerate(zip(s.bezier_points,pts)):
        p.co=co; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
        if radii: p.radius=radii[i]
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o)
    o.data.materials.append(M[material]); PARTS.append(o); return o


def sphere(name,co,scale,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=co)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    o.data.materials.append(M[material]); PARTS.append(o); return o


def panel(name,outline,depth,material,bevel=.2):
    n=len(outline); vs=[(x,y-depth/2,z) for x,y,z in outline]+[(x,y+depth/2,z) for x,y,z in outline]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    fs.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    o=mesh(name,vs,fs,material,smooth=False)
    if bevel:
        b=o.modifiers.new('Chanfro físico','BEVEL'); b.width=bevel; b.segments=3
        b=o.modifiers.new('Normais dos painéis','WEIGHTED_NORMAL')
    return o


def box(name,co,dim,material,bevel=.25):
    x,y,z=co; w,d,h=dim
    return panel(name,[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),
                      (x+w/2,y,z+h/2),(x-w/2,y,z+h/2)],d,material,bevel)


def swept(name,pts,widths,depths,material,nt=16):
    """Mecha ou dedo: seção lenticular, flexionada ao longo de uma trajetória."""
    # Amostragem densa preserva a trajetória e as pontas. Subdividir apenas
    # quatro seções encurtava as mechas e transformava as curvas em lóbulos.
    controls=[(*p,w,d) for p,w,d in zip(pts,widths,depths)]
    samples=[]
    for i in range(len(controls)-1):
        p0=controls[max(0,i-1)];p1=controls[i];p2=controls[i+1];p3=controls[min(len(controls)-1,i+2)]
        for k in range(6):
            t=k/6
            row=[.5*((2*p1[j])+(-p0[j]+p2[j])*t+(2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*t*t+
                 (-p0[j]+3*p1[j]-3*p2[j]+p3[j])*t*t*t) for j in range(5)]
            row[3]=max(.07,row[3]);row[4]=max(.06,row[4]);samples.append(row)
    samples.append(controls[-1])
    pts=[p[:3] for p in samples];widths=[p[3] for p in samples];depths=[p[4] for p in samples]
    vs=[]; fs=[]
    for i,p in enumerate(pts):
        p=Vector(p)
        tangent=Vector(pts[min(len(pts)-1,i+1)])-Vector(pts[max(0,i-1)])
        tangent.normalize(); u=tangent.cross(Vector((0,1,0))).normalized()
        if u.length<.1: u=Vector((1,0,0))
        v=tangent.cross(u).normalized()
        for j in range(nt):
            t=j*math.tau/nt
            # Seção em lente com crista central, em vez de mechas cilíndricas.
            co=p+u*(math.cos(t)*widths[i])+v*(math.sin(t)*depths[i])
            vs.append(tuple(co))
    for i in range(len(pts)-1):
        for j in range(nt):
            a=i*nt+j; b=i*nt+(j+1)%nt; fs.append((a,b,b+nt,a+nt))
    fs.extend([tuple(reversed(range(nt))),tuple((len(pts)-1)*nt+j for j in range(nt))])
    return mesh(name,vs,fs,material,sub=1)


def patch(name,outline,material,surface,raise_by=.1,thickness=.3):
    """Marca/olho sobre superfície anatômica, com volume e sem esfera ocular saliente."""
    area=sum(outline[i][0]*outline[(i+1)%len(outline)][1]-
             outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))
    if area<0:outline=list(reversed(outline))
    vs=[];fs=[];lookup={};nr=10
    def vertex(x,z):
        key=(round(x,6),round(z,6))
        if key not in lookup:
            lookup[key]=len(vs);vs.append((x,surface(x,z)-raise_by,z))
        return lookup[key]
    polygon=[Vector((x,z,0)) for x,z in outline]
    for tri in tessellate_polygon([polygon]):
        a,b,c=[polygon[v] if isinstance(v,int) else v for v in tri]
        grid={}
        for i in range(nr+1):
            for j in range(nr-i+1):
                p=a+(b-a)*(i/nr)+(c-a)*(j/nr);grid[i,j]=vertex(p.x,p.y)
        for i in range(nr):
            for j in range(nr-i):
                fs.append((grid[i,j],grid[i+1,j],grid[i,j+1]))
                if j<nr-i-1:fs.append((grid[i+1,j],grid[i+1,j+1],grid[i,j+1]))
    o=mesh(name,vs,fs,material)
    s=o.modifiers.new('Relevo contínuo','SOLIDIFY'); s.thickness=thickness; s.offset=-1
    return o


def cloth_shell(name,rings,material,start=-.78,end=math.pi+.78,folds=.45):
    vs=[]; fs=[]; nz=110; nt=100
    for i in range(nz+1):
        z=rings[0][0]+(rings[-1][0]-rings[0][0])*i/nz
        cx,cy,rx,ry=interp(rings,z)
        for j in range(nt+1):
            t=start+(end-start)*j/nt
            wave=folds*(.5*math.cos(t*7+z*.13)+.3*math.sin(t*11-z*.18))
            x=cx+(rx+wave)*math.cos(t); y=cy+(ry+wave*.5)*math.sin(t)
            vs.append((x,y,z))
    for i in range(nz):
        for j in range(nt):
            a=i*(nt+1)+j; fs.append((a,a+1,a+nt+2,a+nt+1))
    o=mesh(name,vs,fs,material)
    sol=o.modifiers.new('Espessura do tecido','SOLIDIFY'); sol.thickness=1.3; sol.offset=0
    return o


def pedestal(label,radius):
    bpy.ops.mesh.primitive_cylinder_add(vertices=128,radius=radius,depth=3.6,location=(0,1,1.8))
    o=bpy.context.object; o.name='Base de apoio'; o.data.materials.append(M['base']); PARTS.append(o)
    b=o.modifiers.new('Borda da base','BEVEL'); b.width=.55; b.segments=3
    # Nome pequeno em placa integrada, sem competir com a figura.
    box('Identificação',(0,-radius+1.9,2),(29,3,3),'base',.4)
    bpy.ops.object.text_add(location=(0,-radius+.32,1.95),rotation=(math.pi/2,0,0))
    o=bpy.context.object; o.name='Nome'; o.data.body=label; o.data.align_x='CENTER'; o.data.align_y='CENTER'
    o.data.size=2.5; o.data.extrude=.18; o.data.bevel_depth=.035; o.data.materials.append(M['aco']); PARTS.append(o)


DAVID_HEAD=[(121,0,0,1.8,1.8),(123,0,.0,4.4,3.0),(126,0,.2,6.6,4.3),
            (130,0,.5,7.8,5.4),(134,0,.8,7.9,5.7),(138,0,1,7.1,5.7),
            (141,0,1.3,5.2,4.3),(142,0,1.3,.3,.3)]
REBECCA_HEAD=[(109,0,0,1.9,1.8),(111,0,0,4.2,3.1),(114,0,.3,6.4,4.6),
              (118,0,.7,8.0,5.8),(122,0,1,8.5,6.3),(127,0,1.3,7.8,6.0),
              (130,0,1.5,5.7,4.7),(131.3,0,1.5,.3,.3)]


def head_surface(x,z,r=False):
    rings=REBECCA_HEAD if r else DAVID_HEAD
    cx,cy,rx,ry=interp(rings,z)
    y=cy-ry*math.sqrt(max(0,1-(x/max(rx,.1))**2))
    nosez=117.5 if r else 129
    eyesz=121 if r else 132.7
    # Maçãs discretas, órbitas recuadas, ponte e ponta do nariz na mesma malha.
    y-=.45*(g(x,4.6,2.3)+g(x,-4.6,2.3))*g(z,nosez-1,2.0)
    y+=.6*(g(x,3.7,1.8)+g(x,-3.7,1.8))*g(z,eyesz,1.2)
    y-=1.1*g(x,0,.72)*g(z,nosez+1.7,2.5)
    y-=1.65*g(x,0,.95)*g(z,nosez,.7)
    y-=.32*(g(x,1,.5)+g(x,-1,.5))*g(z,nosez-.25,.45)
    y-=.25*g(x,0,1.8)*g(z,nosez-3,1.4)
    return y


def anime_head(r=False):
    start=len(PARTS); rings=REBECCA_HEAD if r else DAVID_HEAD
    material='pele_r' if r else 'pele'; nz=155; nt=160
    def shape(x,y,z,t,cx,cy,rx,ry):
        w=1 if math.sin(t)<0 else 0
        front=cy-ry*math.sqrt(max(0,1-(x/max(rx,.1))**2))
        y+=(head_surface(x,z,r)-front)*w
        return x,y,z
    skin('Rosto anime contínuo',rings,material,shape,nz,nt)
    surf=lambda x,z:head_surface(x,z,r)
    ez=121 if r else 132.7; nz0=117.5 if r else 129
    for side in [-1,1]:
        # Contornos angulosos; cantos externos levantados como nas referências.
        shape2=[(1.25,ez+.2),(2.7,ez+.55),(5.7,ez+1.45),(6.45,ez+1.3),
                (5.8,ez-.45),(3.4,ez-1.15),(1.8,ez-.6)]
        if r:
            shape2=[(1.1,ez+.1),(3,ez+.5),(6.25,ez+1.6),(6.8,ez+1.4),
                    (5.7,ez-1.1),(3.15,ez-1.55),(1.65,ez-.6)]
        outline=[(side*x,z) for x,z in shape2]
        patch('Área do olho',outline,'preto' if r else 'branco',surf,.12,.35)
        # Íris de superfície, com pupila física e leitura no monocromático.
        ix=side*3.65; iz=ez-.25
        iris=[(ix+.85*math.cos(t*math.tau/32),iz+(.95 if r else .82)*math.sin(t*math.tau/32)) for t in range(32)]
        patch('Íris',iris,'laranja' if r else 'iris',surf,.23,.32)
        pupil=[(ix+(.31 if r else .45)*math.cos(t*math.tau/24),iz+.64*math.sin(t*math.tau/24)) for t in range(24)]
        patch('Pupila',pupil,'preto',surf,.3,.30)
        sphere('Reflexo ocular',(ix-side*.18,surf(ix,iz)-.42,iz+.45),(.18,.12,.18),'branco')
        top=outline[:4]
        curve('Pálpebra superior',[(x,surf(x,z)-.2,z) for x,z in top],.22 if r else .18,'preto')
        low=outline[3:]+[outline[0]]
        curve('Pálpebra inferior',[(x,surf(x,z)-.13,z) for x,z in low],.13,material)
        brow=[(side*1.35,ez+1.5),(side*2.1,ez+1.45),(side*6.3,ez+2.8),
              (side*6.5,ez+3.2),(side*2.6,ez+2.25)]
        patch('Sobrancelha angular',brow,'cabelo',surf,.19,.45)
        # Narinas embutidas e implantes/marcas aderidos à anatomia.
        sphere('Narina',(side*.72,surf(side*.72,nz0-.5)-.09,nz0-.5),(.3,.12,.14),'cabelo')
        earz=117 if r else 129
        sphere('Orelha',(side*7.8,.8,earz),(1.25,.9,2.5),material)
        curve('Hélice da orelha',[(side*7.8,-.05,earz+1.8),(side*8.5,-.2,earz+1.3),
              (side*8.65,-.25,earz),(side*8.25,-.2,earz-1.4)],.23,material)
        curve('Interior da orelha',[(side*8,-.25,earz+.8),(side*8.25,-.4,earz),
              (side*7.8,-.45,earz-.9)],.16,material)
        if r:
            patch('Marca sob o olho',[(side*4.8,ez-1.8),(side*5.5,ez-1.5),
                  (side*5.8,ez-2.65),(side*5.2,ez-2.9)],'rosa',surf,.12,.32)
        else:
            for path in [[(6.6,136.8),(7.1,135.4),(6.75,134.1),(7.1,131.7)],
                         [(6.7,131),(6.45,129.5),(5.7,128),(5.7,126.3),(4.8,125.7)]]:
                curve('Circuito facial',[(side*x,surf(side*x,z)-.12,z) for x,z in path],.17,'aco')
            patch('Placa temporal',[(side*6.6,137.7),(side*7.5,137.5),(side*7.65,135.9),
                  (side*7.1,135.2),(side*6.5,136.4)],'aco_claro',surf,.15,.4)
    mz=nz0-3.6
    mouth=[(-2.25,mz+.1),(-.7,mz+.02),(.7,mz+.1),(2.25,mz+.25)]
    curve('Boca',[(x,surf(x,z)-.13,z) for x,z in mouth],.115,'cabelo')
    curve('Lábio inferior',[(-1.35,surf(-1.35,mz-.42)-.12,mz-.42),
         (0,surf(0,mz-.5)-.14,mz-.5),(1.2,surf(1.2,mz-.25)-.12,mz-.25)],.12,material)
    if r: rebecca_hair()
    else: david_hair()
    if r:
        pivot=Vector((0,0,110)); rot=Matrix.Rotation(math.radians(-7),4,'Y')
        transform=Matrix.Translation(Vector((-1.5,0,0)))@Matrix.Translation(pivot)@rot@Matrix.Translation(-pivot)
        for o in PARTS[start:]:o.matrix_world=transform@o.matrix_world


def david_hair():
    # Couro cabeludo raspado e recorte irregular da linha frontal.
    scalp=[(133.8,0,1.7,7.5,4.5),(137.5,0,1.4,7.35,5.65),(141,0,1.5,5.6,4.5),
           (142.5,0,1.5,.4,.4)]
    # Apenas parte posterior/temporal da base: testa preservada.
    cloth_shell('Undercut',scalp,'cabelo',start=.05,end=math.pi-.05,folds=0)
    skin('Base contínua do topete',[(138,0,1,7.2,5.3),(140,0,1,6.8,5),
         (143,1,1,5.4,3.5),(144,1,1,.3,.3)],'cabelo',nz=45,nt=96)
    for s in [-1,1]:
        panel('Recorte da costeleta',[(s*6.6,-2.5,139),(s*7.6,-1,138),
              (s*7.65,-.7,133.7),(s*6.7,-2,135.2),(s*6.6,-2.5,137)],.65,'cabelo',.12)
    # Mechas largas sobrepostas, pontas triangulares e cristas em lâmina.
    locks=[(-4.4,-1.4,146.5,2.4),(-1.8,-2.3,151.5,3.1),(1,-2.1,153.0,3.0),
           (3.6,-1,150,2.6),(5.3,1,146.5,2),(-4,2,149,2.5),
           (-1,3,153,2.7),(2.4,3.2,151,2.8),(4.4,3.4,147,2.1)]
    for i,(x,y,h,w) in enumerate(locks):
        swept('Mecha angular %02d'%i,[(x,y,137.5),(x-.6,y-.2,140.5),
              (x+.5,y+.1,h-4),(x+2.8,y+.5,h)],
              [w*1.3,w*1.25,w*.9,.11],[1.2,1.2,.65,.07],'cabelo')
    patch('Linha irregular do cabelo',[(-6.5,139),(-5,137.5),(-4.5,138.3),(-2.8,137),
          (-2.5,139),(0,138),(1.5,139),(3,137.9),(5.3,138.4),(6.7,137),(6.5,141),(-6,141)],
          'cabelo',lambda x,z:head_surface(x,z),.35,.65)


def rebecca_hair():
    # Cobertura posterior seguindo o crânio, evitando capacete esférico separado.
    cloth_shell('Cabelo posterior',[(117,0,1.3,8.05,5.5),(123,0,1.4,8.7,6.3),
          (128,0,1.8,8.05,5.6),(132,0,1.7,5.9,4.4),(133,0,1.8,.7,.7)],
          'menta',start=-.1,end=math.pi+.1,folds=.1)
    for s in [-1,1]:
        swept('Franja ondulada principal',[(s*.8,-1.8,132.7),(s*2.8,-4.2,133.2),
              (s*5.3,-5.5,130.6),(s*7.8,-4.4,127.5),(s*9.1,-2.6,128.7),(s*8.2,-2.2,130)],
              [1.5,2.4,2,1.35,.9,.12],[.7,1.3,1.1,.7,.5,.08],'menta')
        swept('Mecha interna da franja',[(s*.5,-2.8,131.5),(s*2,-5.0,130.2),
              (s*4.6,-5.9,127.1),(s*7.3,-4.6,125.7),(s*8.6,-3.1,126.6)],
              [1.1,1.5,1.4,.9,.12],[.65,.85,.8,.5,.08],'menta')
        for j in range(3):
            curve('Sulco da franja',[(s*(.8+j*.4),-2.7,133),(s*(2.8+j*.4),-5.4,132.7),
                  (s*(5.2+j*.4),-6.4,130),(s*(7.4+j*.3),-5.0,127.5)],.12,'menta')
        # Tiras contínuas no lugar das duas massas grossas da versão rejeitada.
        for j in range(4):
            swept('Mecha da cauda',[(s*6.2,4.0,130),(s*(9.3+j*.65),4.7,128),
                  (s*(11.3+j*.65),5.7,116),(s*(10+j*.75),6,104),
                  (s*(9+j*.5),4.7,98.5+j*.65)],
                  [1.65,1.75,1.35,.9,.2],[1.1,1.05,.9,.7,.15],
                  'menta' if j%2==0 else 'cabelo_sombra')
        panel('Presilha lateral',[(s*7.1,-1.4,132),(s*9.7,-.4,132.5),
             (s*10,-.3,129),(s*7.4,-1.4,128)],3.7,'preto',.35)
    curve('Tiara',[(-7.8,-1.4,131.6),(-4.5,-2.1,133.5),(0,-2.3,134.3),
         (4.5,-2.1,133.5),(7.8,-1.4,131.6)],.67,'preto')


def david_torso():
    rings=[(67,0,0,11.8,6.9),(74,0,.1,12.8,7.4),(82,0,.3,14.4,7.9),
           (90,0,.7,18,8.4),(100,0,1,21.1,9.5),(107,0,1.2,21.5,9.1),
           (112,0,1.5,16,7.4),(117,0,1.3,6.2,4.6),(123,0,1,4.6,3.7)]
    def sculpt(x,y,z,t,cx,cy,rx,ry):
        front=max(0,-math.sin(t))**5
        pec=1.8*(g(x,8.7,5.5)+g(x,-8.7,5.5))*g(z,102,3.7)
        abs_=sum(1.05*(g(x,3.8,3.1)+g(x,-3.8,3.1))*g(z,zz,2.15) for zz in [77.7,83.3,88.9,94])
        cleft=.65*g(x,0,.6)*g(z,93,16)
        pec_line=.45*g(z,97.0-.06*abs(x),.5)*g(x,0,18)
        ribs=.34*math.cos((z-85)*1.05+abs(x)*.32)*g(abs(x),12,3.1)*g(z,88,9)
        y-=(pec+abs_-cleft-pec_line+ribs)*front
        # Escápulas e sulco da coluna, integrados à anatomia das costas.
        back=max(0,math.sin(t))**5
        y+=(.7*(g(x,8,5)+g(x,-8,5))*g(z,103,7)-.3*g(x,0,.7))*back
        return x,y,z
    skin('Anatomia integrada do tronco',rings,'pele',sculpt,180,144)
    def surf(x,z):
        cx,cy,rx,ry=interp(rings,z); t=-math.acos(max(-1,min(1,x/rx)))
        yy=cy-ry*math.sqrt(max(0,1-(x/rx)**2))
        return sculpt(x,yy,z,t,cx,cy,rx,ry)[1]
    for s in [-1,1]:
        for path in [[(s*1.1,114),(s*5.5,112),(s*12,110)],
                     [(s*10,91),(s*12,87),(s*10.6,83),(s*11,79)]]:
            curve('Relevo anatômico discreto',[(x,surf(x,z)-.12,z) for x,z in path],.22,'pele')
        patch('Implante peitoral',[(s*14,105),(s*15.1,105.3),(s*15.3,103.5),(s*14,103.2)],
              'aco',surf,.12,.45)
    return surf


def trouser_detail(x,y,z,t,cx,cy,rx,ry):
    # Dobras localizadas no joelho e na virilha, sem cordões sobrepostos.
    front=max(0,-math.sin(t))**3
    fold=.65*math.sin((z-39)*1.1+(x-cx)*.32)*g(z,40,5)
    fold+=.7*math.sin((z-61)*.9+(x-cx)*.65)*g(z,61,6)
    radial=.32*math.cos(t*5+z*.07)*g(z,54,15)
    return x+radial*math.cos(t),y+radial*math.sin(t)+fold*front,z


def boot(s,r=False):
    x=s*(8.6 if r else 12.5); top=31 if r else 29
    rings=[(4,x,-2.3,4.8,8),(5.2,x,-2.3,5.4,8.5),(7.5,x,-2.3,5.5,8.3),
           (10,x,-1.7,5.2,7.1),(13,x,0,4.8,5.6),(18,x,.6,4.2,4.4),
           (top-1,x,.7,4.6,4.8),(top,x,.7,4.8,4.9)]
    if r:rings=[(z,cx,cy,rx+(.3 if z>=18 else 0),ry+(.7 if z>=18 else 0)) for z,cx,cy,rx,ry in rings]
    skin('Bota anatômica',rings,'preto',nz=80,nt=80)
    skin('Sola',[(3.6,x,-2.3,4.8,8),(4.0,x,-2.3,5.6,8.7),
         (5.3,x,-2.3,5.6,8.7),(5.6,x,-2.3,5.4,8.5)],'borracha',nz=12,nt=80)
    for z in [14,18,22]:
        curve('Correia integrada',[(x-3.7,-2.2,z),(x,-4.15,z+.3),(x+3.7,-2.2,z)],.65,'borracha')
        box('Fecho de bota',(x+s*3.5,-2.3,z),(1.4,1.0,1.7),'aco',.18)
    for i in range(5):
        curve('Relevo de sola',[(x-4.3,-8.6+i*2,4.4),(x-4.9,-7.9+i*2,4.6)],.35,'borracha')


def cyber_hand(s,center):
    x,y,z=center
    # Palma humana proporcional, com painel dorsal e dedos abertos da referência.
    outline=[(x-3.4,y,z-3),(x+3.2,y,z-3),(x+3.8,y,z+1.4),
             (x+2.4,y,z+4),(x-2.7,y,z+4),(x-3.9,y,z+1)]
    panel('Luva articulada',outline,4.4,'preto',.8)
    panel('Placa dorsal',[(x-2.8,y-2.1,z),(x+2.5,y-2.1,z-.4),
          (x+3.0,y-2.1,z+2.2),(x+1,y-2.1,z+3.3),(x-2.8,y-2.1,z+2.5)],.8,'aco',.3)
    for j in range(4):
        dx=-2.55+j*1.65; length=[6,7.7,7.2,5.5][j]
        end=dx+(j-1.5)*.9
        points=[(x+dx,y-.4,z-2),(x+dx*1.12,y-.5,z-4.3),
                (x+end,y-.9,z-2-length*.75),(x+end*1.03,y-.7,z-2-length)]
        swept('Dedo aberto',points,[.75,.72,.63,.47],[.8,.78,.65,.48],'aco',12)
        for k in [1,2]:
            sphere('Junta digital',points[k],(.74,.82,.62),'preto')
    swept('Polegar aberto',[(x-s*2.9,y,z+1),(x-s*5,y-.6,z-.8),(x-s*6.5,y-1,z-3.1),
          (x-s*6.4,y-1,z-4.5)],[1.1,1.0,.8,.6],[1,.95,.8,.6],'aco',12)


def david():
    pedestal('DAVID MARTINEZ',29)
    for s in [-1,1]:
        boot(s)
        rings=[(25,s*12.5,.6,5.6,5.4),(28,s*12.5,.5,6.8,6.3),
               (34,s*13,.0,7.5,7),(41,s*12.8,-1.2,7.8,7.2),
               (47,s*11.2,-.1,7.4,7.5),(56,s*9.3,.2,8.4,7.8),
               (65,s*7.0,.4,8.7,7.8),(70,s*6,.3,7.5,7.0)]
        skin('Calça com dobras esculpidas',rings,'pano',trouser_detail,150,112)
        skin('Barra dobrada',[(25,s*12.5,.5,5.8,5.8),(26,s*12.5,.5,6.6,6.6),
             (29,s*12.5,.3,7.2,6.8),(30.5,s*12.6,.2,7.0,6.5)],'pano',nz=24,nt=80)
        curve('Costura da calça',[(s*15,1,67),(s*18,1,56),(s*19,0,44),(s*19,0,33)],.2,'pano')
    skin('Cintura da calça',[(64,0,.5,13.5,7.4),(70,0,.3,13.0,7.4),
         (74,0,.2,12.9,7.4)],'pano',nz=30)
    surf=david_torso()
    for z in [70,74]:
        skin('Cinto duplo',[(z-1.3,0,.3,13.35,7.7),(z+1.3,0,.3,13.35,7.7)],'preto',nz=6)
        box('Fivela',(0,-7.6,z),(4.6,1.3,3.5),'aco_claro',.35)
        box('Centro da fivela',(0,-8.3,z),(3.2,.35,2.1),'preto',.2)
    jacket=[(76,0,1.2,14.7,8.2),(83,0,1.5,17.3,8.9),(95,0,1.8,21.5,10.3),
            (106,0,2,22.8,10.2),(112,0,1.5,17.7,8.0),(115,0,1.2,9,5.6)]
    cloth_shell('Jaqueta aberta',jacket,'jaqueta',folds=.55)
    for s in [-1,1]:
        curve('Zíper e borda da jaqueta',[(s*10.5,-5.2,76),(s*12.4,-6,84),
             (s*15.4,-6.3,96),(s*15.4,-5.9,108),(s*6.5,-3,116)],.6,'faixa')
        # Gola modelada em planos angulosos seguindo a imagem.
        outline=[(s*5.3,-1,114),(s*9.2,-3,110),(s*13.5,-2,116),
                 (s*17.2,.9,123),(s*12.1,3.2,125.5),(s*7.5,2.7,120)]
        panel('Gola exterior',outline,1.8,'preto',.35)
        center=Vector(tuple(sum(p[j] for p in outline)/len(outline) for j in range(3)))
        inner=[tuple(center+(Vector(p)-center)*.86+Vector((0,-1.1,0))) for p in outline]
        panel('Forro azul da gola',inner,.3,'interior',.15)
        def sleeve_shape(x,y,z,t,cx,cy,rx,ry):
            wave=.55*math.sin(2.3*t+z*.55)*g(z,89,4)+.35*math.cos(3*t+z*.4)*g(z,108,5)
            return x+wave*math.cos(t),y+wave*math.sin(t),z
        sleeve=[(87,s*28.5,1,6.6,6.9),(89,s*28.2,1,7.5,7.8),
                (95,s*27.1,1.1,7.2,7.6),(103,s*24.9,1.4,8.3,8.3),
                (109,s*23.3,1.6,8.2,8.0),(112,s*22.3,1.7,6.2,6.7)]
        skin('Manga com volume de tecido',sleeve,'jaqueta',sleeve_shape,100,96)
        skin('Faixa refletiva da manga',[(96,s*26.9,1.1,7.55,7.9),
             (100.5,s*25.7,1.3,8.1,8.2)],'faixa',nz=20)
        skin('Punho dobrado',[(86.4,s*28.5,1,6.8,7.1),(87,s*28.5,1,7.2,7.5),
             (90,s*28.1,1,7.7,8),(90.5,s*28,1,7.4,7.7)],'jaqueta',nz=20)
        panel('Aba sobre o ombro',[(s*19,-1,112),(s*24,-.5,115),(s*34,.5,113),
             (s*35.8,.3,108),(s*29,-1,107)],2.5,'jaqueta',.6)
        curve('Costura da aba',[(s*23,-1.8,113.5),(s*32,-1,111.7),(s*33.6,-1,109)],.25,'faixa')
        fore=[(64,s*33.5,-.7,3.7,3.9),(68,s*33,-.2,4.1,4.4),
              (76,s*31.5,.3,5.4,5.2),(83,s*29.7,.8,5.6,5.5),(88,s*28.5,1,4.7,4.8)]
        skin('Antebraço contínuo',fore,'pele',nz=100,nt=96)
        # Circuitos planos; sem recortes flutuantes.
        panel('Placa do antebraço',[(s*31,-4.7,82),(s*32.4,-4.8,80),(s*34,-4.0,70),
             (s*33,-3.9,66),(s*30.9,-4.0,71)],.75,'aco',.25)
        curve('Costura do implante',[(s*28.7,-3.3,85),(s*30,-4.3,81),
             (s*30.5,-4.6,77),(s*32,-4,71),(s*32.5,-3.5,67)],.2,'aco_claro')
        cyber_hand(s,(s*34,-.6,61.5))
        for z in [117,120,122.5]:
            panel('Implante cervical',[(s*4.3,-1.2,z-.7),(s*5.5,-.4,z-.7),
                 (s*5.5,-.4,z+.7),(s*4.3,-1.2,z+.7)],1.2,'aco',.25)
    for z in range(84,116,3):
        box('Sandevistan dorsal',(0,11.2 if z<107 else 8.5,z),(4.3,1.7,2.1),'aco',.3)
    necklace=[(-4.5,-3,116),(-8.5,-7.4,110),(-8,-10.3,103),(-5,-10.2,98),
              (0,-9.5,95),(5,-10.2,98),(8,-10.3,103),(8.5,-7.4,110),(4.5,-3,116)]
    curve('Colar',necklace,.32,'ouro')
    panel('Pingente',[(0,-9.6,95),(-1,-9.5,93.4),(0,-9.5,92.3),(1.2,-9.5,94)],.6,'ouro',.16)
    anime_head()


def rebecca_torso():
    rings=[(61,0,0,10.4,6.1),(66,0,0,10.5,6.2),(73,-.5,.2,8.7,5.4),
           (81,-.8,.5,8.0,5.2),(88,-.7,.5,9.4,6.1),(94,-.4,.7,11.7,6.3),
           (99,-.2,.8,12.4,5.6),(102,0,.8,8.8,4.2),(106,0,.7,3.6,3.0),
           (112,0,.5,3.3,2.8)]
    def shape(x,y,z,t,cx,cy,rx,ry):
        front=max(0,-math.sin(t))**5
        breasts=1.25*(g(x,4.1,3.7)+g(x,-4.1,3.7))*g(z,92,3.4)
        belly=.22*g(x,0,5)*g(z,77,6)-.18*g(x,0,.6)*g(z,78,7)
        return x,y-(breasts+belly)*front,z
    skin('Anatomia contínua Rebecca',rings,'pele_r',shape,150,128)
    def surf(x,z):
        cx,cy,rx,ry=interp(rings,z); xx=x-cx
        t=-math.acos(max(-1,min(1,xx/rx))); yy=cy-ry*math.sqrt(max(0,1-(xx/rx)**2))
        return shape(x,yy,z,t,cx,cy,rx,ry)[1]
    for s in [-1,1]:
        patch('Top triangular',[(s*.5,88),(s*7.4,88.8),(s*8.3,92.3),(s*5.7,96.8),
              (s*3.9,95.9),(s*2.1,91)],'preto',surf,.22,.65)
        curve('Alça do top',[(s*5.7,surf(s*5.7,95)-.2,95),(s*5.2,-2.5,101),
             (s*4,1,102)],.5,'preto')
        # Áreas em zigue-zague, seguindo o desenho amplo de tatuagem da referência.
        shapes=[[(1,72),(3.6,74),(4.8,77),(3.9,78.9),(6.6,81.1),(5.8,84),(3.9,82.2),
                 (2.1,83.2),(.8,81.2),(2.6,79.4),(2.6,77.3),(.5,75)],
                [(2,85),(4.8,86.1),(6.8,84.5),(6.1,82.9),(4.4,84),(2.8,83.5)],
                [(1.2,101),(3.3,101.8),(3.6,104.9),(2,104.4),(1.1,103.2),(.4,104),(.7,102.1)]]
        for shape2 in shapes:patch('Tatuagem em relevo',[(s*x,z) for x,z in shape2],'rosa',surf,.08,.35)
    patch('Umbigo',[(-.4,75),(.4,75),(.35,74),(-.3,74)],'pele_r',surf,.22,.3)
    patch('Frente do short',[(-10.1,66),(-8.8,68.8),(-4,67.5),(0,66.7),(4,67.5),
          (9.3,68.6),(10.3,65.7),(7.5,62.4),(3.8,62.0),(1.2,59.7),(-1.2,59.7),
          (-4,62),(-7.4,62.5)],'preto',surf,.3,.9)
    return surf


def robot_hand_blue():
    begin=len(PARTS); x,y,z=26,-12,113
    # Ossatura e carcaça com planos inclinados e proporções do desenho.
    panel('Carcaça da mão azul',[(x-8,y,z-7),(x-9,y,z-2),(x-7.6,y,z+7),
          (x+5.8,y,z+8),(x+8.5,y,z+4.8),(x+8,y,z-5),(x+4,y,z-7)],8,'azul',.85)
    panel('Placa do dorso azul',[(x-6.9,y-4,z-5),(x-7.4,y-4,z+3),
          (x-5.2,y-4,z+5.7),(x+5.1,y-4,z+5.7),(x+6.7,y-4,z+3),
          (x+6,y-4,z-4.3)],1.3,'azul_luz',.45)
    box('Punho mecânico',(x,y+1,z-9),(13.3,9.2,5.8),'azul',.8)
    for dx in [-4.8,-1.1,2.6,5.7]:
        panel('Sulco dorsal',[(x+dx-.32,y-4.85,z-3.5),(x+dx+.32,y-4.85,z-3.5),
              (x+dx+.32,y-4.85,z+2),(x+dx-.32,y-4.85,z+2)],.25,'azul',.1)
    for i in range(4):
        fx=x-5.7+i*3.65
        if i==1:
            for k,(zz,h,w) in enumerate([(z+10,6,3.55),(z+15.5,5.4,3.35),(z+20.5,5.1,3.15)]):
                panel('Falange estendida',[(fx-w/2,y,zz-h/2),(fx+w/2,y,zz-h/2),
                      (fx+w/2,y,zz+h/2-.4),(fx+w/2-.4,y,zz+h/2),
                      (fx-w/2+.4,y,zz+h/2),(fx-w/2,y,zz+h/2-.4)],5.0,'azul_luz',.35)
                box('Junta de falange',(fx,y,zz-h/2),(w+0.2,5.3,1.2),'azul',.25)
                box('Ranhura de falange',(fx,y-2.6,zz-1.3),(w*.5,.25,.5),'azul',.1)
        else:
            zz=z+7.7-(.6 if i==3 else 0)
            panel('Falange dobrada',[(fx-1.65,y-2,zz-2.3),(fx+1.65,y-2,zz-2.3),
                  (fx+1.65,y-2,zz+2.5),(fx+.9,y-2,zz+3.1),(fx-1.45,y-2,zz+2.7)],
                  6.7,'azul_luz',.45)
            box('Falange frontal',(fx,y-5.1,zz-2.5),(3.3,3.6,5.4),'azul',.4)
            box('Articulação visível',(fx,y-7.0,zz-2.6),(2.2,.5,1.1),'aco',.15)
            for xx in [-.65,.65]:
                curve('Pistão digital',[(fx+xx,y-6.8,zz-.2),(fx+xx,y-7,zz-1.5)],.25,'azul_luz')
    swept('Polegar mecânico',[(x-7,y-1,z),(x-10,y-2,z+3),(x-10.3,y-4,z+6),
          (x-8.8,y-6,z+6.5)],[2.1,2.2,2,1.6],[2.7,2.7,2.3,1.8],'azul',12)
    for dx in [-5.7,5.7]:
        sphere('Parafuso da mão',(x+dx,y-4.8,z-3.6),(.5,.23,.5),'aco')
    # Inclinação da mão para abrir a silhueta junto ao rosto.
    pivot=Vector((x,y,z-9)); rotation=Matrix.Rotation(math.radians(-10),4,'Y')
    T=Matrix.Translation(pivot)@rotation@Matrix.Translation(-pivot)
    for o in PARTS[begin:]:o.matrix_world=T@o.matrix_world


def rebecca():
    pedestal('REBECCA',27)
    for s in [-1,1]:
        boot(s,True)
        # A referência termina acima dos joelhos: pernas são interpretação explícita.
        rings=[(26,s*8.6,.5,4.3,4.5),(33,s*8.5,.2,4.5,4.8),(42,s*8,-.6,4.5,5.2),
               (47,s*7.8,-.2,5.4,5.7),(55,s*7,0,6.2,6.0),
               (63,s*5.8,.1,6.6,6.2),(67,s*5,.2,6.1,5.9)]
        skin('Perna contínua',rings,'pele_r',nz=120,nt=96)
        if s==-1:
            skin('Marca da coxa',[(52,s*7.3,0,6.05,6.0),(54.2,s*7.1,0,6.3,6.1)],'rosa',nz=12)
    rebecca_torso()
    coat=[(48,0,4,13.0,5),(53,0,4,14.3,5.6),(67,-.1,3.7,12.6,6.3),
          (80,-.2,3.4,11.2,6.4),(93,-.2,2.7,14,6.5),(100,0,1.5,13.8,5.7),
          (104,0,1.4,8.5,4.7)]
    cloth_shell('Casaco amplo aberto',coat,'preto',start=-.88,end=math.pi+.88,folds=.7)
    for s in [-1,1]:
        curve('Acabamento da barra',[(s*8.3,-.1,48),(s*11.7,1.2,49),
              (s*13.9,3.9,52)],.32,'menta')
        panel('Gola alta Rebecca',[(s*4,-1,101),(s*7,-4.4,94),
              (s*11.5,-2.5,99.4),(s*12.5,0,108.6),(s*7.3,1,110),
              (s*4.7,1,106)],2.5,'preto',.55)
        sphere('Botão da gola',(s*8.8,-3.65,99.9),(1.25,.5,1.25),'menta')
        sphere('Miolo do botão',(s*8.8,-4.02,99.9),(.72,.26,.72),'preto')
    def wrinkles(x,y,z,t,cx,cy,rx,ry):
        wave=.6*math.sin(t*2.8+z*.65)*g(z,75,5)+.25*math.sin(t*5+z*.15)
        return x+wave*math.cos(t),y+wave*math.sin(t),z
    skin('Manga caída',[(59,-16,.3,5.1,5.4),(64,-16.5,.7,5.8,6.1),
         (73,-17,1,6.3,6.6),(82,-16,1.4,6.8,6.8),(92,-14.5,1.6,6.7,6.8),
         (99,-12.3,1.5,5.7,5.7)],'preto',wrinkles,140,96)
    panel('Mão rosa', [(-22,-.4,49),(-13,-.4,49),(-11,-.4,53),(-11,-.4,60),
          (-14,-.4,62),(-21,-.4,61),(-23,-.4,56)],6.7,'rosa',.8)
    for i in range(4):
        x=-21+i*2.4
        swept('Dedo rosa',[(x,-.5,51),(x,-1.5,47),(x,-2.5,44.5)],
              [1.15,1.1,.85],[1.4,1.3,1],'rosa',12)
        box('Placa do dedo rosa',(x,-3.2,48.2),(1.6,.8,2),'aco',.2)
    swept('Polegar rosa',[(-12,-.2,56),(-10,-1,53),(-10.5,-2.5,50.5)],
          [1.5,1.4,1],[1.6,1.6,1.2],'rosa',12)
    skin('Manga do braço elevado',[(80,18.5,1,5.4,5.9),(84,18.5,1,6.5,6.7),
          (91,17,1.2,6.7,6.8),(98,14.4,1.1,6.3,6.1),(101,12.5,1,5.2,5.3)],
          'preto',wrinkles,90,96)
    swept('Antebraço dobrado',[(18.5,1,82),(20,-2,86),(23,-7,96),(26,-11,104)],
          [5.5,6.5,6.2,5.9],[6.1,6.8,6.4,5.6],'preto',32)
    robot_hand_blue()
    anime_head(True)


def save_render():
    scene=bpy.context.scene; scene.unit_settings.system='METRIC'
    scene.unit_settings.scale_length=.001; scene.unit_settings.length_unit='MILLIMETERS'
    coll=bpy.data.collections.new('FIGURA_AUTORAL'); scene.collection.children.link(coll)
    for o in PARTS:
        for c in list(o.users_collection):c.objects.unlink(o)
        coll.objects.link(o)
    studio=bpy.data.collections.new('ESTUDIO');scene.collection.children.link(studio)
    def move(o):
        for c in list(o.users_collection):c.objects.unlink(o)
        studio.objects.link(o)
    target=(0,0,79) if args.personagem=='david' else (1,-1,72)
    camera_pos=(65,-360,175) if args.personagem=='david' else (120,-330,165)
    bpy.ops.object.camera_add(location=camera_pos); cam=bpy.context.object; move(cam)
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO'; cam.data.ortho_scale=179 if args.personagem=='david' else 166; scene.camera=cam
    for name,pos,power,size in [('Principal',(-110,-170,235),150000,110),
          ('Preenchimento',(130,-100,150),80000,120),('Recorte',(30,110,210),170000,100)]:
        bpy.ops.object.light_add(type='AREA',location=pos); light=bpy.context.object;move(light)
        light.name=name;light.data.energy=power;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector(target)-light.location).to_track_quat('-Z','Y').to_euler()
    scene.world.color=(.12,.12,.12);scene.render.engine='CYCLES';scene.cycles.samples=40
    scene.cycles.use_denoising=True;scene.render.resolution_x=1200;scene.render.resolution_y=1500
    scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    scene['estado']='RECONSTRUCAO EM REVISAO VISUAL; NAO VALIDADA PARA IMPRESSAO'
    scene['ferramentas']='Terminal nativo Codex; Blender local; codigo autoral sem repositorios externos'
    folder=ROOT/(args.personagem+'_anime'); folder.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(args.personagem+'_anime.blend')))
    print('FONTE_ANIME',args.personagem,len(PARTS),flush=True)
    if args.render:
        scene.render.filepath=str(folder/'corpo.png');bpy.ops.render.render(write_still=True)
    if args.close:
        target=(0,-1,132) if args.personagem=='david' else (-1,-1,121)
        cam.location=(35,-270,155)
        cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=47
        scene.render.resolution_x=1300;scene.render.resolution_y=1300
        scene.render.filepath=str(folder/'rosto.png');bpy.ops.render.render(write_still=True)


(david if args.personagem=='david' else rebecca)()
save_render()
