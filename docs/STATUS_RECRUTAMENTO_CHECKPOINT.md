# Status, energia e recrutamento — 18/10/2026

Pedido: comparar o Mine Piece via REA; limitar atributos; energia bloquear técnicas;
comida no penúltimo slot e bandeira no último (até 8/9); F recruta derrotados com
bandeira ou finaliza sem ela; companheiros sem necessidade de comida.

## Referência verificada

REA abriu `/home/gabriel-bitti/server_onepiece/mods/MinePiece-ver14-forge-1.20.1.jar`:
SHA256 `349b36cdc4dacfe066e385f9ba05205eeb90551a743cf742cf95bfc7a3fbd765`.
`inspect_artifact` concluiu, mas excedeu o transporte de 10 MB; evidência retida
`ev_cd71007835ab7ca9dcd9c917a051aec2545fc40b690595793593cffeecbb5276`.
Descompilação local de mesmo hash: biblioteca-de-mecanicas/fontes-locais/minepiece-v14.
`PlayerPhysicalAbilityProcedure.java`: linhas 311–321 força limitada a amplificador
34, estilo 7 soma 20% (41); vida amplificador 9, estilo 3 soma 5 (14).
Linhas 451–476: armadura máxima 30; toughness é atributo separado.
`DadosEastBlue` já aplica armadura Minecraft e bônus de força 3 por nível de efeito.

Adotados os maiores tetos entre estilos, conforme o pedido de máximo do mod;
alternativa de usar apenas os tetos comuns foi apresentada e segue ajustável.
Constituição 30; Força 42 pontos × 3 = bônus 126; Vida 30 pontos × 2 + 20 = 80 HP
(40 corações). Inteligência e Energia conservam o teto natural de pontos da campanha.

## Implementação em andamento

- Barra dinâmica até 9 com utilidades comida/bandeira; estoque de pão/refeição.
- Botão direito consome uma unidade e repõe fome como o sistema existente.
- Companheiros sem fome, sem alimentação automática, sem botão Alimentar.
- Builder na campanha cobra custo absoluto da ficha, mantendo fração na arena.
- Técnicas acima da capacidade escurecem e exibem cadeado cinza.
- Giro da espada custa 5 para iniciar e 2/s para sustentar; cancelar é gratuito.
- Recrutamento intercepta morte e suspende o corpo até F próximo (3,5 m, sem parede).
  Recompensa/respawn originais só disparam uma vez ao resolver a escolha.
- Animais usam pets existentes; demais modelos usam registro `sistemas.recrutas`,
  integrado à tripulação em terra, reserva, cargos e bordo.

## Validação parcial

- Bateria focada: 7 suítes, zero falhas (barra, Builder, progressão, sobrevivência
  economia/integração/jornada e status/recrutamento). Logs `/tmp/status_regressoes.log`.
- Integração inicial: 19 checks; encontrado consumidor antigo de fome em
  `SobrevivenciaHud`, corrigido e repetido sem erros de runtime.
- Tetos e cálculos adicionados à sonda; próxima rodada também cobre animal e
  personagem Mine Piece reais, além de inimigo estático.
- `test_compila` apresenta falhas no projeto separado `tools/anim_editor/studio/`
  e ruído de autoloads documentado na própria ferramenta. Runtime da campanha passa.
- Portão `validar.sh rapido` em execução (`/tmp/status_rapido.log`), em headless;
  falha observada em `test_agua` ("submerso: sem técnicas de fruta"), ainda sem atribuição.

Próximo passo: terminar regressão, validar os casos ampliados e capturar a interface.

## Contratos e decisões

- Novo limite é validado na distribuição e na leitura do save; excedentes retornam
  ao saldo. A validação do save saiu para `serializacao_do_progresso.gd`, reduzindo
  `progressao.gd` de mais de 1000 para menos de 900 linhas.
- Constituição aplica a fórmula já usada por `DadosEastBlue` no dano recebido pelo
  jogador. Força soma somente ao dano físico no `CombatResolver`, preservando a
  contribuição do golpe/arma e sem aumentar dano de fruta.
- Recrutados comuns usam o controlador aliado já existente (seguir/defender/cargos)
  e o modelo do alvo, com clipes disponíveis. Não importam automaticamente todas as
  técnicas da IA inimiga; isso exigiria adaptar seleção de alvos de cada poder.
- Morte/respawn do selvagem só começam depois da escolha; aliados são identidades
  novas persistentes, como os pets já domados. Não recruta outro aliado ou jogador.
- Mudanças só da campanha; custos percentuais da arena permanecem iguais.
