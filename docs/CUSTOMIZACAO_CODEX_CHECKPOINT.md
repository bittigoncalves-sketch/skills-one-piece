# Checkpoint — assets de customização gerados a partir de imagens do Codex

Fluxo: Codex gera PNG (boneco Minecraft cinza, 3 vistas) em `art_src/references/customizacao_codex/` →
Claude modela em Blender headless com `tools/blender/customizacao_codex.py` (`blender -b --python … -- <peca>`) →
GLB em `assets/models/{acessorios,cabelos,roupas}/` → registro em `src/player/aparencia_historia.gd`
(catálogo, `ACESSORIOS_NOVOS`) e `src/player/detalhes_historia.gd` (`ENCAIXE_DE_ACESSORIOS`, `CONJUNTOS`).

Peças feitas (20/11/2026): espada_katana, ombreira_armadura, espada_larga_cerimonial, capa_com_gola, asas_pequenas, chifre_unico,
chifres_oni_par, orelhas_gato_raposa, bandana_faixa, tapa_olho, cauda_raposa (acessórios);
cabelo_coque_samurai, cabelo_longo_liso, cabelo_afro_volumoso (cabelos);
jaqueta_curta, casaco_naval/casaco_capitao (roupas em malha; material "Ouro" = cor fixa).

Validação: `test_personalizacao_historia` 259/259, `test_sobretudo_historia` TUDO CERTO,
fotos no jogo em `art_src/validation/customizacao_codex/` (`tools/dev_tests/captura_customizacao_codex.gd`,
precisa `--display-driver x11`).

Não modelado: `corpo_musculoso/magro_alto/baixo_robusto` (tipo de corpo = escala/proporção do rig inteiro, não peça;
decidir com o dono se vira preset de escala). Encaixes (posição/escala) são estimados — ajustar vendo no jogo.
ombreira_armadura feita (acc_tronco, Chest sem offset).

Lote 2 (em andamento): cachecol_longo_vermelho (acc_pescoco), luvas_couro_garras (acc_maos, nó Hand_*),
botas_altas_fivelas (acc_pes, nó Foot_* com cano). 271/271 em test_personalizacao_historia.
Medidas dos nós do rig: `tools/dev_tests/medir_nos_corpo.gd` (mão: pivô no punho, palma .19×.14×.105, dedos para baixo).
Lote 2 (cont.): chapeu_pirata_tricornio, chapeu_feiticeiro_bruxa (acc_cabeca), cabelo_tranca_lateral, cabelo_rabo_duplo,
cabelo_ruivo_curto_baguncado (cabelos). 287/287 em test_personalizacao_historia; fotos h_/i_/j_ em art_src/validation/customizacao_codex/.
Lote 2 (cont.): fone_ouvido_headset, oculos_aviador_testa (acc_cabeca), bainhas_duas_espadas_cruzadas, mochila_viagem (acc_costas),
colar_pingente (acc_pescoco), bracadeiras_metal (acc_bracos, ForeArm_*). 301/301; fotos k_/l_ em art_src/validation/customizacao_codex/.
Lote 2 (cont.): coroa_louros (acc_cabeca), escudo_redondo_costas (acc_costas), katana_wakizashi_cintura_direita (acc_cintura),
capuz_manto (acc_pescoco), lanterna_mao (acc_item, Hand_R, emissivo). 313/313; fotos m_/n_ em art_src/validation/customizacao_codex/.
Armadilha: `caixa()` assa a posição na malha (origem em 0,0,0) — girar em torno do centro exige `caixa_rot()`.
Lote 2 completo: mascara_oni (acc_rosto). 315/315. Lote 3 pedido ao Codex.
Lote 3 (em andamento): kimono_yukata (roupa kimono), armadura_aco (roupa armadura), capa_chuva_amarela (roupa capa_chuva), cabelo_mohawk_punk. 325/325. Regras de cor por nome de material em DetalhesHistoria._cor_do_material (Obi, Aco, Bronze, Couro, Ouro).
Lote 3 (cont.): mascara_gas_respirador, barba_cheia_bigode, cabelo_coque_alto_palitos, cabelo_bob_chanel_franja, vestido_gala (roupa vestido), camisa_pirata (roupa pirata). 341/341.
Lote 3 (cont.): cauda_dragao_lagarto, tentaculos_bracos_extras, aureola_asas_anjo, asas_morcego_grandes (membrana em 2 cópias: o exportador funde faces idênticas e o Godot descarta a de trás), chapeu_cauboi. 351/351.
Lote 3 (fim): cicatriz_rosto, bone_capitao_naval, cajado_mago_mao (acc_item Hand_R), machado_batalha_costas. Arco/aljava: Codex recusou (filtro de violência). 359/359. Lote 4 pedido.
Lote 4 (em andamento): jaqueta_motoqueiro, terno_blazer, uniforme_escolar (roupas motoqueiro/terno/escolar). 365/365.
Lote 4 (cont.): sueter_trico (roupa sueter), orelhas_coelho, cauda_pompom. 371/371.
Lote 4 (cont.): tiara_joias, chapeu_panama_palha, polainas_arco_iris, joelheiras_couro, cotoveleiras_couro, cinto_ferramentas_bolsas. 383/383.
Lote 4 (cont.): gancho_pirata (acc_maos Hand_L), perna_de_pau (acc_pernas Shin_L), cabelo_box_braids_longas, furisode_laco (roupa furisode), brincos_longos_piercing (acc_orelhas), cabelo_rabo_cavalo_laco, capuz_gato_orelhas. 403/403.
Lote 4 (fim): casaco_gola_felpuda (roupa casaco_pelo), monoculo_corrente, cabelo_finger_waves_curto, boina_francesa, cachecol_curto_vermelho; gancho/perna de pau trocados para o lado DIREITO. 'porte' (musculoso/magro_alto/baixo_robusto) = escala do rig em DetalhesHistoria.aplicar via Catalogo.PORTES (nova página Porte na escolha). 423/423. Lote 5 pedido.
Lote 5 (parcial): capa_mago_estrelas, armadura_ladino, traje_astronauta (+capacete), roupa_chef (+toque), roupao_banho (+toalha), uniforme_marinheiro (+bone), pijama_nuvens (+gorro), macacao_mecanico. Helper vestir() + tabela ROUPAS_LOTE_5 (aparencia_historia.gd). 449/449.
Lote 5 (cont.): fantasia_dinossauro (roupa dino), smoking_capa (+capa_opera), cocar_grande_penas, coroa_rei, manto_arminho, visor_realidade_virtual, asas_fada_translucidas. 465/465.
Lote 5 (fim): barbatana_sereia, pelucia_urso, cabelo_longo_ondulado_flores, cabelo_anime_azul_espetado, cabelo_duas_trancas_curtas. 481/481. Lote 6 pedido.
Lote 6 (parcial): gorro_la_pompom, colete_salva_vidas, casaco_pirata_vermelho (roupa capitao_vermelho), papagaio_ombro (acc_ombro), chapeu_capitao_pirata, armadura_samurai (roupa samurai + kabuto). 497/497.
Lote 6 (cont.): capa_viajante_remendos, hakama_haori, traje_ninja (+mascara_ninja_faixa), roupa_medica, uniforme_marinha_branco, tunica_monge (+colar_contas). Regras de cor novas: Hakama, Cruz, Azul. 513/513.
Lote 6 (cont.): roupa_aventureiro, vestido_verao (+chapeu_palha_verao), cabelo_menta_rabo_baixo, orelhas_lobo, cauda_lobo, chifres_cervo, cabelo_curto_prateado_mecha, coroa_flores, asas_borboleta. 537/537.
Lote 6 (fim): cinto_bussola_mapas, aureola_neon (brilha), cabelo_longo_camadas. 545/545. Lote 7 pedido.
Lote 7 (parcial): tenis_chunky_colorido, botas_cauboi_esporas, sandalias_gladiador (acc_pes), luvas_boxe_vermelhas (acc_maos), tee_estrela_shorts (roupa tee_estrela), elmo_viking_barba. 557/557.
Lote 7 (cont.): colar_dentes, braceletes_dentes, bailarina_tule (roupa bailarina), jaqueta_jeans, jeans_rasgado_regata, capa_super_heroi, pintura_facial_listras. 571/571.
Lote 7 (cont.): tatuagem_braco (acc_tatuagem), mascara_domino, cabelo_curto_volumoso, elmo_cavaleiro_plumas, chapeu_mago_azul, asas_dragao_pequenas. 587/587.
Lote 7 (fim): orelhas_cachorro, coleira_couro, tiara_gelo, capa_neve, mascara_coruja. 597/597. Lote 8 pedido.
Lote 8 (parcial): presas_vampiro, capa_vampiro, chifres_diabinho, cauda_diabo, peruca_arco_iris (acc_peruca: cores próprias), cabelo_afro_puff_duplo, cabelo_cacheado_lenco, cabelo_ruivo_cacheado. 621/621.
Lote 8 (cont.): cabelo_cornrows, elfico_arqueiro, oficial_vermelho, bardo (+chapeu_bardo, alaude_costas), kamishimo, sacerdote. 639/639.
Lote 8 (cont.): piloto_corrida (+capacete), enfermagem_antiga (+touca), lenhador, junina (+chapeu_junino), gato_preto, asas_anjo_grandes. 657/657.
Lote 8 (fim): orelhas_elfo, capuz_panda. 661/661. Total: ~170 peças/conjuntos modelados a partir de ~160 imagens do Codex; PNGs em art_src/references/customizacao_codex/, fotos em art_src/validation/customizacao_codex/. Para RETOMAR: ler este checkpoint; ver 'ls art_src/references/customizacao_codex' contra PECAS em tools/blender/customizacao_codex.py; padrão por peça = função no script + OPCOES (aparencia_historia.gd) + ENCAIXE/CONJUNTOS (detalhes_historia.gd) + caso em captura_customizacao_codex.gd; rodar test_personalizacao_historia e test_sobretudo_historia.
Lote 9 (parcial): mergulhador (+mascara_snorkel), capacete_esferico, safari (+chapeu_safari), bombeiro (+capacete_bombeiro), abelha, cientista (+cabelo_cientista, oculos_protecao_testa). 685/685.
Lote 9 (cont.): fantasma_pirata (+chapeu_fantasma), armadura_cristal (roupa gelo), yukata_fogos (+lanterna_papel), viking_peles (+capuz_lobo), abobora (+chapeu_bruxa_laranja), cabelo_preto_franja_flores. 707/707.
Lote 9 (fim): papai_noel (+gorro_barba_noel), noiva (+veu_noiva), cabelo_azul_mechas, cabelo_pixie, cabelo_rosa_topete, cabelo_tranca_coroa. 731/731.
Lote 9 (extra): cauboi_neon (+chapeu_cauboi_neon, brilha). 735/735. Lote 10 pedido.
Lote 10 (parcial): esquiador (+gorro_esqui_oculos), surfista (+prancha_surf), basquete (+tenis_alto_laranja), flamenco (+leque_vermelho), ballet, sari, karate (+faixa_karate). 759/759.
Lote 10 (cont.): hanbok, egipcio (+nemes_farao, colar_egipcio), poncho_arco_iris (+sombrero_colorido), astronauta_retro, cabelo_coque_rede, peruca_rosa_azul, cabelo_crespo_curto (+bandana_listrada). 785/785.
Lote 10 (fim): kilt (+gaita_de_fole), quiton_grego, toga_romana (+coroa_louros_dourada), cabelo_undercut_topete. 799/799. Lote 11 pedido.
Lote 10/11 (parcial): futebol, peruca_dreads_coloridos, samurai_feminina (roupa samurai_fem), sailor, punk, hiphop (+bone_aba_reta). 813/813.
Lote 11 (cont.): lolita (+laco_gotico), steampunk (+goggles_steampunk), mago_sombrio, druida (+coroa_galhos), pirata_sereia, leao, coelha_pascoa, robo_retro. 835/835.
Lote 11 (fim): esqueleto, mumia (+ataduras_cabeca), rei_mares (+coroa_coral, manto_ondas), cabelo_chonmage, barba_curta, peruca_barroca, cabelo_spiky_curto (+piercing_prata), cabelo_odango, cabelo_rabo_lateral. 867/867.
Lote 12 (parcial): mecanico_espacial, aviador, jardineiro (+avental, chapeu, luvas), avental_branco, pintor (+boina, paleta), carteiro (+bone, bolsa).
Lote 12 (cont.): garcom, caminhoneiro (+bone), rockstar (+oculos_escuros_grandes, guitarra_costas), baile_azul (+tiara_baile), princesa_guerreira (+capa_princesa), rei_elfo (+coroa_elfica), bruxa_floresta (manto_musgo, chapeu_cogumelo). 921/921.
Lote 12 (fim): samurai_espectral (+kabuto), chef_sushi (+chapeu), fada_flores (+tornozeleira), cabelo_assimetrico_mecha, cabelo_ruivo_ondulado_trancas, cabelo_louro_curto_ondulado. Falta (se o Codex gerar): cabelo azul turquesa em duas tranças. Roupas fada/samurai_espectral deixam 'transparência' só por cor.
Lote 13 (parcial): cacador_tesouros (+chapeu_aventureiro, mochila_aventura, chicote_cinto), detetive (+fedora, lupa), bombeiro_resgate (+capacete_resgate).
Lote 13 (cont.): cirurgiao (+touca, mascara), agente_secreto (+oculos_fone), cacafantasma (+mochila_protons), explorador_polar (+chapeu_polar), pirata_neve (+chapeu).
Lote 13 (cont.): cirurgiao, agente_secreto, cacafantasma, explorador_polar, pirata_neve (+acessórios). Mochilas em acc_costas. 985/985. SUSPENSO: capturas x11 (deixam a tela cinza; ver memória).
Lote 13 (cont.): pizzaiolo (avental_xadrez, toque), ciclista (+capacete), mawashi_sumo, yoga (+faixa), goleiro (+luvas), cabelo_marias_chiquinhas.
Lote 13 (fim): fazendeiro (+botas_borracha), patinador, dj (+fones, luvas), 4 cabelos + cabelo_duas_trancas_longas (turquesa do lote 12).
Lote 14 (parcial): escoteiro (+chapeu), piloto_comercial (+quepe), formatura (+capelo), confeiteiro (+avental_rosa, touca), pescador, campista (+mochila_camping, lanterna_testa; campista = colete em roupa, sem opção própria ainda).
PAUSA (limite de uso do Claude atingido, 20/11/2026): lote 14 do Codex tem imagens ainda não modeladas: professor, capitão de barco, apicultor, marujo, menestrel, vestido de verão com tiara, e cabelos (castanho topete, cinza vovó). Também: nada commitado; capturas visuais no jogo suspensas (tela cinza). Retomar: comparar ls art_src/references/customizacao_codex com PECAS em tools/blender/customizacao_codex.py.
