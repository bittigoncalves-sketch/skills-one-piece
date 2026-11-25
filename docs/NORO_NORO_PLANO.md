# Noro Noro no Mi — teste do Skills Builder (06/10/2026)

Pedido do dono: "iniciar teste do skill builder construindo uma nova fruta a noro noro no
mi que permite desacelerar qualquer ser atingido pelo raio por 3 segundos, apenas a skill
Z o inimigo fica 5 vezes mais lento, criar pose de carregamento do ataque, pose para
segurar o ataque, pose para soltar o ataque e pose final, intercalar animações entre as
poses e fazer a vfx para tal."

## Decisões do dono

| tema | decisão |
|---|---|
| como chega ao jogo | **fruta própria do Builder**: o Builder ganha "fruta" (nome + skills Z/X/C/V); a Noro aparece como fruta de verdade (vendedor na história, menu do M na arena) |
| VFX | **fótons cintilantes**: feixe rosa/lilás com núcleo branco ondulando devagar e soltando cintilas; o lento ganha cintilas orbitando e rastro fantasma |
| poses | **editor de poses no Builder**: girar as juntas na prévia, salvar a pose na skill, a timeline encadeia as poses com transição |
| lentidão | **movimento e ações** a 1/5 por 3 s, em jogador, boneco e animais; inimigo parado do mapa: skills e recarga mais lentas |
| teclas | **só a Z** (Noro Noro Beam) por enquanto |

## Fatias

| # | fatia | pronto quando | estado |
|---|---|---|---|
| 1 | Poses: dados + aplicação + transição | pose (papel → rotação) na skill; prévia e jogador aplicam; blocos de Pose seguidos se misturam | **feito** — `poses_de_skill.gd`, contrato (`poses`, campos Pose/Transição/Pulso), prévia, executor, `ProceduralAnimator`; `test_poses_do_builder` 16/16 (jogo × prévia < 4°) |
| 2 | Editor de poses no Builder | seção Poses: criar/renomear/apagar, juntas X/Y/Z, prévia ao vivo | **feito** — seção Poses (Nova/Duplicar/Espelhar/Apagar, 13 juntas × XYZ), lista de poses no bloco de Animação; `test_editor_de_poses` 12/12 + foto |
| 3 | Ativação "carregar, segurar e soltar" | a timeline pára num ponto enquanto a tecla está apertada; soltar continua; soltar antes cancela | **feito** — modo "Carregar e soltar" (ponto de segurar, segurar máx.), prévia, executor, kit (tecla + rede `pedir_soltar_do_kit`), IA solta em 0,6 s; `test_segurar_e_soltar` 14/14 |
| 4 | Lentidão de movimento e ações | fator no tempo do corpo atingido (andar, golpes, animação, IA, skills) + aura visual | **feito** — `lentidao.gd` (rede p/ jogador), `aura_de_lentidao.gd` (cintilas + rastro fantasma), ganchos em Player/animador/corpo a corpo/boneco/animal/IA/executor; `test_lentidao_noro` 11/11 |
| 5 | VFX do raio | estilos Carga, Feixe e Fótons; hitbox do feixe ao longo da frente | **feito** — `visual_de_skill.gd` (tubos/esferas com brilho suave, fitas helicoidais de cintilas no Feixe, piso de brilho 0,3 para o feixe aparecer de ponta), campos opcionais Altura/À frente/Comprimento no VFX |
| 6 | Frutas do Builder | catálogo de frutas; skill escolhe a fruta; a fruta vira fruta do jogo (vendedor, M) | **feito** — `frutas.json` em `SkillsPublicadas`, campo Fruta + "Criar fruta" na Identificação, vendedor/inventário/save na história, botão `Fruta_<id>` no menu do M; `test_frutas_do_builder` 22/22 |
| 7 | Noro Noro no Mi | feita NO Builder (poses pelo editor), publicada como fruta, validada em jogo | **feito** — `tools/criar_noro_noro.gd` opera o editor e publica em `res://mapas/skills`; `test_noro_noro` 12/12 (braço: carregar 15°, segurar 61°, soltar 89°, final 37°; boneco e vaca a 0,2 por ~3 s, sem dano); fotos `capturar_noro_noro.gd` (câmera do jogo + lateral) |
| 8 | Fechamento da Z (pedido de 06/10, "só fechar a Z") | segurar/soltar e lentidão valem em rede; log sem erro | **feito** — fase Noro em `net_kit_host_probe`/`net_kit_client_probe` (host 6/6: troca de fruta pelo servidor, host a 0,2, sem dano; cliente: livre enquanto segura, 0,2 + aura chegando pela rede depois de soltar); erro `get_meta(k, null)` por quadro no animador corrigido |

**Arquivos publicados (fora do git até o dono pedir commit):** `mapas/skills/noro_noro_beam.json`, `mapas/skills/frutas.json`, `mapas/skills/kit.json`.

**Fora do escopo (decisão do dono):** X, C e V da Noro. Gatilho para voltar: pedido explícito; a proposta era X = corte com o feixe, C = espelho que reflete o raio, V = onda de fótons em área.

Checkpoint: este arquivo é atualizado a cada fatia (estado, arquivos, testes).
