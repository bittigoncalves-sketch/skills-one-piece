# Animais na Ilha Inicial — checkpoint (01/10/2026)


> **02/10/2026 — animações com esqueleto:** todos os animais têm idle/andar/correr/dano/
> ataque/morte (voadores: idle/fly/damage/attack/death). Rig dos 22 de malha única no
> Blender (`tools/blender/rig_animais.py`), clipes extras dos 7 que já tinham ossos gerados
> no Godot (`tools/mapa_ilha/clipes_dos_riggados.gd`). Ver `docs/ANIMACOES_ANIMAIS_CHECKPOINT.md`.
Pedido do dono: espalhar pelo mapa os animais da categoria **Animais** da loja, com um
**comportamento** para cada um e **locais de spawn**.

**Estado: etapas 1–6 feitas.** 71 animais das 30 espécies vivem no mapa vivo;
`test_animais.gd` passa (0 falhas) e as fotos com GPU estão em
`art_src/validation/animais/`.

## Decisões do dono

- **Todos os 30** da categoria; os **chefes** (gorila, harpia) presos numa área — **nos
  morros** (gorila na mata alta, harpia sobre os penhascos), sem sair dela.
- Comportamentos: **presa que foge, doméstico/fazenda, territorial, predador** — tabela
  abaixo, aprovada.
- Morrem: **1 XP** e o item **"none"** (= nada, por enquanto). **Renascem em 30 s** num
  ponto ALEATÓRIO da região da espécie (o cão nasce em algum ponto da vila, pode
  passear até a floresta, morrer lá e voltar em outro ponto da vila). Chefes não seguem
  essa regra.
- Animação **procedural por tipo de corpo**; **longe do jogador, sem animação**; animais
  só **visíveis num raio** em volta do jogador.
- **~70 animais** (2–4 por espécie comum, bandos de 4–6 na fazenda, 1–2 predadores).
- Regiões = **peça nova de área no editor** (volume translúcido no editor, invisível no
  jogo, com espécie e quantidade); eu coloco as iniciais por bioma.

| comportamento | animais |
|---|---|
| presa que foge | coelho, 2 cervos, raposa, sapo, lagarto, 2 pássaros |
| doméstico / fazenda | vaca, 2 ovelhas, galinha, pintinho, pato, cavalo, 5 cães, gato, pelicano |
| territorial | búfalo, bisão, caranguejo grande, macaco |
| predador | urso, águia; gorila e harpia (chefes, presos) |

## Decisões confirmadas pelo dono depois da entrega (01/10/2026)

| decisão | valor | onde muda |
|---|---|---|
| Chefe renasce | **no covil (onde nasceu), depois de 5 min** | `PopulacaoDeAnimais.boss_renasce_em` |
| Quem entra no grupo `enemy` | só **territorial e predador** (pets em guarda e mira assistida miram neles; o cão da vila não vira caça do seu pet). Presa e doméstico continuam tomando dano de soco e do Rocket (que acham o alvo pela física) | `FichaDeAnimal.hostil` |
| Plantação `crops` | **atravessável**: a loja marca `atravessavel`, o editor insere sem colisão, as 4 do mapa ficaram sem colisão | `tools/mapa_ilha/aplicar_atravessaveis.gd` |
| Cavalo de 751 mil triângulos na vila | **simplificado no Blender** → `cavalo_da_vila_leve` (62.429 triângulos, colisão = casca de 160 faces); a peça da vila trocou só o modelo | `tools/blender/simplificar_cavalo.py`, `tools/mapa_ilha/trocar_cavalo_leve.gd` |

Padrões meus ainda valendo: raios do nível de detalhe (anima até **35 m**, anda sem
animar até **80 m**, além some e para — `ANIMADO_ATE`, `VISIVEL_ATE`); passeio solto
puxado de volta além de 70 m do centro, destino só em chão seco com caminho livre
(`LONGE_DE_CASA`, `destino_valido`); nome em português na ficha (`nome`).

## Como funciona (arquivos)

- `src/world/ficha_de_animal.gd` — a ficha no catálogo: comportamento, corpo, vida,
  velocidades, dano, alerta, altura de voo, chefe, XP, item, nome.
- `src/world/mapa_arquivo.gd`, `mapa_montador.gd`, `src/editor_mapa/*` — a peça
  `area_animais` (botão **+ Animais**, painel com espécie e quantidade, desfazer).
- `src/historia/animais/animal_da_ilha.gd` — o bicho: corpo físico (cápsula das medidas
  reais), IA dos quatro comportamentos, voo, chefe preso ao covil, ataque, dano, morte.
- `src/historia/animais/populacao_de_animais.gd` — cria os bichos das áreas (ponto
  sorteado no CHÃO do relevo, fora do rio, onde a cápsula cabe), renascer, nível de
  detalhe por distância.
- `src/historia/animais/animador_de_animal.gd` — clipes dos 7 rigados por palavra-chave,
  patas do caranguejo (animador do pet) e movimento de corpo inteiro nos 22 de malha
  única, com **correção pelo pé mais baixo** (inclinar não afunda a pata).
- `src/historia/ModoHistoria.gd` — liga a população; morte → aviso no HUD e +1 XP.
- `src/world/terreno_do_mapa.gd` — `molhado_local` (o leito do rio é chão para a física).

## Números medidos

- 30 áreas, 71 animais; mapa 484 → 514 peças, **nenhuma alterada** (cópia em
  `art_src/backups/mapa_historia/baseplate_antes_animais_cce7684a0324.json`).
- Custo cronometrado direto (headless, em volta do `_physics_process` de cada bicho):
  vila 11 ativos ≈ 0,3 ms/quadro; fazenda 23 ativos 0,3–1,6 ms/quadro, pior quadro
  ≈ 3 ms. Quase todo o custo é `move_and_slide` (~24 µs por bicho andando).
- ⚠️ Não medir com `Performance.TIME_PHYSICS_PROCESS`: ele muda ~1 vez por segundo e um
  quadro isolado vira "média" de 10 ms (erro registrado em `docs/erros.md`).

## Limitações conhecidas

- Os 22 animais de **malha única** não mexem pernas: andam com balanço de corpo inteiro
  (o pé levanta junto no trote, até ~3,5 % da altura). Pernas exigiriam rig.
- O **macaco** não tem clipe de ataque: ataca sem gesto.
- O passeio não tem navegação: só recusa destino com obstáculo em linha reta; num
  labirinto de casas o bicho pode desistir e escolher outro destino.
- Item "none" é só o nome: não existe inventário de drop ainda.

## Gatilhos para revisitar

- Custo dos animais acima de **2 ms/quadro** no `test_animais.gd`, ou mais de **100**
  animais no mapa → bichos de meia distância (35–80 m) passam a andar 1 quadro em 3
  (velocidade × 3), e/ou camada de colisão própria.
- Itens existirem → o drop entra em `ModoHistoria._ao_abater_animal`.

## Cavalo da vila simplificado (01/10/2026)

- 747.380 → **62.429** triângulos (12×), 32 MB → 1,9 MB. O corpo veio do glTF em 5
  pedaços (limite de 65 mil vértices): juntados e soldados ANTES de reduzir, senão as
  emendas abrem. Olhos e peças pequenas intactos.
- Cor por vértice (sem textura). Os "pontinhos pretos" no pescoço do original NÃO são
  pintura: 0 manchas isoladas nas cores das 5 malhas do corpo — eram defeito de
  renderização (o original importa com compressão de vértice, como a areia de 30/09).
  O leve importa sem compressão e não tem os pontos.
- Comparação lado a lado com a luz do jogo: `art_src/validation/cavalo/`
  (`tools/mapa_ilha/comparar_modelos.gd`). Quadro com um só cavalo na tela: 6,94 →
  6,42 ms (RTX 3050). O original continua na loja.

## Correções depois do teste do dono em jogo (01/10/2026, noite)

- **Nenhum animal tomava dano do soco**: a cápsula de andar é um cilindro fino no
  centro (a vaca tinha 2,3 m de corpo e raio 0,31) e o coelho de 35 cm ficava abaixo do
  punho. Agora cada animal tem uma **hitbox de interação** (decisão do dono): caixa do
  corpo visível **+30 %** no comprimento e na largura, **altura mínima de 1,6 m** (até o
  peito do jogador), girando com o bicho, na camada da `HurtboxDeCombate` (só a
  varredura do combate a enxerga). Desliga ao morrer/ser domado; pet não tem (o dono não o
  fere). A doma mede o alcance pela hitbox. Verificado com **soco de verdade** (anca da
  vaca, ovelha, galinha) no `test_animais`.
- **Tamanhos**: o personagem mede **1,51 m** (modelo, medido); os tamanhos tinham sido
  pensados para ~1,75 m. Tabela aprovada pelo dono aplicada (vaca 1,30, cavalo 1,55,
  búfalo 1,55, bisão 1,60, urso 1,25, cervo 1,40, alce 1,65, ovelhas 0,80, cães
  0,45–0,75…; pintinho e sapo 0,20, lagarto 0,80, pássaros 0,60 para serem vistos).
  Fotos: `art_src/validation/escala_animais/` (`tools/mapa_ilha/capturar_escala_animais.gd`).
- **Bicho preso**: preso, desvia de lado (±70°, alternando); 3 desvios sem resolver,
  desiste; preso de novo sem ter andado livre, volta ao último ponto onde andava livre.
- **Árvores antigas** (`trees`, `pine_trees`, 171 no mapa) colidiam pelos galhos e
  folhas — o urso ficou encaixado entre os galhos. Decisão do dono: **só os troncos**
  (partes convexas, `tools/mapa_ilha/colisao_troncos_arvores.gd`; o .glb não é tocado).
- **Custo** (corrigido em 01/10, 21h40): a medida realista é o cronômetro em volta do
  `_physics_process` de cada bicho, UMA vez por quadro — chamar `move_and_slide` várias
  vezes no mesmo quadro sai muito mais barato e enganou a comparação (e a "bateria 4×
  mais lenta" que cheguei a registrar estava errada: na tomada e na bateria deu o mesmo).
  O que pesava: o fundo do mar numa forma só cobrindo a ilha inteira (~0,9 ms) — virou
  4 faixas em volta da ilha — e os bichos de meia distância (35–80 m), que passaram a
  andar 1 quadro em 3 com passo triplo (o gatilho declarado). Na tomada: vila 0,97 ms,
  fazenda 1,43 ms por quadro.
- Revelado e registrado: com a folhagem sem colisão, o teste "pés no chão nas encostas"
  passou a medir de fato uma encosta de 21° que antes ficava sob uma copa: folga de ~9 cm
  no pé de baixo. Limitação antiga (cápsula + pés sem IK) — próximo passo: IK dos pés.

## Etapas

| # | etapa | estado |
|---|---|---|
| 1 | Ficha de animal no catálogo + tamanhos reais | ✅ |
| 2 | Peça `area_animais` (formato, montador, editor) | ✅ |
| 3 | Animal em jogo: IA, voo, dano/morte/XP/item, renascer, LOD | ✅ |
| 4 | Animação: procedural por corpo + clipes + caranguejo | ✅ |
| 5 | Áreas iniciais na ilha (71), chefes nos morros | ✅ |
| 6 | Testes, capturas GPU, custo medido | ✅ |

## Rodar

```bash
G="$(./find_godot.sh)"
"$G" --headless --path . --script tools/mapa_ilha/aplicar_fichas_de_animais.gd   # fichas (idempotente)
"$G" --headless --path . --script tools/mapa_ilha/colocar_areas_de_animais.gd    # SOMA as áreas ao mapa vivo
"$G" --headless --path . --script tools/dev_tests/test_animais.gd                # confere
"$G" --path . --script tools/mapa_ilha/capturar_animais.gd [-- --so rabbit,cow]  # fotos (precisa de tela)
```
