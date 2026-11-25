# Luta (Z/X/C) — visual 3D, segurar e combate aéreo — checkpoint 20/11/2026

**Objetivo (pedido do dono):** Z soco (segurar repete, mesmo dano) · X soco carregado (+dano por segurar) · C metralhadora
(segurar = mais socos; inimigos na barragem não reagem) · no ar o soco sai na mira da câmera, também para cima e para baixo.
Divisão: Codex = plano + imagens (`art_src/references/luta_visual/`), Claude = código + 3D.

## O que entrou
- `src/combat/frutas_mine_piece/luta.gd`
  - **Z segurado** repete a cada 0,5 s alternando braços; dano idêntico ao avulso; cada repetição paga a energia do soco e a
    sequência acaba sem energia ou ao soltar.
  - **Mira 3D no ar** (`_direcao_do_golpe`): no chão continua horizontal (comportamento antigo); no ar segue a câmera inteira.
    Área de dano, empurrão (`override_kb_dir`) e visual usam a mesma direção. `looking_at` troca o vetor de referência perto da vertical.
  - **Braço inclina com a mira** no ar (`c.pose_extra`, ombro: 90° horizontal / 180° para cima).
  - **Golpe final só solta quem a própria rajada paralisou** (`_presos`); antes soltava qualquer alvo em 6 m, inclusive congelado por outra técnica.
  - Limpeza da aura/inclinação ao encerrar, cancelar, apanhar ou sair da árvore.
- `src/combat/frutas_mine_piece/luta_visual.gd` (novo): explosão de cubos voxel branco/dourado (`estourar`), punho-fantasma da
  rajada (`fantasma`), aura de carga do X em 3 níveis (`aura`). Dois materiais compartilhados, ≤ ~20 cubos por golpe, somem por Tween.
- `src/combat/frutas_mine_piece/controlador.gd`: `pose_extra` somada à pose do clipe.
- **Bug corrigido (causa raiz):** o filtro "clique rápido" do `CombatResolver` (janela de 500 ms por alvo, feito para o M1) engolia
  a rajada do C (só o 1º soco entrava; o final entrava só pela diferença) e as repetições do Z. Agora `DamageZone.sem_janela_de_acerto`
  (→ `CombatResolver.aplicar(..., janela_de_clique_rapido)`) tira as técnicas da Luta dessa janela; o M1 segue igual.

## Validação (headless)
- `tools/dev_tests/test_luta_ar_e_segurar.gd` (novo): **25/0** — Z segurado (contatos, dano igual, soltar encerra), mira para frente/cima/baixo,
  alvo abaixo não é atingido mirando para cima, eixo do punho-fantasma = mira, aura do X cresce e some, cancelar limpa, braço inclina,
  congelamento de outra origem sobrevive ao final do C.
- `test_luta_nativa.gd` **33/0** (antes do conserto: 27/6 — o C dava 2 contatos). `test_clique_rapido.gd` 43/0.
- Cenários extras (dois alvos, cancelar no meio da rajada, Z sem energia, alvo que sai da área, X tocado): todos passam; 33/0 no total.
- Falhas anteriores a esta mudança (provado: com o parâmetro do resolvedor neutralizado os 4 testes falham igual): `test_luta_empurrao_paralisia` (legado do Builder), `test_socos_de_ferro` ("havia um alvo para medir"),
  `test_compila` (ScreenFX/FruitNet fora do contexto `--script`), `test_balance` (chave 'K'; arquivo com edição pendente de outra frente).

## Adendo (mesma data)
- **Rede:** `ControladorFrutaMinePiece.mostrar_golpe` → RPC cosmético `_golpe_visual` (unreliable, só aceita do servidor): clientes remotos
  agora veem a explosão e o punho-fantasma. Em processo único não faz nada (sem peer); **não exercitado com host+cliente reais**.
- **Legibilidade medida por projeção na câmera real:** no pico da rajada os cubos cobrem 13 % do retângulo do alvo (limite do teste: 35 %).
  É proxy numérico, não substitui olhar o jogo.

- **Alvo jogador (PvP):** testado com stand-in no grupo `player`: 8 contatos, congelado entre os socos (6 de 6), solto no fim, final empurra 21,6.
  O `Player` respeita `is_frozen` (`Player.gd` 268/1845/3046), então não anda nem age congelado.
- **Rede:** o Modo História é `Mode.SINGLEPLAYER` com host offline (`GameFlow.start_story`) — hoje não há cliente remoto jogando a Luta, então o RPC
  `_golpe_visual` fica dormente; o lado que envia já roda nos testes (host offline, zero peers) sem erro. Se o Modo História ganhar co-op, testar host+cliente.

- **Prévia visual (Blender headless, sem janela):** `art_src/validation/luta_visual/previa_geometria_blender.png`, gerada por
  `tools/blender/previa_luta_visual.py` (mesma lógica de `luta_visual.gd`). Mostra o punho-fantasma alinhado à mira nos três casos (frente, cima, baixo) e a explosão
  no alvo sem escondê-lo. É geometria plana, sem rig, câmera de jogo nem shader; as faíscas ficaram mais contidas que nas referências do Codex (decisão: legibilidade
  do alvo; se o dono quiser mais explosivo, subir `forca` em `_forca_visual` ou o leque em `estourar`).

- **Captura real no Godot (autorizada pelo dono, 20/11/2026):** `art_src/validation/luta_visual/*.png` (Z, X em 3 cargas, impacto, rajada, final, ar cima/baixo),
  geradas por `tools/dev_tests/captura_luta_visual.gd`. A captura pegou o que os testes não pegaram: aura escondida atrás do braço e faíscas pequenas
  demais — afastei/aumentei (cobertura do alvo medida: 19 %, limite 35 %).
- **Bug reportado pelo dono ao segurar o X:** o clipe `punch_right` era reiniciado a cada tick durante a carga, e o peso de entrada nunca saía de ~0 (braço piscando).
  Agora o X tem **pose única de carga** (`POSE_CARGA` em `luta.gd`: torso torcido, base aberta, punho recolhido, guarda esquerda), um quadro só, sem reiniciar
  (`controlador.registrar_pose`); o soco só toca na liberação. Segundo bug achado no caminho: nos 5 primeiros ticks a liberação disparava antes da hora
  (`_soltou`). Testes: clipe `carga_x` com t=0,50 s (reiniciando seria ≤0,05) e troca para `punch_right` ao soltar. Captura: `pose_carga_x_*.png`
  (`captura_pose_carga.gd`). O ângulo exato do antebraço/torso é meu palpite visual: ajustar `POSE_CARGA` se o dono quiser outra silhueta.

- **Revisão do Codex (msg #61), tudo corrigido:** barras da rajada alternam lados (`_golpear(..., direita)`); Z começa pelo braço direito e a inclinação segue o braço que bate;
  imobilização de OUTRA origem no mesmo alvo é preservada (só entra em `_presos` quem não estava imobilizado); estouro cheio no contato (`hit_landed`), clarão pequeno no vazio
  (nenhum na rajada); aura com níveis em 0/34 %/67 % da carga e anel de 4→8 satélites; comentário dos nós corrigido. Cobertura medida: rajada 9 %, final 35 % (limite 60 %).
  **Ainda aberto:** o punho-fantasma é barra dourada, não punho com rastro (ref. 03).

## Estado final (20/11/2026) — o que foi testado e o que NÃO foi

**Testado (headless, `test_luta_ar_e_segurar` 48/0, `test_luta_nativa` 33/0, `test_clique_rapido` 43/0):** Z segurado/dano igual/energia; X carga, aura, pose própria e transição;
C com 1 e 2 alvos, cancelar, alvo que sai, alvo "jogador" (**stand-in** de grupo `player`, não um `Player` real); mira aérea frente/cima/baixo (área, empurrão, eixo do rastro);
imobilização de outra origem preservada nas DUAS ordens (já preso antes / estendido depois da rajada, por token de ORIGEM em `ImobilizacaoMinePiece` (`aplicar(..., origem)` / `liberar_origem`); inclui outra técnica prendendo por 0,4 s logo antes do final); cobertura do alvo por projeção (rajada ~15 %, final 35 %).

**Capturas reais no Godot (autorizadas):** `art_src/validation/luta_visual/*.png` — quadros isolados; NÃO provam animação nem substituem vídeo/sequência. Ver o contato
encoberto pelo corpo/alvo em alguns quadros (câmera de costas); sequência em ângulo lateral/3-4 ainda é pendência.

**Pendente / não validado:**
- **Aprovação artística do dono** (visual, pose do X, punho-fantasma): NÃO concluída.
- **Cliente remoto real:** inexistente hoje (Modo História = `Mode.SINGLEPLAYER` com host offline); o RPC `_golpe_visual` só foi exercitado no lado que envia (zero peers).
- **Alvo jogador real** (um `Player` de verdade atingido): só stand-in.
- Falhas anteriores a esta mudança, provadas por baseline sem o parâmetro do resolvedor: `test_balance`, `test_socos_de_ferro`, `test_compila`,
  `test_luta_empurrao_paralisia` (legado do Builder), `test_inimigo_lutador`, `test_defesa_historia`.
- **Imobilização, o que foi exercitado e o que é inferência:** exercitado em teste — pré-preso por outra origem, outra origem de 30 s no meio da rajada, outra origem de 0,4 s logo
  antes do final, duas origens no mesmo nó, e expiração do token da Luta + recriação por outra origem (**nível da imobilização**, chamando `liberar_origem` direto, não com um C inteiro).
  Inferido (sem teste de ponta a ponta): C real cujo token expira porque o alvo saiu e outra técnica o recria antes do final. Chamadas LEGADAS sem origem compartilham a chave vazia: a posse
  individual entre duas técnicas legadas NÃO é garantida (a Luta é separada delas).
- Gatilhos: cadência do Z (0,5 s) em `_soco()`; intensidade/tamanho dos cubos em `_forca_visual` e `luta_visual.gd`; pose do X em `POSE_CARGA`.
