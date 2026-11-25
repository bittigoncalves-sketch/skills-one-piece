extends RefCounted
const Catalogo := preload("res://src/player/aparencia_historia.gd")
const Tons := preload("res://src/player/tons_de_pele.gd")


static func aplicar(raiz: Node3D, tipo: String, tom: String, a: Dictionary) -> void:
	var cabeca := raiz.find_child("Head", true, false) as Node3D
	if Catalogo.PORTES.has(a.porte):
		var e: Vector3 = Catalogo.PORTES[a.porte]
		raiz.scale = Vector3(raiz.scale.x * e.x, raiz.scale.y * e.y, raiz.scale.z * e.x)
	if a.cabelo != "original" and a.cabelo != "careca":
		# Os GLBs existentes foram feitos para uma cabeça .50 x .50 x .74,
		# com pivô no topo. A campanha tem cabeça .48 cúbica e Head na base.
		var cena: PackedScene = load("res://assets/models/cabelos/" + str(a.cabelo) + ".glb")
		var cabelo := cena.instantiate() as Node3D
		cabelo.name = "CabeloPersonalizado"
		cabelo.position = Vector3(0, .48, 0)
		cabelo.scale = Vector3(.48 / .50, .48 / .50, .48 / .74)
		Acessorios._fixar_ao_rig(cabelo)
		Acessorios._converter_materiais(cabelo, false, Catalogo.cor_cabelo(a))
		cabelo.set_meta("cabelo_historia", a.cabelo)
		cabeca.add_child(cabelo)
	elif a.cabelo == "original" and tipo == "feminino" and a.cor_cabelo != "original":
		var longo := cabeca.get_node_or_null("CabeloLongo")
		if longo:
			for malha: MeshInstance3D in longo.find_children("*", "MeshInstance3D", true, false):
				var mat := malha.material_override.duplicate() as StandardMaterial3D
				mat.albedo_color = Catalogo.cor_cabelo(a)
				malha.material_override = mat
	if a.nariz != "original":
		_nariz(cabeca, str(a.nariz), Color(Tons.CATALOGO.data[Tons.normalizar(tom)].pele))
	# Roupas em MALHA (peças do Blender presas aos nós do rig). Cada uma é independente: dá para usar moletom + calça pregueada + sapatos + óculos juntos.
	if a.roupa == "sobretudo":
		_montar_conjunto(raiz, tipo, "sobretudo", Catalogo.cor_do_sobretudo(a))
	elif a.roupa == "moletom":
		_montar_conjunto(raiz, tipo, "moletom", Catalogo.cor_do_moletom(a))
	elif a.roupa == "jaqueta":
		_montar_conjunto(raiz, tipo, "jaqueta", Catalogo.cor_do_conjunto(a, Catalogo.COR_DA_JAQUETA))
	elif a.roupa == "kimono":
		_montar_conjunto(raiz, tipo, "kimono", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_KIMONO))
	elif a.roupa == "capa_chuva":
		_montar_conjunto(raiz, tipo, "capa_chuva", Catalogo.cor_do_conjunto(a, Catalogo.COR_DA_CAPA_DE_CHUVA))
	elif a.roupa == "vestido":
		_montar_conjunto(raiz, tipo, "vestido", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_VESTIDO))
	elif a.roupa == "pirata":
		_montar_conjunto(raiz, tipo, "pirata", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_COLETE))
	elif a.roupa == "motoqueiro":
		_montar_conjunto(raiz, tipo, "motoqueiro", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_MOTOQUEIRO))
	elif a.roupa == "terno":
		_montar_conjunto(raiz, tipo, "terno", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_TERNO))
	elif a.roupa == "escolar":
		_montar_conjunto(raiz, tipo, "escolar", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_UNIFORME))
	elif a.roupa == "sueter":
		_montar_conjunto(raiz, tipo, "sueter", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_SUETER))
	elif a.roupa == "furisode":
		_montar_conjunto(raiz, tipo, "furisode", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_FURISODE))
	elif a.roupa == "casaco_pelo":
		_montar_conjunto(raiz, tipo, "casaco_pelo", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_CASACO_PELO))
	elif Catalogo.ROUPAS_LOTE_5.has(a.roupa):
		_montar_conjunto(raiz, tipo, Catalogo.ROUPAS_LOTE_5[a.roupa][0], Catalogo.cor_do_conjunto(a, Catalogo.ROUPAS_LOTE_5[a.roupa][1]))
	elif a.roupa == "armadura":
		_montar_conjunto(raiz, tipo, "armadura", Color.WHITE)
	elif a.roupa == "casaco_naval":
		_montar_conjunto(raiz, tipo, "casaco_capitao", Catalogo.cor_do_conjunto(a, Catalogo.COR_DO_CASACO_NAVAL))
	if a.calca == "pregueada":
		_montar_conjunto(raiz, tipo, "calca", Catalogo.cor_da_calca(a))
	if a.sapatos == "pretos":
		_montar_conjunto(raiz, tipo, "sapato", Color.BLACK)
	if a.roupa_intima == "cueca":
		_montar_conjunto(raiz, tipo, "cueca", Color.WHITE)
	if a.oculos == "escuros":
		_montar_conjunto(raiz, tipo, "oculos", Color.BLACK)
	for parte: String in ["cabeca", "rosto", "costas", "tronco", "cintura", "cauda", "pescoco", "peruca", "tatuagem", "ombro", "orelhas", "bracos", "maos", "item", "pernas", "pes"]:
		if a["acc_" + parte] != "original":
			_acessorio(raiz, tipo, str(a["acc_" + parte]))
	if a.estampa != "original":
		_estampa(raiz, str(a.estampa), str(a.estampa_local), Catalogo.ROUPAS_EM_MALHA.has(a.roupa))


## ROUPAS EM MALHA (19/11/2026). Modeladas no Blender (`assets/models/sobretudo/` e `assets/models/roupas/`, fontes em `art_src/`); cada peça tem o PIVÔ do nó do rig que a
## carrega. `*` na tabela = os dois lados. Roupa nova = uma linha aqui + as opções no `AparenciaHistoria`. A saia do sobretudo fica FIXA ao quadril (decisão do dono).
## [arquivo, nó do rig]; o nome do nó criado é `<Conjunto>_<arquivo>` (ex.: `Sobretudo_tronco`).
const CONJUNTOS := {
	"sobretudo": {"dir": "sobretudo", "pecas": [["tronco", "Chest"], ["saia", "Torso"], ["manga_sup", "UpperArm_*"], ["manga_inf", "ForeArm_*"]]},
	"moletom": {"dir": "roupas", "pecas": [["moletom_tronco", "Chest"], ["moletom_manga_sup", "UpperArm_*"], ["moletom_manga_inf", "ForeArm_*"]]},
	"jaqueta": {"dir": "roupas", "pecas": [["jaqueta_tronco", "Chest"], ["jaqueta_manga_sup", "UpperArm_*"], ["jaqueta_manga_inf", "ForeArm_*"]]},
	"casaco_capitao": {"dir": "roupas", "pecas": [["casaco_capitao_tronco", "Chest"], ["casaco_capitao_saia", "Torso"], ["casaco_capitao_manga_sup", "UpperArm_*"], ["casaco_capitao_manga_inf", "ForeArm_*"]]},
	"kimono": {"dir": "roupas", "pecas": [["kimono_tronco", "Chest"], ["kimono_saia", "Torso"], ["kimono_manga_sup", "UpperArm_*"], ["kimono_manga_inf", "ForeArm_*"]]},
	"capa_chuva": {"dir": "roupas", "pecas": [["capa_chuva_tronco", "Chest"], ["capa_chuva_saia", "Torso"], ["capa_chuva_manga_sup", "UpperArm_*"], ["capa_chuva_manga_inf", "ForeArm_*"]]},
	"vestido": {"dir": "roupas", "pecas": [["vestido_tronco", "Chest"], ["vestido_saia", "Torso"], ["vestido_manga_sup", "UpperArm_*"], ["vestido_manga_inf", "ForeArm_*"]]},
	"pirata": {"dir": "roupas", "pecas": [["pirata_tronco", "Chest"], ["pirata_manga_sup", "UpperArm_*"], ["pirata_manga_inf", "ForeArm_*"]]},
	"motoqueiro": {"dir": "roupas", "pecas": [["motoqueiro_tronco", "Chest"], ["motoqueiro_manga_sup", "UpperArm_*"], ["motoqueiro_manga_inf", "ForeArm_*"]]},
	"terno": {"dir": "roupas", "pecas": [["terno_tronco", "Chest"], ["terno_saia", "Torso"], ["terno_manga_sup", "UpperArm_*"], ["terno_manga_inf", "ForeArm_*"]]},
	"escolar": {"dir": "roupas", "pecas": [["escolar_tronco", "Chest"], ["escolar_saia", "Torso"], ["escolar_manga_sup", "UpperArm_*"], ["escolar_manga_inf", "ForeArm_*"]]},
	"sueter": {"dir": "roupas", "pecas": [["sueter_tronco", "Chest"], ["sueter_manga_sup", "UpperArm_*"], ["sueter_manga_inf", "ForeArm_*"]]},
	"furisode": {"dir": "roupas", "pecas": [["furisode_tronco", "Chest"], ["furisode_saia", "Torso"], ["furisode_manga_sup", "UpperArm_*"], ["furisode_manga_inf", "ForeArm_*"]]},
	"casaco_pelo": {"dir": "roupas", "pecas": [["casaco_pelo_tronco", "Chest"], ["casaco_pelo_saia", "Torso"], ["casaco_pelo_manga_sup", "UpperArm_*"], ["casaco_pelo_manga_inf", "ForeArm_*"]]},
	"ladino": {"dir": "roupas", "pecas": [["ladino_tronco", "Chest"], ["ladino_manga_sup", "UpperArm_*"], ["ladino_manga_inf", "ForeArm_*"]]},
	"astronauta": {"dir": "roupas", "pecas": [["astronauta_tronco", "Chest"], ["astronauta_cintura", "Torso"], ["astronauta_manga_sup", "UpperArm_*"], ["astronauta_manga_inf", "ForeArm_*"], ["astronauta_coxa", "Thigh_*"], ["astronauta_canela", "Shin_*"], ["astronauta_pe", "Foot_*"]]},
	"chef": {"dir": "roupas", "pecas": [["chef_tronco", "Chest"], ["chef_saia", "Torso"], ["chef_manga_sup", "UpperArm_*"], ["chef_manga_inf", "ForeArm_*"]]},
	"roupao": {"dir": "roupas", "pecas": [["roupao_tronco", "Chest"], ["roupao_saia", "Torso"], ["roupao_manga_sup", "UpperArm_*"], ["roupao_manga_inf", "ForeArm_*"]]},
	"marinheiro_listrado": {"dir": "roupas", "pecas": [["marinheiro_listrado_tronco", "Chest"], ["marinheiro_listrado_manga_sup", "UpperArm_*"], ["marinheiro_listrado_manga_inf", "ForeArm_*"]]},
	"pijama": {"dir": "roupas", "pecas": [["pijama_tronco", "Chest"], ["pijama_cintura", "Torso"], ["pijama_manga_sup", "UpperArm_*"], ["pijama_manga_inf", "ForeArm_*"], ["pijama_coxa", "Thigh_*"], ["pijama_canela", "Shin_*"]]},
	"macacao": {"dir": "roupas", "pecas": [["macacao_tronco", "Chest"], ["macacao_cintura", "Torso"], ["macacao_manga_sup", "UpperArm_*"], ["macacao_manga_inf", "ForeArm_*"], ["macacao_coxa", "Thigh_*"], ["macacao_canela", "Shin_*"]]},
	"dino": {"dir": "roupas", "pecas": [["dino_tronco", "Chest"], ["dino_cintura", "Torso"], ["dino_manga_sup", "UpperArm_*"], ["dino_manga_inf", "ForeArm_*"], ["dino_coxa", "Thigh_*"], ["dino_canela", "Shin_*"], ["dino_pe", "Foot_*"]]},
	"smoking": {"dir": "roupas", "pecas": [["smoking_tronco", "Chest"], ["smoking_saia", "Torso"], ["smoking_manga_sup", "UpperArm_*"], ["smoking_manga_inf", "ForeArm_*"]]},
	"capitao_vermelho": {"dir": "roupas", "pecas": [["capitao_vermelho_tronco", "Chest"], ["capitao_vermelho_saia", "Torso"], ["capitao_vermelho_manga_sup", "UpperArm_*"], ["capitao_vermelho_manga_inf", "ForeArm_*"]]},
	"samurai": {"dir": "roupas", "pecas": [["samurai_tronco", "Chest"], ["samurai_saia", "Torso"], ["samurai_manga_sup", "UpperArm_*"], ["samurai_manga_inf", "ForeArm_*"]]},
	"hakama": {"dir": "roupas", "pecas": [["hakama_tronco", "Chest"], ["hakama_saia", "Torso"], ["hakama_manga_sup", "UpperArm_*"], ["hakama_manga_inf", "ForeArm_*"]]},
	"ninja": {"dir": "roupas", "pecas": [["ninja_tronco", "Chest"], ["ninja_cintura", "Torso"], ["ninja_manga_sup", "UpperArm_*"], ["ninja_manga_inf", "ForeArm_*"], ["ninja_coxa", "Thigh_*"], ["ninja_canela", "Shin_*"], ["ninja_pe", "Foot_*"]]},
	"medico": {"dir": "roupas", "pecas": [["medico_tronco", "Chest"], ["medico_saia", "Torso"], ["medico_manga_sup", "UpperArm_*"], ["medico_manga_inf", "ForeArm_*"], ["medico_coxa", "Thigh_*"], ["medico_canela", "Shin_*"]]},
	"marinha_branco": {"dir": "roupas", "pecas": [["marinha_branco_tronco", "Chest"], ["marinha_branco_saia", "Torso"], ["marinha_branco_manga_sup", "UpperArm_*"], ["marinha_branco_manga_inf", "ForeArm_*"]]},
	"monge": {"dir": "roupas", "pecas": [["monge_tronco", "Chest"], ["monge_saia", "Torso"], ["monge_manga_sup", "UpperArm_L"]]},
	"aventureiro": {"dir": "roupas", "pecas": [["aventureiro_tronco", "Chest"], ["aventureiro_cintura", "Torso"], ["aventureiro_canela", "Shin_*"], ["aventureiro_pe", "Foot_*"]]},
	"vestido_verao": {"dir": "roupas", "pecas": [["vestido_verao_tronco", "Chest"], ["vestido_verao_saia", "Torso"]]},
	"tee_estrela": {"dir": "roupas", "pecas": [["tee_estrela_tronco", "Chest"], ["tee_estrela_manga_sup", "UpperArm_*"], ["tee_estrela_cintura", "Torso"], ["tee_estrela_coxa", "Thigh_*"]]},
	"bailarina": {"dir": "roupas", "pecas": [["bailarina_tronco", "Chest"], ["bailarina_saia", "Torso"]]},
	"jeans_jaqueta": {"dir": "roupas", "pecas": [["jeans_jaqueta_tronco", "Chest"], ["jeans_jaqueta_manga_sup", "UpperArm_*"], ["jeans_jaqueta_manga_inf", "ForeArm_*"]]},
	"jeans_rasgado": {"dir": "roupas", "pecas": [["jeans_rasgado_tronco", "Chest"], ["jeans_rasgado_cintura", "Torso"], ["jeans_rasgado_coxa", "Thigh_*"], ["jeans_rasgado_canela", "Shin_*"]]},
	"elfico": {"dir": "roupas", "pecas": [["elfico_tronco", "Chest"], ["elfico_saia", "Torso"], ["elfico_manga_sup", "UpperArm_*"], ["elfico_manga_inf", "ForeArm_*"]]},
	"oficial_vermelho": {"dir": "roupas", "pecas": [["oficial_vermelho_tronco", "Chest"], ["oficial_vermelho_saia", "Torso"], ["oficial_vermelho_manga_sup", "UpperArm_*"], ["oficial_vermelho_manga_inf", "ForeArm_*"]]},
	"bardo": {"dir": "roupas", "pecas": [["bardo_tronco", "Chest"], ["bardo_saia", "Torso"], ["bardo_manga_sup", "UpperArm_*"], ["bardo_manga_inf", "ForeArm_*"], ["bardo_coxa", "Thigh_*"], ["bardo_canela", "Shin_*"], ["bardo_pe", "Foot_*"]]},
	"kamishimo": {"dir": "roupas", "pecas": [["kamishimo_tronco", "Chest"], ["kamishimo_saia", "Torso"], ["kamishimo_manga_sup", "UpperArm_*"], ["kamishimo_manga_inf", "ForeArm_*"]]},
	"sacerdote": {"dir": "roupas", "pecas": [["sacerdote_tronco", "Chest"], ["sacerdote_saia", "Torso"], ["sacerdote_manga_sup", "UpperArm_*"], ["sacerdote_manga_inf", "ForeArm_*"]]},
	"piloto": {"dir": "roupas", "pecas": [["piloto_tronco", "Chest"], ["piloto_cintura", "Torso"], ["piloto_manga_sup", "UpperArm_*"], ["piloto_manga_inf", "ForeArm_*"], ["piloto_coxa", "Thigh_*"], ["piloto_canela", "Shin_*"], ["piloto_pe", "Foot_*"]]},
	"enfermeira": {"dir": "roupas", "pecas": [["enfermeira_tronco", "Chest"], ["enfermeira_saia", "Torso"], ["enfermeira_manga_sup", "UpperArm_*"], ["enfermeira_manga_inf", "ForeArm_*"]]},
	"lenhador": {"dir": "roupas", "pecas": [["lenhador_tronco", "Chest"], ["lenhador_manga_sup", "UpperArm_*"], ["lenhador_manga_inf", "ForeArm_*"]]},
	"junina": {"dir": "roupas", "pecas": [["junina_tronco", "Chest"], ["junina_saia", "Torso"], ["junina_manga_sup", "UpperArm_*"], ["junina_manga_inf", "ForeArm_*"]]},
	"gato_preto": {"dir": "roupas", "pecas": [["gato_preto_tronco", "Chest"], ["gato_preto_cintura", "Torso"], ["gato_preto_manga_sup", "UpperArm_*"], ["gato_preto_manga_inf", "ForeArm_*"], ["gato_preto_coxa", "Thigh_*"], ["gato_preto_canela", "Shin_*"], ["gato_preto_pe", "Foot_*"]]},
	"mergulhador": {"dir": "roupas", "pecas": [["mergulhador_tronco", "Chest"], ["mergulhador_cintura", "Torso"], ["mergulhador_manga_sup", "UpperArm_*"], ["mergulhador_manga_inf", "ForeArm_*"], ["mergulhador_coxa", "Thigh_*"], ["mergulhador_canela", "Shin_*"], ["mergulhador_pe", "Foot_*"]]},
	"safari": {"dir": "roupas", "pecas": [["safari_tronco", "Chest"], ["safari_manga_sup", "UpperArm_*"], ["safari_manga_inf", "ForeArm_*"]]},
	"bombeiro": {"dir": "roupas", "pecas": [["bombeiro_tronco", "Chest"], ["bombeiro_saia", "Torso"], ["bombeiro_manga_sup", "UpperArm_*"], ["bombeiro_manga_inf", "ForeArm_*"]]},
	"abelha": {"dir": "roupas", "pecas": [["abelha_tronco", "Chest"], ["abelha_manga_sup", "UpperArm_*"], ["abelha_manga_inf", "ForeArm_*"]]},
	"cientista": {"dir": "roupas", "pecas": [["cientista_tronco", "Chest"], ["cientista_saia", "Torso"], ["cientista_manga_sup", "UpperArm_*"], ["cientista_manga_inf", "ForeArm_*"]]},
	"fantasma": {"dir": "roupas", "pecas": [["fantasma_tronco", "Chest"], ["fantasma_saia", "Torso"], ["fantasma_manga_sup", "UpperArm_*"], ["fantasma_manga_inf", "ForeArm_*"]]},
	"gelo": {"dir": "roupas", "pecas": [["gelo_tronco", "Chest"], ["gelo_manga_sup", "UpperArm_*"]]},
	"yukata": {"dir": "roupas", "pecas": [["yukata_tronco", "Chest"], ["yukata_saia", "Torso"], ["yukata_manga_sup", "UpperArm_*"], ["yukata_manga_inf", "ForeArm_*"]]},
	"viking_peles": {"dir": "roupas", "pecas": [["viking_peles_tronco", "Chest"], ["viking_peles_saia", "Torso"], ["viking_peles_manga_sup", "UpperArm_*"], ["viking_peles_manga_inf", "ForeArm_*"], ["viking_peles_canela", "Shin_*"], ["viking_peles_pe", "Foot_*"]]},
	"noel": {"dir": "roupas", "pecas": [["noel_tronco", "Chest"], ["noel_saia", "Torso"], ["noel_cintura", "Torso"], ["noel_manga_sup", "UpperArm_*"], ["noel_manga_inf", "ForeArm_*"], ["noel_coxa", "Thigh_*"], ["noel_canela", "Shin_*"], ["noel_pe", "Foot_*"]]},
	"noiva": {"dir": "roupas", "pecas": [["noiva_tronco", "Chest"], ["noiva_saia", "Torso"], ["noiva_manga_sup", "UpperArm_*"], ["noiva_manga_inf", "ForeArm_*"]]},
	"cauboi_neon": {"dir": "roupas", "pecas": [["cauboi_neon_tronco", "Chest"], ["cauboi_neon_saia", "Torso"], ["cauboi_neon_manga_sup", "UpperArm_*"], ["cauboi_neon_manga_inf", "ForeArm_*"], ["cauboi_neon_pe", "Foot_*"]]},
	"esquiador": {"dir": "roupas", "pecas": [["esquiador_tronco", "Chest"], ["esquiador_saia", "Torso"], ["esquiador_cintura", "Torso"], ["esquiador_manga_sup", "UpperArm_*"], ["esquiador_manga_inf", "ForeArm_*"], ["esquiador_coxa", "Thigh_*"], ["esquiador_canela", "Shin_*"], ["esquiador_pe", "Foot_*"]]},
	"surfista": {"dir": "roupas", "pecas": [["surfista_tronco", "Chest"], ["surfista_cintura", "Torso"], ["surfista_manga_sup", "UpperArm_*"], ["surfista_manga_inf", "ForeArm_*"], ["surfista_coxa", "Thigh_*"], ["surfista_canela", "Shin_*"]]},
	"basquete": {"dir": "roupas", "pecas": [["basquete_tronco", "Chest"], ["basquete_cintura", "Torso"], ["basquete_coxa", "Thigh_*"], ["basquete_canela", "Shin_*"]]},
	"flamenco": {"dir": "roupas", "pecas": [["flamenco_tronco", "Chest"], ["flamenco_saia", "Torso"], ["flamenco_manga_sup", "UpperArm_*"], ["flamenco_manga_inf", "ForeArm_*"]]},
	"ballet": {"dir": "roupas", "pecas": [["ballet_tronco", "Chest"], ["ballet_cintura", "Torso"], ["ballet_pe", "Foot_*"]]},
	"sari": {"dir": "roupas", "pecas": [["sari_tronco", "Chest"], ["sari_saia", "Torso"], ["sari_manga_sup", "UpperArm_*"]]},
	"karate": {"dir": "roupas", "pecas": [["karate_tronco", "Chest"], ["karate_saia", "Torso"], ["karate_cintura", "Torso"], ["karate_manga_sup", "UpperArm_*"], ["karate_manga_inf", "ForeArm_*"], ["karate_coxa", "Thigh_*"], ["karate_canela", "Shin_*"]]},
	"hanbok": {"dir": "roupas", "pecas": [["hanbok_tronco", "Chest"], ["hanbok_saia", "Torso"], ["hanbok_manga_sup", "UpperArm_*"], ["hanbok_manga_inf", "ForeArm_*"]]},
	"egipcio": {"dir": "roupas", "pecas": [["egipcio_cintura", "Torso"], ["egipcio_saia", "Torso"], ["egipcio_manga_sup", "UpperArm_*"], ["egipcio_manga_inf", "ForeArm_*"]]},
	"astronauta_retro": {"dir": "roupas", "pecas": [["astronauta_retro_tronco", "Chest"], ["astronauta_retro_cintura", "Torso"], ["astronauta_retro_manga_sup", "UpperArm_*"], ["astronauta_retro_manga_inf", "ForeArm_*"], ["astronauta_retro_coxa", "Thigh_*"], ["astronauta_retro_canela", "Shin_*"], ["astronauta_retro_pe", "Foot_*"]]},
	"kilt": {"dir": "roupas", "pecas": [["kilt_tronco", "Chest"], ["kilt_saia", "Torso"]]},
	"quiton": {"dir": "roupas", "pecas": [["quiton_tronco", "Chest"], ["quiton_saia", "Torso"], ["quiton_manga_sup", "UpperArm_*"]]},
	"toga": {"dir": "roupas", "pecas": [["toga_tronco", "Chest"], ["toga_saia", "Torso"], ["toga_manga_sup", "UpperArm_*"]]},
	"futebol": {"dir": "roupas", "pecas": [["futebol_tronco", "Chest"], ["futebol_cintura", "Torso"], ["futebol_manga_sup", "UpperArm_*"], ["futebol_coxa", "Thigh_*"], ["futebol_canela", "Shin_*"], ["futebol_pe", "Foot_*"]]},
	"samurai_fem": {"dir": "roupas", "pecas": [["samurai_fem_tronco", "Chest"], ["samurai_fem_saia", "Torso"], ["samurai_fem_manga_sup", "UpperArm_*"], ["samurai_fem_manga_inf", "ForeArm_*"]]},
	"sailor": {"dir": "roupas", "pecas": [["sailor_tronco", "Chest"], ["sailor_saia", "Torso"], ["sailor_manga_sup", "UpperArm_*"], ["sailor_manga_inf", "ForeArm_*"], ["sailor_canela", "Shin_*"], ["sailor_pe", "Foot_*"]]},
	"punk": {"dir": "roupas", "pecas": [["punk_tronco", "Chest"], ["punk_cintura", "Torso"], ["punk_manga_sup", "UpperArm_*"], ["punk_manga_inf", "ForeArm_*"], ["punk_coxa", "Thigh_*"], ["punk_canela", "Shin_*"], ["punk_pe", "Foot_*"]]},
	"hiphop": {"dir": "roupas", "pecas": [["hiphop_tronco", "Chest"], ["hiphop_cintura", "Torso"], ["hiphop_manga_sup", "UpperArm_*"], ["hiphop_manga_inf", "ForeArm_*"], ["hiphop_coxa", "Thigh_*"], ["hiphop_canela", "Shin_*"], ["hiphop_pe", "Foot_*"]]},
	"lolita": {"dir": "roupas", "pecas": [["lolita_tronco", "Chest"], ["lolita_saia", "Torso"], ["lolita_manga_sup", "UpperArm_*"], ["lolita_manga_inf", "ForeArm_*"], ["lolita_canela", "Shin_*"], ["lolita_pe", "Foot_*"]]},
	"steampunk": {"dir": "roupas", "pecas": [["steampunk_tronco", "Chest"], ["steampunk_manga_sup", "UpperArm_*"], ["steampunk_manga_inf", "ForeArm_*"]]},
	"mago_sombrio": {"dir": "roupas", "pecas": [["mago_sombrio_tronco", "Chest"], ["mago_sombrio_saia", "Torso"], ["mago_sombrio_manga_sup", "UpperArm_*"], ["mago_sombrio_manga_inf", "ForeArm_*"]]},
	"druida": {"dir": "roupas", "pecas": [["druida_tronco", "Chest"], ["druida_saia", "Torso"], ["druida_manga_sup", "UpperArm_*"], ["druida_manga_inf", "ForeArm_*"]]},
	"pirata_sereia": {"dir": "roupas", "pecas": [["pirata_sereia_tronco", "Chest"], ["pirata_sereia_saia", "Torso"], ["pirata_sereia_manga_sup", "UpperArm_*"], ["pirata_sereia_manga_inf", "ForeArm_*"]]},
	"leao": {"dir": "roupas", "pecas": [["leao_tronco", "Chest"], ["leao_cintura", "Torso"], ["leao_manga_sup", "UpperArm_*"], ["leao_manga_inf", "ForeArm_*"], ["leao_coxa", "Thigh_*"], ["leao_canela", "Shin_*"], ["leao_pe", "Foot_*"]]},
	"coelha_pascoa": {"dir": "roupas", "pecas": [["coelha_pascoa_tronco", "Chest"], ["coelha_pascoa_cintura", "Torso"], ["coelha_pascoa_manga_sup", "UpperArm_*"], ["coelha_pascoa_manga_inf", "ForeArm_*"], ["coelha_pascoa_coxa", "Thigh_*"], ["coelha_pascoa_canela", "Shin_*"], ["coelha_pascoa_pe", "Foot_*"]]},
	"robo_retro": {"dir": "roupas", "pecas": [["robo_retro_tronco", "Chest"], ["robo_retro_cintura", "Torso"], ["robo_retro_manga_sup", "UpperArm_*"], ["robo_retro_manga_inf", "ForeArm_*"], ["robo_retro_coxa", "Thigh_*"], ["robo_retro_canela", "Shin_*"], ["robo_retro_pe", "Foot_*"]]},
	"esqueleto": {"dir": "roupas", "pecas": [["esqueleto_tronco", "Chest"], ["esqueleto_cintura", "Torso"], ["esqueleto_manga_sup", "UpperArm_*"], ["esqueleto_manga_inf", "ForeArm_*"], ["esqueleto_coxa", "Thigh_*"], ["esqueleto_canela", "Shin_*"], ["esqueleto_pe", "Foot_*"]]},
	"mumia": {"dir": "roupas", "pecas": [["mumia_tronco", "Chest"], ["mumia_cintura", "Torso"], ["mumia_manga_sup", "UpperArm_*"], ["mumia_manga_inf", "ForeArm_*"], ["mumia_coxa", "Thigh_*"], ["mumia_canela", "Shin_*"], ["mumia_pe", "Foot_*"]]},
	"mecanico_espacial": {"dir": "roupas", "pecas": [["mecanico_espacial_tronco", "Chest"], ["mecanico_espacial_cintura", "Torso"], ["mecanico_espacial_manga_sup", "UpperArm_*"], ["mecanico_espacial_manga_inf", "ForeArm_*"], ["mecanico_espacial_coxa", "Thigh_*"], ["mecanico_espacial_canela", "Shin_*"], ["mecanico_espacial_pe", "Foot_*"]]},
	"aviador": {"dir": "roupas", "pecas": [["aviador_tronco", "Chest"], ["aviador_manga_sup", "UpperArm_*"], ["aviador_manga_inf", "ForeArm_*"]]},
	"pintor": {"dir": "roupas", "pecas": [["pintor_tronco", "Chest"], ["pintor_cintura", "Torso"], ["pintor_manga_sup", "UpperArm_*"], ["pintor_manga_inf", "ForeArm_*"], ["pintor_coxa", "Thigh_*"], ["pintor_canela", "Shin_*"], ["pintor_pe", "Foot_*"]]},
	"garcom": {"dir": "roupas", "pecas": [["garcom_tronco", "Chest"], ["garcom_saia", "Torso"], ["garcom_cintura", "Torso"], ["garcom_manga_sup", "UpperArm_*"], ["garcom_manga_inf", "ForeArm_*"], ["garcom_coxa", "Thigh_*"], ["garcom_canela", "Shin_*"], ["garcom_pe", "Foot_*"]]},
	"caminhoneiro": {"dir": "roupas", "pecas": [["caminhoneiro_tronco", "Chest"], ["caminhoneiro_manga_sup", "UpperArm_*"], ["caminhoneiro_manga_inf", "ForeArm_*"]]},
	"rockstar": {"dir": "roupas", "pecas": [["rockstar_tronco", "Chest"], ["rockstar_manga_sup", "UpperArm_*"], ["rockstar_manga_inf", "ForeArm_*"]]},
	"baile_azul": {"dir": "roupas", "pecas": [["baile_azul_tronco", "Chest"], ["baile_azul_saia", "Torso"], ["baile_azul_manga_sup", "UpperArm_*"], ["baile_azul_manga_inf", "ForeArm_*"]]},
	"princesa_guerreira": {"dir": "roupas", "pecas": [["princesa_guerreira_tronco", "Chest"], ["princesa_guerreira_saia", "Torso"], ["princesa_guerreira_manga_sup", "UpperArm_*"], ["princesa_guerreira_manga_inf", "ForeArm_*"]]},
	"rei_elfo": {"dir": "roupas", "pecas": [["rei_elfo_tronco", "Chest"], ["rei_elfo_saia", "Torso"], ["rei_elfo_manga_sup", "UpperArm_*"], ["rei_elfo_manga_inf", "ForeArm_*"], ["rei_elfo_coxa", "Thigh_*"], ["rei_elfo_canela", "Shin_*"], ["rei_elfo_pe", "Foot_*"]]},
	"samurai_espectral": {"dir": "roupas", "pecas": [["samurai_espectral_tronco", "Chest"], ["samurai_espectral_saia", "Torso"], ["samurai_espectral_manga_sup", "UpperArm_*"], ["samurai_espectral_manga_inf", "ForeArm_*"]]},
	"sushi": {"dir": "roupas", "pecas": [["sushi_tronco", "Chest"], ["sushi_saia", "Torso"], ["sushi_manga_sup", "UpperArm_*"], ["sushi_manga_inf", "ForeArm_*"]]},
	"fada": {"dir": "roupas", "pecas": [["fada_tronco", "Chest"], ["fada_saia", "Torso"]]},
	"cacador": {"dir": "roupas", "pecas": [["cacador_tronco", "Chest"], ["cacador_manga_sup", "UpperArm_*"], ["cacador_manga_inf", "ForeArm_*"]]},
	"detetive": {"dir": "roupas", "pecas": [["detetive_tronco", "Chest"], ["detetive_saia", "Torso"], ["detetive_manga_sup", "UpperArm_*"], ["detetive_manga_inf", "ForeArm_*"]]},
	"bombeiro_resgate": {"dir": "roupas", "pecas": [["bombeiro_resgate_tronco", "Chest"], ["bombeiro_resgate_cintura", "Torso"], ["bombeiro_resgate_manga_sup", "UpperArm_*"], ["bombeiro_resgate_manga_inf", "ForeArm_*"], ["bombeiro_resgate_coxa", "Thigh_*"], ["bombeiro_resgate_canela", "Shin_*"], ["bombeiro_resgate_pe", "Foot_*"]]},
	"cirurgiao": {"dir": "roupas", "pecas": [["cirurgiao_tronco", "Chest"], ["cirurgiao_saia", "Torso"], ["cirurgiao_manga_sup", "UpperArm_*"], ["cirurgiao_manga_inf", "ForeArm_*"]]},
	"agente": {"dir": "roupas", "pecas": [["agente_tronco", "Chest"], ["agente_saia", "Torso"], ["agente_cintura", "Torso"], ["agente_manga_sup", "UpperArm_*"], ["agente_manga_inf", "ForeArm_*"], ["agente_coxa", "Thigh_*"], ["agente_canela", "Shin_*"], ["agente_pe", "Foot_*"]]},
	"cacafantasma": {"dir": "roupas", "pecas": [["cacafantasma_tronco", "Chest"], ["cacafantasma_cintura", "Torso"], ["cacafantasma_manga_sup", "UpperArm_*"], ["cacafantasma_manga_inf", "ForeArm_*"], ["cacafantasma_coxa", "Thigh_*"], ["cacafantasma_canela", "Shin_*"], ["cacafantasma_pe", "Foot_*"]]},
	"polar": {"dir": "roupas", "pecas": [["polar_tronco", "Chest"], ["polar_saia", "Torso"], ["polar_cintura", "Torso"], ["polar_manga_sup", "UpperArm_*"], ["polar_manga_inf", "ForeArm_*"], ["polar_coxa", "Thigh_*"], ["polar_canela", "Shin_*"], ["polar_pe", "Foot_*"]]},
	"pirata_neve": {"dir": "roupas", "pecas": [["pirata_neve_tronco", "Chest"], ["pirata_neve_saia", "Torso"], ["pirata_neve_manga_sup", "UpperArm_*"], ["pirata_neve_manga_inf", "ForeArm_*"]]},
	"ciclista": {"dir": "roupas", "pecas": [["ciclista_tronco", "Chest"], ["ciclista_manga_sup", "UpperArm_*"], ["ciclista_cintura", "Torso"], ["ciclista_coxa", "Thigh_*"], ["ciclista_canela", "Shin_*"], ["ciclista_pe", "Foot_*"]]},
	"yoga": {"dir": "roupas", "pecas": [["yoga_tronco", "Chest"], ["yoga_manga_sup", "UpperArm_*"], ["yoga_manga_inf", "ForeArm_*"], ["yoga_cintura", "Torso"], ["yoga_coxa", "Thigh_*"], ["yoga_canela", "Shin_*"]]},
	"goleiro": {"dir": "roupas", "pecas": [["goleiro_tronco", "Chest"], ["goleiro_manga_sup", "UpperArm_*"], ["goleiro_manga_inf", "ForeArm_*"], ["goleiro_cintura", "Torso"], ["goleiro_coxa", "Thigh_*"], ["goleiro_canela", "Shin_*"], ["goleiro_pe", "Foot_*"]]},
	"fazendeiro": {"dir": "roupas", "pecas": [["fazendeiro_tronco", "Chest"], ["fazendeiro_cintura", "Torso"], ["fazendeiro_coxa", "Thigh_*"], ["fazendeiro_canela", "Shin_*"], ["fazendeiro_pe", "Foot_*"]]},
	"patinador": {"dir": "roupas", "pecas": [["patinador_tronco", "Chest"], ["patinador_saia", "Torso"], ["patinador_manga_sup", "UpperArm_*"], ["patinador_manga_inf", "ForeArm_*"]]},
	"dj": {"dir": "roupas", "pecas": [["dj_tronco", "Chest"], ["dj_manga_sup", "UpperArm_*"], ["dj_manga_inf", "ForeArm_*"]]},
	"escoteiro": {"dir": "roupas", "pecas": [["escoteiro_tronco", "Chest"], ["escoteiro_manga_sup", "UpperArm_*"], ["escoteiro_cintura", "Torso"], ["escoteiro_coxa", "Thigh_*"], ["escoteiro_canela", "Shin_*"], ["escoteiro_pe", "Foot_*"]]},
	"piloto_comercial": {"dir": "roupas", "pecas": [["piloto_comercial_tronco", "Chest"], ["piloto_comercial_saia", "Torso"], ["piloto_comercial_cintura", "Torso"], ["piloto_comercial_manga_sup", "UpperArm_*"], ["piloto_comercial_manga_inf", "ForeArm_*"], ["piloto_comercial_coxa", "Thigh_*"], ["piloto_comercial_canela", "Shin_*"], ["piloto_comercial_pe", "Foot_*"]]},
	"formatura": {"dir": "roupas", "pecas": [["formatura_tronco", "Chest"], ["formatura_saia", "Torso"], ["formatura_manga_sup", "UpperArm_*"], ["formatura_manga_inf", "ForeArm_*"]]},
	"pescador": {"dir": "roupas", "pecas": [["pescador_tronco", "Chest"], ["pescador_saia", "Torso"], ["pescador_manga_sup", "UpperArm_*"], ["pescador_manga_inf", "ForeArm_*"], ["pescador_coxa", "Thigh_*"], ["pescador_canela", "Shin_*"], ["pescador_pe", "Foot_*"]]},
	"campista": {"dir": "roupas", "pecas": [["campista_tronco", "Chest"]]},
	"armadura": {"dir": "roupas", "pecas": [["armadura_tronco", "Chest"], ["armadura_ombro", "UpperArm_*"]]},
	"calca": {"dir": "roupas", "pecas": [["calca_cintura", "Torso"], ["calca_coxa", "Thigh_*"], ["calca_canela", "Shin_*"]]},
	"sapato": {"dir": "roupas", "pecas": [["sapato", "Foot_*"]]},
	"cueca": {"dir": "roupas", "pecas": [["cueca_quadril", "Torso"], ["cueca_coxa", "Thigh_*"]]},
	"oculos": {"dir": "roupas", "pecas": [["oculos", "Head"]]},
}


static func _montar_conjunto(raiz: Node3D, tipo: String, conjunto: String, cor: Color) -> void:
	var feminino := tipo == "feminino"
	var def: Dictionary = CONJUNTOS[conjunto]
	for par: Array in def.pecas:
		var nos: Array[Node3D] = []
		for lado in (["L", "R"] if str(par[1]).ends_with("*") else [""]):
			var nome_do_no := str(par[1]).replace("_*", "_" + lado) if lado != "" else str(par[1])
			var no := raiz.find_child(nome_do_no, true, false) as Node3D
			if no != null:
				nos.append(no)
		var caminho := "res://assets/models/%s/%s.glb" % [def.dir, par[0]]
		if nos.is_empty() or not ResourceLoader.exists(caminho):
			push_warning("[Roupa] sem nó %s ou sem %s" % [par[1], caminho])
			continue
		for no in nos:
			var peca := (load(caminho) as PackedScene).instantiate() as Node3D
			peca.name = "%s_%s" % [conjunto.capitalize(), par[0]]
			peca.set_meta("roupa_conjunto", conjunto)
			peca.set_meta("sobretudo_peca", par[0])
			Acessorios._fixar_ao_rig(peca)
			_pintar_peca(peca, cor)
			if feminino:
				if str(par[0]).contains("manga"):
					peca.scale.x = 0.78           # braço feminino mais fino (.18 em vez de .24)
				elif str(par[0]).ends_with("tronco"):
					peca.scale.z = 1.6            # o busto (até -.255) passa da profundidade do peito masculino (.145)
					peca.position.z = -0.07         # cresce para a frente: as costas ficam coladas ao corpo
			no.add_child(peca)


## ACESSÓRIOS DO CUSTOMIZADOR ANTIGO (`Acessorios.CATALOGO`), reencaixados no rig do Modo História. O encaixe antigo mede a caixa do nó em tempo de execução, o que aqui
## não serve (o `Torso` carrega o corpo todo). Então cada peça traz posição e escala NO NÓ, calculadas das medidas dos GLBs e do corpo (cabeça .48 cúbica com pivô na base;
## os GLBs de cabeça foram feitos para .50×.50×.74, daí a escala `CABECA` — a mesma do cabelo). `fem` = ajuste do corpo feminino (busto). `brilha` = a auréola emite luz.
const ESCALA_DA_CABECA := Vector3(.48 / .50, .48 / .50, .48 / .74)
const ENCAIXE_DE_ACESSORIOS := {
	"chapeu_palha": {"no": "Head", "pos": Vector3(0, .32, 0), "escala": ESCALA_DA_CABECA},
	"aureola": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA, "brilha": true},
	"coroa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cartola": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"mascara_caveira": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"mascara_peste": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"mascara_covid": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"capa_marinha": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"luffy_camisa": {"no": "Chest", "pos": Vector3(0, .24, 0), "escala": Vector3(.78, .75, .55), "fem": {"escala_z": .9, "pos_z": -.07}},
	"espadas_zoro": {"no": "Torso", "pos": Vector3(-.29, .12, .04), "escala": Vector3(.8, .8, .8)},
	"cauda_raposa": {"no": "Torso", "pos": Vector3(0, .03, 0), "escala": Vector3(.75, .75, .75)},
	"ombreira_armadura": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"cachecol_longo_vermelho": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"luvas_couro_garras": {"no": "Hand_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"botas_altas_fivelas": {"no": "Foot_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"chapeu_pirata_tricornio": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_feiticeiro_bruxa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"fone_ouvido_headset": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"oculos_aviador_testa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"bainhas_duas_espadas_cruzadas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"mochila_viagem": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"colar_pingente": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"bracadeiras_metal": {"no": "ForeArm_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"coroa_louros": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"escudo_redondo_costas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"capuz_manto": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"lanterna_mao": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1), "brilha": true},
	"katana_wakizashi_cintura_direita": {"no": "Torso", "pos": Vector3(.29, .12, .04), "escala": Vector3(.8, .8, .8)},
	"espada_katana": {"no": "Torso", "pos": Vector3(-.29, .12, .04), "escala": Vector3(.8, .8, .8)},
	"bandana_faixa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"mascara_gas_respirador": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"barba_cheia_bigode": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"cauda_dragao_lagarto": {"no": "Torso", "pos": Vector3(0, .03, 0), "escala": Vector3(.75, .75, .75)},
	"tentaculos_bracos_extras": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"aureola_asas_anjo": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"asas_morcego_grandes": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(.7, .7, .7)},
	"chapeu_cauboi": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cicatriz_rosto": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"bone_capitao_naval": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"machado_batalha_costas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"cajado_mago_mao": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1), "brilha": true},
	"orelhas_coelho": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cauda_pompom": {"no": "Torso", "pos": Vector3(0, .03, 0), "escala": Vector3(1, 1, 1)},
	"tiara_joias": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_panama_palha": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"polainas_arco_iris": {"no": "Shin_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"joelheiras_couro": {"no": "Shin_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"cotoveleiras_couro": {"no": "ForeArm_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"cinto_ferramentas_bolsas": {"no": "Torso", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"gancho_pirata": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"perna_de_pau": {"no": "Shin_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"brincos_longos_piercing": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capuz_gato_orelhas": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"monoculo_corrente": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"boina_francesa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cachecol_curto_vermelho": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"capa_mago_estrelas": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"capacete_astronauta": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"toque_chef": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"toalha_turbante": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"bone_marinheiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"gorro_dormir": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cocar_grande_penas": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"coroa_rei": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capa_opera": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"manto_arminho": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"asas_fada_translucidas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(.9, .9, .9)},
	"visor_realidade_virtual": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"barbatana_sereia": {"no": "Torso", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"pelucia_urso": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"gorro_la_pompom": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_capitao_pirata": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"kabuto_samurai": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"colete_salva_vidas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"papagaio_ombro": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"capa_viajante_remendos": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"mascara_ninja_faixa": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"colar_contas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"chapeu_palha_verao": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"orelhas_lobo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chifres_cervo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"coroa_flores": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cauda_lobo": {"no": "Torso", "pos": Vector3(0, .03, 0), "escala": Vector3(.8, .8, .8)},
	"asas_borboleta": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(.8, .8, .8)},
	"cinto_bussola_mapas": {"no": "Torso", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"aureola_neon": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA, "brilha": true},
	"tenis_chunky_colorido": {"no": "Foot_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"botas_cauboi_esporas": {"no": "Foot_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"sandalias_gladiador": {"no": "Foot_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"luvas_boxe_vermelhas": {"no": "Hand_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"elmo_viking_barba": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"colar_dentes": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"braceletes_dentes": {"no": "ForeArm_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"capa_super_heroi": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"pintura_facial_listras": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"tatuagem_braco": {"no": "UpperArm_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"mascara_domino": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"elmo_cavaleiro_plumas": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_mago_azul": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"asas_dragao_pequenas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"orelhas_cachorro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"tiara_gelo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"coleira_couro": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"capa_neve": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"mascara_coruja": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"presas_vampiro": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"capa_vampiro": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"chifres_diabinho": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"cauda_diabo": {"no": "Torso", "pos": Vector3(0, .03, 0), "escala": Vector3(.9, .9, .9)},
	"peruca_arco_iris": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_bardo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"alaude_costas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"capacete_piloto": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"touca_enfermagem": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_junino": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"asas_anjo_grandes": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(.9, .9, .9)},
	"orelhas_elfo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capuz_panda": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"mascara_snorkel": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"capacete_esferico": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_safari": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capacete_bombeiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"oculos_protecao_testa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_fantasma": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capuz_lobo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_bruxa_laranja": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"fantasia_abobora": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"lanterna_papel": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1), "brilha": true},
	"gorro_barba_noel": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"veu_noiva": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_cauboi_neon": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA, "brilha": true},
	"gorro_esqui_oculos": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"faixa_karate": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"tenis_alto_laranja": {"no": "Foot_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"prancha_surf": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"leque_vermelho": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"nemes_farao": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"sombrero_colorido": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"bandana_listrada": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"peruca_rosa_azul": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"colar_egipcio": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"poncho_arco_iris": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"coroa_louros_dourada": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"gaita_de_fole": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"peruca_dreads_coloridos": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"bone_aba_reta": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"laco_gotico": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"goggles_steampunk": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"coroa_galhos": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"ataduras_cabeca": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"coroa_coral": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"peruca_barroca": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"piercing_prata": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"manto_ondas": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"barba_curta": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"capacete_mecanico": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capacete_aviador": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_jardineiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"boina_bordo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"bone_carteiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"avental_jardineiro": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"avental_branco": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"bolsa_carteiro": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"luvas_jardim": {"no": "Hand_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"paleta_tinta": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"bone_caminhoneiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"tiara_baile": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"coroa_elfica": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_cogumelo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capa_princesa": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"manto_musgo": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"guitarra_costas": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"oculos_escuros_grandes": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"kabuto_espectral": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_sushi": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"tornozeleira_flores": {"no": "Shin_*", "pos": Vector3(0, -.2, 0), "escala": Vector3(1, 1, 1)},
	"chapeu_aventureiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"fedora_detetive": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capacete_resgate": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"mochila_aventura": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"chicote_cinto": {"no": "Torso", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"lupa_detetive": {"no": "Hand_R", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"touca_cirurgica": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_polar": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"chapeu_pirata_neve": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"mascara_cirurgica": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"oculos_fone_agente": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"mochila_protons": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1), "brilha": true},
	"toque_pizzaiolo": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capacete_ciclista": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"faixa_yoga": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"avental_xadrez": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"mawashi_sumo": {"no": "Torso", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"luvas_goleiro": {"no": "Hand_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"fones_dj_neon": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA, "brilha": true},
	"luvas_dj": {"no": "Hand_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"botas_borracha": {"no": "Foot_*", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"chapeu_escoteiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"quepe_piloto": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capelo_formatura": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"touca_confeiteiro": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"lanterna_testa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA, "brilha": true},
	"avental_rosa": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"mochila_camping": {"no": "Chest", "pos": Vector3(0, 0, 0), "escala": Vector3(1, 1, 1)},
	"mascara_oni": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"tapa_olho": {"no": "Head", "pos": Vector3(0, .24, -.24), "escala": ESCALA_DA_CABECA},
	"asas_pequenas": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"chifres_oni_par": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"orelhas_gato_raposa": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"capa_com_gola": {"no": "Chest", "pos": Vector3(0, .24, .056), "escala": Vector3(.8, .8, .8), "fem": {"pos_z": -.03}},
	"chifre_unico": {"no": "Head", "pos": Vector3(0, .48, 0), "escala": ESCALA_DA_CABECA},
	"espada_larga_cerimonial": {"no": "Chest", "pos": Vector3(0, .16, .17), "escala": Vector3(.8, .8, .8)},
	"chinelo": {"no": "Foot_*", "pos": Vector3(0, -.09, 0), "escala": Vector3(.8, .8, .58)},
}


static func _acessorio(raiz: Node3D, tipo: String, id: String) -> void:
	if id == "luffy_calcao":
		_calcao_do_luffy(raiz)
		return
	var enc: Dictionary = ENCAIXE_DE_ACESSORIOS.get(id, {})
	if enc.is_empty():
		push_warning("[Acessório] sem encaixe para " + id)
		return
	var caminho := Acessorios.BASE + id + ".glb"
	if not ResourceLoader.exists(caminho):
		push_warning("[Acessório] arquivo ausente: " + caminho)
		return
	for lado in (["L", "R"] if str(enc.no).ends_with("*") else [""]):
		var no := raiz.find_child(str(enc.no).replace("_*", "_" + lado) if lado != "" else str(enc.no), true, false) as Node3D
		if no == null:
			continue
		var peca := (load(caminho) as PackedScene).instantiate() as Node3D
		peca.name = "Acessorio_" + id
		peca.set_meta("acessorio_historia", id)
		peca.position = enc.pos
		peca.scale = enc.escala
		if tipo == "feminino" and enc.has("fem"):
			peca.scale.z *= float(enc.fem.get("escala_z", 1.0))
			peca.position.z = float(enc.fem.get("pos_z", peca.position.z))
		Acessorios._fixar_ao_rig(peca)
		Acessorios._converter_materiais(peca, bool(enc.get("brilha", false)))
		no.add_child(peca)


## Calção do Luffy: o antigo era gerado por caixas em volta da caixa medida de cada nó; aqui as mesmas caixas, com as medidas do corpo novo (cintura no `Torso`, uma bainha por
## coxa — cada metade pendura no nó que a animação move).
static func _calcao_do_luffy(raiz: Node3D) -> void:
	var azul := Materiais.superficie(Color(0.22, 0.34, 0.62))
	var branco := Materiais.superficie(Color(0.90, 0.90, 0.88))
	var torso := raiz.find_child("Torso", true, false) as Node3D
	if torso != null:
		_tecido(torso, "Acessorio_luffy_calcao_cintura", Vector3(.52, .11, .27), Vector3(0, .07, 0), azul)
	for lado in ["L", "R"]:
		var coxa := raiz.find_child("Thigh_" + lado, true, false) as Node3D
		if coxa != null:
			_tecido(coxa, "Acessorio_luffy_calcao_tecido", Vector3(.27, .19, .27), Vector3(0, -.248, 0), azul)
			_tecido(coxa, "Acessorio_luffy_calcao_bainha", Vector3(.28, .034, .28), Vector3(0, -.331, 0), branco)


static func _tecido(pai: Node3D, nome: String, tamanho: Vector3, pos: Vector3, material: Material) -> void:
	var m := MeshInstance3D.new()
	m.name = nome
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	m.mesh = caixa
	m.position = pos
	m.material_override = material
	m.set_meta("acessorio_historia", "luffy_calcao")
	pai.add_child(m)


## A cor de cada superfície vem do NOME do material no GLB: Manto/Principal = a cor da roupa; Punho mais claro; Lapela um tom acima; Forro e Vinco mais escuros;
## Preto, Branco e Lente são fixos (cueca, sapato, óculos).
static func _cor_do_material(nome: String, base: Color) -> Color:
	if nome.contains("Punho"):
		return base.lightened(.3 if nome.begins_with("Sobretudo") else .45)
	if nome.contains("Lapela"):
		return base.lightened(.14)
	if nome.contains("Forro"):
		return base.darkened(.55)
	if nome.contains("Neon"):
		return Color(0.20, 0.75, 1.0)
	if nome.contains("Jeansclaro"):
		return Color(0.40, 0.58, 0.82)
	if nome.contains("Jeans"):
		return Color(0.22, 0.40, 0.70)
	if nome.contains("Hakama"):
		return Color(0.10, 0.14, 0.34)
	if nome.contains("Cruz"):
		return Color(0.15, 0.40, 0.85)
	if nome.contains("Azul"):
		return Color(0.10, 0.20, 0.60)
	if nome.contains("Espinho"):
		return Color(0.62, 0.82, 0.22)
	if nome.contains("Pelo"):
		return Color(0.93, 0.86, 0.70)
	if nome.contains("Rosa"):
		return Color(0.98, 0.74, 0.80)
	if nome.contains("Prata"):
		return Color(0.76, 0.78, 0.82)
	if nome.contains("Gravata"):
		return Color(0.66, 0.08, 0.10)
	if nome.contains("Couro"):
		return Color(0.30, 0.17, 0.09)
	if nome.contains("Obi"):
		return Color(0.72, 0.08, 0.10)
	if nome.contains("Aco"):
		return Color(0.70, 0.72, 0.76)
	if nome.contains("Bronze"):
		return Color(0.72, 0.46, 0.14)
	if nome.contains("Ouro"):
		return Color(0.90, 0.68, 0.14)
	if nome.contains("Vinco"):
		return base.darkened(.14)
	if nome.contains("Preto"):
		return Color(0.06, 0.06, 0.07)
	if nome.contains("Branco"):
		return Color(0.93, 0.93, 0.94)
	if nome.contains("Lente"):
		return Color(0.02, 0.02, 0.03)
	return base


static func _pintar_peca(peca: Node3D, cor: Color) -> void:
	for m: MeshInstance3D in peca.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var original := m.mesh.surface_get_material(i)
			m.set_surface_override_material(i, Materiais.superficie(_cor_do_material(original.resource_name if original != null else "", cor)))


## ESTAMPA: a imagem do jogador num quadro fino sobre a roupa (costas = no Chest, atrás; peito = na frente). Fica a 2 mm da superfície, para o coplanar não piscar.
## Sem a imagem guardada (id sumido) não desenha nada.
static func _estampa(raiz: Node3D, id: String, local: String, com_sobretudo: bool) -> void:
	var textura := EstampasHistoria.textura(id)
	var peito := raiz.find_child("Chest", true, false) as Node3D
	if textura == null or peito == null:
		return
	var prop := EstampasHistoria.proporcao(id)
	var lado := 0.30 if local != "peito" else 0.16
	var tamanho := Vector2(lado, lado / prop) if prop >= 1.0 else Vector2(lado * prop, lado)      # o lado maior mede `lado`: a imagem não estica
	var espessura := 0.145 if com_sobretudo else 0.12
	var quadro := MeshInstance3D.new()
	quadro.name = "EstampaDaRoupa"
	var malha := QuadMesh.new()
	malha.size = tamanho
	quadro.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = textura
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	quadro.material_override = mat
	if local == "peito":
		quadro.position = Vector3(-0.10 if not com_sobretudo else -0.16, 0.10, -(espessura + 0.003))
		quadro.rotation.y = PI                       # o quadro olha para +Z por padrão; a frente do rig é -Z
	else:
		quadro.position = Vector3(0, 0.0, espessura + 0.003)
	quadro.set_meta("estampa_id", id)
	peito.add_child(quadro)


static func _nariz(cabeca: Node3D, estilo: String, pele: Color) -> void:
	# Perfil fechado com ponte, ponta e base; os quatro formatos alteram a silhueta.
	var medidas: Vector3 = {"pequeno": Vector3(.040, .065, .030), "reto": Vector3(.044, .095, .064),
		"largo": Vector3(.080, .070, .046), "arrebitado": Vector3(.050, .070, .055)}[estilo]
	var w := medidas.x * .5
	var h := medidas.y
	var d := medidas.z
	var ponta := -.003 if estilo == "arrebitado" else -h * .28
	var vertices := [Vector3(-w*.55,h*.5,0), Vector3(w*.55,h*.5,0),
		Vector3(-w,-h*.5,0), Vector3(w,-h*.5,0),
		Vector3(-w,ponta,-d), Vector3(w,ponta,-d)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Faces em sentido horário vistas de fora, como o restante do rig.
	for face: Array in [[0,1,5,4], [4,5,3,2], [0,4,2], [1,3,5], [0,2,3,1]]:
		var ordem := [0,1,2] if face.size() == 3 else [0,1,2,0,2,3]
		for i: int in ordem: st.add_vertex(vertices[face[i]])
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "NarizPersonalizado"
	mesh.mesh = st.commit()
	mesh.position = Vector3(0, .185, -.242)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pele
	mat.roughness = .9
	mesh.material_override = mat
	mesh.set_meta("estilo", estilo)
	cabeca.add_child(mesh)
