class_name YoruMoves
extends RefCounted
## Tempos em segundos; dano final; distâncias em metros. Fonte única de gameplay.
##
## `step` e `advance` são as DUAS formas de o corpo se mover num golpe, e não são
## sinônimos. `step` é a passada que É a técnica (o Passo do Predador fecha
## distância no startup e só então corta). `advance` é acompanhamento: o corpo
## segue a espada durante o corte, e o `acertou` da lâmina interrompe o resto —
## quem erra é levado pela inércia, quem acerta para onde conectou.
const MOVES := {
	"M1_1": {"name":"Corte horizontal", "startup":0.32,"active":0.14,"recovery":0.30,"damage":64.0,"kb":6.0,"cooldown":0.0,"blade":true,"advance":1.4},
	"M1_2": {"name":"Corte vertical", "startup":0.40,"active":0.16,"recovery":0.44,"damage":96.0,"kb":8.0,"cooldown":0.0,"blade":true,"advance":1.8},
	"Z": {"name":"Corte do Horizonte", "startup":0.42,"active":0.10,"recovery":0.38,"damage":110.0,"kb":7.0,"cooldown":5.0,"range":16.0,"speed":22.0,"width":1.5,"ground":false},
	"X": {"name":"Passo do Predador", "startup":0.20,"active":0.20,"recovery":0.40,"damage":88.0,"kb":7.0,"cooldown":6.0,"blade":true,"step":2.8},
	"C": {"name":"Guarda da Cruz", "startup":0.06,"active":0.54,"recovery":0.28,"damage":0.0,"kb":0.0,"cooldown":7.0},
	"V": {"name":"Ruptura da Noite", "startup":0.90,"active":0.10,"recovery":0.65,"damage":180.0,"kb":10.0,"cooldown":14.0,"range":18.0,"speed":14.0,"width":2.1,"ground":true},
}
static func get_move(id: String) -> Dictionary:
	return MOVES.get(id, {})
static func duration(id: String) -> float:
	var m := get_move(id)
	return float(m.get("startup",0.0)) + float(m.get("active",0.0)) + float(m.get("recovery",0.0))
