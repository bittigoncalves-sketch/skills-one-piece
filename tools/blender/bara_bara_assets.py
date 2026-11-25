"""Bara Bara: authored fruit, hollow ship cannon and special clown cannonball.
Reproduce with Blender 5: blender -b --python tools/blender/bara_bara_assets.py
No downloaded geometry/textures. Blender +Y becomes Godot -Z; export meters/Y-up.
Editable sources: this generator plus art_src/bara_bara/bara_bara_assets.blend.
"""
import bpy, math, os, json
from math import sin, cos, pi
from mathutils import Vector
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets/models/bara_bara')
SRC = os.path.join(ROOT, 'art_src/bara_bara')
os.makedirs(OUT, exist_ok=True); os.makedirs(SRC, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
manifest = {}

def material(name, color, metal=0, rough=.5):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    return m
plum=material('Bara | satin plum skin',(.28,.075,.40),0,.4)
pink=material('Bara | rose upper lobes',(.49,.13,.36),0,.4)
ridge=material('Bara | lavender embossed spirals',(.77,.46,.79),0,.42)
leafmat=material('Bara | olive stem',(.16,.29,.095),0,.67)
stemlight=material('Bara | stem ridge',(.36,.47,.16),0,.58)
iron=material('Cannon | blued cast iron',(.035,.055,.075),.78,.3)
black=material('Cannon | soot inside bore',(.007,.009,.014),.1,.83)
brass=material('Cannon | worn brass bands',(.52,.31,.09),.72,.3)
wood=material('Cannon | warm oak carriage',(.26,.095,.027),0,.66)
woodlight=material('Cannon | carved oak edges',(.41,.19,.052),0,.58)
steel=material('Cannon | rivets and tires',(.13,.17,.20),.75,.4)
ivory=material('Buggy Ball | ivory emblem',(.89,.81,.62),0,.35)
red=material('Buggy Ball | red clown nose',(.66,.025,.033),.15,.25)
rope=material('Buggy Ball | braided fuse',(.51,.39,.17),0,.8)
# Packed, exportable surface variation. Images survive GLB import; no unsupported procedural shader.
for mat, base, kind in [(plum,(.58,.29,.69),'skin'),(pink,(.73,.38,.63),'skin'),(wood,(.53,.31,.16),'wood')]:
    n=128; img=bpy.data.images.new(mat.name+' microtexture',width=n,height=n); px=[]
    for y in range(n):
        for x in range(n):
            grain=sin(x*12.9898+y*78.233)*43758.5453; grain-=math.floor(grain)
            if kind=='skin': v=.94+.055*grain+.018*sin(x*.34)*sin(y*.29)
            else: v=.82+.10*sin(x*.61+sin(y*.075)*2.1)+.08*grain
            px.extend([min(1,c*v) for c in base]+[1])
    img.pixels=px; img.filepath_raw=os.path.join(SRC,mat.name.split('|')[1].strip().replace(' ','_')+'.png'); img.file_format='PNG'; img.save(); img.pack()
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=img
    mat.node_tree.links.new(tex.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def mesh(name,verts,faces,mat,smooth=True):
    d=bpy.data.meshes.new(name); d.from_pydata(verts,[],faces); d.update()
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); d.materials.append(mat)
    for p in d.polygons: p.use_smooth=smooth
    # Spherical UVs for organic pieces, repeated grain for carriage pieces.
    uv=d.uv_layers.new(name='SurfaceUV')
    for p in d.polygons:
        for li in p.loop_indices:
            co=d.vertices[d.loops[li].vertex_index].co
            uv.data[li].uv=(.5+math.atan2(co.y,co.x)/(2*pi),co.z*.9+.5)
    return o

def tube(name,points,radius,mat,res=2):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.bevel_depth=radius; c.bevel_resolution=res; c.use_fill_caps=True
    s=c.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(*co,1)
    o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(mat); return o

def sphere(name,loc,scale,mat,segments=40,rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def box(name,loc,size,mat,bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat)
    if bevel:
        m=o.modifiers.new('Rounded machined edges','BEVEL'); m.width=bevel; m.segments=3
        o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
    return o

def cyl(name,loc,radius,depth,mat,axis='X',verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc)
    o=bpy.context.object; o.name=name
    if axis=='X':o.rotation_euler.y=pi/2
    if axis=='Y':o.rotation_euler.x=pi/2
    o.data.materials.append(mat)
    m=o.modifiers.new('Soft rim','BEVEL');m.width=.008;m.segments=2
    o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
    for p in o.data.polygons:p.use_smooth=True
    return o

def group_export(name, groups):
    """Join by animated group, retaining distinct material slots and few scene nodes."""
    roots=[]
    for group_name, objects in groups:
        objects=sorted(objects,key=lambda obj:obj.name)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.convert(target='MESH'); bpy.ops.object.join()
        o=bpy.context.object; o.name=group_name
        # All transforms baked and origins at reference point (fruit center/cannon ground/ball center).
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        bpy.context.scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        roots.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in roots:o.select_set(True)
    bpy.context.view_layer.objects.active=roots[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
    coords=[o.matrix_world@v.co for o in roots for v in o.data.vertices]
    minimum=[min(v[i] for v in coords) for i in range(3)];maximum=[max(v[i] for v in coords) for i in range(3)]
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in roots)
    manifest[name]={'triangles':tris,'meshes':len(roots),'godot_min':[minimum[0],minimum[2],-maximum[1]],'godot_max':[maximum[0],maximum[2],-minimum[1]],'bytes':os.path.getsize(os.path.join(OUT,name+'.glb'))}
    for o in roots:o.hide_set(True);o.hide_render=True
    return roots

# Fruit: three rounded interlocking latitude bands, eight gentle lobes per band.
def fruit_surface(lat,a,offset=0):
    r=(.38+.014*cos(a*8+.14*sin(lat*3)))*cos(lat)
    return Vector(((r+offset)*cos(a),(r+offset)*sin(a),.37*sin(lat)+.014*cos(a*3)*cos(lat)**2))
fruit_groups=[]
for band,(lo,hi) in enumerate([(-pi/2,-.37),(-.345,.36),(.385,pi/2)]):
    before=set(bpy.context.scene.objects); N=112;M=24
    verts=[fruit_surface(lo+(hi-lo)*i/M,2*pi*j/N) for i in range(M+1) for j in range(N)]
    faces=[(i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(M) for j in range(N)]
    # Closed cut edges sit under rounded raised rims; no hollow gaps on separation.
    for row in [0,M]:
        ci=len(verts); verts.append(Vector((0,0,.37*sin(lo if row==0 else hi))))
        for j in range(N):faces.append((ci,row*N+(j+1)%N,row*N+j) if row==0 else (ci,row*N+j,row*N+(j+1)%N))
    mesh('Lobes_%d'%band,verts,faces,pink if band==2 else plum)
    latmid=(lo+hi)/2
    for j in range(8):
        angle=2*pi*(j+.08*band)/8; pts=[]
        for k in range(70):
            t=k/69;theta=t*pi*3.1;rr=.045+.19*t
            pts.append(fruit_surface(latmid+rr*sin(theta),angle+rr*cos(theta)/max(.6,cos(latmid)),.007))
        tube('Integrated_spiral_%d_%d'%(band,j),pts,.009,ridge,2)
    fruit_groups.append(('Gomo_%d'%band,list(set(bpy.context.scene.objects)-before)))
before=set(bpy.context.scene.objects)
pts=[]
for i in range(75):
    t=i/74
    if t<.42:
        q=t/.42;pts.append((-.045*sin(q*pi*.75),0,.345+.14*q))
    else:
        q=(t-.42)/.58;a=-pi*.6+q*pi*1.8;r=.077*(1-.65*q)
        pts.append((-.02+r*cos(a),.015*sin(q*pi),.552+r*sin(a)))
tube('Organic_curled_stem',pts,.020,leafmat,3)
for j in range(5):
    a=2*pi*j/5
    pts=[(.06*sin(pi*t/30)*cos(a),.06*sin(pi*t/30)*sin(a),.345+.035*cos(pi*t/30)) for t in range(31)]
    tube('Calyx_%d'%j,pts,.008,stemlight)
fruit_groups.append(('Haste',list(set(bpy.context.scene.objects)-before)))
fruit=group_export('bara_bara_fruit',fruit_groups)

# Cannon: real annular muzzle, deep black bore, trunnions, bolted oak carriage.
before=set(bpy.context.scene.objects)
profile=[(-.66,.075),(-.63,.16),(-.56,.22),(-.43,.235),(-.30,.24),(.15,.22),(.66,.245),(.77,.27),(.86,.27),(.9,.235),(.9,.169),(.84,.16),(.35,.15),(.32,0)]
N=96;vv=[];ff=[]
for y,r in profile:
    for j in range(N):a=2*pi*j/N;vv.append((r*cos(a),y,.69+r*sin(a)))
for i in range(len(profile)-1):
    for j in range(N):ff.append((i*N+j,(i+1)*N+j,(i+1)*N+(j+1)%N,i*N+(j+1)%N))
barrel=mesh('Turned_barrel_hollow_muzzle',vv,ff,iron)
barrel.data.materials.append(black)
for p in barrel.data.polygons:
    if p.index//N>=10:p.material_index=1
for y,r,width in [(-.45,.239,.045),(-.24,.241,.035),(.65,.252,.03),(.805,.274,.025)]:
    # Brass hoops follow tube, not solid discs across the bore.
    pts=[(r*cos(2*pi*j/96),y,.69+r*sin(2*pi*j/96)) for j in range(97)]
    tube('Raised_brass_hoop',pts,width*.5,brass,3)
sphere('Breech_cascabel',(0,-.73,.69),(.07,.095,.07),brass)
barrel_objects=set(bpy.context.scene.objects)-before
for side in [-1,1]:
    cyl('Trunnion',(side*.30,-.13,.68),.085,.15,steel)
    box('Oak_side_carriage',(side*.30,-.14,.36),(.14,.94,.31),wood,.032)
    # Rear rising cheek supports the barrel pivot; front cheek slopes with silhouette.
    box('Oak_cheek',(side*.30,-.27,.53),(.14,.43,.19),woodlight,.03)
    box('Carriage_iron_strap',(side*.379,-.28,.43),(.018,.062,.39),steel,.008)
    for y in [-.5,.12]:
        cyl('Carriage_bolt',(side*.391,y,.43),.025,.025,brass,verts=16)
box('Carriage_crossbeam',(0,-.22,.24),(.69,.22,.15),woodlight,.028)
box('Carriage_front_brace',(0,.30,.29),(.65,.12,.17),wood,.025)
# Four wooden wheels, hubs, eight individual spokes, rim and circumferential iron tire.
for y,rad in [(-.49,.22),(.27,.20)]:
    cyl('Forged_axle',(0,y,rad),.045,1.02,iron)
    for side in [-1,1]:
        x=side*.49
        for rr,mat,thick in [(rad-.028,woodlight,.032),(rad-.004,steel,.018)]:
            tube('Wheel_continuous_rim',[(x,y+rr*cos(2*pi*j/64),rad+rr*sin(2*pi*j/64)) for j in range(65)],thick,mat,2)
        for j in range(8):
            a=2*pi*j/8
            tube('Oak_wheel_spoke',[(x,y+.045*cos(a),rad+.045*sin(a)),(x,y+(rad-.04)*cos(a),rad+(rad-.04)*sin(a))],.022,wood,2)
        cyl('Wheel_oak_hub',(x,y,rad),.069,.11,woodlight)
        cyl('Wheel_brass_pin',(x+side*.064,y,rad),.032,.024,brass,verts=24)
# Small brass touch-hole and fuse on breech, both functional-looking.
before_fuse=set(bpy.context.scene.objects)
cyl('Touch_hole',(0,-.45,.932),.029,.018,brass,axis='Z',verts=24)
tube('Cannon_fuse',[(0,-.45,.943),(.035,-.49,.97),(.085,-.51,.94)],.008,rope)
barrel_objects.update(set(bpy.context.scene.objects)-before_fuse)
cannon=group_export('cannon',[('Barrel',list(barrel_objects)),('Carriage',list(set(bpy.context.scene.objects)-before-barrel_objects))])

# Special ball: cast iron sphere and raised clown-skull emblem on the forward hemisphere.
before=set(bpy.context.scene.objects)
sphere('Special_cast_iron_ball',(0,0,0),(.21,.21,.21),iron,64,40)
# Emblem is purpose-built stylization, no traced/copied artwork or external texture.
sphere('Ivory_skull',(0,.201,.037),(.073,.017,.069),ivory,40,24)
sphere('Skull_jaw',(0,.204,-.020),(.052,.014,.035),ivory)
for side in [-1,1]:
    sphere('Eye_socket',(side*.028,.218,.052),(.016,.009,.020),black)
    a=side*.08
    pts=[(side*.105,.177,-.090),(side*.060,.199,-.064)]
    tube('Crossed_bone',pts,.011,ivory,3)
    for sign in [-1,1]:sphere('Bone_end',(side*.105+sign*.006,.182,-.090+sign*.009),(.014,.010,.014),ivory,24,16)
sphere('Signature_red_clown_nose',(0,.231,.016),(.026,.019,.026),red)
for x in [-.026,-.008,.010,.028]:box('Skull_tooth_gap',(x,.219,-.028),(.004,.008,.016),black,.001)
# Fuse emerges from rear/top, keeping nose-forward silhouette distinct at projectile scale.
tube('Braided_fuse',[(0,-.105,.175),(.010,-.139,.221),(.034,-.145,.244),(.053,-.141,.24)],.009,rope,3)
sphere('Fuse_ember',(.054,-.141,.24),(.012,.012,.012),red,24,16)
ball=group_export('buggy_ball',[('BuggyBall',list(set(bpy.context.scene.objects)-before))])
manifest['conventions']={'units':'meters','up':'+Y','forward':'-Z','cannon_muzzle':[0,.69,-.9],'cannon_root':'ground under axle','ball_root':'sphere center','fruit_root':'fruit center','procedence':'Generated from original meshes and textures in tools/blender/bara_bara_assets.py; anime-inspired motifs, no external source assets.'}
with open(os.path.join(OUT,'manifest.json'),'w') as f:json.dump(manifest,f,indent=2)
# Editable gallery source, separated for inspection. Exported GLBs remain at documented origins.
for objs,x in [(fruit,-1.7),(cannon,0),(ball,1.6)]:
    for o in objs:o.hide_set(False);o.hide_render=False;o.location.x=x
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC,'bara_bara_assets.blend'))
print('BARA_ASSETS',json.dumps(manifest))
