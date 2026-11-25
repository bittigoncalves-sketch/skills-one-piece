"""Fonte autoral: Blender 5.x --background --python art_src/alimentacao/gerar_assets.py.
Unidades em metros; glTF +Y para cima, origem na pega da mão. Sem fontes externas.
"""
import bpy, math, pathlib, random
from mathutils import Vector
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/alimentacao'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name, color, rough=.7, metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    return m
crust=[mat('Crosta dourada',(.62,.245,.055)), mat('Crosta tostada',(.39,.115,.024)), mat('Corte miolo',(.93,.66,.31)), mat('Farinha',(.93,.81,.56))]
blue=mat('Vidro azul estilizado',(.045,.37,.60),.18,.18)
water=mat('Agua turquesa',(.025,.20,.37),.24,.12)
light=mat('Reflexo pintado',(.59,.91,.96),.22)
cream=mat('Rotulo papel',(.92,.83,.61),.8)
ink=mat('Gota azul',(.025,.24,.43),.45)
def mesh(name, verts, faces, mats):
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
    for m in mats: me.materials.append(m)
    for p in me.polygons: p.use_smooth=True
    return ob
def bread():
    # Superellipse along X: plump oval loaf, flat baked underside and scored top.
    v=[]; rows=100; cols=80
    for i in range(rows+1):
        u=-math.pi/2+math.pi*i/rows; x=.19*math.sin(u); r=max(.0005,math.cos(u))**.68
        for j in range(cols):
            a=2*math.pi*j/cols; y=.087*r*math.cos(a); z=.072*r*math.sin(a)
            top=max(0,math.sin(a))**7
            groove=min(abs(x-c-.42*y) for c in [-.105,0,.105])
            z-=.014*math.exp(-(groove/.009)**2)*top
            z+=.0013*math.sin(i*1.3+j*.9)*math.sin(i*.71-j*.73)*r
            z=max(z,-.048)+.024
            v.append((x,y,z))
    f=[]
    for i in range(rows):
        for j in range(cols):
            n=i*cols+j; k=i*cols+(j+1)%cols; f.append((n,k,k+cols,n+cols))
    bread_mat=mat('Crosta e miolo - cor por vertice',(1,1,1),.88)
    attr=bread_mat.node_tree.nodes.new('ShaderNodeVertexColor'); attr.layer_name='Col'
    bread_mat.node_tree.links.new(attr.outputs['Color'],bread_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    ob=mesh('Pao_rustico',v,f,[bread_mat])
    colors=ob.data.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='POINT')
    for vertex,color in zip(ob.data.vertices,colors.data):
        c=vertex.co; groove=min(abs(c.x-q-.42*c.y) for q in [-.105,0,.105])
        top=max(0,min(1,(c.z-.036)/.025))
        cut=math.exp(-(groove/.013)**4)*top
        shade=max(0,min(1,(c.z+.025)/.11))
        grain=.012*math.sin(c.x*700)*math.sin(c.y*930)
        baked=Vector((.36,.12,.022)).lerp(Vector((.70,.33,.075)),shade)
        rgb=baked.lerp(Vector((.93,.69,.36)),cut)+Vector((grain,grain,grain))
        color.color=(*rgb,1)
    return [ob]
def lathe(name, profile, material, segments=64):
    vs=[]
    for z,r in profile:
        for j in range(segments):
            a=2*math.pi*j/segments; vs.append((r*math.cos(a),r*math.sin(a),z))
    fs=[]
    for i in range(len(profile)-1):
        for j in range(segments):
            k=i*segments+j; n=i*segments+(j+1)%segments; fs.append((k,n,n+segments,k+segments))
    return mesh(name,vs,fs,[material])
def bottle():
    # Open neck, rolled rim, raised base, water-colored body and paper band.
    objs=[lathe('Garrafa_agua', [(-.10,0),(-.10,.047),(-.094,.057),(-.083,.06),(.07,.06),(.092,.057),(.12,.031),(.13,.024),(.182,.024),(.19,.029),(.199,.029),(.204,.024),(.204,.018),(.182,.018),(.14,.018)],blue)]
    objs.append(lathe('Agua_visivel',[(-.08,.0605),(.043,.0605),(.047,.060),(.048,.055)],water))
    objs.append(lathe('Rotulo',[(-.044,.061),(.005,.061)],cream))
    # Graphic droplet embossed on the front (-Y -> glTF +Z).
    drop=[(0,-.062,.000),(-.013,-.064,-.019),(-.013,-.064,-.029),(0,-.065,-.036),(.013,-.064,-.029),(.013,-.064,-.019)]
    objs.append(mesh('Gota_do_rotulo',drop,[(0,1,2,3,4,5)],[ink]))
    # Shaped highlight strip, offset on the curved blue shoulder.
    verts=[]
    for z,r,w in [(.021,.061,.007),(.070,.061,.007),(.087,.059,.006),(.11,.041,.004)]:
        for a in [-2.12-w/r,-2.12+w/r]: verts.append((r*math.cos(a),r*math.sin(a),z))
    objs.append(mesh('Reflexo_longo',verts,[(0,1,3,2),(2,3,5,4),(4,5,7,6)],[light]))
    return objs
asset_groups={}
for name,make in [('pao_rustico',bread),('garrafa_agua',bottle)]:
    bpy.ops.object.select_all(action='DESELECT')
    objs=make()
    asset_groups[name]=objs
    for ob in objs: ob.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
    for ob in objs: ob.hide_set(True)
# O .blend abre com as duas peças visíveis, afastadas só para edição.
for name,group in asset_groups.items():
    for ob in group:
        ob.hide_set(False)
        ob.location.x = -.28 if name == 'pao_rustico' else .25
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_src/alimentacao/alimentacao.blend'))
print('ALIMENTACAO: exportados pao e garrafa')
