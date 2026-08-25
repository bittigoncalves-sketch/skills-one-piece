# ============================================================================
#  O PERSONAGEM E TODAS AS SUAS ANIMAÇÕES, NUM .blend
#
#  Uso (a partir da raiz do projeto):
#     godot --headless --path . -s tools/export_rig.gd     # rig  -> JSON
#     godot --headless --path . -s tools/export_anims.gd   # 29 clipes -> JSON
#     blender --background --python tools/blender/montar_personagem.py
#
#  Saída: art_src/blender/personagem_base.blend
#
#  ---------------------------------------------------------------- O FORMATO
#  Uma ARMATURE com os 13 papéis do rig A (BodyScanner.ROLES) e UMA ACTION POR
#  ANIMAÇÃO — 29 delas, trocáveis no dropdown do Action Editor. As caixas do
#  personagem voxel entram como malhas presas aos ossos.
#
#  Por que armature e não uma hierarquia de objetos igual à do Godot: no Godot o
#  rig É uma hierarquia de nós, e copiá-la ao pé da letra daria 13 objetos × 29
#  animações = 377 actions soltas, porque no Blender cada OBJETO só segura uma
#  action por vez. Com armature são 29 actions em um objeto só, que é como um
#  animador espera trabalhar.
#
#  ------------------------------------------------- A PARTE FÁCIL DE ERRAR
#  Godot é Y-up com a frente em −Z; Blender é Z-up com a frente em −Y. E o rig
#  do jogo pendura os membros no −Y LOCAL (o cotovelo fica em (0,−0.312,0)),
#  enquanto o osso do Blender aponta no +Y LOCAL dele.
#
#  São duas conversões diferentes e independentes:
#
#    C  — eixos do MUNDO:  (x, y, z)_godot  ->  (x, −z, y)_blender
#    F  — giro de 180° em X, que faz o osso apontar ao longo do membro em vez
#         de contra ele. Como F muda a BASE em que a pose é escrita, toda
#         rotação local precisa ser conjugada:  R' = F⁻¹ · R · F
#
#  Errar qualquer uma das duas colapsa os membros para dentro do corpo — é o
#  mesmo tipo de erro que o `SkeletonDriver` documenta para os modelos Meshy.
#  Por isso este script NÃO confia na conta: ele COMPARA a pose avaliada pelo
#  Blender com uma cinemática direta feita em Python puro sobre o mesmo JSON, e
#  recusa a exportação se divergirem (ver `conferir()`).
# ============================================================================

import bpy, json, math, os, sys
from mathutils import Matrix, Vector, Euler

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RIGS = os.path.join(RAIZ, "tools", "anim_editor", "rigs")
CLIPS = os.path.join(RAIZ, "tools", "anim_editor", "clips")
SAIDA_DIR = os.path.join(RAIZ, "art_src", "blender")
SAIDA = os.path.join(SAIDA_DIR, "personagem_base.blend")

FPS = 30                      # os clipes do Mixamo foram assados a 30 Hz
# Tolerância da conferência, em METROS.
#
# ⚠️ ELA NÃO FOI ESCOLHIDA PARA O TESTE PASSAR. 1e-4 (0,1 mm) foi a primeira
# tentativa e acusava 0,37 mm no pé — o osso no fim da cadeia mais longa
# (Torso->Thigh->Shin->Foot). Isso é chão numérico: o JSON dos clipes guarda 5
# casas decimais, o Blender guarda chave em float32, e a ida-e-volta
# matriz->Euler YXZ escolhe representações equivalentes mas não idênticas.
#
# Para saber que 1 mm ainda PEGA erro de verdade, `conferir()` roda um CONTROLE:
# repete a conta com a conversão de eixos deliberadamente errada. Se o controle
# não explodir, a conferência não vale nada e o script recusa exportar do mesmo
# jeito. Tolerância sem controle é tolerância que aceita qualquer coisa.
TOLERANCIA = 1e-3

# C: Godot -> Blender. Só troca de eixos, sem escala.
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()
# ============================================================================
#  PARA ONDE CADA OSSO APONTA (só aparência — a deformação não depende disto)
#
#  O osso do Blender tem o comprimento no +Y LOCAL dele. O rig do jogo pendura
#  os MEMBROS no −Y local, mas nem todo papel é membro:
#
#    tronco, pescoço, cabeça  crescem para CIMA  (+Y)
#    braços e pernas          descem              (−Y)
#    PÉS                      apontam para a FRENTE (−Z, a frente do Godot)
#
#  A primeira versão usava um giro de 180° em X para TODOS. Resultado visto em
#  tela: o osso do tronco descia atravessando o peito e os dois ossos dos pés
#  furavam o chão. Nada quebrava — mas rig com osso no lugar errado é rig que
#  não se anima.
#
#  ⚠️ POR QUE PODE SER QUALQUER GIRO, DESDE QUE CONSISTENTE. O osso de repouso é
#  `C · W_repouso · F` e a pose é `C · W_pose · F`. A deformação da malha é
#  `pose · repouso⁻¹`, e nela o F CANCELA. Ou seja: mudar a direção do osso não
#  move um vértice — desde que o MESMO F seja usado nos dois lugares (aqui e na
#  conjugação de `pose_local_blender`). É exatamente essa consistência que o
#  novo `conferir_malha()` verifica.
F_MEMBRO = Matrix.Rotation(math.pi, 4, 'X')          # +Y -> −Y  (desce o membro)
F_CIMA = Matrix.Identity(4)                          # +Y -> +Y  (cresce)
F_FRENTE = Matrix.Rotation(-math.pi / 2.0, 4, 'X')   # +Y -> −Z  (aponta à frente)

F_POR_PAPEL = {
    "Torso": F_CIMA, "Neck": F_CIMA, "Head": F_CIMA,
    "Foot_L": F_FRENTE, "Foot_R": F_FRENTE,
}


def flip(papel):
    return F_POR_PAPEL.get(papel, F_MEMBRO)


# Comprimento de exibição de cada osso, em metros do modelo. Vem da ANATOMIA
# (distância até a junta seguinte), não de uma regra genérica: a regra genérica
# dava 0,125 para o tronco — um toco — porque a coxa nasce quase na mesma altura.
def comprimento(rig, papel):
    d = rig["roles"][papel]
    caixa = d["box"]["size"]
    # quem tem junta seguinte NA MESMA DIREÇÃO usa a distância até ela
    seguinte = {
        "Torso": "Neck", "Neck": "Head",
        "UpperArm_L": "ForeArm_L", "UpperArm_R": "ForeArm_R",
        "Thigh_L": "Shin_L", "Thigh_R": "Shin_R",
        "Shin_L": "Foot_L", "Shin_R": "Foot_R",
    }.get(papel)
    if seguinte and seguinte in rig["roles"]:
        c = Vector(rig["roles"][seguinte]["pos"]).length
        if c > 0.02:
            return c
    # pontas: o próprio tamanho da caixa, no eixo em que o osso aponta
    if papel.startswith("Foot"):
        return max(0.05, caixa[2])          # o pé é comprido no Z
    return max(0.05, caixa[1])              # cabeça e antebraço, no Y


# ⚠️ A ARMADILHA QUE CUSTOU UMA RODADA INTEIRA.
#
# O Godot reporta `Node3D.rotation_order = 2`, que a documentação dele chama de
# **YXZ**. A string equivalente no mathutils NÃO é 'YXZ' — é **'ZXY'**. As duas
# bibliotecas nomeiam a ordem em sentidos opostos (uma pela ordem de aplicação,
# a outra pela ordem de composição da matriz).
#
# Com 'YXZ' o repouso saía perfeito (todos os ângulos são zero, então qualquer
# ordem acerta) e TODA pose animada saía embaralhada — o boneco lia como se
# tivesse caído. E a conferência não pegava, porque os DOIS lados dela usavam
# esta mesma função: um teste que compara o erro com ele mesmo sempre passa.
#
# Por isso existe `ancorar()` embaixo: uma base medida DENTRO DO GODOT, colada
# aqui como número. É a única referência externa deste arquivo.
ORDEM_MATHUTILS = 'ZXY'


def euler_godot(v, ordem=None):
    """Euler de nó do Godot -> matriz. Ver a nota sobre a ordem, acima."""
    return Euler((v[0], v[1], v[2]), ordem or ORDEM_MATHUTILS).to_matrix().to_4x4()


# Medido em 2026-08-25 com um Node3D de verdade:
#   n.rotation = Vector3(-0.2007, 0.2880, -0.8325)   (Torso do boxing_1 em t=0,30s)
# e as COLUNAS da basis resultante impressas do próprio Godot.
ANCORA_EULER = (-0.2007, 0.2880, -0.8325)
ANCORA_COLUNAS = (
    (0.687189, -0.724770, -0.049790),
    (0.671045,  0.659519, -0.338723),
    (0.278334,  0.199355,  0.939568),
)


def ancorar():
    """Confere a conversão de Euler contra uma base MEDIDA no Godot.

    Sem esta âncora, `conferir()` é tautológico: ele compara a cinemática direta
    com o Blender, e as duas leem o Euler pela mesma função. Se a função estiver
    errada, as duas erram junto e o teste fica verde com o boneco desmontado —
    foi exatamente o que aconteceu."""
    M = euler_godot(ANCORA_EULER).to_3x3()
    pior = 0.0
    for c in range(3):
        for l in range(3):
            pior = max(pior, abs(M[l][c] - ANCORA_COLUNAS[c][l]))
    return pior


def limpar_cena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def carregar(caminho):
    with open(caminho, "r", encoding="utf-8") as f:
        return json.load(f)


# --------------------------------------------------------- cinemática direta
def fk_godot(rig, pose=None):
    """Transform de cada papel no espaço do MODELO, em coordenadas do GODOT.
    `pose` = {papel: [x,y,z]} de rotações locais; ausente = pose de repouso.
    É a referência independente contra a qual o Blender é conferido."""
    fora = {}
    for papel in rig["order"]:
        d = rig["roles"][papel]
        rot = (pose or {}).get(papel) or d["rest"]
        local = Matrix.Translation(Vector(d["pos"])) @ euler_godot(rot)
        pai = d["parent"]
        fora[papel] = (fora[pai] @ local) if pai else local
    return fora


# ------------------------------------------------------------------ armature
def montar_armature(rig):
    arm_data = bpy.data.armatures.new("RigA")
    arm = bpy.data.objects.new("Personagem", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')

    repouso = fk_godot(rig)
    # Osso de comprimento zero o Blender APAGA sem avisar.
    comprimentos = {p: comprimento(rig, p) for p in rig["order"]}

    for papel in rig["order"]:
        eb = arm_data.edit_bones.new(papel)
        M = C @ repouso[papel] @ flip(papel)   # base do osso = base do nó, virada
        eb.head = (0, 0, 0)
        eb.tail = (0, comprimentos[papel], 0)
        eb.matrix = M @ Matrix.Translation(Vector((0, 0, 0)))
        eb.length = comprimentos[papel]
        pai = rig["roles"][papel]["parent"]
        if pai:
            eb.parent = arm_data.edit_bones[pai]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def montar_caixas(rig, arm):
    """As caixas do voxel, uma malha só, PESADA NOS OSSOS. É o que faz o
    personagem APARECER — sem elas o .blend abre com um esqueleto e nada em volta.

    ⚠️ A PRIMEIRA VERSÃO USAVA PARENTEAMENTO POR OSSO e as caixas saíram
    espalhadas pela cena (conferido em imagem: cabeça no canto, antebraço solto).
    O parent BONE do Blender ancora o filho na PONTA do osso e exige acertar o
    `matrix_parent_inverse` à mão — três convenções empilhadas, três chances de
    errar.

    Skinning resolve por construção: o vértice nasce na posição de REPOUSO do
    mundo, entra num grupo de peso 1 do seu papel, e o modificador Armature
    aplica `pose · repouso⁻¹`. Não importa para onde o osso APONTA nem qual é o
    roll dele — que é exatamente a dúvida que o `F` introduz. E de quebra é como
    um personagem de verdade é montado.
    """
    repouso = fk_godot(rig)
    verts, faces, grupos, locais = [], [], {}, {}
    FACES_CUBO = [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    for papel in rig["order"]:
        d = rig["roles"][papel]
        tam, off = d["box"]["size"], d["box"]["offset"]
        if max(tam) <= 0.0001:
            continue
        base = len(verts)
        sx, sy, sz = tam[0] / 2.0, tam[1] / 2.0, tam[2] / 2.0
        M = C @ repouso[papel]          # repouso do papel, já em coordenadas do Blender
        for gx in (-sx, sx):
            for gy in (-sy, sy):
                for gz in (-sz, sz):
                    v = Vector((gx + off[0], gy + off[1], gz + off[2]))
                    verts.append(M @ v)
        faces.extend([tuple(base + i for i in f) for f in FACES_CUBO])
        grupos[papel] = list(range(base, base + 8))
        # guarda o vértice em coordenadas LOCAIS do papel: é isso que o
        # `conferir_malha()` precisa para reconstruir onde ele deveria parar.
        locais[papel] = [Vector((gx + off[0], gy + off[1], gz + off[2]))
                         for gx in (-sx, sx) for gy in (-sy, sy) for gz in (-sz, sz)]

    malha = bpy.data.meshes.new("CorpoVoxel")
    malha.from_pydata([tuple(v) for v in verts], [], faces)
    malha.update()
    obj = bpy.data.objects.new("CorpoVoxel", malha)
    bpy.context.collection.objects.link(obj)
    for papel, idxs in grupos.items():
        vg = obj.vertex_groups.new(name=papel)
        vg.add(idxs, 1.0, 'REPLACE')
    obj.parent = arm
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    obj["papeis_locais"] = {p: [list(v) for v in vs] for p, vs in locais.items()}
    obj["papeis_indices"] = {p: list(i) for p, i in grupos.items()}
    return obj


# ------------------------------------------------------- conferência da MALHA
def conferir_malha(rig, arm, corpo, clipes):
    """Onde a MALHA para, contra onde ela deveria parar.

    ⚠️ ESTA É A CONFERÊNCIA QUE FALTAVA. A outra (`conferir`) compara a CABEÇA
    dos ossos, e cabeça de osso não muda quando a direção dele muda — então ela
    é cega para dois defeitos que já aconteceram neste arquivo:

      • as caixas presas ao osso pela ponta, espalhadas pela cena (a primeira
        versão usava parenteamento por osso em vez de skinning);
      • um F inconsistente entre o osso de repouso e a conjugação da pose.

    A referência é `C · W_pose · v_local` — cinemática direta pura, sem passar
    por osso nenhum."""
    idx = {p: list(i) for p, i in corpo["papeis_indices"].to_dict().items()} \
        if hasattr(corpo["papeis_indices"], "to_dict") else dict(corpo["papeis_indices"])
    loc = {p: [Vector(v) for v in vs] for p, vs in (
        corpo["papeis_locais"].to_dict().items()
        if hasattr(corpo["papeis_locais"], "to_dict") else dict(corpo["papeis_locais"]).items())}

    piores = []
    for nome, clip in clipes[:6]:
        arm.animation_data.action = bpy.data.actions[nome]
        for quadro_i in (0, int(round(clip["length"] * 0.5 * FPS))):
            bpy.context.scene.frame_set(1 + quadro_i)
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            ev = corpo.evaluated_get(dg)
            m = ev.to_mesh()
            pose = {}
            t = quadro_i / float(FPS)
            for papel in rig["order"]:
                chaves = clip["tracks"].get(papel)
                pose[papel] = _amostrar(chaves, t) if chaves else rig["roles"][papel]["rest"]
            mundo = fk_godot(rig, pose)
            for papel, indices in idx.items():
                for k, iv in enumerate(indices):
                    esperado = (C @ mundo[papel]) @ loc[papel][k]
                    obtido = corpo.matrix_world @ m.vertices[iv].co
                    piores.append(((esperado - obtido).length, nome, papel))
            ev.to_mesh_clear()
    piores.sort(reverse=True)
    return piores[:5]


# ------------------------------------------------------------------- actions
def pose_local_blender(papel, rot_godot):
    """Rotação local do Godot -> rotação local do OSSO.

    Conjugada pelo F DAQUELE papel: é a mesma virada usada para montar o osso de
    repouso, e é por serem a mesma que a deformação sai correta."""
    Fp = flip(papel)
    return (Fp.inverted() @ euler_godot(rot_godot) @ Fp).to_euler(ORDEM_MATHUTILS)


def montar_actions(rig, arm, clipes):
    # ⚠️ LINEAR, NÃO BÉZIER — e definido AQUI, antes de qualquer chave.
    #
    # O Godot interpola as faixas destes clipes linearmente; o padrão do Blender
    # é Bézier, que arredonda entradas e saídas. O clipe pareceria mais macio no
    # Blender do que no jogo, e um soco reautorado lá chegaria diferente aqui —
    # a diferença aparece justamente nos quadros de impacto, que são os que
    # importam.
    #
    # Vai na preferência e não num laço sobre as f-curves de propósito: o
    # Blender 5.2 trocou a API de Action (sistema de slots) e `act.fcurves`
    # deixou de existir. A preferência atravessa as duas versões.
    bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
    arm.animation_data_create()
    for nome, clip in clipes:
        act = bpy.data.actions.new(nome)
        act.use_fake_user = True          # sobrevive ao salvar sem estar ativa
        arm.animation_data.action = act
        for papel, chaves in clip["tracks"].items():
            if papel not in arm.pose.bones:
                continue
            pb = arm.pose.bones[papel]
            pb.rotation_mode = ORDEM_MATHUTILS
            for t, rot in chaves:
                pb.rotation_euler = pose_local_blender(papel, rot)
                pb.keyframe_insert("rotation_euler", frame=1 + t * FPS, group=papel)
    return


# ---------------------------------------------------------------- conferência
def conferir(rig, arm, clipes, sabotar=False):
    """Compara a pose que o BLENDER avalia com a cinemática direta em Python.
    Recusa a exportação se divergirem — rig calado que erra é pior que erro.

    `sabotar=True` estraga a conversão de eixos de propósito: é o CONTROLE que
    prova que esta conferência sabe reprovar."""
    C_ref = Matrix.Identity(4) if sabotar else C
    piores = []
    for nome, clip in clipes[:6]:
        arm.animation_data.action = bpy.data.actions[nome]
        # ⚠️ TEMPOS ALINHADOS AO QUADRO. A primeira versão amostrava em
        # `length * 0.5`, que cai ENTRE dois quadros; o Blender só avalia em
        # quadro inteiro, então ele e a cinemática de referência olhavam
        # instantes diferentes e a conferência acusava 7,6 cm de "divergência do
        # rig" que era só a régua. Comparar em cima da chave tira essa dúvida.
        n_meio = int(round(clip["length"] * 0.5 * FPS))
        for quadro_i in (0, n_meio, max(0, n_meio // 2)):
            t_alvo = quadro_i / float(FPS)
            bpy.context.scene.frame_set(1 + quadro_i)
            dg = bpy.context.evaluated_depsgraph_get()
            arm_ev = arm.evaluated_get(dg)
            pose = {}
            for papel in rig["order"]:
                chaves = clip["tracks"].get(papel)
                pose[papel] = _amostrar(chaves, t_alvo) if chaves else rig["roles"][papel]["rest"]
            esperado = fk_godot(rig, pose)
            for papel in rig["order"]:
                p_ref = (C_ref @ esperado[papel]).to_translation()
                p_bl = (arm.matrix_world @ arm_ev.pose.bones[papel].matrix).to_translation()
                piores.append((( p_ref - p_bl).length, nome, papel))
    piores.sort(reverse=True)
    return piores[:5]


def _amostrar(chaves, t):
    """O valor da faixa em `t`, com a MESMA interpolação linear do Godot."""
    if not chaves:
        return [0.0, 0.0, 0.0]
    if t <= chaves[0][0]:
        return chaves[0][1]
    for i in range(len(chaves) - 1):
        t0, v0 = chaves[i]
        t1, v1 = chaves[i + 1]
        if t0 <= t <= t1:
            f = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            return [v0[k] + (v1[k] - v0[k]) * f for k in range(3)]
    return chaves[-1][1]


def main():
    if not os.path.isdir(RIGS) or not os.path.exists(os.path.join(RIGS, "base.json")):
        print("✗ rig ausente: rode `godot --headless --path . -s tools/export_rig.gd` antes")
        sys.exit(1)
    rig = carregar(os.path.join(RIGS, "base.json"))

    nomes = sorted(f[:-5] for f in os.listdir(CLIPS)
                   if f.endswith(".json") and f != "index.json")
    clipes = [(n, carregar(os.path.join(CLIPS, n + ".json"))) for n in nomes]
    print("rig: %d papéis | clipes: %d" % (len(rig["roles"]), len(clipes)))

    erro_ancora = ancorar()
    print("âncora (Euler do Godot, base medida): erro máximo %.7f" % erro_ancora)
    if erro_ancora > 1e-5:
        print("✗ A CONVERSÃO DE EULER NÃO BATE COM O GODOT (%.7f). "
              "Ordem em `ORDEM_MATHUTILS` está errada; nada foi montado." % erro_ancora)
        sys.exit(4)

    limpar_cena()
    bpy.context.scene.render.fps = FPS
    arm = montar_armature(rig)
    corpo = montar_caixas(rig, arm)
    montar_actions(rig, arm, clipes)

    piores_malha = conferir_malha(rig, arm, corpo, clipes)
    print("\n-- conferência da MALHA deformada x cinemática direta (metros) --")
    for erro, nome, papel in piores_malha:
        print("   %.6f  %s / %s" % (erro, nome, papel))
    if piores_malha and piores_malha[0][0] > TOLERANCIA:
        print("✗ A MALHA NÃO SEGUE OS OSSOS (pior erro %.6f m > %.6f). Nada foi salvo."
              % (piores_malha[0][0], TOLERANCIA))
        sys.exit(5)

    piores = conferir(rig, arm, clipes)
    controle = conferir(rig, arm, clipes, sabotar=True)
    print("\n-- conferência: Blender x cinemática direta (metros) --")
    for erro, nome, papel in piores:
        print("   %.6f  %s / %s" % (erro, nome, papel))
    pior = piores[0][0] if piores else 0.0
    pior_controle = controle[0][0] if controle else 0.0
    print("   CONTROLE (eixos errados de propósito): %.6f m" % pior_controle)
    if pior_controle < TOLERANCIA * 20.0:
        print("✗ A CONFERÊNCIA NÃO SABE REPROVAR: o controle sabotado deu %.6f m,"
              " dentro da tolerância. Sem poder de prova, não exporto." % pior_controle)
        sys.exit(3)
    if pior > TOLERANCIA:
        print("✗ RIG DIVERGENTE (pior erro %.6f m > %.6f). Nada foi salvo."
              % (pior, TOLERANCIA))
        sys.exit(2)
    print("   ✓ pior erro %.6f m, contra %.3f m do controle — a conta fecha."
          % (pior, pior_controle))

    # Deixa uma animação em cena para o arquivo não abrir vazio.
    arm.animation_data.action = bpy.data.actions[nomes[0]]
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = int(1 + clipes[0][1]["length"] * FPS)

    os.makedirs(SAIDA_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=SAIDA)
    print("\n✓ %s" % SAIDA)
    print("  personagem: armature '%s' (%d ossos) + malha 'CorpoVoxel' (%d caixas, pesadas nos ossos)"
          % (arm.name, len(arm.pose.bones), len(rig["order"])))
    print("  animações: %d actions (Action Editor -> dropdown)" % len(bpy.data.actions))


main()
