extends SceneTree
# ============================================================================
#  INIMIGOS USANDO SKILLS DO BUILDER (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_inimigos_com_skills.gd
#
#  Decisões do dono: a atribuição mora na skill (Usuário Inimigo + "Quem usa" = id
#  do modelo da loja); nesta etapa usam os INIMIGOS DO MAPA e o BONECO DE DUELO; o
#  dano no jogador da história é a mesma FRAÇÃO de vida que na arena (÷ 2048).
#  Modo História de verdade, mapa/progresso/skills de TESTE.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://test_inimigos_skills_mapa.json"
const PROGRESSO := "user://test_inimigos_skills.json"
const PASTA := "user://test_inimigos_skills_pasta"
const DANO := 150.0

var _ok_n := 0
var _falhas := 0
var p: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_esvaziar()
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	_publicar("pirata_soco", "pirate_captain", 4.0, 2.0)
	_publicar("boneco_bafo", "boneco_de_duelo", 6.0, 3.0)
	_publicar("de_outro", "modelo_que_nao_esta_no_mapa", 50.0, 0.5)

	var bib := BibliotecaDeModelos.padrao()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var tam := bib.info("pirate_captain")["tamanho"] as Vector3
	mapa["pecas"].append({"id": "pirata", "tipo": "modelo", "modelo": "pirate_captain",
		"posicao": Vector3(0, tam.y * 0.5, -3.0), "rotacao_graus": Vector3.ZERO, "tamanho": tam,
		"cor": Color.WHITE, "material": "liso", "colisao": true})
	var tb := bib.tamanho_padrao("boneco_de_duelo")
	mapa["pecas"].append({"id": "ninho", "tipo": "modelo", "modelo": "boneco_de_duelo",
		"posicao": Vector3(60, tb.y * 0.5, -3.0), "rotacao_graus": Vector3(0, 180, 0), "tamanho": tb,
		"cor": Color.WHITE, "material": "liso", "colisao": true})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")

	var pirata := current_scene.find_child("pirata", true, false)
	_ok("o inimigo do mapa ganhou as skills do modelo dele",
		pirata != null and pirata.get_node_or_null("UsuarioDeSkills") != null
		and (pirata.get_node("UsuarioDeSkills").get("skills") as Array).size() == 1)

	# Longe (12 m): nada.
	_parar_jogador(Vector3(0, 1.0, 9.0))
	var vida0 := float(p.health)
	for i in 120:
		await physics_frame
	_ok("fora do alcance (12 m > 4 m) o inimigo não usa a skill (vida %.2f → %.2f)" % [vida0, float(p.health)],
		is_equal_approx(float(p.health), vida0) and _executores_de(pirata) == 0)

	# Perto (3 m): usa, e tira a fração de vida.
	_parar_jogador(Vector3(0, 1.0, 0.0))
	vida0 = float(p.health)
	var esperado := DANO * float(p.max_health) / 2048.0
	var lancou := false
	for i in 30:
		await physics_frame
		lancou = lancou or _executores_de(pirata) > 0
	_ok("no alcance o inimigo vira e usa a skill", lancou)
	var tirou := vida0 - float(p.health)
	_ok("dano no jogador da história = 150 × %.0f / 2048 = %.2f (tirou %.2f)" % [p.max_health, esperado, tirou],
		absf(tirou - esperado) < 0.02)
	# Recarga de 2 s: em 1,5 s não há segundo uso; depois de 2,2 s, há.
	vida0 = float(p.health)
	for i in 20:
		await physics_frame          # a skill de 0,3 s acaba
	var lances := 0
	for i in 70:
		await physics_frame
		lances = maxi(lances, _executores_de(pirata))
	# A vida pode SUBIR (regeneração); o que a recarga proíbe é outro lançamento.
	_ok("respeita a recarga: nenhum lançamento nos 1,5 s seguintes (%d; vida %.2f → %.2f)" % [lances, vida0, float(p.health)],
		lances == 0 and float(p.health) >= vida0 - 0.01)
	for i in 60:
		await physics_frame
	_ok("e usa de novo quando a recarga zera (vida %.2f → %.2f)" % [vida0, float(p.health)], float(p.health) < vida0 - 0.5 * esperado)

	# O boneco do ninho.
	var ninho := current_scene.find_child("Ninho_ninho", true, false)
	var boneco: Node = ninho.get("boneco") if ninho != null else null
	_ok("o boneco do ninho ganhou a skill do modelo dele (boneco_de_duelo)",
		boneco != null and boneco.get_node_or_null("UsuarioDeSkills") != null)
	if boneco != null:
		_parar_jogador(Vector3(60, 1.0, 1.0))
		var viu := false
		var ocupado_no_lance := false
		var antes := 0
		for i in 360:
			await physics_frame
			var n := _executores_de(boneco)
			if n > antes:
				viu = true
				var cc: Variant = boneco.get("combate_direcional")
				ocupado_no_lance = ocupado_no_lance or (cc != null and (cc as Object).call("ocupado") and _lancado_agora(boneco))
			antes = n
		_ok("o boneco usa a skill com o jogador perto", viu)
		_ok("e só com o corpo a corpo neutro (intercala, não sobrepõe)", not ocupado_no_lance)

	_ok("skill atribuída a outro modelo não é usada por ninguém",
		current_scene.find_children("SkillBuilder_de_outro", "", true, false).is_empty())

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	_esvaziar()
	print("\nINIMIGOS_COM_SKILLS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _executores_de(quem: Node) -> int:
	var n := 0
	for e in current_scene.find_children("SkillBuilder_*", "", true, false):
		if e.get("ator") == quem:
			n += 1
	return n


## O executor mais novo do boneco nasceu NESTE quadro (tempo de skill ~0).
func _lancado_agora(quem: Node) -> bool:
	for e in current_scene.find_children("SkillBuilder_*", "", true, false):
		if e.get("ator") == quem and float(e.get("_t")) <= 1.0 / 30.0:
			return true
	return false


func _parar_jogador(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.health = p.max_health


func _publicar(id: String, quem: String, alcance: float, recarga: float) -> void:
	var s := Dados.novo()
	s.identificacao.id = id
	s.identificacao.nome = id
	s.identificacao.dono = "Inimigo"
	s.identificacao.atribuida_a = quem
	s.condicoes.exige_alvo = false
	s.dano.valor = DANO
	s.dano.empurrao = 0.0
	s.dano.atordoamento = 0.0
	s.configuracoes.alcance = alcance
	s.configuracoes.recarga = recarga
	s.eventos = [{"id": "hb", "tipo": "hitbox", "inicio": 0.0, "duracao": 0.3, "habilitado": true,
		"parametros": {"z": -2.5, "raio": 1.5}}]
	s.configuracoes.duracao = 0.3
	var r := SkillsPublicadas.publicar(s)
	if not r.ok:
		push_error("publicar %s: %s" % [id, str(r.erros)])


func _esvaziar() -> void:
	var d := DirAccess.open(ProjectSettings.globalize_path(PASTA))
	if d:
		for nome in d.get_files():
			d.remove(nome)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
