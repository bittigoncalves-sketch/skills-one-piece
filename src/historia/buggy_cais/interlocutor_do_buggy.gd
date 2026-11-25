class_name InterlocutorDoBuggy
extends Node
# Faz o Buggy "parecer um NPC" para a `JanelaDeLoja` (ela só pede `loja()` e `nome()`).
var _loja := preload("res://src/historia/buggy_cais/loja_do_buggy.gd").new()


func _init(prog: ProgressaoDoPersonagem = null) -> void:
	_loja.progressao = prog


func loja() -> LojaDeNpc:
	return _loja


func nome() -> String:
	return "Buggy"
