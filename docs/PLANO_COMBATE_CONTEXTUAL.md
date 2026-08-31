# Combate contextual — plano vivo e implementação

**Estado:** Fase 0 documentada; Fase 1 implementada e validada em singleplayer
**e em rede**; Fases 2 (counter hit) e 3 (launcher) implementadas e validadas.  
**Última revisão:** 2026-08-31.  
**Escopo desta frente:** ampliar o corpo a corpo sem substituir o combo M1,
a Aú, a queda esmagadora ou a rota exclusiva dos Minks.

## Objetivo

Dar ao jogador escolhas que dependem de posicionamento e intenção, não apenas
de dano maior. A regra é:

```text
posição cria a oportunidade
→ direção escolhida no clique define a intenção
→ animação e VFX tornam a intenção legível
→ recuperação cria o contra-jogo
```

As referências abaixo servem para princípios de design, não para reproduzir
personagens, animações, efeitos, sons ou nomes de outros jogos.

| Referência de design | Princípio aproveitado | Aplicação no jogo |
|---|---|---|
| Jogos de luta 2D, como Street Fighter | alcance, compromisso e punição de erro | W/S/A/D têm recuperação explícita; não são dashes gratuitos |
| Jogos de ação expressiva, como Devil May Cry | rotas aéreas curtas e legíveis | launcher e continuação aérea ficam para uma fase posterior e limitada |
| Jogos de leitura, como Sekiro | antecipação clara de ataques perigosos | golpes fortes devem ter silhueta e telegráfico antes da hitbox |
| Jogos de arena, como Smash | direção altera trajetória e a aterrissagem importa | ataques aéreos não competem com a Aú ou a queda esmagadora |
| Jogos de luta corporal, como Sifu | esquiva ofensiva sem invencibilidade ampla | A/D + M1 muda a linha e contra-ataca, mas continua vulnerável |

## Contrato de contexto

O resolvedor recebe uma fotografia do instante em que o clique foi aceito:

```gdscript
{
    "grounded": bool,
    "sprinting": bool,
    "weapon": String,
    "input_forward": float,
    "input_side": float,
    "attack_yaw": float,
    "attack_basis": Basis,
    "race_id": String,
    "fall_height": float,
}
```

`attack_basis` é congelada no primeiro frame. Depois disso, a câmera pode
continuar sendo movida, porém não pode girar o corpo, a hitbox, o deslocamento
nem o VFX do ataque já comprometido. Isso evita a mesma falha que a Aú tinha
antes de capturar sua direção.

## Prioridade fixa

Esta ordem é usada pelo `MeleeController`. A intenção mais específica vence a
mais genérica.

| Prioridade | Condição | Resultado | Situação |
|---:|---|---|---|
| 1 | Espaço + M1 | Aú / estrelinha | já existente |
| 2 | No ar, alvo abaixo e altura de queda válida | queda esmagadora | já existente |
| 3 | Mink correndo, mordida disponível e alvo válido | investida → agarrão → chute | já existente |
| 4 | No chão, sem sprint, A/D + M1 | esquiva lateral + gancho | Fase 1 |
| 5 | No chão, sem sprint, S + M1 | chute recuando | Fase 1 |
| 6 | No chão, sem sprint, W + M1 | cotovelada de avanço | Fase 1 |
| 7 | Demais casos | combo M1 base | já existente |

Se W/A/S/D forem pressionadas juntas, A/D vencem W/S: uma esquiva lateral tem
silhueta e intenção menos ambíguas. A rota Mink continua acima de toda variação
direcional, para não perder sua identidade ao segurar W + Shift.

## Fase 1 — variações de solo

Todos os números abaixo são valores finais de dano contra a vida atual de
2048. O dano fica abaixo do finalizador M1 (112), pois estas ações compram
posição, não explosão de dano. Nenhuma recebe cooldown próprio; a recuperação e
a punição de erro são o custo.

| ID | Entrada | Startup | Ativo | Recuperação | Dano | Knockback | Deslocamento |
|---|---|---:|---:|---:|---:|---:|---|
| `context_elbow` | W + M1 | 0,14 s | 0,08 s | 0,20 s | 60 | 16 | frente, até 1,00 m |
| `context_retreat_kick` | S + M1 | 0,15 s | 0,08 s | 0,23 s | 56 | 17 | trás, até 0,85 m |
| `context_side_hook_l` | A + M1 | 0,16 s | 0,08 s | 0,24 s | 58 | 15 | esquerda, até 1,10 m |
| `context_side_hook_r` | D + M1 | 0,16 s | 0,08 s | 0,24 s | 58 | 15 | direita, até 1,10 m |

### W + M1 — cotovelada de avanço

- `0,00–0,14 s`: centro do corpo baixa 0,08 alturas de corpo, tronco inclina
  aproximadamente 22° para frente e o cotovelo direito fecha para cerca de
  35°. O peso comprime na perna traseira.
- `0,14–0,22 s`: o corpo percorre o avanço principal; pelve gira cerca de 38°
  e o cotovelo sobe 20° na diagonal. A hitbox é curta e frontal.
- `0,22–0,42 s`: ombro desce e o cotovelo volta para a guarda. Se errar, a
  recuperação cresce pelo multiplicador normal de whiff.
- VFX: linhas de compressão atrás do torso e rastro curto de ar no cotovelo.

### S + M1 — chute recuando

- `0,00–0,15 s`: quadril desloca para trás, tronco inclina aproximadamente
  14° para trás, joelho sobe e os braços fecham em guarda.
- `0,15–0,23 s`: o pé se abre em chute frontal enquanto a raiz física recua.
  A hitbox continua olhando para a `attack_basis` capturada.
- `0,23–0,46 s`: a perna dobra antes de retornar, deixando uma recuperação
  maior que a cotovelada.
- Regra de segurança: se houver parede imediatamente atrás, a ação deve cair
  para M1 base em vez de deslocar o jogador através da geometria.
- VFX: poeira pequena nos pés e crescente de ar invertido no pé.

### A/D + M1 — esquiva lateral e gancho

- `0,00–0,16 s`: quadril viaja para o lado escolhido, tronco inclina cerca de
  28° para o mesmo lado e a cabeça desce aproximadamente 0,10 alturas de corpo.
- `0,16–0,24 s`: o braço oposto ao deslocamento descreve gancho de baixo para
  cima; ombro abre aproximadamente 62° e cotovelo sai de 88° para 30°.
- `0,24–0,48/0,50 s`: o corpo mantém pequena inclinação lateral antes de
  recuperar a guarda. Não há invencibilidade global: é troca de linha, não
  uma fuga sem risco.
- VFX: duas pós-imagens transparentes, nunca douradas, e arco curto no punho.

## Arquitetura

```text
MeleeController
  ├─ constrói ContextSnapshot
  ├─ ContextualMelee.resolve(snapshot)
  ├─ controla o único relógio de frame data e whiff
  └─ pede ao Player apresentação e RPC

Player
  ├─ congela attack_yaw / attack_basis
  ├─ aplica deslocamento físico local durante a ação
  ├─ replica a apresentação para os demais clientes
  └─ pede dano ao servidor

Servidor
  ├─ valida ID, arma, chão, origem e cadência
  └─ instancia DamageZone no instante ativo

ProceduralAnimator / ContextualMeleeFX
  └─ mostram pose e VFX; não decidem dano
```

O servidor é a autoridade de dano. Clientes podem prever pose, deslocamento e
VFX para a resposta ficar imediata, mas não podem criar uma `DamageZone` que
machuque fora do servidor.

### Arquivos da Fase 1

| Arquivo | Responsabilidade entregue |
|---|---|
| `src/combat/contextual_melee.gd` | ficha declarativa, snapshot de input, resolvedor, frame data, root motion e criação de `DamageZone` no instante ativo |
| `src/player/melee_controller.gd` | prioridade após Aú/queda/Mink, relógio único de fase e punição de whiff para as variações |
| `Player.gd` | captura de `attack_yaw`, validação de recuo, root motion, RPC cliente→servidor e apresentação remota |
| `src/player/hsm/CombatStateAttackStartup.gd` | impede que o auto-lunge do M1 invada a distância especificada da variação |
| `src/anim/ProceduralAnimator.gd` | poses distintas de cotovelada, chute recuando e ganchos laterais |
| `src/effects/contextual_melee_fx.gd` | telegráfico e arco de ar; pós-imagens laterais são transparentes e sem colisão |
| `tools/dev_tests/test_ataques_contextuais.gd` | regressão de resolver, prioridade, pose, VFX, root motion, dano e limpeza |

### Rede e validação efetivamente implementadas

1. O cliente captura o input e mostra a ação imediatamente.
2. O pedido envia somente `id`, origem e direção congelada.
3. O servidor rejeita ID desconhecido, arma equipada, jogador fora do chão,
   vetor vertical/inválido, origem distante, recuo contra cenário e repetição
   antes da cadência mínima.
4. Só o servidor instancia `DamageZone`; a posição horizontal acompanha o
   atacante até terminar o startup para não ficar atrás dele após o avanço.
5. O servidor difunde apenas a apresentação (`id` + direção). Cada cliente
   monta localmente pose e VFX; câmera e dano não são replicados como efeitos.

O servidor ainda não recebe um histórico completo de teclas do cliente. Nesta
fase ele valida o que pode observar de modo autoritativo, enquanto a escolha
W/A/S/D é prevista pelo dono. A futura camada de `AttackContext` sincronizado
deve validar também a intenção de direção em partida remota.

## Compatibilidade racial

| Raça | Efeito na Fase 1 |
|---|---|
| Mink | Mantém a mordida acima das variações direcionais enquanto corre. Sem bônus de dano ou hitbox extra. |
| Lunariano | A chama das costas continua sendo apenas visual; nunca participa da hitbox contextual. |
| Oni | Pode receber poeira mais pesada em fase visual futura, sem multiplicador de dano. |
| Braços/pernas longos | Pode ampliar somente a leitura visual; alcance mecânico permanece o da tabela. |
| Palhaço | Membros podem receber atraso visual futuro, mas a cápsula de dano segue o corpo físico. |

## Fase 2 — counter hit (implementada em 2026-08-31)

Acertar quem está em **startup** rende tempo, não estrago: o dano não sobe, o
hitstun vai a 155% e o empurrão ganha mais 45%. O prêmio por ler o adversário é
ele ficar mais tempo parado e mais longe, e não um pico de dano que encurtaria
a luta.

| Peça | Responsabilidade |
|---|---|
| `Player.em_startup_de_ataque()` | responde pela janela do clique até a hitbox, para o contextual **e** para o M1 — `MeleeController.fase()` já cobre os dois com o mesmo relógio |
| `DamageZone.antes_do_acerto` | sinal novo, emitido **antes** de o dano correr |
| `ContextualMelee._aplicar_counter` | o bônus, com `dano = 0` (o projeto já usa dano zero para "empurrão e hitstun sem machucar") |
| `tools/dev_tests/test_counter_hit.gd` | regra, leitura da fase no Player real e a ordem dos sinais |

⚠️ **Por que o sinal novo.** `hit_landed` chega tarde: quando ele dispara, o
`take_damage` já rodou e já interrompeu o golpe do alvo. A pergunta "ele estava
em startup?" responderia **sempre falso**, e o counter nunca aconteceria — sem
erro e sem aviso. Quem decide continua sendo o servidor, porque é lá que a
`DamageZone` nasce.

## Fase 3 — launcher (implementada em 2026-08-31)

No **quarto** golpe do combo, W deixa de ser cotovelada e vira lançamento. Nos
três primeiros a cotovelada continua valendo — senão o jogador perderia a
variação de avanço no meio da sequência.

| | |
|---|---|
| dano | 72 (o finalizador que ele substitui dá 112) |
| impulso | 15, vertical puro |
| frame data | 0,18 / 0,09 / 0,26 |

O dano é menor de propósito: o que se perde se ganha em ROTA, porque o alvo
sobe e abre a perseguição. Um launcher que também desse 112 seria a escolha
óbvia sempre, e o finalizador normal deixaria de existir.

### O bloqueio contra loop

⚠️ **É o requisito, não um detalhe.** Um launcher que funciona e não bloqueia é
pior que nenhum: lançar → perseguir → lançar prende o alvo no ar e decide a luta
sem o outro jogar.

- um corpo que **já está no ar por lançamento** não pode ser lançado de novo;
- a marca se limpa **sozinha** quando ele toca o chão — ninguém precisa lembrar
  de apagá-la, e um alvo que caiu volta a ser lançável numa troca posterior;
- a perseguição é **uma só** por lançamento (`consumir_perseguicao`).

O golpe de perseguição em si é o "chute aéreo simples" da fase seguinte; o
mecanismo que o limita já está pronto e testado.

## Próximas fases, ainda não implementadas

3. **Chute aéreo simples:** ocupa o espaço entre M1 no ar e queda esmagadora,
   sem competir com a Aú.
4. **Chute de parede:** exige raycast confiável, uma utilização por contato e
   validação de normal no servidor.
5. **Defesa avançada:** não reutilizar F, pois F já pertence ao Corpo de Ferro.

## Critérios de aceite da Fase 1

- Cada direção resolve uma única variação previsível.
- A prioridade preserva Aú, queda e mordida Mink.
- A direção, hitbox e VFX não giram com a câmera após o clique.
- A hitbox nasce apenas na janela ativa e o servidor decide dano.
- O ataque não atravessa parede ao recuar ou avançar.
- Whiff amplia apenas a recuperação; não remove a intenção visual.
- O teste automático registra a escolha de entrada, frame data, hitbox, pose e
  limpeza do estado visual.

## Registro de validação

| Data | Verificação | Resultado |
|---|---|---|
| 2026-08-31 | Documento e especificação inicial | concluído |
| 2026-08-31 | `test_ataques_contextuais.gd` | passou: W/S/A/D, prioridade, pose, VFX, root motion, direção congelada, limpeza e dano de W |
| 2026-08-31 | `test_chute_giratorio.gd` | passou: Aú continua acima da variação contextual |
| 2026-08-31 | `test_ataque_aereo.gd` | passou: queda esmagadora continua acima da variação contextual |
| 2026-08-31 | `test_mink_combate.gd` | passou: investida Mink continua acima de W/A/S/D em sprint |
| 2026-08-31 | `test_arena.gd` | passou: combo M1 e arena permanecem íntegros |
| 2026-08-31 | `test_compila.gd` | saída 0; os avisos de autoload no modo `--script` são tolerados pelo próprio teste |
| 2026-08-31 | `net_contextual_*_probe` (2 processos) | passou nos dois lados. **Nunca tinha rodado**: o lado cliente não compilava (dois `:=` sem inferir de `Variant`) e a sonda media a apresentação 0,70 s depois do clique, quando o golpe dura 0,42 s — reprovava a limpeza correta |
| 2026-08-31 | `test_counter_hit.gd` | passou: dano zero, hitstun ampliado, empurrão extra, leitura da fase no Player e ordem dos sinais |
| 2026-08-31 | `test_launcher.gd` | passou: 19 asserções — a escolha (só no 4º golpe, só com W), o impulso vertical, e o bloqueio contra loop nas duas pontas (não relança no ar, limpa ao aterrissar, uma perseguição só) |
| 2026-08-31 | `test_melee_trava.gd` | atualizado para a regra NOVA: o M1 deixa o corpo livre. O pedido de 2026-08-15 foi revogado pelo dono — "travava o jogador demais, fazendo os movimentos não serem tão fluidos" |
