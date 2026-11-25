# Sistemas do Mine Piece na campanha (plano e checkpoint, 18/10/2026)

Pedido do dono: "trocar os navios atuais pelos navios importados do mod, tornar os personagens
que foram adicionados do mine piece recrutaveis todos os personagens humanoides quando derrotados
ou vida zerada tem a opção de recrutar ou finalizar com exeção de bosses. adicionar como sempre
antecessor ao pão no inventário o botão de agua. adicionar monitor de fps. trazer de skills one
piece o formato de subida de nivel basicamente o XP requerido para cada nivel e os nivels, bem
como o sistema de raid que poderá ser iniciado ao selecionar a bandeira preta e segurar Z. deixar
no modo história o jogador começar sem nenhum pet. adicionar as frutas e arvores novas para as
frutas que foram adicionadas através do mine piece"

Premissa corrigida (com o dono): a fonte de nível e raid é o **Mine Piece** (o mod tem raid pela
bandeira e nível pela recompensa); este projeto é o Skills One Piece.

## Decisões do dono (18/10/2026)

- **Nível:** curva do mod no XP — mantém barra de XP, tetos por ilha, missões 8–10 e 5 pontos por
  nível; troca a tabela pela do mod e o XP por abate pela fórmula de recompensa do mod.
- **Raid:** como no mod — onde o jogador estiver, ondas da região, chefe na última, recompensa;
  bandeira preta selecionada + segurar Z.
- **Navios:** os 12 do mod à venda; os 3 atuais (bote, chalupa, galeão) saem da venda.
- **Árvores/frutas:** arena, como as outras frutas (Pika, Hie, Moku, Nikyu Mine Piece).

## Decisões minhas (declaradas)

- **Sem pet ao começar:** só jogo novo; save existente fica como está.
- **Água:** slot "agua" sempre antes de "comida"; consome `agua_potavel` (provisão que já existe).
- **FPS:** contador pequeno no canto, arena e história.
- **Recrutar:** o mecanismo de hoje (bandeira na mão + F recruta; sem bandeira F finaliza),
  estendido aos `mp_*` humanoides; chefes do mod (`ficha.chefe`) só finalizam.

## Fontes do mod (descompilado, mesmo SHA do JAR)

- Nível: `UpdateBountyProcedure.java` (nível = f(recompensa), faixas 10 mil / 100 mil / 1 milhão).
- Ganho por abate: `WhenEntityDieProcedure.java` (fama da vítima × hakis × dificuldade; teto de
  recompensa por fama).
- Raid: `RaidFlagRightclickedProcedure`, `RaidGetLevelProcedure`, `RaidEastBlue1..8/20`,
  `RaidEntitySpawnProcedure`, `RaidBossAppearanceProcedure`, `RaidFinishProcedure`.

## Etapas

| # | Entrega | Validação |
|---|---|---|
| F1 | Começar sem pet | teste: progresso novo sem pets; save antigo mantém |
| F2 | Água antes do pão | teste da barra: ordem e consumo |
| F3 | Monitor de FPS | captura |
| F4 | Árvores das 4 frutas MP na arena | teste: definições presentes e plantáveis |
| F5 | Recrutar `mp_*` (exceto chefes) | teste: derrota → recrutar/finalizar; chefe só finaliza |
| F6 | Curva de nível + XP por abate do mod | teste: tabela e ganho |
| F7 | 12 navios do mod à venda, 3 atuais fora | teste: loja, compra, navegar e ficar de pé no convés |
| F8 | Raid (bandeira + Z) | teste: inicia, ondas, chefe, recompensa, fim por morte |

## Checkpoint

- **18/10 12:30:** levantamento e decisões. Próximo: F1–F3.
- **18/10 ~13:40:** F1–F8 implementadas.
  - F1 sem pet: `progressao.pets := {}` (save antigo mantém); `test_pomar_e_doma` 44/0, `test_tripulacao` 54/0 (premissas
    da gaivota inicial ajustadas).
  - F2 água: slot `agua` antes de `comida`, bebe `agua_potavel` (botão direito), ícone `assets/ui/barra/agua.svg`;
    `test_barra_de_itens` 23/0, `test_status_recrutamento` 34/0 (+ caso da água), sobrevivência 23+16+50/0.
  - F3 FPS: `src/ui/monitor_de_fps.gd` criado pelo `GameFlow` (fora do headless), F3 liga/desliga; captura.
  - F4 árvores: 4 definições Mine Piece em `TreeAndFruitGenerator`, plantadas ALÉM das 11 (mapa da arena igual);
    `test_arvores_mine_piece` 13/13 (pegar equipa cada fruta).
  - F5 recrutar: já ligado pelo trabalho de status/recrutamento; faltava a exceção dos chefes (`ficha.chefe`);
    `test_recrutar_mine_piece` 9/9.
  - F6 nível: `src/historia/recompensa_mine_piece.gd` (curva do mod e XP de abate pela fórmula de recompensa;
    sem o teto anti-farm — os tetos de ilha fazem o papel); todos os abates da campanha usam a mesma regra.
    `test_progressao` (reescrito), `test_animais`, `test_bandidos_e_missao` 27/0.
  - F7 navios: 12 do mod à venda (ficha pelo tamanho; perfil de navegação do conversor em
    `mapas/modelos/<id>.perfil_navio.json`), 3 antigos fora da venda (saves mantêm). Convés andável = malha
    `Colisao` num AnimatableBody3D `top_level` movido pelo barco (leva o jogador: desvio ≤ 0,16 m navegando e
    virando). Navios ANCORADOS (grupo `_ancorados`) são cenário, não pilotáveis, e ficam no desenho por distância.
  - F8 raid: `src/historia/raid/raid.gd` (East Blue 1–8 + EX como no mod; Grand Line avisa);
    `test_raid_mine_piece` 14/14. Correções achadas pelo teste: autoria real do golpe (`autor_do_dano`) e
    `DamageZone` com autor liberado.
  - Não atribuídas (pré-existentes de outras frentes): `test_modo_historia` "o Civil não tem Akuma no Mi" (estilo
    base equipado) e "vida máxima vira 30" (vida por ponto mudou no trabalho de atributos).

## Pendências e gatilhos

- **Raids da Grand Line:** precisam dos personagens da Grand Line do mod (gatilho: extraí-los).
- **Calado de colisão 1,5 m:** navio grande no raso pode mostrar casco atravessando o fundo (visual).
- **Teto anti-farm do mod não portado:** rever se farm de inimigo fraco levar ao teto da ilha em < 1 h.
- **Haki fora da fórmula de XP:** entra quando houver haki na campanha.
- **Não jogado à mão.**
