# Diálogo cinematográfico — direção e contrato

21/11/2026. Referência e proposta para implementação pelo Claude; as imagens nesta pasta são montagens sobre captura anterior do campo, não uma interface rodando. Os controles e a posição solicitados são requisitos; dimensões, tempos e acabamento abaixo são sugestões ajustáveis em jogo. O JSON é `data/dialogos/treino.json`.

## Composição

- Tarjas escuras no topo e embaixo, faixa horizontal larga para legenda **acima da barra de nível/XP**, sem encobrir nível nem XP. Preserve o enquadramento do NPC e mantenha a legibilidade dos elementos que permanecerem visíveis. Nas montagens a tarja inferior cobre parte da hotbar antiga, a superior corta o rótulo antigo e a faixa encontra o painel de combate: são limitações do estudo, não requisitos; acomodar a HUD real sem recorte indevido.
- Faixa preta azulada translúcida, linha superior discreta dourada, nome do falante em dourado e fala em branco quente; sombra escura e contraste suficiente sobre céu ou vegetação. Sem retrato obrigatório. Indicador de avanço discreto e instrução textual de controles.
- A fonte efetiva é a `FonteMinecraft` do projeto, montada das texturas locais; usar tamanhos múltiplos de 8, escala inteira e fallback do tema quando os arquivos não existirem. As montagens usam os mesmos glifos locais, extraídos no gerador incluído.
- Base das referências 1280×720, captura `art_src/validation/treino/0_antes.png` redimensionada; cena e HUD são anteriores e servem apenas para estudar composição. Ajustar ancoragem à janela, às margens seguras e à posição real da barra, que acompanha a hotbar; testar proporções diferentes, telas menores e ausência da HUD Minecraft. Quebrar texto sem cortar palavras nem texto acentuado.

## Fluxo e estados

1. Interação com o instrutor: verificar primeiro a recusa de nível existente; caso contrário, escolher `primeira` se nenhum treino foi concluído e `repeticao` se já houve treino. Falta de progresso ou de JSON exige tratamento seguro e fallback de código.
2. Abertura: surgem tarjas e faixa; nome e primeira fala aparecem. Entrada que iniciou o diálogo não deve imediatamente revelar/avançar a primeira fala.
3. **Revelando:** texto aparece como máquina de escrever. E, Enter ou clique revela imediatamente o restante da fala; consumir a entrada para que não inicie ações do mundo.
4. **Aguardando:** fala integral fica visível até E, Enter ou clique. Uma entrada avança exatamente uma fala. Na última, fecha a sequência e devolve ao fluxo do instrutor/à oferta de treino existente, sem iniciar treino nem conceder XP por conta do diálogo.
5. **Esc em qualquer fala:** pula o restante da sequência e devolve ao mesmo fluxo de saída previsto para o diálogo concluído; não confirmar treino por acidente. Garantir que Esc não seja propagado no mesmo evento à próxima tela. A recusa nunca pode habilitar treino.
6. **Encerramento:** remover tarjas e faixa e restaurar foco, captura do mouse e entradas no caminho real; tratar reentrada, perda de NPC, troca de cena e cancelamento sem deixar controles presos. Não sobrepor uma segunda janela modal ativa durante as falas.

`primeira` e `repeticao` introduzem uma oferta: a confirmação de Treinar e as instruções completas Z/X/C, seis comandos, tempo e XP continuam no fluxo existente, sem presumir que Esc aceite a oferta. `recusa_nivel` informa que o treino não está disponível. Não alterar regras de progresso, missão ou save; o caso de save antigo acima do limite com missão pendente segue decisão separada já registrada no projeto.

## Ritmo e tom

- Sugestão inicial: entrada/saída das tarjas 0,20–0,25 s; 32 caracteres por segundo, com pausa de pontuação curta opcional (vírgula 0,10 s, ponto 0,20 s). Não exigir espera de animação para revelar/pular; não avançar automaticamente.
- Instrutor direto, calmo e encorajador; recusa respeitosa, sem prometer uma missão ou local inexistente. O JSON tem no máximo três falas por estado e até 90 caracteres por texto. Não prometer 500 XP garantidos.
- Opcional: permitir desativar ou acelerar revelação se já houver configuração acessível no jogo. Não introduzir áudio nem câmera nova como requisito.

## Critérios de verificação para integração

- Validar JSON UTF-8, chaves exatas, contagem e limite; testar primeira oferta, retorno após treino e nível 3 ou superior, inclusive retorno após subir de nível. O critério de repetição é treino concluído segundo a regra existente, não simplesmente ter aberto a conversa.
- Testar E, Enter e clique durante e após a revelação; Esc em cada estado; entrada mantida, repetida e a tecla inicial; último avanço, foco e mouse restaurados; sem duplo avanço nem execução da oferta de treino ao pular.
- Conferir fonte e acentos com e sem recursos locais, tela 1280×720 e outras proporções, texto maior/quebra, sobreposições com XP, nível, hotbar, missões e indicadores, e resposta a redimensionamento.
- Verificar interação no Modo História real, com save novo e existente, treino permitido e recusado, HUD visível e troca de cena/interrupção. Captura real e apreciação do usuário são necessárias para avaliar o acabamento; as montagens não comprovam integração, animação ou aprovação visual.

## Arquivos de referência

- `01_primeira_fala.png`: primeira fala integral, composição e hierarquia.
- `02_recusa_e_controles.png`: recusa, mesma faixa e alinhamento com XP, exemplo da última fala.
- `gerar_referencias.py`: fonte reproduzível das duas montagens; usa a captura e as texturas locais já existentes. As imagens são referências, não assets finais de interface.
