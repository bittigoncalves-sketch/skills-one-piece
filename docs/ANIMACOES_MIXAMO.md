# Biblioteca de Animações Mixamo — `assets/animations/`

Documento de referência da pasta `res://assets/animations/`: o que tem lá, como
entra no jogo, como adicionar mais e quais são as pegadinhas.

Origem dos arquivos: pasta pessoal `~/Downloads/animações importadas do mixamo`
(baixada do [mixamo.com](https://www.mixamo.com), formato FBX, esqueleto
`mixamorig_*`). A pasta do jogo é a **fonte canônica** — o Downloads é só o
staging de onde os FBX chegam.

---

## 1. Como uma animação do Mixamo vira animação do jogo

O jogo **não** toca o FBX direto. Os personagens voxel usam um **rig por-nós**
(nós `Node3D` soltos, sem `Skeleton3D`), então o clipe precisa ser *retargetado*
antes de rodar.

```
Mixamo (.fbx, esqueleto mixamorig_*)      assets/animations/
        │
        │  tools/fbx_to_glb.py  (Blender headless)   ← OBRIGATÓRIO
        ▼
<nome>.glb                                 assets/animations_glb/
        │
        │  tools/bake_mixamo.gd  (Godot headless)
        ▼
<nome>.res  (Animation com faixas "<Papel>:rotation")   assets/animations/
        │
        │  Player.play_style_anim("<nome>")
        ▼
ProceduralAnimator.play_baked()  →  gira os papéis do rig
        │
        └─ se o personagem for SKINNADO, o SkeletonDriver
           espelha os papéis nos ossos do Skeleton3D
```

> ⚠️ **Por que o passo do Blender é obrigatório.** O importador FBX do Godot
> (ufbx) lê **1 chave só** por osso de membro nos arquivos do Mixamo — só o
> `mixamorig_Hips` recebe chaves reais. As curvas **existem** no FBX (o Blender
> acha 520 fcurves), mas se perdem no import, e o bake saía **todo zerado**.
> Convertendo para glTF o Godot lê **57 chaves por osso**.
> Não adianta mexer em `animation/trimming` nem em `remove_immutable_tracks`.

### Comando do bake

O Godot **não está no `PATH`** — é o binário baixado à mão, o mesmo que o
`jogar.sh` usa:

```bash
BLENDER="/home/gabriel-bitti/opt/blender-5.2.0-linux-x64/blender"
GODOT="/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64"
cd ~/dev/skills-one-piece

# 1. FBX -> GLB (converte a pasta inteira)
"$BLENDER" --background --python tools/fbx_to_glb.py -- \
    "$PWD/assets/animations" "$PWD/assets/animations_glb"

# 2. GLB -> .res (retarget pro rig de 13 papéis)
"$GODOT" --headless --path . -s tools/bake_mixamo.gd
```

O conversor aceita **um arquivo ou uma pasta**. Ele imprime `fcurves=N` por
arquivo — se vier `fcurves=0`, o FBX é que está vazio. O baker varre todo `.glb`
e gera o `.res` em `assets/animations/`. Os dois passos são idempotentes.

Último bake: **28 ok, 0 falhas** (2026-08-10 — rebake dos 28 com o baker
consertado; ver "Rebake de 2026-08-10" no fim da seção 5).

### O que o baker faz por dentro (`tools/bake_mixamo.gd`)

1. Instancia o FBX e acha o `Skeleton3D` + `AnimationPlayer`.
2. Escolhe o clipe: prioriza `mixamo_com`; senão pega o mais longo que não seja
   `RESET`.
3. Amostra a **60 FPS** e, para cada osso mapeado, calcula o *delta* em relação
   à pose de repouso (`get_bone_global_rest`), converte para o espaço do pai e
   grava como Euler — **destorcendo o euler chave a chave** (`_euler_continuo`),
   senão a faixa LINEAR faz o caminho longo entre +179° e −179° e o membro dá
   uma volta completa em 1/30 s.
4. Aplica um **flip de 180° em Y** (`yflip`) — o Mixamo exporta olhando +Z, a
   convenção do projeto é **frente = −Z**.

### Mapa osso Mixamo → papel do rig

| Papel no rig | Osso Mixamo | Pai |
|---|---|---|
| `Torso` | `mixamorig_Spine1` | (raiz) |
| `Neck` | `mixamorig_Neck` | Torso |
| `Head` | `mixamorig_Head` | Torso |
| `UpperArm_L` / `_R` | `mixamorig_LeftArm` / `RightArm` | Torso |
| `ForeArm_L` / `_R` | `mixamorig_LeftForeArm` / `RightForeArm` | UpperArm |
| `Thigh_L` / `_R` | `mixamorig_LeftUpLeg` / `RightUpLeg` | Torso |
| `Shin_L` / `_R` | `mixamorig_LeftLeg` / `RightLeg` | Thigh |
| `Foot_L` / `_R` | `mixamorig_LeftFoot` / `RightFoot` | Shin |

> ⚠️ Só esses 13 papéis são capturados. **Mãos, dedos, ombros (`Shoulder`) e
> quadril não entram.** Animação cujo charme está no punho ou no giro de ombro
> perde parte da leitura. O rig **voxel não tem nó `Neck`** — a faixa é gravada
> mesmo assim e o `ProceduralAnimator._apply_baked` a ignora (`if _n.has(role)`);
> quem usa é o personagem skinnado, via `SkeletonDriver`.

---

## 2. Acervo atual (29 clipes)

### Socos / punhos
| Arquivo | Origem Mixamo | Uso pretendido |
|---|---|---|
| `punching` | Punching | soco básico |
| `boxing` | Boxing | combo de boxe |
| `boxing_1` | Boxing (1) | variação de boxe |
| `boxing_2` | Boxing (2) | variação de boxe |
| `boxing_3` | Boxing (3) | variação de boxe |
| `quad_punch` | Quad Punch | combo de 4 golpes |
| `jab_to_elbow_punch` | Jab To Elbow Punch | jab → cotovelada |
| `uppercut_jab` | Uppercut Jab | uppercut |
| `stabbing` | Stabbing (soco) | estocada |
| `smash` | Smash | golpe pesado descendente |

### Chutes
| Arquivo | Origem Mixamo | Uso pretendido |
|---|---|---|
| `kicking` | Kicking | chute básico |
| `roundhouse_kick` | Roundhouse Kick | chute rodado |
| `roundhouse_kick_2` | Roundhouse Kick (1) | variação |
| `flying_kick` | Flying Kick | chute voador |
| `pontera` | Pontera (chute) | chute de capoeira |
| `chapa_2` | Chapa 2 | chapa (capoeira) |
| `chapa_giratoria_2` | Chapa Giratoria 2 | chapa giratória |
| `meia_lua_de_compasso` | Meia Lua De Compasso | meia-lua (capoeira) |
| `armada` | Armada | armada (capoeira) |

### Movimento / parkour
| Arquivo | Origem Mixamo | Uso pretendido |
|---|---|---|
| `au_to_role` | Au To Role (movimentação lateral) | esquiva lateral / aú |
| `running_dive_roll` | Running Dive Roll | rolamento de pouso |
| `jumping_over_into_combat` | Jumping Over Into Combat (parkour) | vault |
| `pivot` | Pivot | virada rápida |

### Estados / poses
| Arquivo | Origem Mixamo | Uso pretendido |
|---|---|---|
| `bouncing_fight_idle` | Bouncing Fight Idle | idle de combate |
| `dying` | Dying | morte |
| `gunplay` | Gunplay | pose de arma de fogo |
| `bencao` | Bencao | bênção / gesto |

### Duplicata conhecida
`Punching.fbx` / `Punching.res` (P maiúsculo) são **byte-a-byte iguais** a
`punching.fbx` / `punching.res`. Sobra no ciclo do "Teste de Animação".
**Pendente:** apagar os de P maiúsculo.

---

## 3. Como usar no código

### Tocar um clipe

```gdscript
player.play_style_anim("kicking")
```

- Carrega `res://assets/animations/kicking.res`.
- Chama `_proc_anim.play_baked(anim)`.
- Trava o movimento por `anim.length + 0.1` (`lock_movement`).
- Se o `.res` não existir, imprime `[StyleAnim] falta o bake do rig: ...` e não
  faz nada — **falha silenciosa em jogo**, só aparece no console.

### Ver todas em jogo

Estilo de combate **"Teste de Animação"** (último de `Player.STYLES_LIST`):
as teclas **Z / X / C** ciclam por *todos* os `.res` da pasta em ordem
alfabética (`_scan_style_anims` → `cycle_style_anim`).

O scan é feito por `DirAccess` em runtime: **animação nova aparece sozinha**,
sem mexer em código. Só precisa do `.res`.

---

## 4. Adicionar uma animação nova

1. Baixar do Mixamo em **FBX Binary**, *sem skin* (`Without Skin`) se possível.
2. Salvar em `assets/animations/` com nome **snake_case, minúsculo, sem
   acento e sem parênteses** (`Roundhouse Kick (1).fbx` → `roundhouse_kick_2.fbx`).
   O nome do arquivo vira a chave usada em `play_style_anim()`.
3. Rodar o baker (comando da seção 1).
4. Testar no estilo "Teste de Animação".

---

## 5. Limitações conhecidas

- **Só o rig por-nós.** Personagens *skinnados* (`Skeleton3D`, modelos Meshy AI:
  `ace`, `nami`, `blackbeard`, `crocodile`) **não** tocam esses `.res`. Cada um
  tem bind-pose própria e usa o `SkeletalAnimator` com o walk nativo dele.
- **Sem root motion.** O baker só grava rotação; deslocamento do quadril é
  descartado. Clipe que "anda" no Mixamo fica no lugar.
- **Sem blend.** `play_baked` substitui a pose inteira e trava o movimento até
  acabar. Não há transição suave de entrada/saída nem mistura com a locomoção.
- **Sem eventos.** Não existe marcação de frame de impacto — o dano hoje é
  disparado por tempo no código do golpe, não pela animação.
- **13 papéis apenas.** Ver aviso da seção 1.

### Rebake de 2026-08-10 — o giro parasita saiu

Os 28 `.res` tinham sido assados **antes** do conserto do euler, e 16 deles
percorriam **~360° entre duas chaves vizinhas** (`running_dive_roll` 367.8°,
`au_to_role` 361.9°, `dying` 361.3°, `kicking` 357.7°…): o membro dava uma volta
completa em 1/30 s. Reassados com o baker consertado, **1 dos 30 clipes** ainda
passa dos 30° de percurso — o `pontera`, com 33.8°, e ali o giro é **real**
(giro geodésico de 29.9° na canela, não gimbal).

**Como conferir que o rebake não mexeu no movimento** (e não só na
representação): `tools/dev_tests/medir_amplitude_res.gd` mede (max−min) do euler
e por isso **não serve** para comparar antes/depois — desdobrar o euler muda o
número nos dois sentidos sem o membro se mexer (no `armada` a coxa esquerda
"subiu" de 596° para 1004°; no `dying` a soma "caiu" de 2666° para 1393°). Quem
compara é o `tools/dev_tests/medir_pose_res.gd`, que mede **rotação**, não euler:
copie os `.res` antigos para `user://ref_anim/` e rode. No rebake de 2026-08-10
deu **DIFF_max = 0.000° em todos os papéis dos 30 clipes** — pose idêntica em
todo instante de chave antiga — e o percurso real caiu onde tinha giro parasita
(`running_dive_roll` −5239°, `au_to_role` −6268°) e ficou igual (±6°) nos limpos.
Duração: idêntica nos 30. Amplitude geodésica: igual em 27, +5.8° no `armada`,
+1.1° no `flying_kick`, +0.3° no `au_to_role` — as chaves novas de 60 fps pegam
um pico que a grade de 30 fps passava por cima.

`tools/dev_tests/medir_impacto_res.gd` mede o **instante do impacto** (alcance
frontal máximo do membro, por cinemática direta) — é o número que calibra o
`atraso` da hitbox em `src/combat/Melee.gd`.

---

## 6. Arquivos relacionados

| Arquivo | Papel |
|---|---|
| `tools/bake_mixamo.gd` | conversor FBX → `.res` |
| `tools/dev_tests/medir_amplitude_res.gd` | acha clipe CONGELADO (amplitude euler) |
| `tools/dev_tests/medir_salto_res.gd` | acha estalo entre chaves (percurso real) |
| `tools/dev_tests/medir_pose_res.gd` | compara dois bakes em ROTAÇÃO (invariante de representação) |
| `tools/dev_tests/medir_impacto_res.gd` | instante do impacto (calibra o `atraso` do `Melee`) |
| `src/anim/ProceduralAnimator.gd` | toca o `.res` (`play_baked`, `_apply_baked`) |
| `src/anim/BodyScanner.gd` | define os 13 papéis (`ROLES`) e mede o corpo |
| `VoxelMeshes.gd` (`_build_skeleton`) | monta o rig com os nomes de papel |
| `Player.gd` (`play_style_anim`, `cycle_style_anim`) | ponte jogo ↔ biblioteca |

---

## Clipes removidos

| clipe | quando | por quê |
|---|---|---|
| `hurricane_kick` | 2026-08-10 | **veio quebrado do Mixamo**: o `.fbx` de origem não tinha as curvas de rotação dos membros (153 das 315 curvas com 1 chave só), então o clipe tocava com braços e pernas congelados. Não havia conserto local. Ver [`erros.md`](erros.md). |

Para trazer de volta, baixe o clipe outra vez em mixamo.com e rode
`./tools/importar_animacao.sh <arquivo.fbx>` — ele recusa o arquivo se vier
quebrado de novo.
