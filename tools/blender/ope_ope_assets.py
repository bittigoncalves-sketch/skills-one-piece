"""Author original Ope fruit / surgical nodachi. Blender 5+, no external assets.
Run: blender -b --python tools/blender/ope_ope_assets.py
Godot fruit Y-up, sword -Z forward. All geometry / materials editable here.
"""
import bpy, math, os
from mathutils import Vector
from math import sin, cos, pi, exp
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT=os.path.join(ROOT,'assets/models/ope_ope')
os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def material(name,color,metal=0,rough=.5):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    return m
ruby=material('Ope | ripe carmine',(0.54,.025,.058),0,.36)
spiral=material('Ope | embossed vermilion',(.95,.12,.16),0,.48)
green=material('Ope | jade leaves',(.075,.29,.06),0,.58)
vein=material('Ope | lime veins',(.32,.49,.065),0,.6)
navy=material('Kikoku | midnight lacquer',(.012,.025,.047),.2,.36)
cream=material('Kikoku | ivory braid',(.82,.76,.57),0,.66)
steel=material('Kikoku | folded steel',(.32,.43,.48),.65,.3)
edge=material('Kikoku | silver edge',(.69,.81,.83),.75,.24)
gold=material('Kikoku | warm brass',(.48,.29,.075),.55,.4)
coral=material('Kikoku | carmine cord',(.57,.032,.035),0,.74)

def mesh(name,verts,faces,mat,smooth=True):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],faces); data.update()
    ob=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(ob); ob.data.materials.append(mat)
    for poly in ob.data.polygons: poly.use_smooth=smooth
    return ob

def tube(name,points,radius,mat,res=3):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.bevel_depth=radius; c.bevel_resolution=res; c.use_fill_caps=True
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(*co,1)
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(mat)
    return o

def heart(a,b,offset=0):
    z0=sin(a); x=cos(a)*cos(b)*(.43+.145*z0)
    y=cos(a)*sin(b)*(.30+.045*z0)
    z=.455*z0-.15*exp(-(x/.105)**2)*max(z0,0)**4
    v=Vector((x,y,z)); n=Vector((x/.43,y/.30,z/.455)).normalized()
    return v+n*offset
N=112; M=72
verts=[heart(-pi/2+pi*i/M,2*pi*j/N) for i in range(M+1) for j in range(N)]
faces=[(i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(M) for j in range(N)]
mesh('Ope_Heart',verts,faces,ruby)
# Embossed double-turn signature swirls wrap the actual curved fruit surface.
centers=[(-.70,-2.7,.24),(-.68,-1.50,.25),(-.64,-.3,.23),(-.64,.90,.25),(-.64,2.12,.24),
         (-.10,-2.9,.29),(-.08,-1.78,.27),(-.06,-.65,.28),(-.08,.48,.27),(-.04,1.60,.28),(0,2.7,.28),
         (.53,-2.6,.25),(.56,-1.36,.27),(.56,-.12,.26),(.56,1.12,.26),(.52,2.33,.25)]
for k,(a,b,span) in enumerate(centers):
    pts=[]
    for j in range(94):
        t=j/93; angle=2*pi*1.6*t+k*.49; r=span*(.05+.95*t)
        pts.append(heart(a+sin(angle)*r,b+cos(angle)*r*1.28,.007))
    tube('Embossed_Spiral_%02d'%k,pts,.009,spiral,2)
# Green curled peduncle: tight botanical spiral, lifted above central cleft.
pts=[]
for j in range(120):
    t=j/119
    if t<.42:
        q=t/.42; x=3*(1-q)*q*q*(-.065)+q*q*q*.015; z=(1-q)**3*.31+3*(1-q)**2*q*.39+3*(1-q)*q*q*.50+q**3*.50; p=(x,.012*sin(q*pi),z)
    else:
        q=(t-.42)/.58; a=-pi/2+q*pi*1.65; r=.102*(1-.59*q)
        p=(.015+r*cos(a),.002+.019*sin(q*pi),.602+r*sin(a))
    pts.append(p)
tube('Curled_Stem',pts,.023,green,3)

def leaf(name,origin,axis,length,width):
    o=Vector(origin); ax=Vector(axis).normalized(); side=Vector((-ax.y,ax.x,0)).normalized()
    vv=[]; ff=[]; vein_pts=[]
    for i in range(25):
        t=i/24; mid=o+ax*length*t+Vector((0,0,.08*sin(pi*t)-.028*t*t)); vein_pts.append(mid)
        for j in range(9):
            s=j/4-1; p=mid+side*(width*sin(pi*t)**.82*s)+Vector((0,0,-.032*s*s*sin(pi*t)))
            vv.append(p)
    for i in range(24):
        for j in range(8): ff.append((i*9+j,i*9+j+1,(i+1)*9+j+1,(i+1)*9+j))
    ob=mesh(name,vv,ff,green); sol=ob.modifiers.new('Living leaf thickness','SOLIDIFY'); sol.thickness=.006
    tube(name+'_midrib',vein_pts,.004,vein,2)
leaf('Crown_Leaf_Left',(-.005,0,.365),(-1,.13,.2),.33,.102)
leaf('Crown_Leaf_Right',(.01,.014,.367),(1,.15,.32),.29,.087)

def export_selected(path,objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    # Convert curves and bake modifiers before joining by material: a small stable draw budget.
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    ob=bpy.context.object; ob.name=os.path.basename(path).replace('.glb','')
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_materials='EXPORT',export_yup=True)
    return ob
fruit=export_selected(os.path.join(OUT,'ope_ope_fruit.glb'),list(bpy.context.scene.objects))
fruit.hide_render=True; fruit.hide_set(True)
# Sword Blender +Y -> Godot -Z. Origin centered in grip, silhouette slightly curved.
start=set(bpy.context.scene.objects)

def box(name,location,scale,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location);o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Machined softened edges','BEVEL');mod.width=bevel;mod.segments=3
        mod2=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o
box('Ray_skin_grip',(0,0,0),(.087,.48,.072),navy,.022)
# Interlaced cream ribbons laid as alternating diamond lacing over the grip.
for i in range(9):
    y=-.207+i*.049
    for sign in [-1,1]:
        pts=[(-.048,y-.026,.023*sign),(0,y,.046*sign),(.048,y+.026,.023*sign)]
        tube('Tsuka_diamond_%02d_%d'%(i,sign),pts,.0105,cream,2)
for y in [-.249,.242]:box('Grip_ferrule',(0,y,0),(.099,.03,.08),gold,.009)
# Squared cruciform guard, enamel inlay and stepped brass perimeter.
box('Tsuba_main',(0,.271,0),(.29,.044,.24),gold,.045)
box('Tsuba_inlay',(0,.294,0),(.24,.008,.196),navy,.032)
for side in [-1,1]:
    box('Tsuba_cross_x',(side*.081,.302,0),(.029,.008,.088),cream,.003)
    box('Tsuba_cross_y',(side*.081,.303,0),(.070,.008,.027),cream,.003)
box('Habaki',(0,.338,0),(.108,.09,.056),gold,.008)
# Forged blade with bevels, a dark spine, longitudinal shinogi and silver cutting edge.
vv=[]; ff=[]; N=64
for i in range(N+1):
    t=i/N; y=.373+t*1.92; curve=.14*t*t
    w=.094*(1-.18*t)*max(.018,min(1,(1-t)*13))
    # Section arranged clockwise; the edge is thin and the spine carries stiffness.
    for x,z in [(-w*.52,.0),(-w*.35,.014),(w*.30,.020),(w*.51,.008),(w*.51,-.008),(w*.30,-.020),(-w*.35,-.014)]:
        vv.append((x+curve,y,z))
for i in range(N):
    for j in range(7):ff.append((i*7+j,i*7+(j+1)%7,(i+1)*7+(j+1)%7,(i+1)*7+j))
ff.append(tuple(range(6,-1,-1)));ff.append(tuple(N*7+j for j in range(7)))
blade=mesh('Kikoku_blade',vv,ff,steel,False);blade.data.materials.append(edge);blade.data.materials.append(navy)
for poly in blade.data.polygons:
    j=poly.index%7;poly.material_index=1 if j in [0,6] else (2 if j==3 else 0)
# Hamon line is geometry to survive every renderer without texture downloads.
for sign in [-1,1]:
    pts=[]
    for i in range(110):
        t=i/109;y=.395+t*1.85;curve=.14*t*t
        pts.append((curve-.023+sin(t*pi*16)*.0025,y,.017*sign))
    tube('Hamon_%d'%sign,pts,.0022,edge,1)
# Carmine wrist cord on pommel.
pts=[(.01+.045*cos(t*2*pi),-.26-.10*sin(t*pi),.034*sin(t*2*pi)) for t in [i/50 for i in range(51)]]
tube('Carmine_pommel_loop',pts,.009,coral,2)
sword=export_selected(os.path.join(OUT,'kikoku.glb'),[o for o in bpy.context.scene.objects if o not in start])
sword.hide_render=True;sword.hide_set(True)
# Renderable source preview scene: high quality product light, separate from runtime assets.
fruit.hide_render=False;fruit.hide_set(False)
world=bpy.context.scene.world or bpy.data.worlds.new('Studio');bpy.context.scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs[0].default_value=(.022,.033,.043,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.35
for name,loc,power,size in [('Key',(-3,-4,5),500,4),('Fill',(3,-2,2),250,3),('Rim',(1,3,4),700,2)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.25,-2.4,1.03));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.12))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=1.32;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.filepath=os.path.join(OUT,'fruit_preview.png');bpy.ops.render.render(write_still=True)
print('OPE_ASSETS_READY',[(o.name,len(o.data.polygons)) for o in [fruit,sword]])
