# Plano de equilíbrio de combate

## Objetivo

Diminuir a diferença de dano entre Z, X, C e V da **mesma fruta** sem apagar
as funções distintas de cada tecla. Hoje o contrato global vai de teto 200 no
Z a 768 no V: uma razão de 3,84×. Em um jogo em que vida base é 2048 e quedas
matam instantaneamente, esse salto torna a escolha de skill mais importante
que mira, posição e contra-jogo.

O alvo desta revisão é uma progressão máxima de aproximadamente **1 : 1,6 :
2,4 : 3,5**. O V continua sendo a opção de maior impacto, mas não pode ser
quase quatro Zs garantidos contra o mesmo alvo.

## Orçamento por slot

| Slot | Papel | Teto atual | Faixa proposta | Contrapartida obrigatória |
|---|---|---:|---:|---|
| Z | pressão/abertura | 200 | 160–192 | alcance, cadência ou risco de aproximação |
| X | confirmação/punição | 256 | 256–288 | preparação curta, direção previsível ou janela de defesa |
| C | controle de espaço | 384 | 352–416 | zona, deslocamento ou status; não dano bruto extra |
| V | clímax | 768 | 576–672 | recarga longa, anúncio visual e evasão possível |

Os valores são **tetos por conjuração contra um alvo**, nunca dano por partícula.
Para multi-hit, a soma dos hits e partes nomeadas deve caber no teto. Para
carregadas, o mínimo e o máximo devem permanecer dentro da faixa do slot.

## Regras de design

1. Dano não é o único orçamento. Alcance, raio, rastreio, mobilidade,
   invulnerabilidade, controle e duração precisam custar dano ou recarga.
2. Um V de área grande não deve também ter rastreio, stun longo e dano máximo.
   Escolher no máximo duas dessas propriedades.
3. Z multi-hit deve manter o impacto por bala legível, mas os hits extras após
   o teto só entregam VFX/controle, não dano invisível.
4. Uma carga curta (até 1,5 s) pode ficar no topo da faixa de X; cargas de
   3 s ou mais recebem no máximo o bônus de leitura/ameaça, não um salto de
   categoria de dano.
5. Parte de clímax usa `reserva` no `DamageSpec`; assim um hit visual final não
   chega sem dano porque os hits anteriores consumiram todo o orçamento.

## Processo de implementação

1. Registrar em `Balance.gd`, por fruta e slot: teto, total alcançável, alcance,
   raio, duração, controle, recarga e tempo de carga.
2. Corrigir primeiro os outliers de V acima de 672 e os Z abaixo de 160 que não
   compensam com segurança, cadência ou controle.
3. Ajustar uma fruta por vez. Depois de cada alteração, executar
   `tools/dev_tests/test_balance.gd` e uma sessão com alvo imóvel + alvo móvel.
4. Medir três cenários: todos os hits, acerto parcial e falha. A decisão vem da
   mediana de dano entregue, não só do teto teórico.
5. Só então ajustar recargas. Recarga não deve ser usada para esconder um golpe
   com dano ou controle excessivo.

## Critérios de aprovação

- Nenhuma skill ultrapassa o teto do slot em `Balance.teto_do_slot`.
- V/Z por fruta fica entre 3,0× e 4,0× no teto até a migração completa; após a
  migração, entre 3,0× e 3,5×.
- Um V não remove mais de 33% da vida base por dano sozinho; quedas continuam
  sendo a condição decisiva de vitória.
- X e C têm vantagem tática explícita que justifica seu dano: confirmação,
  controle ou espaço, respectivamente.
- `test_balance.gd` passa e testes de fruta continuam criando as hitboxes
  previstas sem ultrapassar o orçamento por conjuração.

## Primeira rodada sugerida

1. Comprimir V de 768 para 640–672 nas frutas que não exigem acerto difícil.
2. Manter V de 704 apenas onde o anúncio, a carga e a evasão forem comprovados.
3. Preservar Z em 160–192 totais; elevar somente os Z de tiro que perderam
   pressão por cadência, alcance ou custo de energia.
4. Deixar a Mera Mera como referência: Z 200 (8 × 25), X 256, C 256 e V 640.
   Contra a vida de 2048, isto representa respectivamente 9,8%, 12,5%, 12,5%
   e 31,25% por conjuração completa.
