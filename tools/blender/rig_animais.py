"""RIG DOS ANIMAIS — esqueleto, pesos e as 6 animações (01/10/2026).

    ~/opt/blender/blender -b --python tools/blender/rig_animais.py -- cow [horse ...] [--so-esqueleto]
    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/atualizar_animais_riggados.gd

  --so-esqueleto  só ossos e pesos (foto de conferência), sem animar
O Blender só escreve em art_src/; quem põe na loja é a ferramenta do Godot (mede a caixa
como o jogo mede e grava o `golpe_em` na ficha).

Decisão do dono (docs/ANIMACOES_ANIMAIS_CHECKPOINT.md): os animais de malha única ganham
RIG DE VERDADE — esqueleto, pesos e as animações idle, walk, run, damage, attack e death
por tipo de corpo, adaptadas a cada espécie (perfil abaixo).

Sempre parte do ORIGINAL (art_src/animais/originais/<id>.glb; copiado da loja na primeira
vez): rodar de novo refaz do zero. Saídas:
  art_src/animais/rig/<id>.blend e <id>.glb    fonte e exportado
  art_src/validation/animais_rig/<id>_*.png    ossos/pesos e folhas de quadros por clipe
  art_src/animais/rig/manifesto.json           espécie -> clipes, velocidades, ossos

Velocidades: o passo do clipe casa com a ficha da espécie na loja (passeio e corrida,
na escala do jogo): o jogo toca andar a `rapidez / passeio` e correr a `rapidez / corrida`.
"""
import json
import os
import shutil
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
RAIZ = os.path.normpath(os.path.join(AQUI, "..", ".."))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from animais_rig import geometria, quadrupede, ave, voador, fotos, movimento  # noqa: E402

LOJA = os.path.join(RAIZ, "mapas", "modelos")
ORIGINAIS = os.path.join(RAIZ, "art_src", "animais", "originais")
SAIDA = os.path.join(RAIZ, "art_src", "animais", "rig")
FOTOS = os.path.join(RAIZ, "art_src", "validation", "animais_rig")

# Perfil por espécie. cauda: "ponta" (f, z) em fração da caixa (f 0 = traseira, 1 = focinho)
# + "eixo" de onde seguir (z+ pendurada, z- em pé, f+ horizontal) ou "pontos" à mão.
# ataque: cabecada | mordida | patada | empinar | bicada (ave) | bote (saltador).
# parado: pastar | farejar. corpo: quadrupede (padrão) | ave | saltador | rastejante | voador.
# Ajustes: pescoco/cabeca (fração do comprimento: base do pescoço à frente da cernelha;
# tamanho da cabeça), cabeca_acima (0-1 ao longo do pescoço: daí para a frente, tudo acima
# da junta da cabeça é cabeça — galhada), casco (False = patas), abana (rabo de cão),
# empina (graus, ataque "empinar").
PERFIS = {
    "cow": {"cauda": {"ponta": (0.02, 0.18), "eixo": "z+"}, "ataque": "cabecada", "parado": "pastar"},
    "horse": {"cauda": {"ponta": (0.03, 0.40), "eixo": "z+"}, "ataque": "empinar", "parado": "pastar", "cabeca": 0.22},
    "bizon": {"cauda": {"ponta": (0.0, 0.42), "eixo": "z+"}, "ataque": "cabecada", "parado": "pastar", "pescoco": 0.12},
    "sheep": {"cauda": None, "ataque": "cabecada", "parado": "pastar", "pescoco": 0.12, "cabeca": 0.18},
    "deer": {"cauda": {"ponta": (0.01, 0.72), "eixo": "z-"}, "ataque": "cabecada", "parado": "pastar"},
    "deer-blt2gjhppt": {"cauda": None, "ataque": "cabecada", "parado": "pastar", "cabeca_acima": -0.6},
    "beagle": {"cauda": {"ponta": (0.08, 0.99), "eixo": "z-"}, "ataque": "mordida", "parado": "farejar", "casco": False, "abana": True},
    "cat": {"cauda": {"ponta": (0.06, 0.99), "eixo": "z-"}, "ataque": "patada", "parado": "farejar", "casco": False},
    "dog": {"cauda": {"pontos": [(0.10, 0.66), (0.09, 0.79), (0.18, 0.87), (0.27, 0.78)], "raio": 0.08},
            "ataque": "mordida", "parado": "farejar", "casco": False, "abana": True},
    "dog-9bqpcxoyrk": {"cauda": {"ponta": (0.07, 0.82), "eixo": "z-"}, "ataque": "mordida", "parado": "farejar", "casco": False, "abana": True},
    "dog_final_": {"cauda": {"ponta": (0.03, 0.12), "eixo": "z+"}, "ataque": "mordida", "parado": "farejar", "casco": False, "abana": True},
    "corgi": {"cauda": {"pontos": [(0.116, 0.50), (0.066, 0.265), (0.012, 0.047)], "raio": 0.07},
              "ataque": "mordida", "parado": "farejar", "casco": False, "abana": True},
    "fox": {"cauda": {"pontos": [(0.31, 0.60), (0.20, 0.45), (0.10, 0.31), (0.01, 0.20)], "raio": 0.10},
            "ataque": "mordida", "parado": "farejar", "casco": False},
    "bear": {"cauda": None, "ataque": "empinar", "parado": "farejar", "casco": False, "empina": 30, "cabeca": 0.25},
    # Aves de chão (ave.py): pescoço que sobe, 2 pernas, sem osso de asa.
    "chicken": {"corpo": "ave", "cauda": {"ponta": (0.05, 0.82), "eixo": "z-"}, "ataque": "bicada", "bamboleio": 5},
    "duck": {"corpo": "ave", "cauda": {"pontos": [(0.22, 0.36), (0.10, 0.28), (0.01, 0.21)], "raio": 0.05},
             "ataque": "bicada", "bamboleio": 9},
    "chick": {"corpo": "ave", "cauda": None, "ataque": "bicada", "bamboleio": 6, "cabeca": 0.3},
    # Saltadores: esqueleto de quadrúpede, marcha de SALTO (patas de trás juntas).
    "rabbit": {"corpo": "saltador", "cauda": None, "ataque": "bote", "parado": "farejar", "casco": False, "cabeca": 0.25},
    # Rastejante: esqueleto de quadrúpede, coluna ondulando para os lados.
    "lizard": {"corpo": "rastejante", "cauda": {"pontos": [(0.40, 0.40), (0.25, 0.20), (0.12, 0.10), (0.0, 0.05)], "raio": 0.25},
               "ataque": "mordida", "parado": "farejar", "casco": False, "cabeca": 0.12, "faixa_chao": 0.75},
    # Voadores (voador.py): pose de voo, 2 ossos por asa; clipes idle (planar), fly, damage,
    # attack (mergulho), death.
    "bird_2": {"corpo": "voador", "batida": 0.27},
    "bird-h5izaudltz": {"corpo": "voador", "batida": 0.3},
    "frog": {"corpo": "saltador", "cauda": None, "ataque": "bote", "bote_patas": False, "parado": "farejar", "casco": False, "cabeca": 0.3},
}


def _ficha(id_):
    """Ficha e escala do jogo (tamanho padrão / tamanho do arquivo) lidas da loja."""
    with open(os.path.join(LOJA, "catalogo.json"), encoding="utf-8") as f:
        cat = json.load(f)
    for e in cat["modelos"]:
        if e["id"] == id_:
            k = e["tamanho_padrao"][1] / e["tamanho"][1] if e.get("tamanho_padrao") else 1.0
            return e.get("animal", {}), k
    raise KeyError(id_)


def carregar(id_):
    os.makedirs(ORIGINAIS, exist_ok=True)
    original = os.path.join(ORIGINAIS, id_ + ".glb")
    if not os.path.exists(original):
        shutil.copy2(os.path.join(LOJA, id_ + ".glb"), original)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=original)
    malhas = [o for o in bpy.data.objects if o.type == 'MESH']
    if len(malhas) != 1:
        raise RuntimeError("%s: %d malhas (esperava 1)" % (id_, len(malhas)))
    obj = malhas[0]
    antes, depois = geometria.preparar_malha(obj)
    for o in list(bpy.data.objects):
        if o.type == 'EMPTY':
            bpy.data.objects.remove(o)
    obj.name = id_
    return obj, antes, depois


def fotos_do_rig(id_, obj, arm, m):
    os.makedirs(FOTOS, exist_ok=True)
    cores = fotos.pintar_regioes(obj)
    tubos = fotos.tubos_dos_ossos(arm, m["H"] * 0.008)
    lo, hi = geometria.caixa(obj)
    centro = (lo + hi) * 0.5
    # Quadro 4:3: bicho alto (ave) precisa caber na altura, não só na largura.
    tam = max(hi.x - lo.x, hi.y - lo.y, (hi.z - lo.z) * 4 / 3) * 1.1
    arquivos = []
    for vista in ("lado", "cima", "tres4", "tras"):
        caminho = os.path.join(FOTOS, "_%s_%s.png" % (id_, vista))
        fotos.foto(caminho, centro, tam, vista)
        arquivos.append(caminho)
    fotos.montar_folha(arquivos, os.path.join(FOTOS, id_ + "_ossos.png"), 2, ["lado", "cima", "3/4", "tras"],
                       legenda=sorted(cores.items()))
    bpy.data.objects.remove(tubos)
    obj.data.color_attributes.remove(obj.data.color_attributes["regiao"])


def processar(id_, so_esqueleto):
    perfil = PERFIS[id_]
    obj, antes, depois = carregar(id_)
    corpo = perfil.get("corpo", "quadrupede")
    m = {"ave": ave, "voador": voador}.get(corpo, quadrupede).analisar(obj, perfil)
    rigger = voador if corpo == "voador" else quadrupede
    arm = rigger.montar_esqueleto(m)
    contagem = rigger.pesar(obj, arm, m)
    print("RIG %s: %d -> %d vertices, %d costuras separadas; pesos %s" % (id_, antes, depois, m.get("costuras", 0), json.dumps(contagem)))
    for n, p in m["pernas"].items():
        print("  perna %s topo z=%.2f J=%s K=%s A=%s G=%s" % (n, p.topo.z, _v(p.J), _v(p.K), _v(p.A), _v(p.G)))
    for k in ("R", "C", "S", "Nb", "Hj", "N"):
        if k in m:
            print("  %s=%s" % (k, _v(m[k])))
    if m.get("cauda") and hasattr(m["cauda"], "linha"):
        print("  cauda %s raio %.3f" % (" ".join(_v(p) for p in m["cauda"].linha), m["cauda"].raio))
    for lado, a in m.get("asas", {}).items():
        print("  asa%s ombro %s cotovelo %s ponta %s" % (lado, _v(a["ombro"]), _v(a["cotovelo"]), _v(a["ponta"])))
    fotos_do_rig(id_, obj, arm, m)
    if so_esqueleto:
        return None
    ficha, k = _ficha(id_)
    v_andar = float(ficha.get("passeio", 1.0)) / k
    v_correr = float(ficha.get("corrida", 4.0)) / k
    rig = movimento.Rig(arm, m)
    clipes = movimento.todas(rig, obj, perfil, v_andar, v_correr)
    info = {}
    for nome, (poses, dados) in clipes.items():
        rig.gravar(nome, poses)
        dados = dict(dados)
        dados["duracao"] = round(dados["quadros"] / movimento.FPS, 4)
        if "velocidade" in dados:
            dados["velocidade_jogo"] = round(dados.pop("velocidade") * k, 4)
        info[nome] = dados
        print("  clipe %-6s %s" % (nome, json.dumps(dados)))
    rig.repouso()
    estiramento = medir_estiramento(obj, rig, clipes)
    fotos_dos_clipes(id_, obj, rig, clipes)
    os.makedirs(SAIDA, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SAIDA, id_ + ".blend"))
    exportar(id_, obj, arm)
    return {"clipes": info, "ossos": [b.name for b in arm.data.bones], "escala_jogo": round(k, 5),
            "estiramento_max": estiramento,
            "perfil": {c: v for c, v in perfil.items() if c != "cauda"}}


ESTIRAMENTO_LIMITE = 0.05      # fração do tamanho do bicho (altura; voador: 1/4 da envergadura)


def medir_estiramento(obj, rig, clipes, amostras=8):
    """Pior alongamento de aresta em todos os clipes, em fração da altura do bicho.

    Conta só aresta que MAIS QUE DOBRA (articulação normal estica pouco): peso errado
    aparece como triângulo esticado até o chão (casco preso ao pescoço do bisão: aresta
    de 7,6 cm virou 2 m). Lasca de milímetros que triplica não é defeito à vista. Acima
    de ESTIRAMENTO_LIMITE sai aviso com o clipe e o quadro."""
    me = obj.data
    arestas = [(e.vertices[0], e.vertices[1], max((me.vertices[e.vertices[0]].co - me.vertices[e.vertices[1]].co).length, 1e-6))
               for e in me.edges]
    dg = bpy.context.evaluated_depsgraph_get()
    pior = (0.0, 0.0, "", 0)
    for nome, (poses, _) in clipes.items():
        for j in range(amostras):
            i = round(j * (len(poses) - 1) / (amostras - 1))
            rig.aplicar(poses[i])
            ev = obj.evaluated_get(dg)
            m2 = ev.to_mesh()
            for a, b, l0 in arestas:
                l1 = (m2.vertices[a].co - m2.vertices[b].co).length
                if l1 > 2.0 * l0 and (l1 - l0) / rig.tamanho > pior[0]:
                    pior = ((l1 - l0) / rig.tamanho, l1 / l0, nome, i)
            ev.to_mesh_clear()
    rig.repouso()
    aviso = "  <-- ACIMA DO LIMITE" if pior[0] > ESTIRAMENTO_LIMITE else ""
    print("  ESTIRAMENTO max %.1f %% do tamanho (x%.1f) em %s q%d%s" % (100 * pior[0], pior[1], pior[2], pior[3], aviso))
    return round(pior[0], 4)


def exportar(id_, obj, arm):
    for trilha in arm.animation_data.nla_tracks:
        trilha.mute = False
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    caminho = os.path.join(SAIDA, id_ + ".glb")
    bpy.ops.export_scene.gltf(filepath=caminho, export_format='GLB', use_selection=True,
                              export_animations=True, export_animation_mode='NLA_TRACKS',
                              export_force_sampling=True, export_skins=True, export_yup=True,
                              export_apply=False, export_rest_position_armature=True,
                              export_influence_nb=4)
    return caminho


def fotos_dos_clipes(id_, obj, rig, clipes, quadros=8):
    """Folha: uma linha por clipe, 8 quadros de lado (com chão); a morte também de 3/4."""
    chao = _chao(rig)
    lo, hi = geometria.caixa(obj)
    centro = (lo + hi) * 0.5
    tam = max(hi.y - lo.y, (hi.z - lo.z) * 4 / 3) * 1.35
    centro.z = lo.z + tam * 0.36
    arquivos, rotulos = [], []
    linhas = [(n, "lado") for n in clipes] + [("death", "tres4"), ("attack", "tres4")]
    for nome, vista in linhas:
        poses = clipes[nome][0]
        for j in range(quadros):
            i = round(j * (len(poses) - 1) / (quadros - 1))
            rig.aplicar(poses[i])
            caminho = os.path.join(FOTOS, "_%s_%s_%s_%d.png" % (id_, nome, vista, j))
            fotos.foto(caminho, centro, tam, vista, res=(320, 240), cor='TEXTURE')
            arquivos.append(caminho)
            rotulos.append("%s %s q%d" % (nome, vista, i))
    rig.repouso()
    fotos.montar_folha(arquivos, os.path.join(FOTOS, id_ + "_clipes.png"), quadros, rotulos)
    bpy.data.objects.remove(chao)


def _chao(rig):
    bpy.ops.mesh.primitive_plane_add(size=rig.L * 4, location=(0, 0, rig.z0 - 0.002))
    chao = bpy.context.active_object
    mat = bpy.data.materials.new("chao")
    mat.diffuse_color = (0.45, 0.55, 0.38, 1)
    chao.data.materials.append(mat)
    return chao


def _v(p):
    return "(%.2f,%.2f,%.2f)" % (p.x, p.y, p.z)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    so = "--so-esqueleto" in args
    ids = [a for a in args if not a.startswith("--")] or list(PERFIS)
    caminho_manifesto = os.path.join(SAIDA, "manifesto.json")
    manifesto = {}
    if os.path.exists(caminho_manifesto):
        with open(caminho_manifesto, encoding="utf-8") as f:
            manifesto = json.load(f)
    for i in ids:
        r = processar(i, so)
        if r is not None:
            manifesto[i] = r
    if not so:
        os.makedirs(SAIDA, exist_ok=True)
        with open(caminho_manifesto, "w", encoding="utf-8") as f:
            json.dump(manifesto, f, indent=1, ensure_ascii=False, sort_keys=True)
