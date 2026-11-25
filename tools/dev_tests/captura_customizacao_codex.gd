extends SceneTree
## ATENÇÃO: abre uma janela real (X11) e deixa a tela do usuário cinza enquanto roda. Só rodar com o usuário ciente; nos testes de rotina usar só os testes --headless.
## Fotos do personagem do Modo História vestido com as peças modeladas a partir das imagens do Codex.
##   DISPLAY=:1 godot --path . -s tools/dev_tests/captura_customizacao_codex.gd   -> art_src/validation/customizacao_codex/*.png
const Corpo := preload("res://src/player/corpo_historia.gd")
const SAIDA := "res://art_src/validation/customizacao_codex/"
const CASOS := {
	"a_samurai": {"cabelo": "cabelo_coque_samurai", "acc_cintura": "espada_katana", "roupa": "jaqueta", "calca": "escura"},
	"b_capitao": {"cabelo": "cabelo_longo_liso", "roupa": "casaco_naval", "acc_costas": "capa_com_gola", "acc_cabeca": "bandana_faixa"},
	"f_armadura": {"cabelo": "curto", "acc_tronco": "ombreira_armadura", "acc_rosto": "tapa_olho"},
	"g_viajante": {"cabelo": "curto", "acc_pescoco": "cachecol_longo_vermelho", "acc_maos": "luvas_couro_garras", "acc_pes": "botas_altas_fivelas", "roupa": "jaqueta"},
	"h_bruxa": {"cabelo": "cabelo_tranca_lateral", "acc_cabeca": "chapeu_feiticeiro_bruxa"},
	"i_pirata": {"cabelo": "cabelo_ruivo_curto_baguncado", "acc_cabeca": "chapeu_pirata_tricornio"},
	"j_rabos": {"cabelo": "cabelo_rabo_duplo"},
	"k_mochila": {"cabelo": "curto", "acc_cabeca": "oculos_aviador_testa", "acc_costas": "mochila_viagem", "acc_pescoco": "colar_pingente", "acc_bracos": "bracadeiras_metal"},
	"l_espadas": {"cabelo": "curto", "acc_cabeca": "fone_ouvido_headset", "acc_costas": "bainhas_duas_espadas_cruzadas"},
	"m_guerreiro": {"cabelo": "curto", "acc_cabeca": "coroa_louros", "acc_costas": "escudo_redondo_costas", "acc_cintura": "katana_wakizashi_cintura_direita", "acc_item": "lanterna_mao"},
	"n_capuz": {"cabelo": "careca", "acc_pescoco": "capuz_manto"},
	"o_mascara": {"cabelo": "curto", "acc_rosto": "mascara_oni"},
	"p_kimono": {"cabelo": "cabelo_coque_samurai", "roupa": "kimono", "acc_cintura": "katana_wakizashi_cintura_direita"},
	"q_armadura": {"cabelo": "curto", "roupa": "armadura", "calca": "escura"},
	"r_chuva": {"cabelo": "careca", "roupa": "capa_chuva"},
	"s_punk": {"cabelo": "cabelo_mohawk_punk"},
	"t_gala": {"cabelo": "cabelo_coque_alto_palitos", "roupa": "vestido"},
	"u_pirata": {"cabelo": "cabelo_bob_chanel_franja", "roupa": "pirata", "acc_rosto": "barba_cheia_bigode"},
	"v_gas": {"cabelo": "curto", "acc_rosto": "mascara_gas_respirador"},
	"w_demonio": {"cabelo": "curto", "acc_costas": "asas_morcego_grandes", "acc_cauda": "cauda_dragao_lagarto", "acc_cabeca": "chapeu_cauboi"},
	"x_anjo": {"cabelo": "curto", "acc_costas": "aureola_asas_anjo"},
	"y_tentaculos": {"cabelo": "curto", "acc_costas": "tentaculos_bracos_extras"},
	"z_capitao": {"cabelo": "curto", "acc_cabeca": "bone_capitao_naval", "acc_rosto": "cicatriz_rosto", "acc_item": "cajado_mago_mao", "acc_costas": "machado_batalha_costas"},
	"aa_moto": {"cabelo": "cabelo_mohawk_punk", "roupa": "motoqueiro", "calca": "escura"},
	"ab_terno": {"cabelo": "curto", "roupa": "terno"},
	"ac_escolar": {"cabelo": "cabelo_rabo_duplo", "roupa": "escolar"},
	"ad_coelho": {"cabelo": "careca", "roupa": "sueter", "acc_cabeca": "orelhas_coelho", "acc_cauda": "cauda_pompom"},
	"ae_artesao": {"cabelo": "curto", "acc_cabeca": "chapeu_panama_palha", "acc_cintura": "cinto_ferramentas_bolsas", "acc_pernas": "joelheiras_couro", "acc_bracos": "cotoveleiras_couro"},
	"af_princesa": {"cabelo": "cabelo_longo_liso", "acc_cabeca": "tiara_joias", "acc_pernas": "polainas_arco_iris"},
	"ag_pirata": {"cabelo": "cabelo_box_braids_longas", "acc_maos": "gancho_pirata", "acc_pernas": "perna_de_pau", "acc_orelhas": "brincos_longos_piercing"},
	"ah_furisode": {"cabelo": "cabelo_rabo_cavalo_laco", "roupa": "furisode"},
	"ai_gato": {"cabelo": "careca", "acc_cabeca": "capuz_gato_orelhas"},
	"aj_inverno": {"cabelo": "cabelo_finger_waves_curto", "roupa": "casaco_pelo", "acc_rosto": "monoculo_corrente"},
	"ak_boina": {"cabelo": "curto", "acc_cabeca": "boina_francesa", "acc_pescoco": "cachecol_curto_vermelho"},
	"al_musculoso": {"cabelo": "curto", "porte": "musculoso"},
	"am_magro": {"cabelo": "curto", "porte": "magro_alto"},
	"an_baixo": {"cabelo": "curto", "porte": "baixo_robusto"},
	"ba_astro": {"cabelo": "careca", "roupa": "astronauta", "acc_cabeca": "capacete_astronauta"},
	"bb_chef": {"cabelo": "curto", "roupa": "chef", "acc_cabeca": "toque_chef"},
	"bc_pijama": {"cabelo": "careca", "roupa": "pijama", "acc_cabeca": "gorro_dormir"},
	"bd_macacao": {"cabelo": "curto", "roupa": "macacao"},
	"be_mago": {"cabelo": "curto", "roupa": "ladino", "acc_costas": "capa_mago_estrelas"},
	"bf_marujo": {"cabelo": "curto", "roupa": "marinheiro_listrado", "acc_cabeca": "bone_marinheiro"},
	"bg_roupao": {"cabelo": "careca", "roupa": "roupao", "acc_cabeca": "toalha_turbante"},
	"bh_dino": {"cabelo": "careca", "roupa": "dino"},
	"bi_gala": {"cabelo": "curto", "roupa": "smoking", "acc_costas": "capa_opera"},
	"bj_rei": {"cabelo": "curto", "acc_cabeca": "coroa_rei", "acc_costas": "manto_arminho"},
	"bk_indio": {"cabelo": "careca", "acc_cabeca": "cocar_grande_penas"},
	"bl_fada": {"cabelo": "curto", "acc_costas": "asas_fada_translucidas", "acc_rosto": "visor_realidade_virtual"},
	"bm_sereia": {"cabelo": "cabelo_longo_ondulado_flores", "acc_pernas": "barbatana_sereia"},
	"bn_urso": {"cabelo": "careca", "acc_rosto": "pelucia_urso"},
	"bo_anime": {"cabelo": "cabelo_anime_azul_espetado"},
	"bp_trancas": {"cabelo": "cabelo_duas_trancas_curtas"},
	"bq_pirata": {"cabelo": "curto", "roupa": "capitao_vermelho", "acc_cabeca": "chapeu_capitao_pirata", "acc_ombro": "papagaio_ombro", "acc_rosto": "tapa_olho"},
	"br_samurai": {"cabelo": "careca", "roupa": "samurai", "acc_cabeca": "kabuto_samurai"},
	"bs_colete": {"cabelo": "curto", "acc_tronco": "colete_salva_vidas", "acc_cabeca": "gorro_la_pompom"},
	"bt_viajante": {"cabelo": "curto", "roupa": "hakama", "acc_costas": "capa_viajante_remendos"},
	"bu_ninja": {"cabelo": "careca", "roupa": "ninja", "acc_rosto": "mascara_ninja_faixa"},
	"bv_medico": {"cabelo": "curto", "roupa": "medico"},
	"bw_marinha": {"cabelo": "curto", "roupa": "marinha_branco"},
	"bx_monge": {"cabelo": "careca", "roupa": "monge", "acc_pescoco": "colar_contas"},
	"by_aventura": {"cabelo": "cabelo_curto_prateado_mecha", "roupa": "aventureiro"},
	"bz_verao": {"cabelo": "cabelo_menta_rabo_baixo", "roupa": "vestido_verao", "acc_cabeca": "chapeu_palha_verao"},
	"ca_lobo": {"cabelo": "careca", "acc_cabeca": "orelhas_lobo", "acc_cauda": "cauda_lobo"},
	"cb_cervo": {"cabelo": "curto", "acc_cabeca": "chifres_cervo", "acc_costas": "asas_borboleta"},
	"cc_flores": {"cabelo": "cabelo_longo_liso", "acc_cabeca": "coroa_flores"},
	"cd_neon": {"cabelo": "cabelo_longo_camadas", "acc_cabeca": "aureola_neon", "acc_cintura": "cinto_bussola_mapas"},
	"ce_viking": {"cabelo": "careca", "acc_cabeca": "elmo_viking_barba", "acc_maos": "luvas_boxe_vermelhas", "acc_pes": "botas_cauboi_esporas"},
	"cf_casual": {"cabelo": "curto", "roupa": "tee_estrela", "acc_pes": "tenis_chunky_colorido"},
	"cg_gladiador": {"cabelo": "curto", "acc_pes": "sandalias_gladiador"},
	"ch_heroi": {"cabelo": "curto", "roupa": "jeans_rasgado", "acc_costas": "capa_super_heroi", "acc_rosto": "pintura_facial_listras", "acc_pescoco": "colar_dentes", "acc_bracos": "braceletes_dentes"},
	"ci_bailarina": {"cabelo": "cabelo_coque_alto_palitos", "roupa": "bailarina"},
	"cj_jeans": {"cabelo": "curto", "roupa": "jeans_jaqueta", "calca": "escura"},
	"ck_cavaleiro": {"cabelo": "careca", "acc_cabeca": "elmo_cavaleiro_plumas", "acc_tatuagem": "tatuagem_braco", "acc_costas": "asas_dragao_pequenas"},
	"cl_mago": {"cabelo": "careca", "acc_cabeca": "chapeu_mago_azul"},
	"cm_heroi": {"cabelo": "cabelo_curto_volumoso", "acc_rosto": "mascara_domino"},
	"cn_gelo": {"cabelo": "cabelo_longo_liso", "acc_cabeca": "tiara_gelo", "acc_costas": "capa_neve"},
	"co_cao": {"cabelo": "careca", "acc_cabeca": "orelhas_cachorro", "acc_pescoco": "coleira_couro", "acc_rosto": "mascara_coruja"},
	"cp_vampiro": {"cabelo": "cabelo_ruivo_cacheado", "acc_rosto": "presas_vampiro", "acc_costas": "capa_vampiro"},
	"cq_diabo": {"cabelo": "cabelo_afro_puff_duplo", "acc_cabeca": "chifres_diabinho", "acc_cauda": "cauda_diabo"},
	"cr_peruca": {"cabelo": "careca", "acc_peruca": "peruca_arco_iris"},
	"cs_lenco": {"cabelo": "cabelo_cacheado_lenco"},
	"ct_bardo": {"cabelo": "cabelo_cornrows", "roupa": "bardo", "acc_cabeca": "chapeu_bardo", "acc_costas": "alaude_costas"},
	"cu_elfo": {"cabelo": "curto", "roupa": "elfico"},
	"cv_oficial": {"cabelo": "curto", "roupa": "oficial_vermelho"},
	"cw_kami": {"cabelo": "cabelo_coque_samurai", "roupa": "kamishimo"},
	"cx_padre": {"cabelo": "curto", "roupa": "sacerdote"},
	"cy_piloto": {"cabelo": "careca", "roupa": "piloto", "acc_cabeca": "capacete_piloto"},
	"cz_enf": {"cabelo": "curto", "roupa": "enfermeira", "acc_cabeca": "touca_enfermagem"},
	"da_lenha": {"cabelo": "curto", "roupa": "lenhador", "calca": "escura"},
	"db_junina": {"cabelo": "cabelo_duas_trancas_curtas", "roupa": "junina", "acc_cabeca": "chapeu_junino"},
	"dc_gato": {"cabelo": "careca", "roupa": "gato_preto"},
	"dd_anjo": {"cabelo": "curto", "acc_costas": "asas_anjo_grandes"},
	"de_elfo": {"cabelo": "cabelo_longo_liso", "acc_orelhas": "orelhas_elfo"},
	"df_panda": {"cabelo": "careca", "acc_cabeca": "capuz_panda"},
	"dg_mergulho": {"cabelo": "careca", "roupa": "mergulhador", "acc_rosto": "mascara_snorkel"},
	"dh_astro": {"cabelo": "curto", "roupa": "astronauta", "acc_cabeca": "capacete_esferico"},
	"di_safari": {"cabelo": "curto", "roupa": "safari", "acc_cabeca": "chapeu_safari"},
	"dj_bombeiro": {"cabelo": "careca", "roupa": "bombeiro", "acc_cabeca": "capacete_bombeiro"},
	"dk_abelha": {"cabelo": "careca", "roupa": "abelha"},
	"dl_cientista": {"cabelo": "cabelo_cientista", "roupa": "cientista", "acc_cabeca": "oculos_protecao_testa"},
	"dm_fantasma": {"cabelo": "careca", "roupa": "fantasma", "acc_cabeca": "chapeu_fantasma"},
	"dn_gelo": {"cabelo": "curto", "roupa": "gelo"},
	"do_yukata": {"cabelo": "cabelo_coque_alto_palitos", "roupa": "yukata", "acc_item": "lanterna_papel"},
	"dp_viking": {"cabelo": "careca", "roupa": "viking_peles", "acc_cabeca": "capuz_lobo"},
	"dq_abobora": {"cabelo": "careca", "acc_tronco": "fantasia_abobora", "acc_cabeca": "chapeu_bruxa_laranja"},
	"dr_flores": {"cabelo": "cabelo_preto_franja_flores"},
	"ds_noel": {"cabelo": "careca", "roupa": "noel", "acc_cabeca": "gorro_barba_noel"},
	"dt_noiva": {"cabelo": "careca", "roupa": "noiva", "acc_cabeca": "veu_noiva"},
	"du_cabelos": {"cabelo": "cabelo_rosa_topete"},
	"dv_neon": {"cabelo": "careca", "roupa": "cauboi_neon", "acc_cabeca": "chapeu_cauboi_neon"},
	"dw_esqui": {"cabelo": "careca", "roupa": "esquiador", "acc_cabeca": "gorro_esqui_oculos"},
	"dx_surf": {"cabelo": "curto", "roupa": "surfista", "acc_costas": "prancha_surf"},
	"dy_basq": {"cabelo": "curto", "roupa": "basquete", "acc_pes": "tenis_alto_laranja"},
	"dz_flam": {"cabelo": "cabelo_coque_alto_palitos", "roupa": "flamenco", "acc_item": "leque_vermelho"},
	"ea_sari": {"cabelo": "cabelo_longo_liso", "roupa": "sari"},
	"eb_karate": {"cabelo": "careca", "roupa": "karate", "acc_cabeca": "faixa_karate"},
	"ec_hanbok": {"cabelo": "cabelo_coque_rede", "roupa": "hanbok"},
	"ed_egito": {"cabelo": "careca", "roupa": "egipcio", "acc_cabeca": "nemes_farao", "acc_pescoco": "colar_egipcio"},
	"ee_mexico": {"cabelo": "cabelo_crespo_curto", "acc_cabeca": "sombrero_colorido", "acc_tronco": "poncho_arco_iris"},
	"ef_astro": {"cabelo": "careca", "roupa": "astronauta_retro", "acc_cabeca": "capacete_esferico"},
	"eg_peruca": {"cabelo": "careca", "acc_peruca": "peruca_rosa_azul"},
	"eh_kilt": {"cabelo": "cabelo_undercut_topete", "roupa": "kilt", "acc_costas": "gaita_de_fole"},
	"ei_toga": {"cabelo": "careca", "roupa": "toga", "acc_cabeca": "coroa_louros_dourada", "acc_pes": "sandalias_gladiador"},
	"ej_quiton": {"cabelo": "curto", "roupa": "quiton"},
	"ek_futebol": {"cabelo": "curto", "roupa": "futebol"},
	"el_dread": {"cabelo": "careca", "acc_peruca": "peruca_dreads_coloridos", "roupa": "hiphop", "acc_cabeca": "bone_aba_reta"},
	"em_sailor": {"cabelo": "cabelo_duas_trancas_curtas", "roupa": "sailor"},
	"en_punk": {"cabelo": "cabelo_mohawk_punk", "roupa": "punk"},
	"eo_sam": {"cabelo": "cabelo_coque_samurai", "roupa": "samurai_fem"},
	"ep_lolita": {"cabelo": "cabelo_longo_liso", "roupa": "lolita", "acc_cabeca": "laco_gotico"},
	"eq_steam": {"cabelo": "curto", "roupa": "steampunk", "acc_cabeca": "goggles_steampunk"},
	"er_mago": {"cabelo": "careca", "roupa": "mago_sombrio"},
	"es_druida": {"cabelo": "cabelo_longo_ondulado_flores", "roupa": "druida", "acc_cabeca": "coroa_galhos"},
	"et_sereia": {"cabelo": "cabelo_menta_rabo_baixo", "roupa": "pirata_sereia"},
	"eu_leao": {"cabelo": "careca", "roupa": "leao"},
	"ev_coelha": {"cabelo": "careca", "roupa": "coelha_pascoa"},
	"ew_robo": {"cabelo": "careca", "roupa": "robo_retro"},
	"ex_esq": {"cabelo": "careca", "roupa": "esqueleto"},
	"ey_mumia": {"cabelo": "careca", "roupa": "mumia", "acc_cabeca": "ataduras_cabeca"},
	"ez_rei": {"cabelo": "careca", "acc_cabeca": "coroa_coral", "acc_costas": "manto_ondas"},
	"fa_cabelos": {"cabelo": "cabelo_chonmage", "acc_rosto": "barba_curta"},
	"fb_odango": {"cabelo": "cabelo_odango"},
	"fc_barroca": {"cabelo": "careca", "acc_peruca": "peruca_barroca"},
	"fd_mec": {"cabelo": "careca", "roupa": "mecanico_espacial", "acc_cabeca": "capacete_mecanico"},
	"fe_avia": {"cabelo": "careca", "roupa": "aviador", "acc_cabeca": "capacete_aviador"},
	"ff_jard": {"cabelo": "curto", "acc_cabeca": "chapeu_jardineiro", "acc_tronco": "avental_jardineiro", "acc_maos": "luvas_jardim"},
	"fg_pintor": {"cabelo": "careca", "roupa": "pintor", "acc_cabeca": "boina_bordo", "acc_item": "paleta_tinta"},
	"fh_cart": {"cabelo": "curto", "acc_cabeca": "bone_carteiro", "acc_tronco": "bolsa_carteiro"},
	"fi_garcom": {"cabelo": "curto", "roupa": "garcom"},
	"fj_camin": {"cabelo": "careca", "roupa": "caminhoneiro", "acc_cabeca": "bone_caminhoneiro"},
	"fk_rock": {"cabelo": "cabelo_curto_volumoso", "roupa": "rockstar", "acc_costas": "guitarra_costas", "acc_cabeca": "oculos_escuros_grandes"},
	"fl_baile": {"cabelo": "cabelo_longo_liso", "roupa": "baile_azul", "acc_cabeca": "tiara_baile"},
	"fm_princ": {"cabelo": "cabelo_rabo_lateral", "roupa": "princesa_guerreira", "acc_costas": "capa_princesa"},
	"fn_elfo": {"cabelo": "cabelo_longo_liso", "roupa": "rei_elfo", "acc_cabeca": "coroa_elfica"},
	"fo_musgo": {"cabelo": "careca", "acc_cabeca": "chapeu_cogumelo", "acc_costas": "manto_musgo"},
	"fp_espectral": {"cabelo": "careca", "roupa": "samurai_espectral", "acc_cabeca": "kabuto_espectral"},
	"fq_sushi": {"cabelo": "careca", "roupa": "sushi", "acc_cabeca": "chapeu_sushi"},
	"fr_fada": {"cabelo": "cabelo_ruivo_ondulado_trancas", "roupa": "fada", "acc_costas": "asas_fada_translucidas", "acc_pernas": "tornozeleira_flores"},
	"fs_mecha": {"cabelo": "cabelo_assimetrico_mecha"},
	"ft_louro": {"cabelo": "cabelo_louro_curto_ondulado"},
	"fu_cacador": {"cabelo": "careca", "roupa": "cacador", "acc_cabeca": "chapeu_aventureiro", "acc_costas": "mochila_aventura", "acc_cintura": "chicote_cinto"},
	"fv_detetive": {"cabelo": "careca", "roupa": "detetive", "acc_cabeca": "fedora_detetive", "acc_item": "lupa_detetive"},
	"fw_resgate": {"cabelo": "careca", "roupa": "bombeiro_resgate", "acc_cabeca": "capacete_resgate"},
	"fx_cirurgiao": {"cabelo": "careca", "roupa": "cirurgiao", "acc_cabeca": "touca_cirurgica", "acc_rosto": "mascara_cirurgica"},
	"fy_agente": {"cabelo": "curto", "roupa": "agente", "acc_rosto": "oculos_fone_agente"},
	"fz_caca": {"cabelo": "curto", "roupa": "cacafantasma", "acc_costas": "mochila_protons"},
	"ga_polar": {"cabelo": "careca", "roupa": "polar", "acc_cabeca": "chapeu_polar"},
	"gb_pneve": {"cabelo": "careca", "roupa": "pirata_neve", "acc_cabeca": "chapeu_pirata_neve"},
	"c_oni": {"cabelo": "cabelo_afro_volumoso", "acc_cabeca": "chifres_oni_par", "acc_rosto": "tapa_olho", "acc_costas": "espada_larga_cerimonial", "acc_cauda": "cauda_raposa"},
	"d_raposa": {"acc_cabeca": "orelhas_gato_raposa", "acc_costas": "asas_pequenas", "acc_cauda": "cauda_raposa", "cabelo": "careca"},
	"e_unicornio": {"cabelo": "curto", "acc_cabeca": "chifre_unico"},
}


func _init() -> void:
	executar.call_deferred()


func executar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	for nome: String in CASOS:
		for tipo in ["masculino"]:
			var vp := SubViewport.new()
			vp.size = Vector2i(560, 760)
			vp.own_world_3d = true
			vp.transparent_bg = false
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var env := WorldEnvironment.new()
			env.environment = Environment.new()
			env.environment.background_mode = Environment.BG_COLOR
			env.environment.background_color = Color(0.82, 0.84, 0.88)
			env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
			vp.add_child(env)
			var luz := DirectionalLight3D.new()
			luz.rotation_degrees = Vector3(-35, -30, 0)
			vp.add_child(luz)
			var corpo: Node3D = Corpo.construir(tipo, "medio", CASOS[nome])["node"]
			vp.add_child(corpo)
			for giro in [0, 180]:
				corpo.rotation_degrees.y = giro
				var cam := Camera3D.new()
				vp.add_child(cam)
				cam.position = Vector3(0, 1.05, -4.6)
				cam.look_at(Vector3(0, 0.98, 0))
				cam.current = true
				cam.fov = 38
				for i in 4:
					await process_frame
				vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA) + "%s_%d.png" % [nome, giro])
				cam.queue_free()
			vp.queue_free()
	quit()
