"""Fonte autoral reproduzível do pet. Blender --background --python este_arquivo.
Coordenadas de autoria iguais ao Godot: X lateral, Y vertical, frente -Z.
Conversão para Blender só na gravação; GLB exporta novamente Y-up.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector
ROOT=Path(__file__).resolve().parents[2]
random.seed(300926)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def v(p): return Vector((p[0],-p[2],p[1]))
def material(name, color, rough=.5, vertex=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough
 if vertex:
  a=m.node_tree.nodes.new('ShaderNodeVertexColor');a.layer_name='Cor';m.node_tree.links.new(a.outputs['Color'],bs.inputs['Base Color'])
 return m
shell=material('Quitina castanha moteada',(.27,.105,.045),.37,True)
ivory=material('Bordas gastas marfim',(.58,.41,.23),.56)
under=material('Ventre areia',(.37,.28,.17),.68)
joint=material('Membrana nas articulacoes',(.055,.033,.023),.78)
black=material('Olhos umidos',(.012,.017,.014),.12)
def mesh(name, verts, faces, mat, parent=None):
 me=bpy.data.meshes.new(name);me.from_pydata([v(p) for p in verts],[],faces);me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);me.materials.append(mat)
 for f in me.polygons:f.use_smooth=True
 if mat==shell:
  col=me.color_attributes.new(name='Cor',type='FLOAT_COLOR',domain='POINT')
  for i,vert in enumerate(verts):
   p=Vector(vert);n=noise_vector(p*8.3).x*.5+.5;fine=noise_vector(p*43).y*.5+.5
   t=max(0,min(1,n*.8+fine*.2));t=t*t
   col.data[i].color=(.13+.35*t,.046+.24*t,.022+.12*t,1)
 if parent:o.parent=parent
 return o
body=bpy.data.objects.new('Corpo',None);bpy.context.collection.objects.link(body)
def ellipsoid(name,c,r,mat,parent=body,nu=40,nv=20):
 vs=[];fs=[]
 for j in range(nv+1):
  a=math.pi*j/nv
  for i in range(nu):
   b=2*math.pi*i/nu
   vs.append((c[0]+r[0]*math.sin(a)*math.cos(b),c[1]+r[1]*math.cos(a),c[2]+r[2]*math.sin(a)*math.sin(b)))
 for j in range(nv):
  for i in range(nu):
   a=j*nu+i;b=j*nu+(i+1)%nu;fs.append((a,b,b+nu,a+nu))
 # Ring winding faces out in the right-handed author space.
 return mesh(name,vs,fs,mat,parent)
def tube(name, points, radii, mat= shell, parent=body, sides=14):
 pts=[Vector(p) for p in points];vs=[];fs=[]
 for j,p in enumerate(pts):
  d=(pts[min(j+1,len(pts)-1)]-pts[max(j-1,0)]).normalized();axis=Vector((0,1,0))
  if abs(d.dot(axis))>.95:axis=Vector((0,0,1))
  u=d.cross(axis).normalized();w=d.cross(u).normalized()
  for i in range(sides):
   a=math.tau*i/sides;q=p+radii[j]*(u*math.cos(a)+w*math.sin(a));vs.append(tuple(q))
 for j in range(len(pts)-1):
  for i in range(sides):
   a=j*sides+i;b=j*sides+(i+1)%sides;fs.append((a,b,b+sides,a+sides))
 fs.append(tuple(reversed(range(sides))));fs.append(tuple((len(pts)-1)*sides+i for i in range(sides)))
 return mesh(name,vs,fs,mat,parent)
# Broad, low carapace, scalloped rim, and gastric/branchial regions.
ellipsoid('Carapaca',(0,.91,.08),(1.02,.35,.76),shell,nu=96,nv=40)
ellipsoid('Ventre',(0,.72,.09),(.85,.17,.64),under)
for side in [-1,1]:
 for i in range(8):
  a=.10+i*.28;x=side*math.cos(a)*.98;z=.08+math.sin(a)*.72
  tube('Dente_da_borda',[(x,.91,z),(x+side*.12,.94,z+.04),(x+side*.21,.94,z+.07)],[.085,.057,.003],shell,sides=12)
 for x,z,sx,sz in [(.52,.10,.33,.43),(.27,-.16,.23,.23),(.35,.43,.24,.17)]:
  ellipsoid('Regiao_branquial',(x*side,1.115,z),(sx,.10,sz),shell,nu=32,nv=12)
 # Eye stalks in front of the shell, dark small corneas (no cartoon whites).
 tube('Pedunculo',[(side*.36,1.00,-.51),(side*.44,1.23,-.67),(side*.46,1.36,-.69)],[.085,.061,.048],shell)
 ellipsoid('Olho',(side*.46,1.36,-.71),(.095,.09,.11),black,nu=24,nv=12)
 for i in range(3):
  tube('Maxilipede',[(side*(.05+i*.07),.78,-.64),(side*(.10+i*.06),.67,-.84),(side*.04,.64,-.91)],[.034,.03,.006],under,sides=10)
 # Four pairs of jointed walking legs, rest configuration consumed by the animator.
 for i in range(4):
  z=-.35+i*.29
  hip=(side*.83,.81,z);knee=(side*(1.36+(.09 if i in [1,2] else 0)),.66,z+(i-1.5)*.16)
  foot=(side*(1.84+(.13 if i in [1,2] else 0)),.035,z+(i-1.5)*.31)
  tag=('E' if side<0 else 'D')+'_'+str(i)
  # Meshes in local +Y, unit length: animation sets start/end, preserving thickness.
  for suffix,a,b,r in [('A',hip,knee,.115),('B',knee,foot,.078)]:
   seg=tube('Pata_'+tag+'_'+suffix,[(0,0,0),(0,.18,0),(0,.55,.018),(0,.87,0),(0,1,0)],[r*.7,r,r*.84,r*.47,.007 if suffix=='B' else r*.4],shell,parent=body,sides=16)
   vec=v(b)-v(a);seg.location=v(a);seg.rotation_mode='QUATERNION';seg.rotation_quaternion=Vector((0,0,1)).rotation_difference(vec.normalized());seg.scale=(1,1,vec.length)
  j=ellipsoid('Junta_'+tag,(0,0,0),(.095,.095,.095),joint,nu=16,nv=10)
  j.location=v(knee)
 # Robust chelipeds and two opposing curved fingers, separate moving jaw.
 tag='E' if side<0 else 'D';claw=bpy.data.objects.new('Garra_'+tag,None);bpy.context.collection.objects.link(claw);claw.parent=body
 tube('Braco_'+tag,[(side*.73,.84,-.45),(side*1.19,.65,-.75),(side*1.22,.80,-1.12)],[.16,.22,.17],shell,parent=claw,sides=24)
 ellipsoid('Palma_'+tag,(side*1.12,.84,-1.26),(.32,.27,.39),shell,parent=claw,nu=40,nv=24)
 tube('Dedo_fixo_'+tag,[(side*.93,.86,-1.4),(side*.90,.84,-1.69),(side*1.01,.83,-1.94),(side*1.14,.83,-2.00)],[.14,.115,.055,.003],shell,parent=claw,sides=20)
 finger=tube('Dedo_movel_'+tag,[(side*1.34,.86,-1.4),(side*1.41,.84,-1.64),(side*1.31,.83,-1.89),(side*1.15,.83,-1.99)],[.16,.12,.048,.003],shell,parent=claw,sides=20)
 for k in range(4):
  z=-1.54-k*.075
  tube('Dente_pinça',[(side*.96,.84,z),(side*1.045,.84,z-.025)],[.038,.004],ivory,parent=claw,sides=10)
 anchor=bpy.data.objects.new('Bolhas_'+tag,None);bpy.context.collection.objects.link(anchor);anchor.parent=claw;anchor.location=v((side*1.14,.88,-1.94))
# Raised granular surface detail clustered on shell, where it changes highlights.
for i in range(150):
 x=random.uniform(-.94,.94);z=random.uniform(-.56,.73);q=(x/1.02)**2+((z-.08)/.76)**2
 if q>.91:continue
 y=.91+.35*math.sqrt(1-q);r=random.uniform(.009,.023)
 ellipsoid('Granulo',(x,y,z),(r,r*.45,r),shell,nu=8,nv=4)
# Merge static shell detail into one draw mesh; keep animated limbs separate.
static=[o for o in body.children if o.type=='MESH' and not o.name.startswith(('Pata_','Junta_'))]
bpy.ops.object.select_all(action='DESELECT')
for o in static:o.select_set(True)
bpy.context.view_layer.objects.active=static[0];bpy.ops.object.join();static[0].name='Carapaca_detalhada'
# Merge claw geometry per hand, retaining the emitter markers.
for tag in ['E','D']:
 par=bpy.data.objects['Garra_'+tag];objs=[o for o in par.children if o.type=='MESH' and o.name!='Dedo_movel_'+tag]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name='Pinça_'+tag
bpy.ops.object.select_all(action='SELECT')
for out in ['art_src/pets','assets/models/pets']:(ROOT/out).mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_src/pets/caranguejo.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/pets/caranguejo_grande.glb'),export_format='GLB',export_yup=True,export_animations=False,export_extras=True)
print('CARANGUEJO_EXPORTADO')
