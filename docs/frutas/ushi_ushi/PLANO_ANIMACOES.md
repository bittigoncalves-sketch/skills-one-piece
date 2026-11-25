# Ushi Ushi — plano de animações de chute

Estado: direção e valores iniciais para implementação e playtest; nenhuma animação ou captura foi produzida por este plano. Conforme feedback do dono transmitido pelo Claude, **o Z atual está muito bom**: preservá-lo. Claude implementa código/áudio; este documento e as imagens são a entrega de planejamento do Codex.

## Escopo e decisão do dono

- Forma 0 humana e forma 1 humanoide: X é chute aéreo que lança um corte; C é rajada de nove chutes/cortes. O gesto deve aparecer no corpo do jogador em ambas as formas.
- Forma 2 quadrúpede: X continua sendo a martelada com o nariz; C continua inexistente. O dono escolheu o **coice visual na preparação do X**, sem dano, mantendo o Z intocado. A proposta coreográfica usa uma pata traseira com apoio nas outras três antes de o pescoço varrer; o coice não cria hitbox, custo ou golpe novo e não substitui a martelada.
- A escolha de usar o kit novo na forma 0 foi registrada como premissa pendente em `IMPLEMENTACAO.md`; este plano descreve sua animação caso o kit seja mantido, sem resolver essa decisão.

## Convenções para os quadros

Tempos são segundos transcorridos desde pressionar a tecla; ângulos são **deslocamentos em graus sobre a pose de repouso**, não Euler absoluto. Frente do personagem é −Z local. Como o sinal real depende das bases exportadas, conferir no modelo: para uma perna inicialmente apontando para baixo, uma rotação positiva em X aproxima o pé de −Z. `Body` deve inclinar para a frente; no rig humano `Torso.x` negativo representa frente, enquanto as bases da `FormaZoan` precisam de conversão/teste visual. Ajustar sinal e escala à junta, sem impor os mesmos sinais cegamente nos dois rigs.

Na tabela: `R/L` = direita/esquerda; `Thigh`/`Shin` são coxa e canela do rig humano; `RightLeg`/`LeftLeg` são as peças da forma do mod. Em humanos, canela negativa flexiona o joelho para trás, conforme `src/anim/MeleePoses.gd`; 0° é esticada. A forma Ushi de `FormaZoan` tem **pernas rígidas**, ao contrário do rig articulado do humano; não atribuir joelho inexistente à malha e não prometer flexão que o modelo não possui. Os graus da coxa servem de guia para sua peça inteira. Para agachar com a malha rígida, usar inclinação/pivô do quadril e deslocamento pequeno do corpo, sem fingir que houve articulação.

## X humano e humanoide — chute aéreo, um corte

Proposta de duração 0,74 s: preparo/salto 0,30 s; ativo 0,10 s; recuperação/aterrissagem 0,34 s. É uma mudança da implementação atual (0,20 + 0,10 + 0,34 s): alinhar tempos de pose, emissão, travamento, custo e recarga, sem duplicar o projétil. Perna direita chuta; esquerda dá impulso e aterrissa primeiro. O jogador deve perceber subida, extensão, retração e apoio.

| Tempo | Ação e altura visual | Coxa R / joelho R | Coxa L / joelho L | Tronco e braços |
|---:|---|---|---|---|
| 0,00 | Guarda, pés apoiados | 0° / −8° | 0° / −8° | tronco 0°; braços em guarda |
| 0,15 | Agacha 0,12 m; recolhe direita, peso na esquerda | −25° / −45° | +25° / −55° | tronco 15° à frente; braço R recua 25°, L avança 20° |
| 0,30 | Impulso; pés deixam o chão; quadril sobe ~0,10 m | +45° / −65° | +10° / −20° | tronco 5° para trás; braços abrem para equilíbrio |
| **0,34** | **Pico do chute e emissão**; altura ~0,25 m | **+85° / −5°** | +20° / −45° | tronco 15° para trás; braço R recua 35°, L avança 25° |
| 0,40 | Perna termina a varredura, corte já saiu | +65° / −30° | +25° / −40° | retorna em direção à vertical |
| 0,55 | Pé esquerdo toca; absorver no joelho | +20° / −35° | +20° / −45° | tronco 12° à frente; braços protegem |
| 0,74 | Ambos apoiados e volta para guarda | 0° / −8° | 0° / −8° | retorna sem salto de pose |

Os valores de coxa/joelho são alvos para o rig humano; no humanoide rígido usar os valores de coxa como rotação da peça inteira, e trabalhar silhueta e compensação do quadril. A altura visual é **0,25 m acima da posição normal** no pico; avanço opcional ≤0,20 m, sem teleporte. Não somar offset visual e movimento físico duas vezes: se a cápsula realmente saltar, animar a malha em relação ao chão sem duplicar o salto; se não saltar, indicar que é salto visual e manter hitbox/câmera coerentes. Pouso em solo inclinado, obstáculos e cancelamento precisam restaurar transformações e não prender o jogador.

O corte é emitido uma vez no quadro de máxima extensão, no ponto do pé direito ou na extremidade da peça correspondente. Usar posição em mundo da peça efetivamente renderizada, com deslocamento pequeno à frente do pé e validação contra parede; a direção é a mira. **Não** emitir no começo da fase ativa se isso preceder a pose; hoje `_ao_comecar_ativo()` solta o X e `_soltar_corte()` usa uma origem fixa próxima ao corpo. Sincronizar emissão e pose sem depender da ordem incerta entre `_physics_process` e `_process`: calcular a pose/ponta no mesmo relógio que emite e testar com frames lentos. A descrição pictórica do ângulo não deve alterar o dano, custo, alcance ou recarga sem playtest e decisão própria.

## C humano e humanoide — nove chutes alternados

Manter a janela atual como ponto de partida: preparo 0,16 s, emissões durante 1,26 s, recuperação 0,40 s; duração 1,82 s. A sequência inicia com direita, depois esquerda, alternando `R L R L R L R L R`. Cada ciclo dura 0,14 s. Emissão no **pico de cada chute**, não no início do ciclo: cerca de **0,244, 0,384, 0,524, 0,664, 0,804, 0,944, 1,084, 1,224 e 1,364 s** desde o início. São 0,084 s após cada início de ciclo; o último precede o fim do ativo em 0,056 s.

Em cada ciclo de 0,14 s:

| Fase no ciclo | Perna ativa | Perna de suporte e tronco |
|---|---|---|
| 0,000–0,042 s | recolhe coxa +25°, joelho −50° | suporte absorve −20° no joelho; tronco gira levemente para o lado da perna |
| 0,042–0,084 s | estende até coxa +75° e joelho −5° | tronco compensa 8–12° para trás, braços em oposição |
| **0,084 s** | **pé em máxima extensão: emitir um corte** | alinhar origem com pé ativo, exatamente um projétil |
| 0,084–0,140 s | recolhe, troca de apoio | baixar e transferir peso antes do próximo chute |

Na forma rígida, animar `RightLeg`/`LeftLeg` sem inventar canela; no humano, usar `Thigh_*`/`Shin_*` articulados. O joelho não dobra para a frente. Defasagem leve dos braços, inclinação de tronco ±8° e pequenas diferenças na altura da perna (por exemplo ±5°) quebram a repetição, mas cada emissão precisa corresponder a um pé visível; não usar um giro completo que oculte os chutes. Variações são determinísticas, com transições contínuas. Nine emissões podem ocorrer em quadros físicos diferentes ou cair no mesmo quadro lento; não perder/duplicar cortes e usar a pose calculada para o instante de cada evento, inclusive em catch-up. C pode manter deslocamento permitido pelo controle existente; não criar voo ou hitbox de perna.

## Forma 2 — coice visual na preparação do X

**Não alterar o Z aprovado.** Para X, manter timing atual `0,38 + 0,24 + 0,46 s` e trajetória/dano da martelada. Com três patas apoiadas, a proposta faz a pata traseira direita iniciar recolhida, estender para trás uma vez durante o preparo e retornar antes da varredura do nariz. Evitar que a pata apareça como fonte de dano. Na captura, dar vista lateral e superior para separar coice de martelada.

Referência inicial para as duas juntas da pata traseira direita, em relação ao repouso; sinais devem ser verificados na hierarquia real e anatomia da girafa:

| Tempo do X | Coxa | Canela | Corpo e outras patas |
|---:|---:|---:|---|
| 0,00 | 0° | 0° | quatro cascos apoiados |
| 0,12 | +20° | −35° | três cascos de apoio, tronco com contrapeso suave |
| 0,24 | −40° | −5° | coice para trás, uma só extensão visual |
| 0,38 | 0° | 0° | casco retorna ao apoio; pescoço inicia martelada |
| 0,62 | 0° | 0° | contato do nariz durante a varredura; manter apoios |
| 1,08 | 0° | 0° | recuperação suave, retomar galope se houver movimento |

Estes sinais são hipóteses de partida, não a convenção anatômica validada; verificar que o casco recua e que a junta dobra de forma coerente nas vistas lateral e frontal. Se a topologia impedir um coice claro, registrar a limitação em vez de distorcer a pata. Para correr e apoiar, continuar usando as quatro patas e o galope atual; isto não substitui a decisão sobre o chute.

## Capturas e validação

1. Forma 0 e 1, X: registrar antecipação, pés saindo do chão, quadro exato pé estendido/projétil saindo, aterrissagem e repouso. Vistas de perfil e frente, velocidade normal e lenta; conferir joelhos humanos dobrando para trás, apoio e ausência de cabeça/membro duplicado.
2. Forma 0 e 1, C: vídeo de toda a sequência e captura com múltiplos cortes separados. Contar nove picos, alternância R/L, nove emissões e posição de origem. Testar quadro lento e interrupção para não ocorrer rajada extra ou perda de tiros.
3. Forma 2: mostrar o coice visual escolhido e a martelada com nariz/impacto, sem dano adicional. Revalidar que Z mantém a aparência e comportamento aprovados e que C não existe.
4. No caminho real do Modo História, testar movimento, paredes, salto, retorno à corrida, troca de forma/fruta, morte, respawn, cancelamento e sincronização remota quando aplicável. Avaliar tempo de quadro em condições comparáveis. As imagens de referência são conceitos; capturas estáticas e testes headless não substituem apreciação visual de animação.

## Referências de pose

Novas imagens em `art_src/references/ushi_ushi/`: `chute_x_humano.png`, `chute_x_humanoide.png`, `chute_c_humano.png`, `chute_c_humanoide.png`. Servem à leitura dos apoios e do gesto, não ao desenho exato dos modelos do jogo; a altura desenhada nas imagens do X é ilustrativa, prevalece o salto curto descrito acima. As duas imagens do C ajudam a visualizar o pico e o corte, mas **não mostram a alternância entre pernas com clareza**: seguir a sequência R/L escrita, não copiar literalmente as três poses. Verificar a existência dos PNGs antes da utilização.

`chute_quadrupede_conceito.png` ilustra o coice visual escolhido. Não representa um golpe novo nem altera o Z aprovado.
