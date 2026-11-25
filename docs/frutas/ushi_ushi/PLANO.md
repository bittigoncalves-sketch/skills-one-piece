# Ushi Ushi no Mi, modelo Girafa — plano de combate

Estado: proposta de implementação e referências conceituais; tempos, distâncias e danos são pontos de partida para playtest, não valores aprovados ou medições do jogo. Responsabilidade: Codex prepara este plano e as imagens; Claude implementa, integra e valida. ID existente: `ushi_ushi_giraffe`.

## Formas e controles

| Forma | Aparência | Z | X | C |
|---|---|---|---|---|
| 0 | Humano normal | Sem técnica específica proposta | Sem técnica específica proposta | Sem técnica específica proposta |
| 1 | Girafa humanoide atual | Investida com pescoço e cabeça | Corte de ar único, refeito | Rajada de cortes de ar |
| 2 | Girafa quadrúpede nova | Pescoçada reta | Martelada lateral com o nariz | Não existe |

A atribuição acima é a solicitada para as duas formas transformadas. O comportamento das teclas na forma humana e o controle/ciclo de transformação não foram especificados: preservar os contratos existentes quando possível e alinhar eventual conflito; não presumir uma técnica nova. Na forma 2, C deve ser ignorado sem custo, recarga, animação ou efeito e sem cair no C genérico. Na troca de forma, fruta, morte ou interrupção, encerrar estado, efeitos e hitboxes pendentes; nenhuma forma pode deixar a locomoção travada.

## Régua de números para protótipo

Unidades são metros no mundo e segundos de tempo real. `D` é o dano de um X humanoide inteiro num alvo sem modificadores; usar o balanceamento real como base e multiplicadores abaixo para comparar, sem substituir o cálculo existente de atributos/resistências. Alcance é distância horizontal a partir do centro do personagem no instante do início; corpo, cabeça e efeito devem acompanhar o alcance efetivo. Ant. = antecipação, ativo = janela de colisão/emissão, rec. = recuperação. Tolerâncias, recursos e recargas finais dependem de playtest.

| Forma / tecla | Ant. | Ativo | Rec. | Alcance máximo | Dano relativo por alvo |
|---|---:|---:|---:|---:|---:|
| Humanoide Z | 0,24 | 0,24 | 0,32 | 5,0 m | 1,35 D, um acerto |
| Humanoide X | 0,18 | 0,10 emissão | 0,22 | 12,0 m | 1,0 D, um acerto |
| Humanoide C | 0,25 | 0,75 emissão | 0,35 | 12,0 m | até 2,0 D, cinco cortes de 0,40 D |
| Quadrúpede Z | 0,28 | 0,20 | 0,32 | 4,5 m | 1,45 D, um acerto |
| Quadrúpede X | 0,30 | 0,22 | 0,38 | 3,5 m | 1,25 D, um acerto |

X e C: projéteis permanecem após a emissão, no máximo 0,8 s; a 15 m/s percorrem até 12 m a partir do ponto de origem. Como a régua da tabela é a partir do centro, limitar deslocamento ao espaço restante após subtrair a distância do ponto de emissão ao centro. Travamento da animação termina com a recuperação, não espera o projétil acabar. C emite cinco cortes em intervalos de aproximadamente 0,15 s; os projéteis podem acertar o mesmo alvo uma vez cada. Se interrompido, cessar emissões futuras e tratar projéteis já emitidos conforme o contrato de limpeza de troca/morte.

### Humanoide Z — investida de aríete

Pés apoiam e tronco recua levemente (0,24 s); corpo avança com o pescoço esticando para frente e cabeça conduzindo o golpe (0,24 s); pescoço retorna e passada estabiliza (0,32 s). Proposta: avanço de até 1,5 m, respeitando obstáculos; o restante do alcance vem do pescoço. A área de golpe acompanha o percurso real da cabeça e não atravessa paredes; acertar cada alvo no máximo uma vez. Anel fino branco/ocre e poucos traços no impacto, sem esconder a extensão.

### Humanoide X — corte de ar inteiramente novo

Preparar o movimento corporal (0,18 s), emitir uma única lâmina de ar (0,10 s), recuperar a postura (0,22 s). Crescente delgado, núcleo branco e borda dourada discreta, sem espada física: uma malha visual por projétil. Proposta inicial: largura 1,8 m, altura 0,8 m, velocidade 15 m/s, até 12 m; direção coerente com a mira e início fora do corpo. Um acerto por alvo e parar no primeiro obstáculo/alvo sólido, salvo exigência do sistema existente. Descartar o visual antigo da Ushi, inclusive o efeito genérico associado; não alterar frutas que o compartilham.

### Humanoide C — metralhadora de cortes

Preparar (0,25 s), emitir cinco versões menores do mesmo corte X (0,75 s), recuperar (0,35 s). Cada corte tem a mesma trajetória base e uma leve variação de altura/ângulo, ainda direcionada à mira; devem ser visíveis como cortes separados, não feixe contínuo. Usar a mesma geometria e material compartilhados do X, uma instância de malha por projétil ativo. Cada projétil segue as regras de colisão e duração do X; dano máximo de 2 D pressupõe cinco acertos sem obstrução.

### Quadrúpede Z — pescoçada

Quatro apoios firmes; retrair o pescoço como mola (0,28 s), estender reto para frente com a cabeça como punho (0,20 s), voltar sem atravessar o tronco (0,32 s). Corpo quase fixo; a distância vem da extensão, não de teleporte. Uma área de dano acompanha a trajetória da cabeça, bloqueada por obstáculos; uma aplicação por alvo. Traço curto no sentido do golpe e clarão de impacto branco/ocre; sem martelo literal.

### Quadrúpede X — martelada com o nariz

Girar a cabeça e retrair para um lado (0,30 s), varrer horizontalmente com o pescoço e atingir com o próprio nariz (0,22 s), recuperar com contrapeso (0,38 s). Proposta: arco frontal de até 100°, raio de 3,5 m; amostrar o trajeto real do nariz, aplicar dano uma vez por alvo, sem atravessar paredes. Rastro curvo fino e impacto achatado branco/ocre. A imagem deve mostrar o nariz como ponto de contato, não uma arma ou martelo independente.

## Corrida e rig

- Humanoide transformado: inclinação de tronco para frente, alternância de pernas e braços com apoio; pescoço alto oscila em atraso suave, sem dobrar de maneira desconexa. Retomar parada sem salto de pose.
- Quadrúpede: galope com quatro membros, suspensão breve, contatos e contrapeso de cabeça/pescoço; verificar de perfil e de frente, sem patas penetrando no solo nem juntas dobrando no sentido errado. Adaptar ritmo à velocidade real e interromper a corrida durante ataques que exigem apoio.
- Validar colisão, câmera, escala, rotação e altura do alvo para ambos os corpos. O rig e a forma quadrúpede precisam possibilitar extensão, flexão lateral e retorno do pescoço sem peças se soltarem. A aparência humana e customização precisam voltar ao sair da forma.

## Desempenho e integração

- X/C: malha simples por corte, geometria/material reutilizáveis, movimento por atualização leve e consulta de colisão contínua/segmentada para não atravessar alvos em quadros lentos; sem rigid bodies ou simulação física pesada por projétil. Limitar duração e quantidade simultânea; medir tempo de quadro e contagem de objetos com rajadas repetidas no hardware disponível. O objetivo é não gerar travamentos perceptíveis; a medição é obrigatória antes de declarar que não há lag.
- Respeitar o caminho real de habilidades, autoridade de dano/rede, custo, recarga e feedback do jogo; cliente não aplica dano duplicado. Testar offline e em host/cliente se a fruta estiver disponível em rede. Verificar interrupção, morte, troca de cena/fruta/forma, alvo atrás de obstáculo e limpeza de instâncias.
- O registro atual em `docs/frutas/tecnicas_do_mod.json` apresenta mapa genérico Z/X/C/V, e `src/combat/poder/poder_da_fruta.gd` associa a técnica 23 da Ushi a um efeito compartilhado de chute. Conferir os caminhos efetivos em execução: a implementação nova não deve acumular golpe/visual antigo nem mudar outras frutas. Os arquivos são evidência estática, não prova de runtime.

## Referências visuais previstas

Os PNGs abaixo são conceitos de pose e leitura, não modelos, capturas do jogo ou aprovação artística. Branco e dourado são proposta inicial sujeita à resposta do usuário. Confirmar os arquivos existentes antes de usá-los.

| Imagem em `art_src/references/ushi_ushi/` | Propósito |
|---|---|
| `forma_humana.png` | Forma 0, avatar normal |
| `forma_humanoide.png` | Forma 1 e postura da corrida |
| `forma_quadrupede.png` | Forma 2 e galope |
| `humanoide_z.png` | Investida com pescoço |
| `humanoide_x.png` | Corte de ar único |
| `humanoide_c.png` | Rajada de cortes |
| `quadrupede_z.png` | Pescoçada reta |
| `quadrupede_x.png` | Martelada lateral com nariz |

## Critérios de conclusão para a implementação

1. Em jogo, testar Z/X/C nas três formas: correspondência da tabela, C da forma 2 sem efeito e sem custo, e ausência de efeitos antigos duplicados.
2. Verificar uma aplicação por golpe/alvo; cinco impactos possíveis na rajada; alcance, obstáculos, cooldown/custo e limpeza. Comparar dano real relativo com a régua, incluindo atributos e resistências.
3. Capturar cada golpe em preparação, ativo e recuperação na câmera real; filmar corrida de frente e perfil em velocidade normal e lenta. Conferir contato, direção do nariz, estabilidade do pescoço, legibilidade dos cortes e ausência de interseções graves.
4. Medir desempenho durante rajadas repetidas, anotar dispositivo, cenário, FPS/tempo de quadro e quantidade máxima de objetos; comparar em condições iguais antes/depois. Registrar qualquer gargalo e não alegar ausência de lag sem evidência.
5. Confirmar restauração após troca/morte/respawn e, quando aplicável, autoridade em rede e sincronização entre host e cliente. Revisão visual e de balanceamento pelo dono seguem separadas de testes técnicos.
