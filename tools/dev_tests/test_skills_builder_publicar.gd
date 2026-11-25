extends SceneTree
# ============================================================================
#  SKILLS BUILDER — Publicar no jogo e o Kit do Builder (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_skills_builder_publicar.gd
#
#  Pasta de TESTE (`SkillsPublicadas.pasta_forcada`): nunca toca `res://mapas/skills`.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "user://test_skills_publicadas"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_esvaziar()
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()

	var a := _skill("soco_a", "Jogador", "Z")
	var r := SkillsPublicadas.publicar(a)
	_ok("publica: grava %s (%s)" % [r.caminho, str(r.erros)], r.ok and FileAccess.file_exists(PASTA.path_join("soco_a.json")))
	_ok("skill do Jogador entra no kit na tecla dela (Z)", r.tecla == "Z" and r.substituiu == "")
	SkillsPublicadas.recarregar()
	_ok("o kit relido do disco tem Z = soco_a", SkillsPublicadas.dono_da_tecla("Z") == "soco_a"
		and str(SkillsPublicadas.kit().get("Z", {}).get("identificacao", {}).get("id", "")) == "soco_a")

	var b := _skill("soco_b", "Jogador", "Z")
	r = SkillsPublicadas.publicar(b)
	_ok("outra na mesma tecla substitui (substituiu=%s)" % r.substituiu, r.ok and r.substituiu == "soco_a" and SkillsPublicadas.dono_da_tecla("Z") == "soco_b")
	_ok("a substituída continua publicada (arquivo e leitura)", not SkillsPublicadas.skill("soco_a").is_empty())

	a.ativacao.tecla = "X"
	r = SkillsPublicadas.publicar(a)
	_ok("republicar na tecla X move a skill: X = soco_a, Z = soco_b",
		SkillsPublicadas.dono_da_tecla("X") == "soco_a" and SkillsPublicadas.dono_da_tecla("Z") == "soco_b")

	var inimigo := _skill("bafo_inimigo", "Inimigo", "C")
	r = SkillsPublicadas.publicar(inimigo)
	_ok("skill de Inimigo é publicada mas fica fora do kit", r.ok and r.tecla == "" and SkillsPublicadas.dono_da_tecla("C") == "" and not SkillsPublicadas.skill("bafo_inimigo").is_empty())

	a.identificacao.dono = "Chefe"
	r = SkillsPublicadas.publicar(a)
	_ok("virar skill de Chefe tira a skill do kit (X livre)", r.ok and SkillsPublicadas.dono_da_tecla("X") == "")
	_ok("o kit do jogo só tem as do Jogador: %s" % str(SkillsPublicadas.kit().keys()), SkillsPublicadas.kit().keys() == ["Z"])

	var ruim := _skill("ruim", "Jogador", "V")
	ruim.configuracoes.duracao = 999.0
	r = SkillsPublicadas.publicar(ruim)
	_ok("skill inválida é recusada e não grava nada", not r.ok and not FileAccess.file_exists(PASTA.path_join("ruim.json")) and SkillsPublicadas.dono_da_tecla("V") == "")

	_ok("id que tenta sair da pasta não é lido", SkillsPublicadas.skill("../../project").is_empty() and SkillsPublicadas.skill("a/b").is_empty())

	var f := FileAccess.open(PASTA.path_join("kit.json"), FileAccess.WRITE)
	f.store_string("{ isto não é json")
	f.close()
	SkillsPublicadas.recarregar()
	_ok("kit.json corrompido: kit vazio, sem erro de execução", SkillsPublicadas.kit().is_empty())
	r = SkillsPublicadas.publicar(b)
	_ok("e publicar de novo reconstrói o kit (Z = soco_b)", r.ok and SkillsPublicadas.dono_da_tecla("Z") == "soco_b")

	# O botão no Builder.
	root.get_node("GameFlow").start_skills_builder()
	for i in 8:
		await process_frame
	var editor := current_scene
	editor.pasta_skills = "user://test_skills_publicadas_rascunho"
	var botao := editor.find_child("Publicar", true, false) as Button
	_ok("o Builder tem o botão Publicar", botao != null)
	if botao:
		editor.skill = _skill("pelo_botao", "Jogador", "V")
		botao.pressed.emit()
		await process_frame
		var status: Label = editor.get("_status")
		_ok("clicar publica e avisa a tecla (%s)" % status.text, FileAccess.file_exists(PASTA.path_join("pelo_botao.json"))
			and SkillsPublicadas.dono_da_tecla("V") == "pelo_botao" and "tecla V" in status.text)

		# "Quem usa" (06/10/2026): a atribuição mora na skill.
		editor._mostrar_secao("identificacao")
		await process_frame
		editor._editar_dono("Inimigo")
		for i in 3:
			await process_frame
		var lista := editor.find_child("atribuida_a", true, false) as OptionButton
		var ids: Array = []
		if lista:
			for i in lista.item_count:
				ids.append(str(lista.get_item_metadata(i)))
		_ok("Usuário Inimigo: lista os inimigos da loja (%d; tem pirate_captain e boneco_de_duelo)" % ids.size(),
			lista != null and "pirate_captain" in ids and "boneco_de_duelo" in ids)
		if lista:
			lista.select(ids.find("pirate_captain"))
			lista.item_selected.emit(ids.find("pirate_captain"))
			await process_frame
		_ok("escolher na lista grava atribuida_a = pirate_captain", str(editor.skill.identificacao.get("atribuida_a", "")) == "pirate_captain")
		editor._editar_dono("Animal")
		for i in 3:
			await process_frame
		_ok("trocar para Animal limpa o inimigo escolhido", str(editor.skill.identificacao.get("atribuida_a", "")) == "")
		var aviso := false
		for l in editor.find_children("*", "Label", true, false):
			aviso = aviso or "a IA ainda não usa" in (l as Label).text
		_ok("Animal avisa que a IA ainda não usa", aviso)
		editor._editar_dono("Jogador")
		for i in 3:
			await process_frame
		_ok("Jogador não tem lista: vai para a tecla do kit", editor.find_child("atribuida_a", true, false) == null)

	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	_esvaziar()
	print("\nSKILLS_BUILDER_PUBLICAR %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill(id: String, dono: String, tecla: String) -> Dictionary:
	var s := Dados.novo()
	s.identificacao.id = id
	s.identificacao.nome = id
	s.identificacao.dono = dono
	s.ativacao.tecla = tecla
	return s


func _esvaziar() -> void:
	var abs := ProjectSettings.globalize_path(PASTA)
	var d := DirAccess.open(abs)
	if d:
		for nome in d.get_files():
			d.remove(nome)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
