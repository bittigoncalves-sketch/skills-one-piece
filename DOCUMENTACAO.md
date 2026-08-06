# SKILLS ONE PIECE — Documentação

Jogo de ação 3D em **Godot 4.6.3** (fan game de One Piece com Akuma no Mi/estilos de
luta). Cliente-servidor (ENet, servidor-autoridade). Código dividido em módulos
pequenos de responsabilidade única. **Convenção global: FRENTE = −Z.**

> Última revisão: 2026-08-02. Ao mudar sistemas grandes, atualize este arquivo.

---

## 1. Como rodar

| O quê | Como |
|---|---|
| Jogar (janela) | `./jogar.sh` — usa o **driver Wayland nativo** (`--display-driver wayland`). NÃO forçar X11: o XWayland trava o mouse relativo ao segurar WASD (bug da câmera). |
| Servidor dedicado | `./servidor.sh` (passa `--server` → `GameFlow.start_dedicated`, headless, sem player local). |
| Validar parse/import (headless) | `godot --headless --path . --quit-after 90` |
| Registrar `class_name` novo no cache | `godot --headless --path . --editor --quit` (**obrigatório** ao criar um `class_name`, senão dá "Could not find type"). |
| Binário | `~/Downloads/Godot_v4.6.3-stable_linux.x86_64` |

**Cena inicial:** `MainMenu.tscn`. Singleplayer = servidor local (host id 1) usando o
MESMO código do multiplayer.

---

## 2. Controles

| Ação | Tecla |
|---|---|
| Andar / correr | WASD (+ **Shift** corre) |
| Pular / parkour | **Espaço** (vault, salto longo, wall run, pouso; segurar contra parede = escalar) |
| Câmera | Mouse (1ª/3ª pessoa em **F5**) |
| Skills | **Z / X / C / V** (segurar = mira/carrega; soltar = dispara) |
| Alternar Fruta ↔ Estilo | **R** |
| Assistência de mira | **E** (liga/desliga) |
| Menu de Personagens | **M** |
| Ciclar fruta (debug) | **T** |
| Ciclar personagem | **F6** |
| Menu principal | **ESC** |

---

## 3. Estrutura de pastas

```
raiz/                 scripts CORE (referenciados pela cena/preloads — não mover à toa)
  Player.gd           MONÓLITO do jogador: movimento, câmera, camera-feel, parkour,
                      pipeline de cast, rajada de pistola, ramo skinnado.
  Main.gd             orquestrador do mundo (spawn de players/inimigos/dummy via MultiplayerSpawner).
  CharacterBuilder.gd monta os modelos (voxel por código OU skinnado Meshy); SKINNED_MODELS.
  CharacterAnimator.gd wrapper do AnimationPlayer (one-shots damage/kill/death) — rig por-nós.
  SkillSystem.gd      dados das skills Z/X/C/V por fruta + knockback/void/supressão.
  FruitPassiveSystem.gd passivas das frutas.
  TreeAndFruitGenerator.gd árvores + frutos coletáveis.
  Main.tscn / MainMenu.tscn cenas.

autoload/  GameFlow.gd — fachada dos 3 modos (SP/HOST/CLIENT) + sala por ID.
network/   ServerManager, ClientManager, FruitNet (RPCs de fruta), NetworkConfig.
src/
  anim/    ProceduralAnimator (rig por-nós), SkeletalAnimator (skinnado), BodyScanner.
  audio/   audio_manager, sound_library, audio_events, components/ (footstep, character).
  combat/  FightingStyles (5 estilos + "Teste de Animação" Mixamo).
  effects/ 17 arquivos de VFX/combate: FxUtil, AudioFX, DamageZone, + FX por fruta
           (Gomu*, Fire, Ice, Sand*, Goro, Gura, Bara, Yami, Burn, Tumbleweed).
  entities/ Enemy, TrainingDummy, PickupSpawner.
  fx/      ScreenFX (autoload — pós-processamento: vinheta/flash/speed lines).
  ui/      Hud, StatsHud, SkillBar, Inventory, CharacterMenu, MainMenu.
  utils/   TargetSystem.
  world/   WorldEnv (luz/céu/fog), MapBuilder (mapa fixo), TreeScatter.
VFX/       BreathVFX (fôlego).
tools/     bake_mixamo.gd (retarget Mixamo→rig), dev_tests/ (testes órfãos arquivados).
assets/    models/ (glb/fbx + texturas), animations/ (Mixamo .fbx + .res bakeados).
```

---

## 4. Sistemas principais

### 4.1 Personagens & Rigs (DOIS tipos)
- **Voxel (rig por-nós):** `base`, `buggy` — modelo feito de **nós separados** nomeados
  (`Torso`, `UpperArm_L→ForeArm_L`, `Thigh_L→Shin_L→Foot_L`…). Animado pelo
  **`ProceduralAnimator`** (gira os nós por role via `BodyScanner`).
- **Skinnado (esqueleto):** `ace`, `nami`, `blackbeard`, `crocodile` — modelos **Meshy AI**
  (`Skeleton3D` de 24 ossos + malha skinada + textura PBR), em `assets/models/meshy_*/`.
  Registrados em `CharacterBuilder.SKINNED_MODELS`. Animados pelo **`SkeletalAnimator`**.
  Cada um tem seu **walk nativo** (`SKINNED_WALKS`) — NÃO reusar entre modelos (bind-pose
  diferente distorce). Idle = pausa/bind-pose própria.
- Todos os jogáveis são normalizados p/ **mesma altura** (`Player.CHAR_TARGET_H = 1.5`).
- Skinnado usa **escala UNIFORME** no fit (não-uniforme corrompe o skinning → tela cinza).

### 4.2 Animação
- **ProceduralAnimator** (`src/anim/`): idle/walk/run/jump/climb + poses de parkour, charge,
  dedo-revólver, recovery — dirigindo os nós do rig voxel em runtime. Tem `play_baked()`
  p/ tocar clipes Mixamo retargetados por-nós.
- **SkeletalAnimator** (`src/anim/`): toca clipes ESQUELETAIS por estado nos personagens
  skinnados; gera idle/run/jump/damage/death procedurais nos ossos quando faltam.
- **Mixamo:** FBX esqueletais em `assets/animations/`. `tools/bake_mixamo.gd` retargeta
  cada um pro rig por-nós (`<nome>.res`, faixas `<Role>:rotation`). Estilo **"Teste de
  Animação"** cicla por todos (Z=próx, X=ant, C=repete).

### 4.3 Combate (2 modos, tecla R)
- **Fruta** (`current_fruit_id`): `gomu_gomu, mera_mera, hie_hie, bara_bara, goro_goro,
  yami_yami, suna_suna, gura_gura`. Skills Z/X/C/V em `SkillSystem.get_fruit_skills()`.
- **Estilo** (`STYLES_LIST`): `karate_tritao, pacifista, mink, boxe, cyborg, teste_animacao`
  (`src/combat/FightingStyles.gd`).
- **Pipeline servidor-autoridade:** `begin_charge/release_charge → _request_cast → _net_cast
  → _do_server_cast → _net_play_cast → _fire_skill`. `DamageZone` só aplica dano no servidor.
- **Hold-to-cast:** segurar Z/X/C/V congela o player (mira), soltar dispara.
- **Rajada Z (Mera/Hie):** pistola nas 2 mãos, congela no ar até soltar/16 balas, mira
  corrigida (converge no ponto sob a mira), coice por tiro.

### 4.4 HUD (`src/ui/`)
`Hud` monta: `StatsHud` (vida 2048 verde / energia 4096 azul / DANO TOTAL / aim assist /
**ID da sala** quando host / nome da animação de teste), `SkillBar` (Z/X/C/V), `Inventory`
(I), `CharacterMenu` (M, centralizado), `MainMenu` (ESC).

### 4.5 Multiplayer & Sala por ID
- ENet, servidor-autoridade. Autoloads `ServerManager`/`ClientManager`/`FruitNet` + `GameFlow`.
- **Sala:** o "ID" **codifica o IP do host** em base32 de 7 chars (`GameFlow.encode/decode_room_id`).
  Menu ONLINE: **Criar Servidor** (gera ID, mostrado no HUD) + **Entrar** (decodifica → conecta).
  Porta fixa `NetworkConfig.DEFAULT_PORT = 24565`. É ENet direto (LAN, ou port-forward p/ internet).

### 4.6 Feedback de dano (qualquer ser)
`FxUtil.flash_red(model)` (pisca vermelho), `FxUtil.damage_number(...)` (número flutuante),
`AudioFX.hurt(...)` (som). Chamados em `Player/Enemy/TrainingDummy.take_damage`.

### 4.7 Camera Feel
Em `Player._process`: screen-shake (h/v_offset, não afeta mira), FOV dinâmico, head-bob,
hit-stop/slow-mo (`Engine.time_scale` + timer ignore_time_scale). `ScreenFX` (autoload) faz
vinheta/speed-lines/flash por shader.

### 4.8 Mundo
`Main.gd` monta via `WorldEnv` (luz/céu/fog), `MapBuilder` (plataforma+blocos FIXOS),
`TreeScatter`. Inimigos (`Enemy`, passivos, domáveis no botão direito) e `TrainingDummy`
(imóvel no centro, reseta) spawnam por `MultiplayerSpawner`.

---

## 5. Convenções críticas (leia antes de mexer)
- **FRENTE = −Z.** Facing por movimento: `atan2(-dir.x, -dir.z)`. Mira: `-_cam.basis.z`.
- **Validar SEMPRE headless** antes de dar como pronto (parse + boot). `class_name` novo
  exige `--editor --quit` p/ entrar no cache global.
- **jogar.sh usa driver Wayland** (bug do mouse no XWayland).
- **Skinnado:** escala uniforme no fit; direção corrigida girando a `Armature` +180°
  (Meshy nasce olhando +Z); Smart Topology → cada modelo tem bind-pose própria (não
  compartilhar animação entre bind-poses diferentes sem retarget).
- **Fullscreen:** `project.godot` usa `stretch/mode="canvas_items"` + `aspect="expand"`
  (o 3D renderiza na resolução real; "viewport" borrava por upscale de 720p).
- **Skill é data-driven** (`SkillSystem` / `FightingStyles`): novo golpe = nova entrada
  no dicionário + função de VFX em `src/effects/`.

---

## 6. Assets
- `assets/models/*.glb` (voxel base/buggy) e `meshy_*/*.fbx` (skinnados + PBR).
- `assets/animations/*.fbx` (Mixamo esqueletal) + `*.res` (bakeados pro rig por-nós).
- Personagens skinnados: textura vem do PBR do modelo; NÃO aplicar `<id>.png` por cima.

---

## 7. Dívidas / próximos passos
- Fase 2 skinnados: retargetar o set Mixamo completo pro esqueleto Meshy (idle/run/golpes)
  e prender a pistola num osso da mão. Ideal gerar próximos personagens no MESMO modo de
  rig (evita bind-pose diferente).
- Base/Buggy no rig skinnado dependem de modelos Meshy próprios.
- Reorganização opcional: mover os 7 scripts core da raiz p/ `src/` (exige atualizar
  todos os `preload`/`load` e referências de cena — fazer com validação headless).
