import re

def replace_in_file(filepath, replacements):
    with open(filepath, 'r') as f:
        content = f.read()
    
    for old, new in replacements:
        if old not in content:
            print(f"Failed to find {old} in {filepath}")
        content = content.replace(old, new)
        
    with open(filepath, 'w') as f:
        f.write(content)

yami_replacements = [
    (
        "var hit_targets := []\n\tvar mesh_inst: MeshInstance3D",
        "var hit_targets: Array[Node3D] = []\n\tvar mesh_inst: MeshInstance3D\n\tvar _cached_targets: Array = []"
    ),
    (
        "\t\tadd_child(mesh_inst)\n\n\tfunc _physics_process",
        "\t\tadd_child(mesh_inst)\n\t\tif get_tree():\n\t\t\t_cached_targets = get_tree().get_nodes_in_group(\"enemy\") + get_tree().get_nodes_in_group(\"player\")\n\n\tfunc _exit_tree() -> void:\n\t\thit_targets.clear()\n\t\t_cached_targets.clear()\n\t\tcaster = null\n\t\tmesh_inst = null\n\n\tfunc _physics_process"
    ),
    (
        "if get_tree():\n\t\t\tfor e in get_tree().get_nodes_in_group(\"enemy\") + get_tree().get_nodes_in_group(\"player\"):",
        "if get_tree():\n\t\t\tfor e in _cached_targets:"
    ),
    (
        "func destroy() -> void:\n\t\tqueue_free()\n",
        "func destroy() -> void:\n\t\tqueue_free()\n\n\tfunc _exit_tree() -> void:\n\t\tcaster = null\n\t\tpool = null\n\t\tif is_instance_valid(zone):\n\t\t\tzone = null\n"
    )
]

bara_replacements = [
    (
        "func _process(delta: float) -> void:",
        "func _exit_tree() -> void:\n\t\tcaster = null\n\n\tfunc _process(delta: float) -> void:"
    )
]

camera_rig_replacements = [
    (
        "func set_current(v: bool) -> void:\n\t_cam.current = v",
        "func set_current(v: bool) -> void:\n\t_cam.current = v\n\nfunc _exit_tree() -> void:\n\t_ombro = null\n\t_spring = null\n\t_cam = null\n"
    )
]

replace_in_file("src/effects/YamiFX.gd", yami_replacements)
replace_in_file("src/effects/BaraFX.gd", bara_replacements)
replace_in_file("src/player/camera_rig.gd", camera_rig_replacements)

print("Patch perf done!")
