# Baú e skins da campanha — 18/11/2026

## Entrada do Modo História — 19/11/2026

- Toda entrada no Modo História abre `EntradaHistoria`: personagem 3D de frente à direita, **Jogar** verde e **Customizar** vermelho à esquerda. A prévia usa o corpo real, a aparência salva e uma luz frontal; fica fixa, sem girar com o mouse.
- **Customizar** abre sexo e tons de pele, incluindo personagens de campanhas existentes. **Concluir personalização** retorna à entrada com a prévia atualizada. **Jogar** grava a aparência e inicia a campanha sem reiniciar nível ou progresso. Em campanha nova, Jogar abre a customização enquanto nenhum sexo foi escolhido.
- **Cancelar** descarta a edição atual. **Voltar ao menu** não grava mudanças, mesmo após concluir a personalização. Falha ao salvar preserva a aparência anterior em memória e permite tentar de novo.
- Implementação: `src/ui/entrada_historia.gd`, configuração de `escolha_corpo_historia.gd`, opções de frente fixa/base oculta em `PreviaDoPersonagem.gd` e entrada incondicional em `ModoHistoria.gd`. Testes automatizados comuns continuam pulando a interface; `exigir_escolha_de_corpo` ativa o fluxo completo nos testes de UI.
- Correção pontual encontrada na integração: `InventarioDaHistoria.embutir()` era chamado antes de `_ready`, acessando um cabeçalho inexistente. Agora registra o modo e aplica o estilo depois de construir os controles, preservando a organização da mochila.
- Validação no Godot 4.6.3: entrada **30/30** com janela Forward+ e capturas; corpos/rig/save/respawn **168/168** headless; seletor **28/28**; política de teste **4/4**. Sem `SCRIPT ERROR`, `Parse Error` ou asserções com falha nos logs finais. Há avisos de animação `idle` no teste de respawn e recursos/objetos no encerramento; não se afirma regressão global validada.
- Capturas e logs: `art_src/validation/entrada_historia/`. Saves isolados em `/tmp`; o save pessoal não foi modificado.

## Tons de pele — 19/11/2026

- A seleção de sexo agora oferece seis tons: Muito claro, Claro, Médio, Moreno, Escuro e Muito escuro, para ambos os corpos. São 12 combinações: os dois atlas originais (Médio) mais dez novos SVGs de 384×512.
- A troca atualiza os dois modelos da tela; rosto, orelhas, colo, abdômen masculino, braços, mãos e dedos seguem a mesma paleta. Roupas, olhos e cabelos mantêm suas cores. Lábios, sombra e luz têm cores próprias por tom.
- O campo `tom_de_pele` fica salvo com a campanha e acompanha PlayerRig, remontagem, respawn, Mochila e Status. Saves antigos ou valores inválidos usam Médio; cancelar não grava a prévia e reiniciar a campanha restaura Médio.
- Fonte única das paletas: `assets/textures/skins_historia/tons.json`. O gerador abaixo exporta todas as combinações; `src/player/tons_de_pele.gd` fornece validação e caminhos para o jogo.
- Uso atual: na entrada do Modo História, clique em **Customizar**, escolha sexo e tom, conclua e pressione **Jogar**. A aparência salva já aparece na prévia em visitas futuras.
- Validação final no Godot 4.6.3/Forward+: `test_tons_de_pele.gd -- --capturar` **133/133**; `test_corpo_historia.gd -- --capturar` **164/164**, ambos com saída 0. Os seis tons foram capturados na seleção; Claro masculino e Muito escuro feminino também foram conferidos na campanha e em agachamento. Persistência, reentrada, cancelamento, reset, respawn e prévias foram verificados.
- Evidências e logs: `art_src/validation/tons_de_pele/`. Testes usaram dados isolados em `/tmp`, sem alterar o save pessoal. Logs ainda registram animação `idle` ausente no respawn e objetos/recursos no encerramento; o teste com janela também registra mensagens de decodificação Unicode sem falhas nas asserções. Não se declara regressão global validada ou aprovação artística do usuário.

Implementado no projeto, com fonte editável e capturas do Godot 4.6.3 (Forward+, RTX 3050).

## Uso

- Escolher Masculino ou Feminino ao iniciar uma campanha sem corpo definido. Saves que já possuem escolha usam as novas texturas automaticamente.
- O feminino tem cabelo longo preso à junta Head, com mechas traseiras, laterais e franja. Rosto, roupa, abdômen masculino e cabelo curto masculino são texturas. As proporções e juntas existentes foram preservadas.
- Mochila e Status usam o corpo selecionado, em vez do antigo boneco genérico.
- Na central de janelas, aba BLOCOS, seção **Itens de exploração**, o baú pode ser colocado no inventário. Clique esquerdo: 16; direito: 1. Ícone, hotbar, divisão de pilha, movimentação e save usam o inventário existente.
- O baú é **colecionável** nesta entrega; não há uma segunda abertura com loot dentro do inventário. A pergunta sobre isso não recebeu resposta durante a execução.
- A abertura dos naufrágios também entrega um baú e mantém o ouro original. Sem espaço, não marca aberto nem paga. Essa regra passou em cenário controlado; o teste no mapa completo encontrou zero naufrágios registrados, portanto a coleta por E no mapa vivo permanece não validada. O catálogo é o caminho de obtenção validado.

## Fontes

- `art_src/skins_historia/gerar_texturas.py`: fonte autoral dos atlas SVG, 384×512, seis faces por linha e oito linhas por corpo. Regenerar com `python3 art_src/skins_historia/gerar_texturas.py`.
- `assets/textures/skins_historia/{masculino,feminino}.svg`: texturas exportadas e editáveis.
- `src/player/skin_historia.gd`: UVs, materiais e cabelo longo procedural.
- `src/player/corpo_historia.gd`: integração com rig, mãos e corpo da campanha.
- `src/inventario/bau_de_tesouros.gd`: item `historia:bau_tesouros`, pilha máxima 16.
- O modelo do baú reutiliza `mapas/modelos/chest_closed.glb`, já existente no projeto. Não foi importado um novo modelo externo nem se reivindica autoria do modelo existente.
- `tools/dev_tests/capturar_bau_icone.gd`: renderiza o modelo real em PNG transparente, 256×256, em `assets/ui/itens/bau_tesouros.png`. Executar no Godot com renderização e janela, opção `--script`.

## Validação

- `test_corpo_historia.gd -- --capturar`: **148/148**, saída 0. Fluxo de escolha, save/reentrada, ambos os rigs, dedos, pega dos itens, remontagem, andar, agachar e respawn.
- `test_bau_tesouros.gd -- --capturar`: **22/22**, saída 0. Inventário cheio, ouro original, idempotência, pilhas, divisão, shift, persistência, transparência do ícone, cliques do catálogo, campanha real e prévia feminina na mochila.
- Capturas em `art_src/validation/bau_skins/`: seleção, ambos os corpos na campanha/agachados, baú no inventário, cabelo visto de trás e agachado. A captura anterior da seleção continua em `art_src/validation/corpo_historia/01_selecao.png` para comparação.
- Importação dos assets concluída. Saves de teste isolados com `XDG_DATA_HOME` em `/tmp`; o save pessoal não foi modificado.

## Limitações observadas

- `test_compila.gd`: **11 scripts não compilam**, fora dos arquivos alterados nesta tarefa: RenderSkyProcedure, quatro scripts aposentados de A11_luta_builder e seis de tools/anim_editor/studio. Log integral junto às capturas.
- `test_naufragios.gd`: o mapa atual carregou zero naufrágios registrados; o teste esperava cinco, acessou índice inexistente e atingiu timeout. Não se afirma validação dessa interação no mapa completo.
- O teste dos corpos registra avisos de animação `idle` ausente ao forçar respawn. Os testes também registram recursos/objetos ainda em uso ao encerrar. As verificações focadas passaram, mas os logs não estão isentos desses avisos.
- Cabelo acompanha a cabeça como malha rígida; não possui simulação de fios. A revisão visual abrange seleção, posição em pé e agachamento, não todos os golpes e transformações.
- Não houve aprovação artística do usuário nem validação de regressão global verde.
