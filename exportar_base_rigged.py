import bpy

# Limpa a cena inicial
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

anim_path = "/home/administrador/dev/skills-one-piece/assets/animations_glb/punching.glb"
base_path = "/home/administrador/dev/skills-one-piece/assets/models/base.glb"
export_path = "/home/administrador/dev/skills-one-piece/assets/models/base_rigged.glb"

# disable_bone_shape=True: sem isso o importador cria uma "Icosphere" e a usa
# como custom shape dos 65 ossos. Como o armature do Mixamo tem dimensao minima
# NEGATIVA (-10.12) e scale 0.01, a conta do addon (min_dim/scale * 0.05) da uma
# esfera de escala -50 — a famosa bola cinza gigante engolindo o personagem.
print("Importando esqueleto base...")
bpy.ops.import_scene.gltf(filepath=anim_path, disable_bone_shape=True)

armature = None
descartar = []
for obj in list(bpy.context.scene.objects):
    if obj.type == 'ARMATURE':
        armature = obj
    elif "Beta_Surface" in obj.name or "Beta_Joints" in obj.name:
        descartar.append(obj)
for obj in descartar:
    bpy.data.objects.remove(obj, do_unlink=True)

if armature:
    # Limpa as animações para exportar um rig limpo
    if armature.animation_data:
        armature.animation_data_clear()

    # Pose de descanso
    armature.data.pose_position = 'REST'

    print("Importando base.glb...")
    bpy.ops.import_scene.gltf(filepath=base_path, disable_bone_shape=True)

    mapping = {
        "Torso": "mixamorig:Spine",
        "Head": "mixamorig:Head",
        "UpperArm_L": "mixamorig:LeftArm",
        "ForeArm_L": "mixamorig:LeftForeArm",
        "UpperArm_R": "mixamorig:RightArm",
        "ForeArm_R": "mixamorig:RightForeArm",
        "Thigh_L": "mixamorig:LeftUpLeg",
        "Shin_L": "mixamorig:LeftLeg",
        "Foot_L": "mixamorig:LeftFoot",
        "Thigh_R": "mixamorig:RightUpLeg",
        "Shin_R": "mixamorig:RightLeg",
        "Foot_R": "mixamorig:RightFoot"
    }

    # Preserva transformações globais. So entram as 12 pecas do base.glb —
    # qualquer malha avulsa da cena fica de fora e nao vai parar no export.
    def osso_de(nome):
        for key, val in mapping.items():
            if key in nome:
                return val
        return None

    global_matrices = {}
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and osso_de(obj.name):
            global_matrices[obj] = obj.matrix_world.copy()

    faltando = set(mapping) - {k for o in global_matrices for k in mapping if k in o.name}
    if faltando:
        raise RuntimeError("ABORTADO: pecas ausentes no base.glb -> %s" % sorted(faltando))

    # Aplica as transformações para o objeto (Apply Transform) para garantir que a Vertex Weight funcione 100%
    for obj in global_matrices:
        obj.parent = None
        obj.matrix_world = global_matrices[obj]

    bpy.ops.object.select_all(action='DESELECT')
    for obj in global_matrices:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = list(global_matrices.keys())[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action='DESELECT')

    # Faz o vínculo por Vertex Groups (peso 1.0 rígido para estilo Roblox)
    for obj in global_matrices:
        bone_name = osso_de(obj.name)

        if bone_name:
            # Parentesco com o esqueleto (Sem gerar pesos automáticos).
            #
            # O armature vem do Mixamo com scale 0.01 e rotação +90° em X no
            # objeto. Parentear direto faz a malha HERDAR essa transform e
            # encolher 100x — as 12 peças viram um caroço cinza de ~2cm.
            # O matrix_parent_inverse cancela a transform do pai (é o que o
            # Ctrl+P "Keep Transform" faz), então a malha fica onde está,
            # no tamanho certo.
            obj.parent = armature
            obj.matrix_parent_inverse = armature.matrix_world.inverted()

            # Adiciona o Armature Modifier
            mod = obj.modifiers.new(name="Armature", type='ARMATURE')
            mod.object = armature

            # Cria o grupo de vértices com o nome do osso
            vg = obj.vertex_groups.new(name=bone_name)

            # Associa todos os vértices da malha com peso 1.0 a esse grupo
            vertices = [v.index for v in obj.data.vertices]
            vg.add(vertices, 1.0, 'REPLACE')

    # Trava anti-bola-cinza: se alguma peça sumiu de escala, aborta antes de
    # gravar por cima do arquivo bom.
    for obj in global_matrices:
        alt = max(obj.dimensions)
        if alt < 0.05:
            raise RuntimeError(
                "ABORTADO: '%s' ficou com %.4f de tamanho — o rig colapsou." % (obj.name, alt)
            )

    print("Exportando base_rigged.glb...")
    # Seleciona as malhas e a armadura para exportar
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    for obj in global_matrices:
        obj.select_set(True)

    bpy.ops.export_scene.gltf(
        filepath=export_path,
        use_selection=True,
        export_animations=False,
        export_apply=False
    )
    print("Sucesso! base_rigged.glb gerado.")
