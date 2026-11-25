# Missão 5 — barril e duelo com Alvida

Documento de referência para implementação pelo Claude; nenhuma mecânica é implementada aqui. Decisões recebidas: após `resgate_do_bau`, bússola leva ao vendedor de navios; vitória sobre Buggy significa acertar os copos; derrota no duelo devolve à Ilha dos Macacos sem itens, preservando os permanentes; vitória rende 1000 moedas e 8000 XP. Partida retratada como Alvida original no começo da história, proposta visual sujeita à revisão.

## Estado do projeto e ponto bloqueante

Em `src/historia/missoes/missoes.gd`, `resgate_do_bau` depende de `desafio_dos_copos`. Em `src/historia/buggy_cais/regras_do_desafio_buggy.gd`, acertar grava `prog.sistemas["desafio_buggy"]["fase"] == "copos_certo"`, mas errar também marca a missão dos copos como `entregue`; o desafio tem tentativa única. Portanto `entregue` isolado **não prova vitória**, e uma pessoa que errou pode concluir o baú mas não cumprir a condição do vendedor. Exibir a fala `sem_vitoria`, sem entregar barril, até haver decisão do dono sobre recuperação desse caminho. Não inventar nova tentativa, vitória alternativa ou migração automática de saves.

`ProgressaoDoPersonagem.zerar_inventario()` cria outro inventário, mas é necessário verificar todos os locais onde itens e equipamentos persistem, inclusive cursor, grade, equipamentos, item ativo e dados legados; não se pode presumir que essa chamada preserve os permanentes nem que remova tudo mais. **Quais itens contam como permanentes exige definição** antes de aplicar a penalidade. Não apagar moedas, XP, nível, habilidades, frutas ou outros dados por suposição. Incluir teste com itens permanentes e não permanentes, e save/reload.

## Fluxo e estados sugeridos

1. Missão disponível apenas depois de `resgate_do_bau` entregue. Bússola/marcador acompanham o vendedor real e o reencontram após carregar; não usar coordenada de NPC diferente.
2. Aproximação e conversa. Exigir `copos_certo` real para entrega do barril; teste negativo separado para `copos_errado` e saves legados sem fase. Sem vitória: diálogo de bloqueio, sem prosseguir.
3. Vendedor olha o jogador, entrega barril e transição ao mar; câmera em primeira pessoa **de dentro do barril fechado**, sem mostrar o exterior até o corte previsto. Oscilação suave, áudio abafado; opção de reduzir movimento.
4. Barril pescado ao navio, aberto, apresentação de Alvida e falas. Câmera em close do rosto do falante com caixa cinematográfica e troca das três texturas de boca `fechada`, `meia`, `aberta`; ciclo aproximado de 8 Hz apenas enquanto a fala/tempo de texto estiver ativo, fechar ao avançar. Respeitar tempo de leitura; sem depender de áudio falado. Um visema por boca, não três NPCs.
5. Duelo com sete vidas para cada. Pedra vence tesoura; tesoura vence papel; papel vence pedra. Empate: Alvida ataca e jogador desvia, nenhuma vida perdida. Vitória de rodada: vencedor ataca, outro recebe dano e perde exatamente uma vida. Ao atingir zero, encerrar uma única vez; input bloqueado entre escolha e fim das animações. Escolha da Alvida deve ser feita antes ou simultaneamente à do jogador, sem consultar sua escolha; revelar ambas depois.
6. Derrota: transição à Ilha dos Macacos, limpar somente itens abrangidos pela regra aprovada e preservar permanentes; sem recompensa. Vitória: cena de saída do navio e chegada à Ilha dos Macacos, +1000 moedas e +8000 XP exatamente uma vez. Uma única fonte paga recompensa, conciliada com a tabela de missões para não duplicar.

Salvar fase, resultado dos copos, vidas e resultado do duelo, aplicação da penalidade/recompensa; transições idempotentes mesmo com reconexão, salvar/carregar e repetição de sinal. Para multiplayer, validar jogador dono e autoridade do estado e transportar apenas participantes corretos; não compartilhar recursos entre personagens inadvertidamente. Encerrar cutscene e restaurar câmera, controles, HUD e áudio em todos os caminhos, inclusive troca de cena e desconexão. A política para interrupção no meio da cinemática/duelo precisa ser fixada na implementação e testada, sem atribuir derrota ou recompensa silenciosamente.

## Storyboard proposto

Durações são mínimos de direção, não temporizadores que cortam o texto; as falas vêm dos JSON em `data/dialogos/`. Travessias podem ser puladas se o estado permanecer íntegro.

| Plano | Tempo aproximado | Enquadramento e ação |
|---|---:|---|
| 1 | 3–5 s | Terceira pessoa: bússola indica o vendedor no cais; jogador se aproxima. |
| 2 | 5–10 s + leitura | Close no rosto do vendedor, alternando com reação do jogador; diálogo em caixas cinematográficas. |
| 3 | 3–5 s | Plano médio: vendedor vira para o jogador e entrega o barril após confirmação dos copos. |
| 4 | 5–8 s | Primeira pessoa de dentro do barril fechado: tampa, frestas e balanço; som de mar abafado. |
| 5 | 4–6 s | Plano externo: tripulantes içam/pescam o barril para o convés da Alvida. |
| 6 | 3–5 s | De dentro do barril: tampa abre e luz entra; corte para rosto de Alvida. |
| 7 | 5–10 s + leitura | Close em Alvida: percebe o jogador, grita “Um invasor no meu navio!” e propõe o duelo. |
| 8 | variável | Plano aberto no convés: HUD de vidas e escolhas; revelar rodada e animar ataque/dano ou desvio antes da próxima. |
| 9A | 5–8 s + leitura | Vitória: reação de Alvida, saída do navio e chegada à Ilha dos Macacos; apresentar recompensa uma vez. |
| 9B | 4–7 s + leitura | Derrota: reação de Alvida, transição à Ilha dos Macacos; comunicar perda efetivamente aplicada. |

## Poses, animações e HUD

- Vendedor: repouso, olhar/virada para jogador, oferta e entrega do barril, três visemas.
- Jogador: entrar no barril, repouso interno, sair, escolha de pedra/papel/tesoura, ataque, receber dano, desvio, vitória e derrota.
- Alvida: repouso, olhar, surpresa/grito, três visemas, escolha/revelação, ataque com clava, receber dano, reação de vitória e de derrota.
- Tripulantes: lançar/operar corda, içar e abrir tampa; barril: flutuar, ser içado, tampa abrir. Navio: deslocamento/balanço sutil.
- HUD: topo esquerdo retrato/nome jogador + **7 corações**, topo direito retrato/nome Alvida + **7 corações**; centro revela escolhas e resultado sem encobrir os lutadores; base com três botões grandes identificados Pedra, Papel, Tesoura. Corações cheios/vazios e contador numérico asseguram legibilidade. Indicar foco de teclado/controle e bloquear duplo clique por rodada.

## Referências e limites

Pranchas conceituais geradas: [Alvida](alvida_conceito.png) e [navio](navio_conceito.png). São referência de design, não modelos ou evidência de fidelidade. As vistas e os detalhes gerados podem divergir entre si ou do desenho oficial. Prompts: Alvida original do começo da história, corpo quadrado, chapéu branco, casaco rosa e clava, vistas frontal/lateral e três bocas; navio Miss Love Duck em blocos, proa de pato, madeira e detalhes rosa, vistas lateral e três quartos. Ambas foram geradas pela ferramenta de imagem integrada.

Referência externa de identificação do navio: [Netflix Tudum — guia de One Piece](https://www.netflix.com/tudum/articles/one-piece-guide); a identificação da primeira aparição e da capitã armada de clava também aparece em [Crunchyroll — tripulações piratas](https://www.crunchyroll.com/id/news/guides/2024/11/22/one-piece-anime-pirate-crews). Revisar detalhes visuais com frames licenciados do anime antes da modelagem final. O diálogo é conteúdo planejado no formato `id`/`estados`/`falante`/`texto` dos JSON existentes; ainda requer ligação e validação em runtime.

## Aceite

Verificar os dois resultados dos copos, inclusive reload; progressão após o baú; entregas e câmeras reais; empate e todas as combinações de escolhas; sete acertos em ambas as direções; nenhuma ação repetida no meio de animação; perdas e permanentes definidos; recompensa idempotente; retorno e recuperação de controles; save/reload e multiplayer quando aplicável. Teste estrutural não substitui playtest, escuta e revisão visual em jogo.
