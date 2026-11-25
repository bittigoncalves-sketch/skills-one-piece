extends Resource
## Binding editável de uma parte preparada; nenhuma malha de Buggy no código comum.
@export var id: StringName
@export var source_mesh: StringName
@export var bone_name: StringName
@export var remaining_mesh: Mesh
@export var attached_mesh: Mesh
@export var detached_mesh: Mesh

func valid() -> bool:
	return id != &"" and source_mesh != &"" and bone_name != &"" \
		and remaining_mesh != null and attached_mesh != null and detached_mesh != null
