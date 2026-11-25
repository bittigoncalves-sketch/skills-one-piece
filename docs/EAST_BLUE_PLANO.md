# Ilha do East Blue — personagens do Mine Piece (plano e checkpoint, 17/10/2026)

Pedido do dono: "realizar a extração dos inimigos, personagens e npcs do east blue, uma nova
ilha deve ser criada e eles devem ser colocados lá cada um com o comportamento original,
poderes, ataques e aparência que eles têm no minecraft; mais tarde serão alterados".

## Decisões

**Do dono (17/10/2026):**
- **Aparência:** a do Mine Piece, como PROVISÓRIA ("mais tarde, antes de lançar, vou
  recalibrar tudo"). Os `.glb` convertidos ficam FORA do git (`.gitignore`: `mapas/modelos/mp_*`);
  o conversor os refaz a partir do JAR local. Em outra máquina o catálogo mostra o marcador de
  modelo ausente. Trocar pela arte própria = trocar o `.glb` (mesmo id).
- **Ordem:** todos de uma vez.
- **Ilha:** uma ilha com zonas por bando.

**Minhas, declaradas (o dono pode trocar):**
- **Elenco = o do mod:** raids 1–8 e EX do East Blue + quem nasce no East Blue + aliados
  da saga. 41 personagens (`docs/referencias/mine_piece/east_blue/personagens.json`). Fora:
  `Zoro1` (versão Grand Line), Mihawk (o mod o trata como Shichibukai, não East Blue).
- **Ilha:** "Ilha do East Blue", teto de nível 30, a LESTE da Ilha dos Macacos, centro em
  (3000, 0), placa 384 × 384 m. Zonas: bandidos (Higuma), Alvida, Shells Town (Marinha 153),
  Orange Town (Buggy), Vila Syrup (Gato Preto), Baratie (Krieg), Arlong Park, Loguetown,
  acampamento do Ruivo (Shanks, o "Raid EX") e o porto com os aliados.
- **Escala:** a vida da história é a do Minecraft (jogador nível 1 = 20). Vida, dano e
  armadura do mod entram 1:1; força e resistência viram multiplicadores pela fórmula do mod
  (dano × (1 + 0,333 × nível de força); resistência −20 %/nível). Balancear é depois.
- **Comportamento:** porta do laço do mod (decide a cada 10 tiques = 0,5 s): tabela de
  técnicas própria de cada IA (chance, distância, vida, recarga) e, senão, o ataque comum
  sorteado pelas tags (salto, investida, golpe por cima, veloz, nado, rifle). Hostilidade e
  alvos como no mod (quem ataca jogador, quem ataca pirata/marinha).
- **Técnicas:** cada técnica do mod vira uma skill do Builder (`mapas/skills/mpeb_*.json`,
  Usuário Chefe/Inimigo, "Quem usa" = id do personagem), gerada por ferramenta a partir da
  leitura do procedimento (dano, alcance, duração, projétil/área/investida). O cérebro lança
  pelo `ExecutorDeSkill`, como o `UsuarioDeSkills`.

## Arquitetura

| Parte | Onde | O que faz |
|---|---|---|
| Extrator | `tools/mine_piece/extrair_east_blue.py` | lê o descompilado, gera a ficha de dados |
| Conversor | `tools/mine_piece/geo_para_glb.py` | `.geo.json` + roupas + arma + textura + animações → `.glb` |
| Catálogo | `mapas/modelos/catalogo.json` (`mp_*`, categoria `east_blue`) | peça do editor; comportamento `mine_piece` |
| Corpo | `src/historia/east_blue/personagem_mine_piece.gd` | CharacterBody3D: modelo, animação, vida, dano |
| Cérebro | `src/historia/east_blue/cerebro_mine_piece.gd` | laço do mod |
| Ligação | `src/historia/east_blue/personagens_east_blue.gd` | troca as peças por personagens vivos |
| Técnicas | `tools/mine_piece/criar_tecnicas_east_blue.gd` → `mapas/skills/mpeb_*` | uma skill por técnica |
| Ilha | `tools/mapa_ilha/gerar_ilha_east_blue.gd` + `ilhas.gd` | placa, zonas, construções, personagens |

## Etapas e validação

1. Extração — ficha de dados de 41 personagens. ✅ (17/10)
2. Conversor — 41 `.glb`; captura lado a lado com a textura para conferir UV, frente e escala.
3. Corpo + cérebro — teste headless: persegue, usa técnica pela tabela, toma dano, morre e renasce.
4. Técnicas — uma skill válida por técnica; teste: cada uma acerta um alvo.
5. Ilha — placa, zonas e peças; teste: os 41 nascem nas zonas certas; capturas por zona.

## Como refazer tudo (do JAR local)

```bash
python3 -I tools/mine_piece/extrair_east_blue.py        # ficha factual (docs/referencias/.../personagens.json)
python3 -I tools/mine_piece/resumir_tecnicas.py <Proc...> > docs/referencias/mine_piece/east_blue/tecnicas.json
python3 -I tools/mine_piece/gerar_dados_east_blue.py     # mapas/east_blue/personagens.json (dados de jogo)
python3 -I tools/mine_piece/geo_para_glb.py              # build/mine_piece/mp_*.glb (53 modelos)
G="$(./find_godot.sh)"
$G --headless --path . --script tools/mine_piece/registrar_na_loja.gd [-- --forcar]
$G --headless --path . --script tools/mine_piece/criar_tecnicas_east_blue.gd   # mapas/skills/mpeb_* (37)
$G --headless --path . --script tools/mapa_ilha/gerar_ilha_east_blue.gd       # a ilha no mapa vivo
$G --headless --path . --import
```

## Decisões declaradas na implementação (o dono pode trocar)

- **O jogador conta como pirata de bando próprio:** marinha, bandidos e os bandos do East Blue
  o atacam; os "aliados" (tag `group_1` do mod: Luffy, Zoro, Sanji, Yosaku, Johnny, o bando do
  Shanks) nunca começam a briga, só revidam.
- **Brigas entre personagens por facção desligadas** (`CerebroMinePiece.BRIGAS_ENTRE_FACCOES`):
  no mod marinha e piratas se atacam; aqui só o revide entre eles, para as zonas não se
  esvaziarem sozinhas. Golpe de alguém do mesmo bando não fere (LogicAttack do mod).
- **`level_power >= N` conta como cumprido** (no mod o raid sobe o nível); **"contra alvo forte"**
  = o alvo tem ao menos metade da vida máxima do atacante.
- **Renascer:** 60 s; chefes (Higuma, Alvida, Morgan, Buggy, Kuro, Krieg, Arlong, Smoker,
  Shanks) 300 s. Barra no topo da tela para os chefes; os outros, barra de criatura "N30".
- **XP:** a regra dos animais (vida e dano do soco com a força).
- **Animação:** o cérebro toca o clipe ORIGINAL do modelo (`mapas/east_blue/animacoes.json`);
  as skills `mpeb_*` só têm acerto, projétil, movimento, VFX, som e câmera.

## Estado (17/10/2026)

| Etapa | Resultado |
|---|---|
| 1. Extração | 41 personagens + pirata homem-peixe; 33 técnicas resumidas |
| 2. Conversor | 53 `.glb` (41 + 12 peles de pirata), 27 MB, fora do git; capturas `art_src/validation/east_blue/l*_modelos_*.png` |
| 3. Corpo + cérebro | `test_east_blue_personagens` 11/11 |
| 4. Técnicas | 37 skills `mpeb_*` válidas no `DadosSkill.validar` |
| 5. Ilha | 146 peças (36 blocos, 28 de praia, píer, 17 construções, 63 personagens); `test_ilha_east_blue` 7/7; capturas `art_src/validation/east_blue/ilha_*.png` e `perto_*.png` |

Regressão: `test_ilha_dos_macacos` passou a esperar um fundo do mar por ilha do cadastro (era
"2"); `test_cadeia_do_guarda` 46/0, `test_lod_das_ilhas`, `test_missao_madeira_reset`,
`test_kit_do_builder_historia` 15/0, `test_npcs_e_lojas` 54/0, `test_nikyu_nikyu` 14/0,
`test_noro_noro` 12/0.

## Pendências e limites conhecidos

- **Balanceamento:** números do mod 1:1. O Buggy (força 2) derruba um jogador de nível 1 (20 de
  vida) em dois socos; o Shanks com armadura 20 + resistência 3 tira ~84 % do dano. É uma ilha
  de teto 30 — recalibrar depois, como o dono pediu.
- **Fiel com simplificação:** cada técnica do mod virou uma skill do Builder com o dano, alcance
  e duração lidos; o desenho do efeito usa os VFX do Builder (não as entidades do mod). Os
  golpes de deslocamento e o nado dos homens-peixe (AIFish) não foram portados.
- **Não jogado à mão:** validação por testes headless e capturas; falta sentir em partida.
- **Erro pré-existente exposto:** "Lambda capture at index 0 was freed" aparece quando o
  JOGADOR morre (sem morte do jogador, 0 ocorrências) — fora do código do East Blue.
- **Outra máquina:** sem os `.glb` (fora do git) o catálogo mostra o marcador de modelo
  ausente e o personagem nasce como cápsula colorida pela facção; a IA funciona igual.

## Checkpoint

- **17/10 15:55:** etapa 1 feita. Próximo: conversor.
- **17/10 ~17:00:** etapas 1–5 feitas e validadas (ver Estado). Próximo: o dono jogar a ilha
  e decidir balanceamento, brigas entre facções e a troca da arte provisória.
