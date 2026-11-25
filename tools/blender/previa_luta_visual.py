# Prévia da geometria do visual da Luta (mesma lógica de luta_visual.gd): rajada em 3 direções.
import bpy, math, random, sys
from mathutils import Vector
saida = sys.argv[sys.argv.index("--")+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'FLAT'; sc.display.shading.color_type = 'OBJECT'
sc.render.resolution_x = 1600; sc.render.resolution_y = 700
sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.08, 0.08, 0.1)
def cubo(pos, tam, cor, frente=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.active_object; o.scale = tam; o.color = cor
    if frente is not None:
        o.rotation_mode='QUATERNION'; o.rotation_quaternion = frente.to_track_quat('Z','Y')
        o.scale = tam
    return o
OURO=(1,0.78,0.12,1); BR=(1,0.97,0.85,1)
def eixos(f):
    ref = Vector((0,0,1)) if abs(f.z)<0.98 else Vector((1,0,0))
    u=f.cross(ref).normalized(); v=f.cross(u).normalized(); return u,v
def estourar(onde,f,forca,rng):
    u,v=eixos(f)
    cubo(onde,(0.2+0.34*forca,)*3,BR)
    for i in range(5+round(7*forca)):
        a=rng.random()*math.tau; rad=u*math.cos(a)+v*math.sin(a)
        d=(f*rng.uniform(.2,.9)+rad*rng.uniform(.5,1)).normalized()
        l=0.07+0.06*rng.random()+0.04*forca
        cubo(onde+d*rng.uniform(.25,.6),(l,l,l*rng.uniform(1.6,3)),BR if i%3==0 else OURO,d)
    if forca>=.5:
        for i in range(10):
            a=math.tau*i/10; rad=u*math.cos(a)+v*math.sin(a)
            cubo(onde+rad*(0.25+.5),(0.1+.08*forca,)*3,OURO)
def fantasma(org,f,lado,alc=3.1):
    u,v=eixos(f); c=org+f*alc*.5+u*.28*lado
    cubo(c,(0.24,0.24,alc*0.8),(0.9,0.6,0.35,1),f)
def corpo(org):  # ponto de referência do jogador (boneco simples) e alvo
    cubo(org,(0.5,0.4,1.6),(0.3,0.5,0.9,1))
def alvo(p): cubo(p,(0.6,0.4,1.2),(0.8,0.3,0.3,1))
rng=random.Random(4)
casos=[(Vector((1,0,0)),Vector((-8,0,0))),(Vector((0.66,0,0.75)).normalized(),Vector((-1,0,-1.5))),(Vector((0.66,0,-0.75)).normalized(),Vector((6,0,1.5)))]
for f,org in casos:
    corpo(org); alvo(org+f*2.5)
    for k in range(3):
        fantasma(org,f,1 if k%2==0 else -1)
    estourar(org+f*2.5,f,0.15,rng); estourar(org+f*2.5+f*0.4,f,0.6,rng)
cam=bpy.data.cameras.new("c"); cam.type='ORTHO'; cam.ortho_scale=19
co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
co.location=(0,-30,0.5); co.rotation_euler=(math.pi/2,0,0)
sc.render.filepath=saida; bpy.ops.render.render(write_still=True)
