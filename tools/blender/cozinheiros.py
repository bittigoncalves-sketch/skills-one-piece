"""Cinco cozinheiros autorais para a cidade (15/10/2026).

Blender -b -P tools/blender/cozinheiros.py
Fonte: art_src/cozinheiros/*.blend; entrega: mapas/modelos/cozinheiro_*.glb.
Metros; Blender +Y = frente, +Z = cima; glTF/Godot -Z = frente.
Malha deformável, pesos explícitos nas juntas e quatro ações por personagem.
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector, Euler, Matrix, Quaternion

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cozinheiros_blocos import converter, limpar, unir_volumes, CONFIG

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'mapas/modelos'
SRC = ROOT / 'art_src/cozinheiros'
SRC.mkdir(parents=True, exist_ok=True)
PALETA = {
    'pele': (.72, .43, .25), 'sombra_pele': (.45, .23, .13),
    'branco': (.88, .85, .73), 'preto': (.018, .024, .038),
    'sola': (.009, .012, .017), 'cabelo': (.11, .045, .018),
    'ouro': (.66, .39, .08), 'metal': (.30, .36, .40),
    'camisa': (.18, .43, .66), 'tecido': (.82, .78, .65),
    'calca': (.025, .038, .057), 'acento': (.5, .035, .024),
    'lapela': (.035, .046, .065), 'iris': (.10, .24, .31),
    'placa': (.048, .058, .072), 'linha': (.006, .009, .014),
    'cabelo_luz': (1.0, .71, .065), 'cabelo_sombra': (.56, .30, .015),
    'botao_ouro': (.98, .72, .10),
}
PERFIS = [
    # Sanji refeito em 17/10/2026: células de .027 (mais voxel), tronco e membros mais
    # grossos (`membros`) e o cabelo em volumes cheios, como o Barba Negra e a Nami.
    dict(id='sanji', nome='Sanji', h=1.84, w=1.0, pele=(.88,.60,.37),
         cabelo=(1.0,.69,.035), tecido=(.023,.029,.044), acento=(.13,.32,.52), estilo='terno',
         cel=.027, membros=1.3),
    dict(id='beto', nome='Beto · Mestre do fogão', h=1.85, w=1.28, pele=(.67,.36,.19),
         cabelo=(.07,.025,.012), tecido=(.90,.86,.74), acento=(.62,.045,.026), estilo='toque'),
    dict(id='iara', nome='Iara · Confeiteira', h=1.76, w=.88, pele=(.42,.19,.085),
         cabelo=(.035,.012,.008), tecido=(.035,.30,.26), acento=(.92,.53,.15), estilo='coque'),
    dict(id='ravi', nome='Ravi · Cozinha do mar', h=1.90, w=.91, pele=(.55,.28,.13),
         cabelo=(.022,.032,.039), tecido=(.69,.63,.49), acento=(.31,.045,.075), estilo='bandana'),
    dict(id='otto', nome='Otto · Padeiro', h=1.82, w=1.10, pele=(.84,.55,.33),
         cabelo=(.28,.13,.045), tecido=(.78,.75,.66), acento=(.055,.20,.40), estilo='gorro'),
]
MATS = {}
PARTES = []
RIG = None


def material(nome, cor):
    m = bpy.data.materials.new(nome)
    m.diffuse_color = (*cor, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*cor, 1)
    bs.inputs['Roughness'].default_value = .76
    if nome in ('ouro', 'metal'):
        bs.inputs['Metallic'].default_value = .72
        bs.inputs['Roughness'].default_value = .3
    return m


def finalizar(obj, nome, mat, osso, pesos=None):
    obj.name = nome
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Cabeça maior e volumes quadriculados como o Barba Negra, por pedido atual.
    if osso == 'Head':
        for v in obj.data.vertices:
            v.co.x *= 1.35
            v.co.y *= 1.23
            v.co.z = 1.53 + (v.co.z - 1.53) * 1.18
    if not nome.startswith('Utensilio') and osso.split('_')[0] in ('Hand','Index','Middle','Ring','Little','Thumb'):
        side=osso.rsplit('_',1)[1]
        wrist=RIG.data.bones['Hand_'+side].head_local
        for v in obj.data.vertices:
            v.co=wrist+(v.co-wrist)*1.22
    converter(obj, nome, osso, pesos)
    obj.data.materials.append(MATS[mat])
    if pesos:
        for v in obj.data.vertices:
            for bone, weight in pesos(v.co).items():
                if weight > 0:
                    group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
                    group.add([v.index], weight, 'REPLACE')
    else:
        obj.vertex_groups.new(name=osso).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    for face in obj.data.polygons:
        face.use_smooth = False
    obj.select_set(False)
    PARTES.append(obj)
    return obj


def ovo(nome, p, s, mat, bone='Head', segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=p)
    obj = bpy.context.object
    obj.scale = s
    return finalizar(obj, nome, mat, bone)


def caixa(nome, p, s, mat, bone, bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    obj = bpy.context.object
    obj.scale = s
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new('Costuras arredondadas', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finalizar(obj, nome, mat, bone)


def perfil(nome, rings, mat, bone, pesos=None, n=24):
    # Superelipse: superfícies amplas e cantos quadrados, como a referência enviada.
    verts = []
    for x,y,z,rx,ry in rings:
        for i in range(n):
            a = 2*math.pi*i/n
            cx=math.cos(a); cy=math.sin(a)
            power=1.0 if nome.startswith('Utensilio') else .30
            verts.append((x+rx*math.copysign(abs(cx)**power,cx), y+ry*math.copysign(abs(cy)**power,cy), z))
    faces = [tuple(reversed(range(n)))]
    for j in range(len(rings)-1):
        for i in range(n):
            a=j*n+i; b=j*n+(i+1)%n
            faces.append((a,b,b+n,a+n))
    faces.append(tuple((len(rings)-1)*n+i for i in range(n)))
    mesh=bpy.data.meshes.new(nome)
    mesh.from_pydata(verts, [], faces); mesh.update()
    obj=bpy.data.objects.new(nome, mesh)
    bpy.context.collection.objects.link(obj)
    return finalizar(obj,nome,mat,bone,pesos)


def linha(nome, points, radius, mat, bone='Head'):
    curve=bpy.data.curves.new(nome, 'CURVE'); curve.dimensions='3D'
    curve.bevel_depth=radius; curve.bevel_resolution=2
    spline=curve.splines.new('POLY'); spline.points.add(len(points)-1)
    for pt, co in zip(spline.points,points): pt.co=(*co,1)
    obj=bpy.data.objects.new(nome,curve); bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.convert(target='MESH')
    return finalizar(obj,nome,mat,bone)


def painel(nome, coords, mat, bone='Spine'):
    mesh=bpy.data.meshes.new(nome); mesh.from_pydata(coords,[],[tuple(range(len(coords)))])
    mesh.update(); obj=bpy.data.objects.new(nome,mesh); bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Espessura do tecido','SOLIDIFY'); mod.thickness=max(.009,CONFIG['cel']*.6)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finalizar(obj,nome,mat,bone)


def placa(nome, p, size, mat, bone):
    # Camada preta recuada e placa menor saliente: relevos têm bordas legíveis.
    x,y,z=p; sx,sy,sz=size
    caixa('Contorno_'+nome,(x,y-.004,z),(sx+.008,sy,sz+.008),'linha',bone,.001)
    return caixa('Placa_'+nome,(x,y+.004,z),(sx,sy,sz),mat,bone,.001)


def rig_criar(w):
    global RIG
    arm=bpy.data.armatures.new('Esqueleto'); RIG=bpy.data.objects.new('Rig',arm)
    bpy.context.collection.objects.link(RIG); bpy.context.view_layer.objects.active=RIG
    RIG.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
    def bone(n,h,t,parent=None):
        b=arm.edit_bones.new(n); b.head=h; b.tail=t
        if parent: b.parent=arm.edit_bones[parent]
    bone('Root',(0,0,0),(0,0,.15))
    bone('Hips',(0,0,.88),(0,0,1.04),'Root')
    bone('Spine',(0,0,1.04),(0,0,1.34),'Hips')
    bone('Chest',(0,0,1.34),(0,0,1.49),'Spine')
    bone('Neck',(0,0,1.49),(0,0,1.58),'Chest')
    bone('Head',(0,0,1.58),(0,0,1.85),'Neck')
    for side, s in [('R',1),('L',-1)]:
        x=s*.265*w; elbow=x+s*.075; wrist=x+s*.12
        bone('Shoulder_'+side,(s*.1,0,1.42),(x,0,1.42),'Chest')
        bone('UpperArm_'+side,(x,0,1.42),(elbow,0,1.15),'Shoulder_'+side)
        bone('ForeArm_'+side,(elbow,0,1.15),(wrist,0,.90),'UpperArm_'+side)
        bone('Hand_'+side,(wrist,0,.90),(wrist+s*.018,0,.81),'ForeArm_'+side)
        for i,f in enumerate(['Index','Middle','Ring','Little']):
            fx=wrist+s*((i-1.5)*.022+.012)
            bone(f+'_'+side,(fx,.012,.82),(fx,.02,.755+(abs(i-1.3))*.009),'Hand_'+side)
        bone('Thumb_'+side,(wrist-s*.04,.015,.87),(wrist-s*.067,.045,.81),'Hand_'+side)
        hip=s*.115*w
        bone('Thigh_'+side,(hip,0,.92),(hip,.015,.51),'Hips')
        bone('Shin_'+side,(hip,.015,.51),(hip,0,.12),'Thigh_'+side)
        bone('Foot_'+side,(hip,0,.12),(hip,.15,.075),'Shin_'+side)
        wrist_point=arm.edit_bones['Hand_'+side].head.copy()
        for finger in ('Index','Middle','Ring','Little','Thumb'):
            b=arm.edit_bones[finger+'_'+side]
            b.head=wrist_point+(b.head-wrist_point)*1.22
            b.tail=wrist_point+(b.tail-wrist_point)*1.22
    bpy.ops.object.mode_set(mode='OBJECT'); RIG.select_set(False)


def construir(p):
    global PARTES,MATS
    CONFIG['cel']=p.get('cel',.018); lw=p.get('membros',1.0)
    def grosso(rings): return [(x,y,z,rx*lw,ry*lw) for x,y,z,rx,ry in rings]
    bpy.ops.wm.read_factory_settings(use_empty=True); PARTES=[]; limpar()
    cores=dict(PALETA)
    for k in ('pele','cabelo','tecido','acento'): cores[k]=p[k]
    if p['estilo']!='terno':
        cores['placa']=tuple(min(1,c*.90) for c in p['tecido'])
    cores['sombra_pele']=tuple(c*.6 for c in p['pele'])
    MATS={k:material(k,c) for k,c in cores.items()}
    w=p['w']; estilo=p['estilo']; sanji=estilo=='terno'; rig_criar(w)
    def tronco_pesos(v):
        t=max(0,min(1,(v.z-1.22)/.18))
        return {'Spine':1-t,'Chest':t}
    perfil('Casaco',[(0,0,1.0,.20*w,.13),(0,0,1.04,.22*w,.145),
        (0,0,1.18,.215*w,.15 if w<1.2 else .21),(0,0,1.34,.245*w,.15),
        (0,0,1.44,.265*w,.125),(0,0,1.49,.18*w,.10)],'tecido','Spine',tronco_pesos)
    perfil('Quadril',[(0,0,.86,.18*w,.11),(0,0,.99,.20*w,.13),(0,0,1.04,.19*w,.12)],'calca','Hips')
    ovo('Pescoço',(0,0,1.53),(.072,.072,.11),'pele','Neck')
    for side,s in [('R',1),('L',-1)]:
        hip=s*.115*w; arm=s*.265*w
        def perna(v, side=side):
            t=max(0,min(1,(v.z-.44)/.14)); return {'Thigh_'+side:t,'Shin_'+side:1-t}
        perfil('Calça_'+side,grosso([(hip,0,.13,.074,.078),(hip,0,.22,.074,.08),
            (hip,.01,.44,.078,.085),(hip,.015,.51,.082,.085),(hip,0,.59,.088,.094),
            (hip,0,.81,.098*w,.11),(hip,0,.94,.104*w,.115)]),'calca','Thigh_'+side,perna)
        caixa('Bloco_sola_'+side,(hip,.075,.035),(.195*lw,.35,.065),'sola','Foot_'+side,.004)
        caixa('Bloco_sapato_'+side,(hip,.07,.10),(.18*lw,.32,.095),'preto','Foot_'+side,.007)
        placa('biqueira_'+side,(hip,.20,.105),(.17,.035,.065),'placa','Foot_'+side)
        placa('peito_pe_'+side,(hip,.075,.152),(.145,.15,.018),'placa','Foot_'+side)
        linha('Costura_sapato_'+side,[(hip-.06,.15,.115),(hip,.19,.12),(hip+.06,.15,.115)],.003,'lapela','Foot_'+side)
        elbow=arm+s*.075; wrist=arm+s*.12
        def braco(v,side=side):
            t=max(0,min(1,(v.z-1.10)/.11)); return {'UpperArm_'+side:t,'ForeArm_'+side:1-t}
        perfil('Manga_'+side,grosso([(wrist,0,.91,.061,.062),(wrist-s*.012,0,1.0,.066,.066),
            (elbow,0,1.12,.074,.075),(elbow-s*.012,0,1.20,.077,.078),
            (arm+s*.012,0,1.37,.089,.09),(arm,0,1.45,.086,.087)]),'tecido','UpperArm_'+side,braco)
        perfil('Punho_'+side,grosso([(wrist,0,.885,.063,.064),(wrist,0,.929,.063,.064)]),'camisa' if sanji else 'branco','ForeArm_'+side)
        ovo('Palma_'+side,(wrist,0,.85),(.058,.037,.064),'pele','Hand_'+side)
        for i,f in enumerate(['Index','Middle','Ring','Little']):
            fx=wrist+s*((i-1.5)*.022+.012)
            ovo(f+side,(fx,.015,.79),(.012,.018,.037-abs(i-1.3)*.004),'pele',f+'_'+side,12,8)
        ovo('Polegar'+side,(wrist-s*.051,.025,.84),(.021,.027,.035),'pele','Thumb_'+side,12,8)
        # Dobra do cotovelo e botão do punho dão leitura ao movimento.
        ovo('Botão_manga'+side,(wrist+s*.055,.026,.92),(.009,.009,.009),'ouro','ForeArm_'+side,12,8)
    # Face esculpida por seções: mandíbula e maçãs; olhos, nariz e orelhas separados.
    perfil('Rosto',[(0,0,1.56,.117,.087),(0,0,1.59,.136,.101),
        (0,0,1.66,.145,.105),(0,0,1.76,.145,.105),
        (0,-.005,1.84,.139,.102),(0,-.008,1.88,.115,.085)],'pele','Head')
    for s in (-1,1):
        caixa('Bloco_orelha',(s*.15,0,1.71),(.038,.052,.071),'pele','Head',.003)
        caixa('Bloco_orelha_dentro',(s*.16,.027,1.71),(.015,.009,.035),'sombra_pele','Head',.001)
        if sanji and s==1: continue
        caixa('Bloco_contorno_olho',(s*.061,.112,1.735),(.066,.012,.030),'linha','Head',.002)
        caixa('Bloco_olho',(s*.061,.12,1.734),(.058,.009,.021),'branco','Head',.001)
        caixa('Bloco_pupila',(s*.058,.127,1.735),(.012,.006,.017),'linha','Head',.001)
        linha('Sobrancelha',[(s*.024,.122,1.752),(s*.055,.124,1.761),(s*.095,.12,1.774)],.006,'linha')
    caixa('Bloco_nariz',(0,.125,1.689),(.028,.041,.052),'pele','Head',.004)
    linha('Boca',[(-.048,.111,1.629),(-.015,.115,1.635),(.022,.113,1.634),(.044,.11,1.625)],.003,'sombra_pele')
    if not sanji:
        caixa('Bloco_cabelo_base',(0,-.017,1.852),(.316,.255,.115),'cabelo','Head',.008)
    if sanji:
        # Cabelo em volumes CHEIOS (voxelizados na mesma grade do corpo), sem mechas finas
        # sobrepostas: crânio, franja que esconde o olho do lado +X, mecha que desce até a
        # bochecha, laterais e nuca. O olho do lado -X fica livre, com a sobrancelha.
        ovo('Cabelo_cranio',(0,-.012,1.855),(.158,.142,.112),'cabelo')
        caixa('Cabelo_franja',(.078,.100,1.768),(.150,.056,.190),'cabelo','Head',.001)
        caixa('Cabelo_franja_ponta',(.118,.104,1.664),(.070,.048,.100),'cabelo','Head',.001)
        caixa('Cabelo_franja_alta',(-.065,.104,1.822),(.135,.052,.075),'cabelo','Head',.001)
        for s in (-1,1):
            caixa('Cabelo_lateral',(s*.150,-.025,1.765),(.052,.200,.205),'cabelo','Head',.001)
        caixa('Cabelo_nuca',(0,-.108,1.765),(.275,.085,.225),'cabelo','Head',.001)
        caixa('Cabelo_luz_topo',(.035,.020,1.962),(.110,.120,.030),'cabelo_luz','Head',.001)
        caixa('Cabelo_luz_frente',(.090,.118,1.800),(.060,.020,.100),'cabelo_luz','Head',.001)
        caixa('Cabelo_sombra_nuca',(0,-.150,1.700),(.230,.025,.120),'cabelo_sombra','Head',.001)
        pts=[]
        for i in range(25):
            t=i/24*math.pi*2.2; r=.016*(1-i/33)
            pts.append((-.070+r*math.cos(t),.119,1.788+r*math.sin(t)))
        linha('Espiral_Sanji',pts,.0028,'linha')
        for i in range(7):
            caixa('Bloco_barba',(i*.011-.033,.109,1.59),(.004,.006,.009),'linha','Head',.0005)
        caixa('Bloco_cavanhaque',(0,.112,1.58),(.024,.008,.018),'linha','Head',.001)
        for i in range(7):
            caixa('Bloco_bigode',(i*.012-.036,.115,1.651),(.003,.005,.006),'sombra_pele','Head',.0005)
        linha('Cigarro',[(-.043,.119,1.631),(-.079,.17,1.614)],.006,'branco')
        # Peito em caixas na grade do corpo (painéis finos davam pontilhado): camisa azul
        # lisa e gravata preta, uma camada à frente do paletó. Sem lapelas: elas se
        # misturavam ao casaco preto e sujavam a leitura (17/10/2026).
        caixa('Camisa_azul',(0,.172,1.335),(.17,.040,.30),'camisa','Spine',.001)
        caixa('Gola_camisa',(0,.172,1.475),(.20,.040,.045),'camisa','Chest',.001)
        caixa('Gravata',(0,.200,1.335),(.050,.030,.26),'preto','Spine',.001)
    else:
        # Avental acompanha a cintura; a bainha fica acima dos joelhos.
        painel('Avental',[(-.17*w,.148,1.10),(.17*w,.148,1.10),(.19*w,.14,.77),
            (-.19*w,.14,.77)],'branco','Hips')
        caixa('Bolso_avental',(0,.159,.91),(.20*w,.012,.13),'tecido','Hips',.012)
        linha('Bainha_avental',[(-.18*w,.15,.79),(0,.158,.78),(.18*w,.15,.79)],.004,'acento','Hips')
        perfil('Faixa_cintura',[(0,0,1.055,.225*w,.161),(0,0,1.09,.225*w,.161)],'acento','Spine')
        perfil('Gola',[(0,0,1.46,.09,.09),(0,0,1.51,.079,.079)],'branco','Chest')
        for s in (-1,1):
            painel('Lenço',[(s*.07,.095,1.50),(s*.12,.125,1.43),(0,.172,1.35)],'acento','Chest')
        ovo('Nó_lenço',(0,.171,1.365),(.035,.024,.027),'acento','Chest')
        painel('Ponta_lenço',[(-.018,.17,1.36),(.024,.17,1.36),(.05,.17,1.24),(.01,.175,1.26)],'acento')
        if estilo=='toque':
            perfil('Base_toque',[(0,-.01,1.82,.137,.11),(0,-.01,1.94,.143,.116)],'branco','Head')
            for i in range(7):
                a=i*2*math.pi/7
                ovo('Gomos_toque',(.092*math.cos(a),-.01+.07*math.sin(a),1.98),(.083,.076,.105),'branco')
            ovo('Centro_toque',(0,-.01,2.01),(.10,.09,.09),'branco')
        elif estilo=='coque':
            ovo('Coque',(0,-.08,1.94),(.095,.09,.10),'cabelo')
            perfil('Fita_cabelo',[(0,-.01,1.81,.139,.112),(0,-.01,1.85,.139,.112)],'acento','Head')
            for s in (-1,1): ovo('Brinco',(s*.145,.015,1.67),(.013,.01,.019),'ouro')
        elif estilo=='bandana':
            perfil('Bandana',[(0,-.012,1.79,.14,.114),(0,-.02,1.86,.14,.114),(0,-.02,1.90,.09,.08)],'acento','Head')
            painel('Cauda_bandana',[(.10,-.1,1.84),(.16,-.12,1.84),(.15,-.15,1.57),(.11,-.14,1.62)],'acento','Head')
        else:
            ovo('Gorro',(0,-.02,1.88),(.17,.13,.075),'branco')
            perfil('Faixa_gorro',[(0,-.01,1.80,.14,.112),(0,-.01,1.85,.143,.115)],'acento','Head')
        if estilo in ('toque','gorro'):
            for s in (-1,1):
                linha('Bigode',[(s*.008,.137,1.662),(s*.035,.125,1.656),
                    (s*.065,.102,1.661),(s*.082,.088,1.68)],.013,'cabelo')
    for s in (-1,1):
        for z in (1.13,1.23,1.32):
            ovo('Botão', (s*(.135 if sanji else .093*w),.225 if sanji else (.181 if w<1.2 else .23),z),
                (.030,.020,.030) if sanji else (.017,.012,.017),
                'botao_ouro' if sanji else 'preto','Spine',12,8)
    # Placas maiores reproduzem os relevos da imagem; todas seguem o osso local.
    for side,s in [('R',1),('L',-1)]:
        arm=s*.265*w; elbow=arm+s*.075; hip=s*.115*w
        placa('ombro_'+side,(arm,.104,1.408),(.153,.025,.112),'placa','UpperArm_'+side)
        placa('manga_alta_'+side,(arm+s*.035,.098,1.285),(.126,.024,.10),'placa','UpperArm_'+side)
        placa('manga_baixa_'+side,(elbow+s*.02,.085,1.015),(.105,.024,.12),'placa','ForeArm_'+side)
        placa('calca_coxa_'+side,(hip,.11,.75),(.132,.025,.24),'calca','Thigh_'+side)
        placa('calca_canela_'+side,(hip,.09,.32),(.123,.025,.27),'calca','Shin_'+side)
        if sanji:
            placa('aba_terno_'+side,(s*.106,.159,1.035),(.18,.027,.12),'placa','Spine')
            for j in range(2):
                caixa('Bloco_botao_punho',(arm+s*.12+s*(j-.5)*.03,.095,.938),(.022,.02,.022),'botao_ouro','ForeArm_'+side,.003)
    # Relevos de tecido: barras, bolsos e costuras em pequenas placas quadradas.
    for s in (-1,1):
        for k in range(7):
            x=s*(.07+k*.019)*w
            caixa('Costura_casaco',(x,.151,1.035),(.016,.012,.014),'lapela' if sanji else 'branco','Spine',.001)
        for k in range(4):
            caixa('Costura_bolso',(s*(.11+k*.014)*w,.153,1.16),(.012,.012,.014),'lapela' if sanji else 'acento','Spine',.001)
    # Objetos presos à mão pelo mesmo skin. Só ficam visíveis no clipe culinário.
    for side,s in [('L',-1),('R',1)]:
        wrist=s*(.265*w+.12)
        if side=='L':
            caixa('Utensilio_panela_cabo',(wrist,.035,.715),(.035,.032,.25),'cabelo','Hand_L',.009)
            perfil('Utensilio_panela',[(wrist,.04,.51,.13,.13),(wrist,.04,.55,.15,.15),
                (wrist,.04,.575,.15,.15),(wrist,.04,.575,.135,.135),
                (wrist,.04,.535,.115,.115)],'metal','Hand_L')
            ovo('Utensilio_comida',(wrist,.04,.543),(.105,.105,.012),'acento','Hand_L')
            # Em repouso a panela fica vertical; o braço a leva à horizontal.
            for obj in PARTES:
                if obj.name.startswith(('Utensilio_panela','Utensilio_comida')) and 'cabo' not in obj.name:
                    for v in obj.data.vertices:
                        dy=v.co.y-.04; dz=v.co.z-.54
                        v.co.y=.04+dz
                        v.co.z=.54-dy
        else:
            linha('Utensilio_colher_cabo',[(wrist,.03,.84),(wrist,.03,.57)],.012,'ouro','Hand_R')
            ovo('Utensilio_colher',(wrist,.03,.55),(.029,.015,.048),'ouro','Hand_R')
    # Corpo consolidado; utensílios separados para serem ocultados no descanso.
    body=[o for o in PARTES if not o.name.startswith('Utensilio')]
    props=[o for o in PARTES if o.name.startswith('Utensilio')]
    unir_volumes(body)
    bpy.ops.object.select_all(action='DESELECT')
    for o in body: o.select_set(True)
    bpy.context.view_layer.objects.active=body[0]; bpy.ops.object.join()
    body=[bpy.context.object]; body[0].name='Corpo_'+p['id']
    for o in body+props:
        mod=o.modifiers.new('Deformação por ossos','ARMATURE'); mod.object=RIG; o.parent=RIG
    animar()
    scale=p['h']/1.9
    RIG.scale=(scale,)*3
    bpy.context.scene.frame_set(1)
    RIG.animation_data.action=None
    for b in RIG.pose.bones:
        b.rotation_quaternion=(1,0,0,0); b.location=(0,0,0)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(p['id']+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/('cozinheiro_'+p['id']+'.glb')),
        export_format='GLB', export_animations=True, export_animation_mode='ACTIONS',
        export_force_sampling=True, export_frame_range=False, export_skins=True,
        export_yup=True, export_apply=False, export_all_influences=False)
    vertices=[v.co for obj in body+props for v in obj.data.vertices]
    altura=(max(v.z for v in vertices)-min(v.z for v in vertices))*scale
    tris=sum(len(face.vertices)-2 for obj in body+props for face in obj.data.polygons)
    return dict(id='cozinheiro_'+p['id'], nome=p['nome'], ossos=len(RIG.data.bones),
                altura=round(altura,4), triangulos=tris,
                clipes=['descanso','caminhada','saudacao','cozinhar'])


def animar():
    scene=bpy.context.scene; scene.render.fps=30
    RIG.animation_data_create()
    for nome,frames in [('descanso',120),('caminhada',36),('saudacao',90),('cozinhar',90)]:
        action=bpy.data.actions.new(nome); RIG.animation_data.action=action
        scene.frame_start=1; scene.frame_end=frames+1
        for frame in range(1,frames+2,3):
            u=(frame-1)/frames; a=u*2*math.pi; scene.frame_set(frame)
            rot={}; loc={}
            if nome=='descanso':
                rot={'Chest':(.017*math.sin(a),0,0),'Head':(0,.024*math.sin(a),.02*math.sin(a))}
                for side,s in [('R',1),('L',-1)]: rot['ForeArm_'+side]=(.055,0,s*.01*math.sin(a))
            elif nome=='caminhada':
                for side,s in [('R',1),('L',-1)]:
                    ph=a+(0 if s==1 else math.pi)
                    rot['Thigh_'+side]=(.38*math.sin(ph),0,0)
                    rot['Shin_'+side]=(-.48*max(0,math.sin(ph)),0,0)
                    rot['Foot_'+side]=(.16*max(0,math.sin(ph)),0,0)
                    rot['UpperArm_'+side]=(-.28*math.sin(ph),0,0)
                    rot['ForeArm_'+side]=(-.16-.06*math.sin(ph),0,0)
                rot['Spine']=(0,0,.035*math.sin(a))
                loc['Hips']=(0,0,.016*(1-math.cos(2*a)))
            elif nome=='saudacao':
                envelope=math.sin(math.pi*u)**.7
                rot['UpperArm_R']=(.35*envelope,-1.15*envelope,0)
                rot['ForeArm_R']=(1.45*envelope,0,0)
                rot['Hand_R']=(0,.22*math.sin(a*3)*envelope,0)
                rot['Head']=(.045*envelope,0,-.10*envelope)
                rot['Chest']=(0,0,-.04*envelope)
            else:
                # Cotovelos sustentam os utensílios; punhos compensam a inclinação.
                rot['UpperArm_L']=(.32,-.32,0)
                rot['ForeArm_L']=(1.20+.025*math.sin(a),0,0)
                rot['Hand_L']=(.05,0,0)
                rot['UpperArm_R']=(.40+.04*math.sin(a),.64,0)
                rot['ForeArm_R']=(1.0+.07*math.sin(a),0,.09*math.cos(a))
                rot['Hand_R']=(-.5,0,0)
                rot['Head']=(-.15,0,.045*math.sin(a))
                rot['Chest']=(.035,0,.025*math.sin(a))
                for side,s in [('R',1),('L',-1)]:
                    for finger in ('Index','Middle','Ring','Little'):
                        rot[finger+'_'+side]=(1.0,0,0)
                    rot['Thumb_'+side]=(.35,-.45*s,0)
            for bone in RIG.pose.bones:
                # Converte rotações nos eixos do personagem para o repouso de cada osso.
                basis=bone.bone.matrix_local.to_3x3()
                mat=Euler(rot.get(bone.name,(0,0,0)),'XYZ').to_matrix()
                bone.rotation_mode='QUATERNION'
                bone.rotation_quaternion=(basis.inverted() @ mat @ basis).to_quaternion()
                offset=Vector(loc.get(bone.name,(0,0,0)))
                bone.location=basis.inverted() @ offset
                bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
                bone.keyframe_insert('location',frame=frame,group=bone.name)
            if nome=='cozinhar':
                # Targets measured in character space, same for all silhouettes.
                # The spoon tip traces a small circle INSIDE the pan.
                bpy.context.view_layer.update()
                ik_braco('L',Vector((-.16,.36,1.18)),Quaternion((1,0,0),math.pi/2))
                wrist=Vector((.08,.43,1.43))
                tip=Vector((-.16+.035*math.cos(a),.70+.035*math.sin(a),1.18))
                spoon=Vector((0,0,-1)).rotation_difference((tip-wrist).normalized())
                ik_braco('R',wrist,spoon)
                for side in ('L','R'):
                    for part in ('UpperArm_','ForeArm_','Hand_'):
                        bone=RIG.pose.bones[part+side]
                        bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
                        bone.keyframe_insert('location',frame=frame,group=bone.name)
        # Slots e NLA mantêm as quatro ações associadas ao rig no Blender 5.
        track=RIG.animation_data.nla_tracks.new(); track.name=nome
        strip=track.strips.new(nome,1,action); strip.action_slot=RIG.animation_data.action_slot
        track.mute=True
    RIG.animation_data.action=None


def ik_braco(side, wrist, hand_deform):
    upper=RIG.pose.bones['UpperArm_'+side]; lower=RIG.pose.bones['ForeArm_'+side]
    hand=RIG.pose.bones['Hand_'+side]
    shoulder=upper.head.copy()
    delta=wrist-shoulder; distance=delta.length; axis=delta.normalized()
    l1=upper.bone.length; l2=lower.bone.length
    d=min(distance,l1+l2-.0001)
    mid=(l1*l1-l2*l2+d*d)/(2*d)
    height=math.sqrt(max(0,l1*l1-mid*mid))
    pole=Vector((1 if side=='R' else -1,0,-.7))
    pole=(pole-axis*pole.dot(axis)).normalized()
    elbow=shoulder+axis*mid+pole*height
    for bone,start,end in ((upper,shoulder,elbow),(lower,elbow,wrist)):
        rest_direction=bone.bone.tail_local-bone.bone.head_local
        rotation=rest_direction.rotation_difference(end-start) @ bone.bone.matrix_local.to_quaternion()
        bone.matrix=Matrix.LocRotScale(start,rotation,Vector((1,1,1)))
        bpy.context.view_layer.update()
    hand.matrix=Matrix.LocRotScale(wrist,hand_deform @ hand.bone.matrix_local.to_quaternion(),Vector((1,1,1)))
    bpy.context.view_layer.update()


if __name__=='__main__':
    # `-- sanji` refaz só esse cozinheiro (e atualiza a entrada dele no manifesto).
    so=[a for a in sys.argv[sys.argv.index('--')+1:]] if '--' in sys.argv else []
    novos=[construir(p) for p in PERFIS if not so or p['id'] in so]
    if so:
        antigo=json.loads((SRC/'manifesto.json').read_text())
        por_id={m['id']:m for m in antigo}
        por_id.update({m['id']:m for m in novos})
        manifest=[por_id[m['id']] if m['id'] in por_id else m for m in antigo]
    else:
        manifest=novos
    (SRC/'manifesto.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('COZINHEIROS_EXPORTADOS',json.dumps(manifest,ensure_ascii=False))
