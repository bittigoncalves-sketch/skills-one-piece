"""Converte FBX do Mixamo -> glTF binário (.glb) usando o Blender headless.

Motivo: o importador FBX do Godot (ufbx) lê só 1 chave por osso de membro nos
FBX do Mixamo — as curvas existem no arquivo, mas se perdem no import. O Godot
lê glTF de forma confiável, então o Blender vira a ponte.

Uso (um arquivo ou uma pasta inteira):
  blender --background --python tools/fbx_to_glb.py -- <entrada.fbx> <saida.glb>
  blender --background --python tools/fbx_to_glb.py -- <pasta_fbx> <pasta_glb>
"""
import os
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]

# Diagnóstico: quantas curvas de animação chegaram de fato?
# O Blender 4.4+ trocou Action.fcurves por layers/strips/channelbags (slots).
def contar_fcurves(act):
    if hasattr(act, "fcurves"):
        return len(act.fcurves)
    n = 0
    for layer in getattr(act, "layers", []):
        for strip in getattr(layer, "strips", []):
            for cb in getattr(strip, "channelbags", []):
                n += len(cb.fcurves)
    return n


def converter(entrada, saida):
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # O Blender 5.x trocou o operador de import de FBX; aceita os dois nomes.
    if hasattr(bpy.ops.wm, "fbx_import"):
        bpy.ops.wm.fbx_import(filepath=entrada)
    else:
        bpy.ops.import_scene.fbx(filepath=entrada)

    total = sum(contar_fcurves(a) for a in bpy.data.actions)

    bpy.ops.export_scene.gltf(
        filepath=saida,
        export_format="GLB",
        export_animations=True,
        export_force_sampling=True,   # amostra as curvas -> nada de chave sumida
        export_bake_animation=True,
        export_anim_single_armature=True,
        export_skins=True,
    )
    print(f"[ok] {os.path.basename(saida)}  fcurves={total}")
    return total > 0


if os.path.isdir(src):
    os.makedirs(dst, exist_ok=True)
    ok = falha = 0
    for nome in sorted(os.listdir(src)):
        if not nome.lower().endswith(".fbx"):
            continue
        alvo = os.path.join(dst, os.path.splitext(nome)[0] + ".glb")
        try:
            if converter(os.path.join(src, nome), alvo):
                ok += 1
            else:
                falha += 1
                print(f"[VAZIO] {nome} — nenhuma fcurve")
        except Exception as e:  # noqa: BLE001
            falha += 1
            print(f"[ERRO] {nome}: {e}")
    print(f"[FINAL] ok={ok} falha={falha}")
else:
    converter(src, dst)
