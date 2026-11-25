# Análise do pack "Simply Optimized Continued" e o que foi aplicado ao Skills One Piece (2026-11-12)

Pack: `~/Documents/curseforge/minecraft/Instances/Simply Optimized Continued` — Minecraft **26.2**, NeoForge 26.2.0.59, 16 mods (≈ 700 mixins). Análise anterior (04/11/2026) está em
`docs/CHECKPOINT_DESEMPENHO_2026-11-04.md` (EntityCulling, ServerCore, Gnetum); esta a completa com o pack inteiro, os `config/` do pack e **medição no jogo**.
**REA:** `open_binary` + `extract_artifact` abriram o jar do Sodium (resultado: o jar externo só traz o bootstrap e o mod real vem aninhado em `META-INF/jarjar/`; a lista de ~110 arquivos
inunda o contexto). Para os outros 15 jars usei o mesmo conteúdo lido por zip (listas `*.mixins.json`, incluindo os jars aninhados) — o REA não decompila Java.

## Catálogo: técnica → equivalente no jogo (Godot) → decisão
| Mod (mixins) | Técnica (lida nas listas de mixins e nos configs) | Equivalente aqui | Decisão |
|---|---|---|---|
| **Sodium** (92) | malha por seção de 16³ com faces visíveis, oclusão de seção, formato de vértice compacto, ordenação de translúcidos | `GradeVoxel` já faz seções, face-culling por bits e fusão gulosa (385 k → 19 k triângulos) | feito antes; vértice compacto: gatilho abaixo |
| **MoreCulling** (55) | cull de faces por forma do bloco, folhas `leavesCullingMode CHECK/amount 2`, quadros/placas/chuva por distância | face-culling por octante já cobre; folhas opacas cortam a face entre vizinhas | já coberto |
| **ImmediatelyFast** (20) | batching de GUI, texto em atlas, evitar troca de framebuffer, mapas em atlas | o Godot agrupa `CanvasItem` sozinho; os `SubViewport` (prévia do personagem) só atualizam visíveis (`UPDATE_WHEN_PARENT_VISIBLE`) | verificado: 2 SubViewports pequenos |
| **Gnetum** (31) | HUD em buffer reaproveitado (`maxFps 60`, `screenMaxFps 20`, 3 passes) | HUD retido do Godot já não redesenha sem mudança | **achei o equivalente real**: janelas fechadas refazendo listas — ver "Aplicado" (1) |
| **Lithium** (292) | caches de estado/forma, colisão e raycast rápidos, ticking que "dorme", coleções sem alocação, entity sections | `IaDoMod.faixa_de_ativacao` (04/11), `economia_de_parado`, `NpcDaIlha.economia_fora_da_tela` | já aplicado; não há novo gargalo medido |
| **ServerCore** (56) | faixa de ativação por tipo (mob 20 blocos, tick 1/6), caps de mob, tickets de chunk | `IaDoMod.faixa_de_ativacao` (80 m, 1 tick em 6) | já aplicado (04/11) |
| **FerriteCore** (13) | deduplicar estados/formas/modelos em memória | deduplicar RECURSOS: texturas e materiais | **aplicado** — ver "Aplicado" (2) |
| **ModernFix** (118) | carga dinâmica/preguiçosa de recursos, menos memória, caches | texturas em VRAM comprimida, carga em thread | **aplicado** parte textura (2); resto = gatilho |
| **C2ME** (config) | paralelismo de chunk = f(CPUs, RAM), carga simultânea limitada (6) | `GradeVoxel` usa `WorkerThreadPool`, `MAX_TAREFAS = 16`, 2 seções refeitas por quadro | fórmula de threads por CPU: gatilho |
| **ScalableLux** (16) | iluminação em paralelo (Starlight) | o jogo ainda não tem luz de bloco | futuro (quando houver luz por bloco) |
| **Better Block Entities** (40) | funde entidades de bloco estáticas no mesh da seção | ilha inicial: 7 799 `MeshInstance3D`, 960 só nos `Modelo` das lojas/casas | medido: render NÃO é o gargalo (ver abaixo) → gatilho |
| **Ixeris** (11) | entrada/eventos do janelas em outra thread, limitador de FPS | `Input.use_accumulated_input = false` já no `GameFlow` | nada a fazer |
| **zfastnoise**, **NoChatReports**, **Cloth/ConfigManager** | ruído rápido; (resto não é desempenho) | `FastNoiseLite` nativo | nada a fazer |

## Medido no jogo (ilha inicial, GPU RTX 3050, 1280×720; `tools/dev_tests/medir_render_ilha.gd`)
- **Render não é o gargalo:** 3 050 chamadas de desenho, 3 900 objetos, 2,3 M de primitivas, mas **render CPU 1,8 ms e GPU 4,8 ms** por quadro; o quadro de ~17 ms é o vsync do sistema. Esconder floresta/natureza/NPCs/relevo ou desligar a sombra direcional não muda
  a CPU de render e mexe ≤ 1,3 ms na GPU. Logo Sodium/MoreCulling/BBE/ImmediatelyFast (render) têm retorno baixo AGORA — a mesma conclusão da análise de 04/11.
- **Nós:** 24 929 (7 799 `MeshInstance3D`, 7 277 `CollisionShape3D`, 2 293 `StaticBody3D`); 6 073 meshes sem `visibility_range`; 5 903 projetam sombra.
- **Memória de vídeo: 1 071 MB, dos quais texturas 643 MB** — esse era o custo grande e nunca medido.

## Aplicado
1. **Janelas fechadas não recalculam (Gnetum/ImmediatelyFast, "não faça trabalho que ninguém vê")** — `InventarioDaHistoria` e `BancadaDeArmas` só se refazem visíveis. Rolar a hotbar: **700 ms → 2,6 ms por troca** (`tools/dev_tests/medir_rolar_hotbar.gd`).
2. **Texturas grandes em VRAM comprimida (FerriteCore/ModernFix: menos memória sem mudar o resultado)** — `tools/otimizar_texturas.py --aplicar`: 184 texturas ≥ 1 MP (Meshy, rochas, Yoru…) saíram de `compress/mode=0` (RGBA8 sem perdas + mipmaps)
   para VRAM comprimida (BC7; normais em `normal_map=1`). **Memória de textura 643 → 280 MB (−363 MB); vídeo total 1 071 → 707 MB (−34 %); carga do Modo História 10,27 → 9,44 s.** Visual: o quadro inicial deu PSNR 43 dB contra o anterior
   (os outros 3 quadros variam por animação/chefe; comparados a olho, iguais). Reimportar leva ~3 min (`godot --headless --path . --import`). Reversível: `--desfazer`.
   ⚠️ Só desktop (o projeto só exporta Linux/Windows); para Android seria preciso ligar `rendering/textures/vram_compression/import_etc2_astc`.
   NÃO tocado: `assets/minecraft_local` (pixel art exige pixels exatos) e texturas < 1 MP.

## Gatilhos (decididos adiar, com o motivo)
- Vértice compacto nas seções de bloco (Sodium): hoje ~56 B/vértice (posição + normal + cor + UV + UV2); medir `mem_buffer` (267 MB) por seção antes — só se a memória de buffer virar problema ou o raio de seções subir de 8.
- Fundir os `Modelo` estáticos de cada loja/casa em um mesh por material (BBE): só se a GPU passar de ~10 ms ou as chamadas de desenho de 5 000.
- `visibility_range` nos meshes decorativos distantes e sombra só perto (EntityCulling): idem — a sombra direcional custa ≤ 0,1 ms de CPU hoje.
- Paralelismo de seções por CPU (C2ME): se a ilha demorar > 1 s para ficar pronta em máquinas com poucos núcleos.
- Carga em thread de recursos grandes (ModernFix): se a carga do Modo História (9,4 s) incomodar; maiores custos da carga: relevo 1,7 s, fundo do mar 1,4 s, ilha inicial 1,9 s.
