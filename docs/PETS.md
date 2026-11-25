# Pets do Modo História

Estado em 30/09/2026. Dois pets: o **caranguejo grande** (sessão do caranguejo, manhã) e a
**gaivota** (noite), com **comportamentos** escolhidos pelo menu da tecla **B** e um
**inventário** na tecla **N**. Checkpoints: `docs/PET_CARANGUEJO_CHECKPOINT.md`,
`docs/PET_GAIVOTA_CHECKPOINT.md`.

## Como se joga

| tecla | o que faz |
|---|---|
| **N** | inventário: aba **PETS** (Tirar / Guardar cada pet, modo atual, vida, "fora: n de 6"), aba **FRUTAS** (frutas do pomar; Segurar põe na mão) e aba **PESCA** (vazia até a pesca existir) |
| **Y** | com fruta do pomar na mão: tenta domar o herbívoro a até 3 m (35 %, gasta 1 fruta) |
| **B** | menu de comportamento do pet **mais perto** (até 20 m): **1** Livre · **2** Seguir · **3** Em guarda · **4** Agressivo. B ou ESC fecha |

O personagem **já começa** com a gaivota e o caranguejo guardados (decisão do dono; um
vendedor vai vender outros depois). Pets possuídos e o modo de cada um ficam **salvos no
progresso**; ao abrir o jogo os pets começam guardados. Tirar/guardar saiu da janela M.

## Pets domados, limite e morte (01/10/2026)

Pedido do dono: frutas do pomar **domam herbívoros**, que viram pets. Detalhes em
[FRUTAS_E_DOMA_CHECKPOINT.md](FRUTAS_E_DOMA_CHECKPOINT.md).

- **Doma:** inventário **N › FRUTAS › Segurar** põe a fruta na mão; **Y** perto (≤ 3 m) de
  um herbívoro domável tenta domar — gasta 1 fruta, **35 %** de chance. Com fruta na mão
  o herbívoro não foge nem ataca (a não ser que tenha apanhado há pouco).
- **Domáveis:** vaca, cavalo, búfalo, bisão, coelho, cervo, alce, ovelha, carneiro,
  macaco, galinha, pintinho, pato (`FichaDeAnimal.domavel`). Chefes nunca.
- **Quantos quiser, no máximo 6 fora** (`Companhia.MAX_FORA`). Domado com 6 já fora vai
  direto para o inventário.
- **Um registro por pet** no progresso (`pets`: id → espécie, nome, modo). Vários da mesma
  espécie ("Coelho", "Coelho 2"). Os iniciais têm id = espécie: saves antigos valem.
- **Morte permanente** (vale para todos, gaivota e caranguejo também): vida 40 (gaivota),
  120 (caranguejo), a da ficha (domados). Só bicho bravo fere pet: quem é atacado por um
  pet **revida contra o pet**. Morreu → sai do progresso de vez e o HUD avisa.
- O domado (`src/historia/animais/pet_domado.gd`) é o mesmo corpo/animação do animal da
  ilha com o cérebro dos 4 modos. Quem tem dano na ficha (búfalo, bisão, macaco) luta em
  guarda/agressivo; os mansos só acompanham.

## Os comportamentos (`src/historia/pets/modo_do_pet.gd`)

| modo | o que o pet faz |
|---|---|
| **Livre** | vive por conta própria em volta de onde ficou livre (onde saiu do inventário ou recebeu a ordem) |
| **Seguir** | acompanha o jogador; não ataca |
| **Em guarda** | acompanha e ataca inimigo a até **6 m do jogador** |
| **Agressivo** | acompanha e caça inimigo a até **15 m do jogador**, voltando depois |

Inimigo = grupo `enemy` vivo e visível (o adormecido, esperando renascer, não conta).
Modo inicial: gaivota **livre** (pedido do dono: só segue quando mandada), caranguejo
**seguir** (o que ele fazia antes dos modos).

## A gaivota (`src/historia/pets/gaivota.gd`)

Low poly de verdade: **326 triângulos**, faces chapadas, manto cinza, ventre branco, pontas
pretas, bico amarelo com a mancha vermelha. Fonte: `tools/blender/gaivota_pet.py` →
`assets/models/pets/gaivota.glb` (+ `art_src/pets/gaivota.blend`). Juntas são vazios
nomeados (Corpo, Cabeca, Cauda, Asa_E/D → Ponta_E/D, Perna_E/D); a animação é procedural
(`animador_gaivota.gd`): batida com a ponta atrasada, planeio, inclinação na curva, freio de
pouso, mergulho, asas dobradas no chão, olhar em volta e bicar o chão.

| estado | quando |
|---|---|
| VOANDO | livre: troca de ponto em volta de casa (4–10 m, 4–8 m de altura); 10–20 s no ar |
| POUSANDO | chega por cima de um chão firme e desce freando |
| NO_CHAO | anda passinhos, olha, bica; 5–12 s; **livre: o jogador a menos de 3,5 m a espanta** |
| DECOLANDO | batida forte para cima |
| SEGUINDO | atrás e acima do dono andando; circula (3,2 m) com ele parado; pousa ao lado se ele ficar 6 s parado |
| MERGULHANDO / SUBINDO | em guarda / agressivo: desce em linha, **bica (8)**, sobe; recarga 1,6 s |

Sem navmesh: voa reto com curva limitada (2,4 rad/s), escorrega em parede e não desce a
menos de 1,2 m do chão — ou da **água do oceano**, que é só visual (sem colisão): ela lê o
`nivel` do nó `Oceano` e nunca acha "chão" para pousar no mar.

## O caranguejo com modos (`src/historia/pets/caranguejo.gd`)

Livre: passeia devagar entre pontos a até 5 m de casa, com pausas de 3–7 s. Em guarda /
agressivo: vai até o inimigo e **belisca** (14 de dano, alcance 2,4 m, recarga 1,3 s): vira
as pinças para ele, estoca e as garras sobem e avançam (`animador_caranguejo.beliscar`).

## Onde mora cada parte

| parte | arquivo |
|---|---|
| espécies (nome, cena, modo inicial) | `src/historia/pets/catalogo_de_pets.gd` |
| regra dos modos e escolha de alvo | `src/historia/pets/modo_do_pet.gd` |
| pets fora do inventário (tirar/guardar, grava o modo) | `src/historia/pets/companhia.gd` |
| posse e modo salvos | `ProgressaoDoPersonagem.pets` / `.pesca` |
| inventário N | `src/ui/InventarioDaHistoria.gd` |
| menu B | `src/ui/MenuDeComportamento.gd` |
| teclas, pet mais perto | `src/ui/HistoriaHud.gd` (`ligar_pets`, `pet_mais_perto`) |
| visual compartilhado dos painéis | `src/ui/estilo_da_historia.gd` (a janela M usa o mesmo) |

## Testes

- `tools/dev_tests/test_pets_comportamento.gd` — 32 checagens: inventário, gaivota livre
  (voa/pousa/anda/decola sem seguir), fuga, menu B, modo salvo, seguir, em guarda (controle:
  12 m não é alvo) e agressivo, caranguejo livre e beliscando, guardar.
- `tools/dev_tests/test_pet_caranguejo.gd` — 24 checagens, agora pelo N.
- Capturas: `art_src/pets/gaivota/` (prévias e poses) e `art_src/pets/gaivota/jogo/`.

## Limites conhecidos

- Sem pio da gaivota (só o sopro de asa ao decolar e o impacto da bicada).
- Inimigos não revidam os pets (o boneco de duelo mira só o jogador).
- Pet colocado pelo editor (o caranguejo da aba pets) não é do inventário: o modo dele não
  é salvo.
- Sem navmesh: gaivota e caranguejo não contornam obstáculos grandes.
