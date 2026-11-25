# Animações dos animais — checkpoint (01/10/2026)

Pedido do dono: "adicionar as animações aos animais: idle, walk, run, damage, attack e
death". Na mesma rodada: interruptor da fruta na janela M (feito — ver abaixo).

## Decisões do dono

- **Os 22 animais de malha única** (sem ossos): **rig de verdade no Blender** — esqueleto
  (pernas, coluna, pescoço, cabeça, cauda) com pesos em cada modelo, e as 6 animações
  por tipo de corpo (quadrúpede, ave, saltador, rastejante, voador), adaptadas a cada
  espécie. Feito por grupos, com fotos a cada etapa.
- **Os 7 que já têm ossos** (búfalo, macaco, águia, gorila, harpia, pelicano, ovelha
  animada): os clipes que faltam (dano em quase todos; ataque e morte em vários) **feitos
  no Blender, nos ossos deles**.
- **Ordem**: quadrúpedes primeiro (beagle, corgi, cão, cão de guarda, vira-lata, gato,
  vaca, cavalo, ovelha, cervo, alce, raposa, urso, bisão); depois aves de chão,
  saltadores, rastejante e voadores; por último os 7 com ossos.
- **Fruta no M**: interruptor que desliga TUDO — sem técnicas nem voo E nadando como quem
  nunca comeu; ligar devolve. ✅ feito (`ProgressaoDoPersonagem.fruta_ativa`,
  `fruta_em_uso()`, botão na linha "Fruta" da janela M; salvo no progresso;
  `test_agua` A3c).

## Levantamento (01/10/2026)

| grupo | animais | o que têm |
|---|---|---|
| quadrúpedes sem ossos | 14 | malha única; só balanço de corpo inteiro |
| aves de chão sem ossos | galinha, pintinho, pato | idem |
| saltadores sem ossos | coelho, sapo | idem |
| rastejante sem ossos | lagarto | idem |
| voadores sem ossos | 2 pássaros | idem |
| com ossos | búfalo (completo), macaco, ovelha animada, pelicano, gorila, águia, harpia | faltam dano (6), ataque (4), morte (6) |
| caranguejo | patas articuladas por nós | procedural próprio |

## Como funciona (02/10/2026)

Pipeline, sempre a partir do ORIGINAL sem ossos (`art_src/animais/originais/<id>.glb`,
copiado da loja na 1ª vez — rodar de novo refaz do zero):

    ~/opt/blender/blender -b --python tools/blender/rig_animais.py -- cow [horse ...] [--so-esqueleto]
    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/atualizar_animais_riggados.gd [-- cow ...]
    "$(./find_godot.sh)" --headless --path . --import
    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_clipes_animais.gd -- cow   (GPU)

| peça | o que faz |
|---|---|
| `tools/blender/animais_rig/geometria.py` | aplica a escala, SOLDA a casca (guardando as normais por canto — o chapado) e FATIA por planos: cada corte dá contornos fechados |
| `.../quadrupede.py` | pernas: 4 contornos perto do chão seguidos para cima até fundir no tronco; jarrete = maior dobra da linha de centro; coluna/pescoço/cabeça pelo centro dos cortes transversais acima da barriga; cauda seguida da ponta (dica no perfil) ou marcada à mão. 21 ossos. Pesos por REGIÃO topológica (perna/cauda/tronco) com faixas de mistura nas juntas |
| `.../movimento.py` | poses por quadro: FK no tronco/pescoço/cauda (rotações nos eixos do repouso), IK de 2 ossos nas patas (pé plantado, joelho/jarrete dobrando para o lado do repouso). As 6 ações; morte e empinar "assentam" no chão pela malha deformada |
| `.../fotos.py` | foto dos ossos (cores fixas por osso + legenda) e folha de quadros por clipe |
| `tools/blender/rig_animais.py` | perfis por espécie, exporta `art_src/animais/rig/<id>.glb/.blend` + `manifesto.json` |
| `tools/mapa_ilha/atualizar_animais_riggados.gd` | copia para a loja, remede caixa/SHA, grava `golpe_em` na ficha (loja compartilhada: confere a hora do catálogo) |

Clipes: `idle` (6 s; herbívoro pasta, carnívoro fareja; cão abana o rabo), `walk` e `run`
(passo casado com passeio/corrida da ficha: no jogo o ritmo é `rapidez / passeio` e
`rapidez / corrida`), `damage` (0,5 s), `attack` (cabeçada 0,9 s / mordida 0,75 s /
patada 0,8 s / empinar 1,2 s), `death` (1,4 s, tomba de lado e fica).

Jogo: `AnimadorDeAnimal` ganhou a intenção `dano` (`tomar_dano()`, chamado em
`AnimalDaIlha.take_damage`), ataque/dano duram o clipe, ritmo por passeio e corrida. O
dano do bicho cai no IMPACTO do clipe (`golpe_em` da ficha) e confere o alcance de novo
(afastar-se na preparação esquiva). Rig próprio (osso `raiz`) mede o corpo pela caixa
do catálogo, não pelos ossos.

Qualidade dos pesos (02/10): `rig_animais.py` mede o pior alongamento de aresta em todos
os clipes (conta aresta que mais que dobra; limite 5 % da altura). Também: rótulo de perna
pelo vizinho mais próximo (as coxas do cão se tocam), tudo abaixo de 12 % da altura é pata
(ponta de casco), corte SÓ em aresta não-manifold (cortar superfície contínua abriu buraco
no corgi), topo da perna meio tronco, 3 passadas de suavização. Acima do limite e ACEITOS
à vista: beagle 5,7 % (coxa no galope), alce 6,6 % (ombro), ovelha 7,8 % (franja da lã no
topo da pata), corgi 13 % (ponta da cauda no chão entre as patas, embaixo do corpo).
Custo medido: 0,013 ms de CPU por bicho animado (mixer + ossos; 30 bichos = 0,39 ms).

Decisões técnicas minhas (revisáveis):
- Pastar: pescoço baixa no máximo 62° e a cabeça no máximo 78° abaixo da horizontal —
  passar disso amassa a malha; bicho de pescoço curto (vaca) pasta com o focinho no
  capim alto, não no chão.
- Fronteira Blender/loja: o Blender só escreve em `art_src/`; a loja é do Godot.
- Base do pescoço: herbívoro na cernelha (alcance para pastar), carnívoro 7 % à frente
  (senão o peito sobe junto na mordida); bisão e ovelha 12 % (perfil).
- Investida/recuo escalados pelo comprimento da perna (`Rig.alcance`): perna curta não
  acompanha a investida de um cão de perna longa.

## Etapa 4 feita (02/10)

- Aves de chão (`ave.py`): pescoço seguido por fatias horizontais (o contorno mais à
  frente acima do corpo), 2 pernas; idle bica o chão inclinando o corpo, passo bamboleado,
  corrida inclinada, ataque `bicada`.
- Coelho e sapo: quadrúpede com marcha de salto (`saltar`) e ataque `bote` (o sapo bota
  sem tirar as patas da frente do chão: os dedos da frente e de trás são a mesma malha).
- Lagarto: patas em diagonal com a coluna ondulando em S; idle com "flexões"; perna que
  sai de lado entra na região da perna (`pernas_laterais`).
- Voadores (`voador.py`): asa = 2 ossos (ombro-cotovelo-ponta pelos cortes em X), raiz da
  asa presa ao peito; clipes `idle` (planar), `fly`, `damage`, `attack` (mergulho),
  `death`. O animador planando agora aceita "idle" (águia e harpia seguem no "gliding").
- Estiramento final: todos ≤ 5 %, menos (aceitos à vista) corgi 9 % e cavalo 7 % no
  galope, pato 6 % e sapo 19 % na morte (dedos colados).

## Planejamento de origem da etapa 4 (02/10)

- galinha, pintinho, pato: bípedes, asa colada ao corpo (sem asa separada) — corpo,
  pescoço, cabeça, cauda e 2 pernas (3 ossos); marcha bamboleando, bicar no idle.
- coelho, sapo: o esqueleto de quadrúpede serve; marcha de SALTO (patas de trás juntas).
  Sapo sentado com a pata de trás dobrada: juntas por perfil.
- lagarto: coluna longa ondulando de lado + patas laterais curtas.
- pardal e andorinha: pose de voo, asas abertas — 2 ossos por asa; clipes de voo
  (`fly`, `glide`) no lugar de walk/run, como pede o `AnimadorDeAnimal` (voando/planando).

## Etapas

| # | etapa | estado |
|---|---|---|
| 1 | Pipeline de rig de quadrúpede (vaca) + 6 ações + fotos | ✅ 02/10 — vaca na loja, `test_animais` 0 falhas, folha GPU `cow_godot.png` |
| 2 | Os outros 13 quadrúpedes | ✅ 02/10 — 14 na loja; `test_animais`/`test_pomar_e_doma`/`test_agua` 0 falhas; folhas GPU `<id>_godot.png` |
| 3 | Jogo: dano/ataque/morte/ritmo pelos clipes; teste | ✅ (B6 do `test_animais` reescrito para clipes) |
| 4 | Aves de chão, saltadores, rastejante, voadores | ✅ 02/10 — 8 na loja (`ave.py`, `voador.py`, marchas de salto/rastejo/voo); testes 0 falhas; folhas GPU |
| 5 | Clipes que faltam nos 7 com ossos | ✅ 02/10 — gerados no Godot (decisão do dono); búfalo já completo |

## Etapa 5: levantamento (02/10)

| modelo | tem | falta | ossos |
|---|---|---|---|
| búfalo | idle, walk, gallop, attack_headbutt, death, hitreact | nada | AnimalArmature |
| macaco | idle×6, fastwalk, run, sleep | damage, attack, death | `Spine_00…`, `Arm01_L`, `Foot_L`, `tail.000…008` |
| ovelha animada | idle, walk, trot, run, eat, look, jump… | damage, attack, death | hierarquia ACHATADA (tudo filho de `center_ctrl`) |
| pelicano | idle A/B, walk, flapping, sleep | damage, attack, death (run = walk mais rápido) | `Spine.00x`, `Neck.001…007`, `Shoulder02_L` |
| gorila | idle, walk, trot, run, chestdrum, eat… | damage, attack (chestdrum é exibição), death | Auto-Rig: `spine_01.x`, `arm_stretch.l`… |
| águia, harpia | fly, flapping, gliding, idle, leap, sleep | damage, attack (leap é decolar), death (sleep fazia de morte) | Auto-Rig |

Armadilha: o Blender corta nome de ação acima de 63 caracteres (`Animal_3146_Rig|…|Animal_3146.001`) —
na ida e volta os clipes perdem `monkey_walk`/`monkey_run`. Renomear pelo nome original
lido do GLB antes de exportar, e conferir no Godot que os clipes antigos saem iguais.

### Tentativa no Blender (02/10) — não serve como está

`tools/blender/clipes_riggados.py` importa, renomeia as ações pelo nome do glTF, cria dano/
ataque/morte como deltas sobre o idle e exporta. Os clipes novos ficam bons, mas o arquivo
reexportado sai GIRADO no Godot: a conversão de eixos do Sketchfab mora num nó-junta
(`Armature_deform_01`, −90° em X + translação) que o importador assa no repouso dos ossos e
o exportador não devolve. `tools/mapa_ilha/comparar_clipes_riggados.gd` mede 2 m de desvio
nos clipes antigos. Nada foi para a loja (o macaco da loja é o original, conferido com cmp).

Caminhos: (a) gerar os clipes novos no próprio Godot, numa biblioteca de animação ao lado
do .glb original, que a loja acopla ao instanciar — o arquivo original fica intocado e os
clipes antigos idênticos por construção; (b) continuar no Blender e consertar a conversão
de eixos — mais tempo e risco de diferença sutil nos clipes antigos.

### Etapa 5 feita no Godot (02/10, decisão do dono: "Gerar no Godot")

    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/clipes_dos_riggados.gd [-- <ids>]

- `tools/mapa_ilha/clipes_dos_riggados.gd`: para cada modelo, toca o clipe-base (idle; nas
  aves, `fly`), calcula `damage`, `attack` e `death` como deltas por papel de osso (mapa
  por modelo), nos eixos do MODELO convertidos para o espaço do esqueleto (o do Sketchfab é
  girado e em escala 0,01), e assenta a morte no chão com skinning na CPU. Grava
  `mapas/modelos/<id>.clipes.res` (AnimationLibrary) e o `golpe_em` na ficha.
- `BibliotecaDeModelos.instanciar` acopla essa biblioteca como "extra" ("extra/damage");
  o `.glb` original não muda — clipes antigos idênticos por construção.
- Ataques: macaco tapa (0,33 s), ovelha animada cabeçada (0,42), pelicano bicada (0,30),
  gorila soco no chão com os dois braços (0,5), águia/harpia garras (0,45). Morte de ave
  grande: cai de barriga com as asas abertas (de lado ficava apoiada na ponta da asa).
- Ovelha animada: rig ACHATADO (pescoço e cabeça não são pai/filho) — o perfil dá uma
  hierarquia virtual só para propagar os deltas.
- `AnimadorDeAnimal._clipe_por_chave`: nome exato > começo > contém, ignorando o prefixo
  da biblioteca; `test_animais` confere o gorila (extra/* e o andar original).
- A tentativa de reexportar pelo Blender foi apagada (`tools/blender/clipes_riggados.py`);
  a conferência osso a osso `tools/mapa_ilha/comparar_clipes_riggados.gd` fica para qualquer
  modelo que um dia precise passar pelo Blender.
