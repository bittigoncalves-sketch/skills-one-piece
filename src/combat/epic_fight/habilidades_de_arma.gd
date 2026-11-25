class_name HabilidadesDeArma
extends RefCounted
## HABILIDADES INATAS DAS ARMAS DO EPIC FIGHT (12/11/2026). Mapeamento EXATO do mod (`EpicFightMovesets.addInnateSkill`, decompilado): cada moveset de arma tem a sua habilidade.
##   montante 2H → Steel Whirlwind · espada longa 2H → Liechtenauer · adaga 1H → Eviscerate · adaga DUAL → Blade Rush · lança 2H → Grasping Spire ·
##   espada(bokken) 1H → Sweeping Edge · tachi 2H → Rushing Tempo · uchigatana → Battojutsu.
## RECURSO (`Skill.Resource.WEAPON_CHARGE` + `ServerPlayerPatch`: `container.getResource() + event.getModifiedDamage()`): a habilidade tem uma BARRA que vai de 0 até o seu
## `consumption` (`habilidades.json`: Steel Whirlwind 60, Liechtenauer 40…); CADA GOLPE QUE ACERTA soma o dano do golpe (o do item no mod) à barra; cheia, a habilidade pode ser usada e zera.
## Aqui: tecla R. Dois tipos — `golpe` (um golpe do mod no encaixe `HABILIDADE` do estilo, com o clipe da habilidade) e `modo` (Liechtenauer: por `max_duration` 240 ticks = 12 s a cadeia
## do clique passa a ser a `longsword_liechtenauer_auto1..3`).
## Habilidades de VÁRIAS partes (Eviscerate first→second, Blade Rush 1→2→3, Rushing Tempo 1→2→3, Grasping Spire first→second) encadeiam as partes que TÊM clipe extraído: a parte seguinte começa quando a anterior ACERTOU (`EspadaDaHistoria`).
## Battojutsu usa `battojutsu_dash` (avanço de ~10 m) quando usada correndo, como no mod. Steel Whirlwind é CARREGADA como no mod (`SteelWhirlwindSkill`: segura R; mínimo 6 ticks = 0,3 s, máximo 30 ticks = 1,5 s; andar fica 80 % mais lento no máximo da carga; soltar executa). Declarado: a carga não escala o dano/rotações (o mod passa `CHARGING_TICKS` à animação) e o `first` da Grasping Spire não tem clipe no pacote extraído.
const TABELA := {
	"greatsword|2h": {"id": "steel_whirlwind", "nome": "Steel Whirlwind", "tipo": "golpe", "clipes": ["skill/steel_whirlwind"], "clipe_carga": "steel_whirlwind_charging", "carga_min": 0.3, "carga_max": 1.5},
	"longsword|2h": {"id": "liechtenauer", "nome": "Liechtenauer", "tipo": "modo", "variante": "liechtenauer", "duracao": 12.0},
	"dagger|1h": {"id": "eviscerate", "nome": "Eviscerate", "tipo": "golpe", "clipes": ["skill/eviscerate_first", "skill/eviscerate_second"]},
	"dagger|dual": {"id": "blade_rush", "nome": "Blade Rush", "tipo": "golpe", "clipes": ["skill/blade_rush_combo1", "skill/blade_rush_combo2", "skill/blade_rush_combo3"]},
	"spear|2h": {"id": "grasping_spire", "nome": "Grasping Spire", "tipo": "golpe", "clipes": ["skill/grasping_spire_first", "skill/grasping_spire_second"]},
	"sword|1h": {"id": "sweeping_edge", "nome": "Sweeping Edge", "tipo": "golpe", "clipes": ["skill/sweeping_edge"]},
	"tachi|2h": {"id": "rushing_tempo", "nome": "Rushing Tempo", "tipo": "golpe", "clipes": ["skill/rushing_tempo1", "skill/rushing_tempo2", "skill/rushing_tempo3"]},
	"uchigatana|2h": {"id": "battojutsu", "nome": "Battojutsu", "tipo": "golpe", "clipes": ["skill/battojutsu"], "clipe_corrida": "skill/battojutsu_dash"},
}


## Empunhadura padrão da categoria com a mão livre (`DEFAULT_1H/2H_WIELD_STYLE`): adaga e espada a uma mão; o resto a duas.
static func empunhadura(categoria: String, dual: bool) -> String:
	if dual:
		return "dual"
	return "1h" if categoria in ["dagger", "sword"] else "2h"


## A habilidade inata da arma (+ `consumo` = o máximo da barra, de `habilidades.json`), ou {} se a categoria/empunhadura não tem (ex. espada longa a 1 mão = Sharp Stab, não ligada).
static func para(categoria: String, dual := false) -> Dictionary:
	var h: Variant = TABELA.get("%s|%s" % [categoria, empunhadura(categoria, dual)])
	if h == null:
		return {}
	var r: Dictionary = (h as Dictionary).duplicate()
	r["consumo"] = float(EpicFightDados.habilidade(str(r.id)).get("consumption", 30.0))
	return r
