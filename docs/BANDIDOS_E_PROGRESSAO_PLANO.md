# Dash do ar, nível 2400, XP por dificuldade, barra de chefes, bandidos e missão — plano (08/10/2026)

Pedido do dono, palavra por palavra:

> "diminuir distancia do dash e o impulso recebido é resetado ao final do do dash voltando a velocidade normal, aumentar nivel máximo para 2400, sendo na primeira ilha nivel máximo 10, modificar a experiencia recebida por matar cada animal com base na dificuldade de cada um, pontos ganhos por nivel 3. adicionar a capacidade do jogador ver no topo superior da tela quanto de vida tem cada boss. adicionar no mapa bandidos com base no dummy que é capaz de lutar adicione-os em campo aberto, adicionar um npc na vila com uma interrogação amarela acima da cabeça que dá a missão de matar os bandidos"

## Decisões

**Respondidas pelo dono:**
- **Dash:** só o dash do AR fica menor ("com o ganho de velocidade ele vai muito longe"). O roll do chão segue com 8 m.
- **Bandidos (visual):** corpo do Base com roupa de bandido.
- **Bandidos (quantidade e XP):** 2 acampamentos de 3, em campo aberto; cada um dá 25–75 XP (o "inimigo forte" do documento) e renasce em 60 s.
- **Missão:** matar 5 bandidos dá 300 XP + 50 de ouro, uma vez. Aceita-se no NPC (E), há contador na tela, entrega-se no mesmo NPC e a "?" some.

**Minhas, declaradas:**
- **Dash do ar:** 8 m → 5 m. Ao fim do dash, a velocidade horizontal volta ao teto normal do jogador.
- **Níveis:**
  - O teto geral é 2400. Na primeira ilha o teto é 10; o XP excedente fica guardado. A barreira do 7 com missões especiais continua.
  - Depois do 10, cada nível pede 500 mil + 25 mil × (nível − 9). É uma curva provisória. **Gatilho:** rever quando existir a 2ª ilha.
- **Pontos:** 3 por nível. O save do dono está no nível 1 sem pontos, então não há migração.
- **Títulos:** do 11 em diante, "Ápice" até haver títulos por ilha.
- **XP de animal:** vida/10 × (1 + dano/2), arredondado, no mínimo 1. Vale também para as bestas do mar. O valor fica gravado na ficha (catálogo) e o dono pode trocar por espécie.
- **Barra de chefe:**
  - No topo da tela, uma barra por chefe.
  - Aparece quando ele está a até 60 m ou em combate com o jogador, e some quando morre. As barras empilham, até 3.
  - Chefes: gorila, harpia e Sea Serpent.

## Etapas (cada uma com validação)

1. Dash do ar: 5 m e corte do impulso no fim. Validar com `test_q_rolar_e_dash` e uma medição do deslocamento total depois do dash.
2. Progressão (2400, teto da ilha, 3 pontos, curva). Validar com `test_progressao`, a janela M e `test_modo_historia`.
3. XP por dificuldade (ficha e catálogo) e XP das bestas. Validar com `test_animais` e uma conferência dos valores.
4. Barras de chefe. Validar com teste e foto.
5. Bandidos: visual, peça da loja, ninho, XP e dois acampamentos no mapa vivo, gravados por uma ferramenta idempotente que relê o arquivo antes de gravar. Validar com teste e fotos.
6. NPC da missão: "?" amarela, diálogo, contador, entrega e save. Validar com teste e fotos.
7. Documentação, memória e bateria.

## Estado

As etapas 1 a 6 estão **feitas** (08/10/2026):

1. **Dash do ar:** 5 m. Depois dele a velocidade cai para 4,2 m/s; sem o corte, ficava em
   14,3 m/s (controle rodado). `test_q_rolar_e_dash`: 12/12.
2. **Progressão:** teto absoluto 2400, teto 10 na ilha, 3 pontos por nível, curva acima
   do 10 e missões especiais só no 8–10. `test_progressao`: TUDO OK.
3. **XP por dificuldade:** gravado nas 30 fichas (o catálogo mudou SÓ no campo `xp`,
   conferido). As bestas do mar também dão XP. `test_animais`: 0 falhas.
4. **Barras de chefe:** `test_barras_de_chefes` 9/9, com foto.
5. **Bandidos e mapa vivo:**
   - Na loja: "Bandido" (inimigos) e "Guarda da vila" (NPCs).
   - No mapa vivo: 11 peças, gravadas com cópia `baseplate_antes_bandidos_4b55ec61d324.json`.
6. **Missão:** `test_bandidos_e_missao` 25/25, com fotos.

7. **Testes vizinhos** (24 testes, 08/10):
   - **Passaram:** 21, depois do ajuste meu ao `test_modo_historia`, que tinha 5 pontos
     fixos e agora usa `PONTOS_POR_NIVEL` (TUDO OK).
   - **Vermelhos sem relação com esta tarefa:**
     - `test_compila`: os 6 do studio, de sempre.
     - `test_inimigo_lutador`: intermitente; passou 3 de 3 de novo.
     - `test_frutas_acertam_npcs`: intermitente, item 66; o golpe que falha muda a cada
       rodada.
     - `test_ataques_agua_bestas` e `test_comportamento_bestas_mar`: trabalho em
       andamento de outra frente nas bestas; diagnóstico no item 69 da LISTA.
