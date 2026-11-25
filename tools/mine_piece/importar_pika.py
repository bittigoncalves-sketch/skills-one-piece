#!/usr/bin/env python3
"""Assets da Pika Pika (Mine Piece v14): partículas de luz, sons, a onda de impacto
(EntityImpactWave: geo rubble + haki_yellow), poses e a espada Ama no Murakumo (modelo de
item Java → GLB, pega na origem e lâmina em +Y, como a EspadaDaHistoria espera).
Arte do mod fica fora do git."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from geo_para_glb import converter, FONTE, Gltf, Malha, elementos_java, modelo_de_item
from importar_combate import clipe_bedrock

RAIZ = Path(__file__).resolve().parents[2]
ORIGEM = Path(FONTE) / "assets/minepiece"
DESTINO = RAIZ / "assets/mine_piece/frutas/pika"
FONTE_ARTE = RAIZ / "art_src/mine_piece/frutas/pika"
PARTICULAS = {"particle_light_small": 5, "particle_light_large": 5}
# Evento do mod → arquivo (sounds.json): flame_explode toca fire1, punch toca punch_hit1.
SONS = {"laser_beam": "laser_beam", "flame_explode": "fire1", "high_speed_movement": "high_speed_movement",
        "punch": "punch_hit1", "frame_set": "frame_set"}
# PlayAnimationPlayerProcedure: -19/0 right_arm_front, -19/1 right_leg_front, -4/0 both_arm_front,
# -6/0 kick_right|left, -21/0 invisibility, -24/0 yasakani_no_magatama.
POSES = ["right_arm_front", "right_leg_front", "both_arm_front", "kick_right", "kick_left",
         "invisibility", "yasakani_no_magatama"]
CORTE_DAS_POSES = 3.0


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    FONTE_ARTE.mkdir(parents=True, exist_ok=True)
    manifesto = {"obra": "Mine Piece v14", "autor": "orca", "licenca": "All Rights Reserved",
                 "origem_jar": (Path(FONTE) / "ORIGEM.sha256").read_text(), "arquivos": {}}

    def copiar(relativo):
        src = ORIGEM / relativo
        dst = FONTE_ARTE / relativo
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        manifesto["arquivos"][relativo] = hashlib.sha256(src.read_bytes()).hexdigest()
        return src

    # A onda de impacto do Laser (modos 0 e 2): EntityImpactWave, geo rubble, textura haki_yellow.
    for rel in ("geo/rubble.geo.json", "animations/rubble.animation.json", "textures/entities/haki_yellow.png"):
        copiar(rel)
    converter(FONTE, {"id": "onda_amarela", "classe": "EntityImpactWave", "modelo": {
        "geo": "geo/rubble.geo.json", "animacao": "animations/rubble.animation.json",
        "textura": "textures/entities/haki_yellow.png"}}, str(DESTINO))

    for nome, n in PARTICULAS.items():
        quadros = [Image.open(copiar(f"textures/particle/{nome}_{i}.png")).convert("RGBA") for i in range(1, n + 1)]
        lado = quadros[0].size[0]
        tira = Image.new("RGBA", (lado * n, lado))
        for i, im in enumerate(quadros):
            tira.paste(im.resize((lado, lado), Image.NEAREST), (i * lado, 0))
        tira.save(DESTINO / f"{nome}.png")

    for evento, arquivo in SONS.items():
        shutil.copyfile(copiar(f"sounds/{arquivo}.ogg"), DESTINO / f"{evento}.ogg")

    clipes = {}
    for pose in POSES:
        data = json.loads(copiar(f"player_animation/{pose}.json").read_text())["animations"][pose]
        clipes[pose] = clipe_bedrock(data, fps=60, ate=CORTE_DAS_POSES)
    (DESTINO / "poses.json").write_text(json.dumps(clipes, separators=(",", ":")))

    _espada(copiar)
    (FONTE_ARTE / "ORIGEM.json").write_text(json.dumps(manifesto, ensure_ascii=False, indent=2) + "\n")
    print(f"Pika: onda, {len(PARTICULAS)} partículas, {len(SONS)} sons, {len(clipes)} poses e a espada em {DESTINO}")


def _espada(copiar):
    """AMANO_MURAKUMO: modelo de item com elements (custom/amano_murakumo_sword) e a textura
    animada tex_pikapika_animation (5 quadros de 64 px, 1 tick cada). O GLB leva o quadro 0;
    a tira inteira vai junto para o jogo animar a UV."""
    copiar("models/item/amano_murakumo.json")
    copiar("models/custom/amano_murakumo_sword.json")
    strip = copiar("textures/block/tex_pikapika_animation.png")
    modelo, pngs = modelo_de_item(FONTE, "AMANO_MURAKUMO")
    tira = Image.open(strip).convert("RGBA")
    lado = tira.size[0]
    tira.save(DESTINO / "espada_luz_tira.png")
    quadro0 = FONTE_ARTE / "espada_luz_quadro0.png"
    tira.crop((0, 0, lado, lado)).save(quadro0)
    pngs = {k: str(quadro0) for k in pngs}
    ys = [y for el in modelo["elements"] for y in (el["from"][1], el["to"][1])]
    pega = min(ys) + 2.0   # o pomo fica embaixo: a mão segura 2 px acima dele
    gl = Gltf()
    raiz = gl.no("mp_espada_luz")
    malha = Malha()
    mats = {k: gl.material(v, f"espada_luz_{k}") for k, v in pngs.items()}
    # Em px (elementos_java divide por 16): x/z centrados no bloco do modelo, y a partir da pega.
    elementos_java(malha, mats, modelo, (0, 0, 0), lambda c: (c[0] - 8.0, c[1] - pega, c[2] - 8.0))
    gl.filho(raiz, gl.no("lamina", malha=gl.malha(malha, "lamina")))
    gl.gravar(str(DESTINO / "mp_espada_luz.glb"))
    comprimento = (max(ys) - pega) / 16.0
    (DESTINO / "espada_luz.json").write_text(json.dumps({"ponta_blocos": comprimento, "pega_px": pega}))


if __name__ == "__main__":
    main()
