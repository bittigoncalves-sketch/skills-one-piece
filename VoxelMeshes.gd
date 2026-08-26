class_name VoxelMeshes
extends RefCounted
# Construtores de MODELO VOXEL (rig por-nós) extraídos do CharacterBuilder:
# Buggy, Nami e Ace montados em caixas + esqueleto por-nós. Tudo estático.
# Entradas públicas: build_buggy(root), build_nami(root), build_ace(root).

static func build_buggy(root: Node3D) -> void:
	# Paleta de Cores Fiel à Imagem de Referência:
	var c_skin := Color(0.96, 0.82, 0.72)       # Tom de pele
	var c_red_stripe := Color(0.85, 0.12, 0.12)  # Vermelho listras/detalhes
	var c_white := Color(0.95, 0.95, 0.95)       # Branco listras/luvas/caveira
	var c_hat_orange := Color(0.93, 0.42, 0.12)  # Laranja do chapéu/manto
	var c_hair_blue := Color(0.18, 0.48, 0.88)   # Azul das Maria-Chiquinhas
	var c_nose_red := Color(0.95, 0.05, 0.05)   # Vermelho vibrante do nariz
	var c_scar_red := Color(0.7, 0.15, 0.1)      # Cicatriz em X no rosto
	var c_scarf_purple := Color(0.52, 0.22, 0.68)# Cachecol roxo no pescoço
	var c_sash_teal := Color(0.12, 0.62, 0.65)   # Faixa verde-água/turquesa na cintura
	var c_pants_blue := Color(0.42, 0.65, 0.82)  # Calça azul clara
	var c_epaulette_gold := Color(0.95, 0.75, 0.15) # Hombreiras de ouro
	var c_boot_brown := Color(0.38, 0.22, 0.14)  # Bota de pirata marrom
	var c_steel := Color(0.8, 0.82, 0.86)        # Aço das facas

	# ------------------------------------------------------------------- TORSO (CAMISA LISTRADA)
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.95, 0)
	root.add_child(torso)

	# Camisa listrada em camadas (Vermelho e Branco alternados)
	for i in range(5):
		var stripe_col := c_red_stripe if (i % 2 == 0) else c_white
		var stripe := _create_box_part("ShirtStripe_%d" % i, Vector3(0.56, 0.11, 0.38), stripe_col)
		stripe.position = Vector3(0, 0.22 - i * 0.11, 0)
		torso.add_child(stripe)

	# Cachecol Roxo no Pescoço
	var scarf := _create_box_part("PurpleScarf", Vector3(0.48, 0.14, 0.42), c_scarf_purple)
	scarf.position = Vector3(0, 0.32, -0.02)
	torso.add_child(scarf)

	# Faixa Verde-Água / Turquesa na Cintura (Sash)
	var sash := _create_box_part("TealSash", Vector3(0.6, 0.16, 0.42), c_sash_teal)
	sash.position = Vector3(0, -0.28, 0)
	torso.add_child(sash)

	var sash_knot := _create_box_part("TealSashKnot", Vector3(0.16, 0.28, 0.12), c_sash_teal)
	sash_knot.position = Vector3(-0.22, -0.32, -0.2)
	torso.add_child(sash_knot)

	# ------------------------------------------------------------------- CABEÇA E ROSTO
	var head := _create_box_part("Head", Vector3(0.46, 0.44, 0.42), c_skin)
	head.position = Vector3(0, 0.58, 0)
	torso.add_child(head)

	# Nariz Vermelho Esférico Icônico
	var nose := _create_box_part("RedNose", Vector3(0.2, 0.2, 0.2), c_nose_red, true)
	nose.position = Vector3(0, 0.02, -0.23)
	head.add_child(nose)

	# Cicatriz em 'X' na Testa (Cruzando as sobrancelhas)
	var scar_x1 := _create_box_part("ScarX1", Vector3(0.28, 0.04, 0.02), c_scar_red)
	scar_x1.position = Vector3(0, 0.14, -0.22)
	scar_x1.rotation.z = deg_to_rad(35.0)
	head.add_child(scar_x1)

	var scar_x2 := _create_box_part("ScarX2", Vector3(0.28, 0.04, 0.02), c_scar_red)
	scar_x2.position = Vector3(0, 0.14, -0.22)
	scar_x2.rotation.z = deg_to_rad(-35.0)
	head.add_child(scar_x2)

	# Sorriso de Palhaço com Maquiagem
	var smile := _create_box_part("Smile", Vector3(0.24, 0.06, 0.02), c_white)
	smile.position = Vector3(0, -0.12, -0.22)
	head.add_child(smile)

	# ------------------------------------------------------------------- HAIR (MARIA-CHIQUINHAS AZUIS)
	var hair_left := _create_box_part("HairRightPigtail", Vector3(0.22, 0.65, 0.24), c_hair_blue)
	hair_left.position = Vector3(0.35, 0.05, 0.05)
	head.add_child(hair_left)

	var hair_right := _create_box_part("HairLeftPigtail", Vector3(0.22, 0.65, 0.24), c_hair_blue)
	hair_right.position = Vector3(-0.35, 0.05, 0.05)
	head.add_child(hair_right)

	# ------------------------------------------------------------------- CHAPÉU PIRATA DE CAPITÃO
	var hat_base := _create_box_part("HatBase", Vector3(0.72, 0.12, 0.6), c_hat_orange)
	hat_base.position = Vector3(0, 0.26, 0)
	head.add_child(hat_base)

	# Borda Branca Superior do Chapéu
	var hat_trim := _create_box_part("HatTrimWhite", Vector3(0.74, 0.04, 0.62), c_white)
	hat_trim.position = Vector3(0, 0.32, 0)
	head.add_child(hat_trim)

	# Frente dobrada do chapéu de capitão
	var hat_front := _create_box_part("HatFrontBrim", Vector3(0.64, 0.36, 0.14), c_hat_orange)
	hat_front.position = Vector3(0, 0.38, -0.24)
	head.add_child(hat_front)

	# Faixa Vermelha e Branca na Base do Chapéu
	var hat_band := _create_box_part("HatBand", Vector3(0.5, 0.08, 0.44), c_red_stripe)
	hat_band.position = Vector3(0, 0.24, 0)
	head.add_child(hat_band)

	# Logo da Caveira Pirata Buggy no Chapéu (White Skull + Red Nose + Crossbones)
	var skull_center := _create_box_part("HatSkullFace", Vector3(0.18, 0.18, 0.04), c_white)
	skull_center.position = Vector3(0, 0.38, -0.32)
	head.add_child(skull_center)

	var skull_nose := _create_box_part("HatSkullNose", Vector3(0.06, 0.06, 0.04), c_nose_red, true)
	skull_nose.position = Vector3(0, 0.38, -0.34)
	head.add_child(skull_nose)

	var crossbone1 := _create_box_part("HatBone1", Vector3(0.3, 0.05, 0.03), c_white)
	crossbone1.position = Vector3(0, 0.38, -0.31)
	crossbone1.rotation.z = deg_to_rad(45.0)
	head.add_child(crossbone1)

	var crossbone2 := _create_box_part("HatBone2", Vector3(0.3, 0.05, 0.03), c_white)
	crossbone2.position = Vector3(0, 0.38, -0.31)
	crossbone2.rotation.z = deg_to_rad(-45.0)
	head.add_child(crossbone2)

	# ------------------------------------------------------------------- MANTO DE CAPITÃO NAS COSTAS
	var coat_back := _create_box_part("BackCoat", Vector3(0.82, 0.95, 0.08), c_hat_orange)
	coat_back.position = Vector3(0, -0.05, 0.26)
	torso.add_child(coat_back)

	var coat_border := _create_box_part("CoatBorderWhite", Vector3(0.86, 0.06, 0.1), c_white)
	coat_border.position = Vector3(0, -0.52, 0.26)
	torso.add_child(coat_border)

	# Logo de Caveira Grande nas Costas do Manto
	var back_skull := _create_box_part("BackSkullLogo", Vector3(0.32, 0.32, 0.02), c_white)
	back_skull.position = Vector3(0, 0.05, 0.31)
	torso.add_child(back_skull)

	var back_skull_nose := _create_box_part("BackSkullNose", Vector3(0.08, 0.08, 0.02), c_nose_red, true)
	back_skull_nose.position = Vector3(0, 0.05, 0.32)
	torso.add_child(back_skull_nose)

	# Hombreiras de Ouro com Franjas (Epaulettes)
	var epaulette_r := _create_box_part("EpauletteL", Vector3(0.28, 0.1, 0.36), c_epaulette_gold)
	epaulette_r.position = Vector3(0.38, 0.32, 0)
	torso.add_child(epaulette_r)

	var epaulette_l := _create_box_part("EpauletteR", Vector3(0.28, 0.1, 0.36), c_epaulette_gold)
	epaulette_l.position = Vector3(-0.38, 0.32, 0)
	torso.add_child(epaulette_l)

	# ------------------------------------------------------------------- BRAÇOS E LUVAS BRANCAS
	# Braço Esquerdo
	var arm_r := _create_box_part("RightArm", Vector3(0.2, 0.5, 0.2), c_red_stripe)
	arm_r.position = Vector3(0.42, 0.1, 0)
	torso.add_child(arm_r)

	var glove_r := _create_box_part("RightGlove", Vector3(0.24, 0.28, 0.24), c_white)
	glove_r.position = Vector3(0, -0.25, 0)
	arm_r.add_child(glove_r)

	var knife_r := _create_box_part("KnifeRight", Vector3(0.05, 0.42, 0.12), c_steel, true)
	knife_r.position = Vector3(0, -0.2, -0.15)
	glove_r.add_child(knife_r)

	# Braço Direito
	var arm_l := _create_box_part("LeftArm", Vector3(0.2, 0.5, 0.2), c_red_stripe)
	arm_l.position = Vector3(-0.42, 0.1, 0)
	torso.add_child(arm_l)

	var glove_l := _create_box_part("LeftGlove", Vector3(0.24, 0.28, 0.24), c_white)
	glove_l.position = Vector3(0, -0.25, 0)
	arm_l.add_child(glove_l)

	var knife_l := _create_box_part("KnifeLeft", Vector3(0.05, 0.42, 0.12), c_steel, true)
	knife_l.position = Vector3(0, -0.2, -0.15)
	glove_l.add_child(knife_l)

	# ------------------------------------------------------------------- PERNAS E BOTAS
	# Perna Esquerda (Calça Azul Clara)
	var leg_r := _create_box_part("RightLeg", Vector3(0.24, 0.55, 0.24), c_pants_blue)
	leg_r.position = Vector3(0.18, -0.6, 0)
	torso.add_child(leg_r)

	var boot_r := _create_box_part("BootRight", Vector3(0.26, 0.18, 0.32), c_boot_brown)
	boot_r.position = Vector3(0, -0.28, -0.04)
	leg_r.add_child(boot_r)

	# Perna Direita (Calça Azul Clara)
	var leg_l := _create_box_part("LeftLeg", Vector3(0.24, 0.55, 0.24), c_pants_blue)
	leg_l.position = Vector3(-0.18, -0.6, 0)
	torso.add_child(leg_l)

	var boot_l := _create_box_part("BootLeft", Vector3(0.26, 0.18, 0.32), c_boot_brown)
	boot_l.position = Vector3(0, -0.28, -0.04)
	leg_l.add_child(boot_l)

# -------------------------------------------------- RIG ARTICULADO COMPARTILHADO
# Monta o esqueleto com os NOMES que o BodyScanner/ProceduralAnimator exigem
# (Torso, Head, UpperArm_L/R -> ForeArm_L/R, Thigh_L/R -> Shin_L/R -> Foot_L/R),
# na hierarquia correta. É o que faz Nami/Ace animarem e receberem as pistolas
# como o personagem Base. Devolve {torso, head} p/ o chamador decorar (cabelo etc).
static func _build_skeleton(root: Node3D, torso_col: Color, skin: Color, arm_col: Color, thigh_col: Color, shin_col: Color, foot_col: Color) -> Dictionary:
	var torso := _create_box_part("Torso", Vector3(0.5, 0.6, 0.34), torso_col)
	torso.position = Vector3(0, 0.98, 0)
	root.add_child(torso)

	var head := _create_box_part("Head", Vector3(0.42, 0.42, 0.4), skin)
	head.position = Vector3(0, 0.54, 0)
	torso.add_child(head)

	# braços: UpperArm (ombro) -> ForeArm (cotovelo). Pendem em -Y no repouso.
	var ua_l := _seg(torso, "UpperArm_L", Vector3(-0.32, 0.2, 0), 0.30, 0.16, arm_col)
	_seg(ua_l, "ForeArm_L", Vector3(0, -0.30, 0), 0.30, 0.145, skin)
	var ua_r := _seg(torso, "UpperArm_R", Vector3(0.32, 0.2, 0), 0.30, 0.16, arm_col)
	_seg(ua_r, "ForeArm_R", Vector3(0, -0.30, 0), 0.30, 0.145, skin)

	# pernas: Thigh (quadril) -> Shin (joelho) -> Foot (tornozelo).
	var th_l := _seg(torso, "Thigh_L", Vector3(-0.14, -0.32, 0), 0.30, 0.19, thigh_col)
	var sh_l := _seg(th_l, "Shin_L", Vector3(0, -0.30, 0), 0.30, 0.17, shin_col)
	_foot_seg(sh_l, "Foot_L", foot_col)
	var th_r := _seg(torso, "Thigh_R", Vector3(0.14, -0.32, 0), 0.30, 0.19, thigh_col)
	var sh_r := _seg(th_r, "Shin_R", Vector3(0, -0.30, 0), 0.30, 0.17, shin_col)
	_foot_seg(sh_r, "Foot_R", foot_col)

	return {"torso": torso, "head": head}

# Um segmento de membro: nó-pivô (junta) + malha pendurada em -Y.
static func _seg(parent: Node3D, part_name: String, joint_pos: Vector3, length: float, thick: float, color: Color) -> Node3D:
	var j := Node3D.new()
	j.name = part_name
	j.position = joint_pos
	parent.add_child(j)
	var mesh := _create_box_part(part_name + "M", Vector3(thick, length, thick), color)
	mesh.position = Vector3(0, -length * 0.5, 0)
	j.add_child(mesh)
	return j

# Pé: junta no tornozelo + malha achatada projetada p/ frente (-Z).
static func _foot_seg(parent: Node3D, part_name: String, color: Color) -> Node3D:
	var j := Node3D.new()
	j.name = part_name
	j.position = Vector3(0, -0.30, 0)
	parent.add_child(j)
	var mesh := _create_box_part(part_name + "M", Vector3(0.19, 0.11, 0.3), color)
	mesh.position = Vector3(0, -0.05, -0.06)
	j.add_child(mesh)
	return j

# Dois olhos escuros na frente (-Z) da cabeça.
static func _add_eyes(head: Node3D, color: Color) -> void:
	var l := _create_box_part("EyeL", Vector3(0.07, 0.07, 0.03), color)
	l.position = Vector3(-0.1, 0.02, -0.2)
	head.add_child(l)
	var r := _create_box_part("EyeR", Vector3(0.07, 0.07, 0.03), color)
	r.position = Vector3(0.1, 0.02, -0.2)
	head.add_child(r)

# -------------------------------------------------------------- NAMI VOXEL MESH
static func build_nami(root: Node3D) -> void:
	var skin := Color(0.96, 0.84, 0.74)
	var hair := Color(0.96, 0.46, 0.09)      # laranja
	var top := Color(0.20, 0.52, 0.86)       # top azul
	var shorts := Color(0.22, 0.42, 0.78)    # short jeans
	var sandal := Color(0.55, 0.35, 0.2)
	var refs := _build_skeleton(root, top, skin, skin, skin, skin, sandal)
	var torso: Node3D = refs["torso"]
	var head: Node3D = refs["head"]

	# short jeans na base do torso (quadril)
	var belt := _create_box_part("Shorts", Vector3(0.52, 0.2, 0.36), shorts)
	belt.position = Vector3(0, -0.32, 0)
	torso.add_child(belt)

	# cabelo laranja: topo, franja (-Z) e cabelo LONGO nas costas (+Z)
	var hair_top := _create_box_part("HairTop", Vector3(0.46, 0.16, 0.44), hair)
	hair_top.position = Vector3(0, 0.24, 0.0)
	head.add_child(hair_top)
	var bangs := _create_box_part("HairBangs", Vector3(0.46, 0.12, 0.06), hair)
	bangs.position = Vector3(0, 0.15, -0.2)
	head.add_child(bangs)
	var hair_back := _create_box_part("HairBack", Vector3(0.44, 0.72, 0.16), hair)
	hair_back.position = Vector3(0, -0.28, 0.22)
	head.add_child(hair_back)

	_add_eyes(head, Color(0.35, 0.22, 0.15))

# -------------------------------------------------------------- ACE VOXEL MESH
static func build_ace(root: Node3D) -> void:
	var skin := Color(0.95, 0.82, 0.72)
	var hair := Color(0.1, 0.1, 0.13)        # preto
	var shorts := Color(0.12, 0.12, 0.16)    # bermuda preta
	var boots := Color(0.14, 0.1, 0.08)      # botas escuras
	var hat := Color(0.92, 0.5, 0.14)        # chapéu de vaqueiro laranja
	var beads := Color(0.9, 0.15, 0.15)      # colar de contas vermelhas
	# peito nu (torso = pele), coxas com bermuda, canelas pele, botas escuras
	var refs := _build_skeleton(root, skin, skin, skin, shorts, skin, boots)
	var torso: Node3D = refs["torso"]
	var head: Node3D = refs["head"]

	# colar de contas vermelhas + cinto/bolsa laranja
	var neck := _create_box_part("Beads", Vector3(0.44, 0.07, 0.38), beads)
	neck.position = Vector3(0, 0.24, -0.02)
	torso.add_child(neck)
	var belt := _create_box_part("Belt", Vector3(0.52, 0.1, 0.36), hat)
	belt.position = Vector3(0, -0.3, 0)
	torso.add_child(belt)

	# cabelo preto + CHAPÉU de vaqueiro (aba larga + copa + faixa)
	var hair_top := _create_box_part("HairTop", Vector3(0.46, 0.14, 0.44), hair)
	hair_top.position = Vector3(0, 0.2, 0.02)
	head.add_child(hair_top)
	var hair_back := _create_box_part("HairBack", Vector3(0.44, 0.32, 0.14), hair)
	hair_back.position = Vector3(0, -0.02, 0.22)
	head.add_child(hair_back)
	var brim := _create_box_part("HatBrim", Vector3(0.8, 0.06, 0.8), hat)
	brim.position = Vector3(0, 0.3, 0)
	head.add_child(brim)
	var crown := _create_box_part("HatCrown", Vector3(0.46, 0.2, 0.46), hat)
	crown.position = Vector3(0, 0.42, 0)
	head.add_child(crown)
	var hatband := _create_box_part("HatBand", Vector3(0.48, 0.06, 0.48), beads)
	hatband.position = Vector3(0, 0.34, 0)
	head.add_child(hatband)

	_add_eyes(head, Color(0.15, 0.1, 0.08))
	# sardas (marcas) nas bochechas
	var fr_l := _create_box_part("FreckleL", Vector3(0.05, 0.04, 0.03), Color(0.7, 0.45, 0.3))
	fr_l.position = Vector3(-0.15, -0.05, -0.2)
	head.add_child(fr_l)
	var fr_r := _create_box_part("FreckleR", Vector3(0.05, 0.04, 0.03), Color(0.7, 0.45, 0.3))
	fr_r.position = Vector3(0.15, -0.05, -0.2)
	head.add_child(fr_r)

# ------------------------------------------------------------- CRIADOR DE BLOCOS
static func _create_box_part(part_name: String, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box

	# ⚠️ FUNIL DO CORPO. Toda caixa de todo personagem voxel sai daqui, então é
	# o segundo ponto da Fase 3 do plano visual — depois do `MapBuilder._gray`,
	# que faz o mundo.
	if emissive:
		# Peça que BRILHA (crista, olho, marca): auto-iluminada, sem banda de
		# luz e sem escurecer na sombra. Ver `FxUtil.brilho()` para o porquê de
		# o brilho ir no albedo e não na emissão.
		var lum := StandardMaterial3D.new()
		lum.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lum.albedo_color = FxUtil.brilho(color, 2.0)
		mi.material_override = lum
	else:
		mi.material_override = Materiais.superficie(color)
	return mi

# ---------------------------------------------------------- ANIMAÇÕES PROCEDURAIS (BUGGY)
