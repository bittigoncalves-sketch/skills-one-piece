# Primeira missão de madeira e reset total — 11/10/2026

Pedido: colocar a coleta de madeira como primeira missão e adicionar aos status um botão de reset total com confirmação.

Decisões de implementação: missão do Guarda antes dos bandidos, 5 madeiras coletadas após aceitar, 300 XP + 50 ouro (recompensa da primeira missão anterior). A madeira fica no inventário. Perguntados quantidade/recompensa e alcance do reset; sem resposta adicional até este checkpoint. Reset da campanha preserva mapa autoral, aparência, configurações e conteúdo do editor.

Implementado:

- `missoes.gd`, `progressao.gd`, `npc_da_ilha.gd`: missão de madeira, contagem em unidades, pré-requisito dos bandidos e migração do save v1 → v2. Saves que já começaram a cadeia são preservados, sem recompensa retroativa.
- `vegetacao_coletavel.gd`, `marcador_de_missao.gd`: marcador aponta para vegetação disponível mais próxima; após coletar, aponta para o Guarda.
- `JanelaDeStatus.gd`, `HistoriaHud.gd`: botão Reset total da campanha, diálogo com consequências, Cancelar com foco inicial e ESC cancelando apenas o diálogo. Fechar o status descarta confirmação pendente.
- `ModoHistoria.gd`: só o sinal confirmado solicita reset; salva a campanha nova antes de recarregar o mundo. Falha de gravação conserva a campanha atual. O reload remove os estados temporários do mundo. `progressao.reiniciar()` também passou a limpar fruta, ativação, raça e ilha, antes omitidas.
- Testes atualizados de cadeia/missionário/marcadores/coleta e novo `test_missao_madeira_reset.gd`, usando exclusivamente saves e mapas de teste.

## Validação concluída

- `test_missao_madeira_reset.gd`: **26/26** verificações em headless; execução gráfica final **30/30**, incluindo quatro capturas e acionamento dos botões reais do diálogo por sinais `pressed`.
- Cancelar, ESC e fechar a janela preservam o save. Falha de gravação simulada com destino que é diretório preserva o progresso e a cena. Confirmar recarrega o mundo, volta aos valores iniciais e salva; o hash do mapa permanece igual.
- Passaram também `test_bandidos_e_missao`, `test_cadeia_do_guarda`, `test_machado_madeira`, `test_marcador_de_missao`, `test_modo_historia`, `test_progressao` e `test_vida_energia_historia`. A coleta física pelo machado completa a missão e o autosave mantém a missão pronta.
- Godot 4.6.3, Forward+, RTX 3050; Weston headless isolado, com subjanela embutida (`--single-window`) para capturar a confirmação. Inspecionadas missão/marcador, botão nos status, consequências/Cancelar na confirmação e status nível 1 após reset.
- Evidências permanentes em `art_src/validation/missao_madeira_reset/`: `teste_headless.log`, `teste_visual.log`, `01_missao_madeira.png`, `02_status_reset.png`, `03_confirmacao_reset.png`, `04_status_zerado.png`.
- Sem `SCRIPT ERROR`/`Parse Error` na execução gráfica final. O compositor virtual sem ponteiro emite `pointed_win is null` ao tentar capturar o mouse, como na validação anterior do machado. Não representa playtest manual do desktop.

Estado: implementação e validação concluídas. O save do usuário não foi resetado; todos os resets dos testes usam `test_missao_madeira_reset.json`. Próximo passo opcional: playtest manual pelo Guarda da vila e pela janela M.
