# Dados: criar estilo, golpe e pose

Nenhum número de combate mora em código. Um estilo novo é um `.tres` novo; um golpe
novo é um `GolpeDirecional` dentro dele; uma pose é uma lista de `ChaveDePose`.

> ⚠️ **Padrões NEUTROS.** Todo campo destes recursos nasce em zero/false de propósito:
> o Godot NÃO grava no `.tres` um campo igual ao padrão do script, então um padrão
> "bonito" no código viraria um número invisível no arquivo. Se um valor sumir do
> `.tres`, ele vira zero e a validação reprova — que é o comportamento desejado.

## Criar um estilo

1. Duplique `estilos/boxe.tres` (é a fonte canônica dos números do boxe).
2. Preencha: `id`, `nome`, os **4 golpes** (um por direção), o ritmo (`buffer`,
   transições, `guarda_apos_acao`), o grupo Defesa, o grupo "Aparo, riposte e finta",
   o grupo "Pés de apoio", a `guarda`, as `maos` e as poses de reação.
3. Rode `test_pose_de_combate.gd` e `test_executor_corpo_a_corpo.gd`: os dois carregam
   o estilo e cobram `validar()`, incluindo as invariantes de §REGRAS.
4. Para trocar o estilo em jogo, mude `ModoHistoria.ESTILO_CORPO_A_CORPO` (ou passe
   outro `EstiloCorpoACorpo` para `executor.montar`).

## Criar um golpe (`GolpeDirecional`)

| campo | o que é |
|---|---|
| `direcao` | FRENTE / PARA_ESQUERDA / PARA_DIREITA / DE_CIMA (exatamente um por direção) |
| `preparo`, `ativo`, `recuperacao` | as três fases, em segundos |
| `dano`, `hitstun`, `pesado`, `dano_de_postura`, `aparavel` | o que ele faz em quem recebe |
| `fator_movimento_*`, `giro_max_*` | quanto se anda e se gira em cada fase |
| `avanco` | empurrão para a frente (m) entre metade do preparo e o fim do ativo |
| `efetor`, `raio_de_contato` | qual nó do rig machuca (ex. `Hand_L`) e com que raio |
| `empurrao`, `hitstop` | knockback e congelamento no acerto |
| `chaves` | as poses-chave, em ordem de tempo |

A hitbox NÃO tem números próprios: ela varre o efetor real, quadro a quadro, durante o
ATIVO. Golpe que "não alcança" se conserta na POSE (ou no `avanco`), não numa caixa.

## Uma pose-chave (`ChaveDePose`)

Duas linguagens, misturadas na mesma chave:

- **Alvo** (metros, espaço do corpo: origem nos pés, frente = −Z, +X = direita do
  personagem): `mao_direita`/`mao_esquerda` (o punho, nó `Wrist_*`), `cotovelo_*` (para
  onde o cotovelo aponta), `pe_direito`/`pe_esquerdo` (o tornozelo), `joelho_*` e
  `quadril` (deslocamento do nó `Torso`).
- **Rotação** (graus somados ao repouso; todos os papéis do `base_v2` têm repouso zero):
  `rotacoes = {"SpineMid": Vector3(...)}`. Convenção medida do rig:
  - `x > 0` leva a ponta de um membro que aponta para BAIXO à frente (e a de um que
    aponta para cima, para trás);
  - `y > 0` leva o lado +X (ombro/quadril direito) para a FRENTE;
  - `z > 0` sobe o lado +X.
  - Exceção declarada: com pés por alvo, `Foot_*` é a orientação do pé em relação ao
    CORPO (não à canela) — `y` abre a ponta, `x < 0` ergue o calcanhar; `Ball_*`
    (antepé) continua sendo rotação local e desfaz a inclinação para a sola ficar no chão.

Uma chave só escreve o que muda: o resto é completado pela **guarda do estilo**
(mãos, pés, quadril e rotações). `usa_mao_*` e `usa_pes` ligam cada grupo.

`fase` + `fracao` dizem QUANDO a chave acontece (ex.: ATIVO 0,5 = meio do ativo), e
`curva` diz como o trecho que CHEGA nela distribui o tempo (SUAVE, ACELERA para o
contato, DESACELERA para o follow-through, LINEAR).

Entre chaves há Hermite com tangente por diferença finita: a mão PASSA pela chave do
meio com velocidade, em vez de parar nela. A linha do tempo é sempre
`guarda → chaves → guarda`, e é isso que deixa dois golpes emendarem sem estalo.

## Pé de apoio (grupo "Pés de apoio")

O alvo do pé vem no espaço do corpo, mas o corpo anda. Então:

- pé com alvo até `altura_de_apoio` = **no chão**: trava no MUNDO, sob o antepé
  (`Ball_*`), e o corpo avança e gira sobre ele;
- pé acima disso = **no ar**: segue a pose (é um passo autorado, como o do jab);
- travado longe demais do que a pose pede (`soltar_pe_a`) ou fora do alcance da perna:
  dá um passo em arco (`duracao_do_passo`, `altura_do_passo`) até o lugar novo;
- **um pé de cada vez**: com o outro no ar, o pé segura a base mesmo passando do ponto;
- corpo EMPURRADO (reação, quebra, rebote) não trava nada: os pés derrapam;
- andando de verdade, as pernas voltam para a marcha do animador.

Autorar compensação de avanço nos dados seria errado: o avanço para quando o golpe
conecta. Por isso o travamento é no mundo, e não nos números.

## Mãos (dedos)

`maos` (no estilo, não na chave) é a forma dos dedos durante toda ação — no boxe, o
punho fechado; num estilo de espada, a pega. Fica no estilo porque a mão não muda de
forma no meio do golpe, e 30 papéis a mais em cada chave seriam 30 curvas por quadro.
No `base_v2`, `rotation.x` NEGATIVO fecha os dedos para dentro da palma (medido com
close-up em 17/09).

## Autoria reproduzível

O `.tres` é canônico, mas os números de corpo inteiro do boxe também existem como
script comentado, golpe a golpe, em
`~/dev/sop-snapshots/2026-09-16-combate-historia/fases/fase6/autorar_boxe_fase6.gd`
(valores absolutos: rodar de novo dá o mesmo arquivo). Ele é o lugar certo para
reautorar em bloco; ajustes pontuais podem ir direto no `.tres`.

## Como saber se ficou bom (medição, não "no olho")

| pergunta | instrumento |
|---|---|
| a IK alcança? o punho chega onde a chave pede? | `medir_pose_combate.gd` → "pior erro da IK" |
| o golpe é perigoso na hora certa? | mesma sonda → "pico de velocidade … na fase ATIVO" |
| o pé patina? afunda? quantos passos? | mesma sonda → deslize travado/solto, passos, sola |
| o defensor LÊ a direção? | `medir_leitura_combate.gd` → vetor e ângulo da carga na câmera real |
| como isso aparece em 3ª pessoa? | `capturar_pose_combate.gd` (fotos) |
