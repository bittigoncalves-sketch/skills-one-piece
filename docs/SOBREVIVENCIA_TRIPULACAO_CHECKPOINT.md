# Sobrevivência, tripulação e início da campanha — 15/10/2026

Funcionalidade implementada e validada; bateria geral em andamento. Preservar alterações locais anteriores. Nenhum commit solicitado.

## Regras e decisões

- Fome 200, consumo 50/dia; zero bloqueia regeneração. Sede 300, consumo 75/dia; zero mata em quatro dias do ciclo existente (`CicloDiaNoite.DURACAO_DO_DIA`), com aviso no último dia. Menus pausam o ciclo. Após morrer de sede, a nova vida restaura necessidades.
- B: lista de até 16 membros; seis vagas cinza com + preto, arrastar ou selecionar/clicar; vida/fome dos membros e controles individuais de pets. Sexto cargo combatente aprovado como entrada em `provisoes.gd:CARGOS`.
- Cozinheiro: alimentação e estoque para um dia, considerando nutrição e quantidade de membros. Construtor: madeira e reparo do casco. Médico: impede morte por NPC comum com 1 HP, inclusive projéteis; boss continua letal. Estoquista: somente reserva depositada, déficit diário, prioridade comida → saúde → casco; doses médicas calculadas pelo déficit. Sem estoquista, cargos usam ouro do jogador com limite de 100/dia e aviso de gasto.
- Comandante amigável acompanha; neutro combate inimigos; maligno permite política de roubo, morte ou captura de NPCs, persistida por vítima. Capturados acompanham o jogador.
- Comida: pão +25/1 moeda, refeição +75/3, água potável +75/1. Vendedor junto às barracas; ferreiro junto à ferraria, ambos inseridos pelo bootstrap sem alterar o mapa pessoal.
- Missões: vara gratuita → peixe raro/20 moedas → ferraria/machado → três árvores (arbustos não contam) → pirata ou marinheiro/60 pães. Sem recompensa extra na primeira/quarta. Recompensas únicas e migração de campanhas anteriores sem duplicá-las.

Alinhamentos aprovados pelo Claude via ponte por delegação expressa do usuário. Permissões da plataforma seguem o mecanismo próprio. Refinamento visual da ferraria aprovado: bancada, lâmina, fornalha e tanque; impacto/vapor, com alternativas de teclado/toque.

## Arquivos centrais

`src/historia/tripulantes/{provisoes,sobrevivencia,aliado_da_tripulacao,socorro}.gd`; `src/historia/missoes/inicio_da_jornada.gd`; lojas de comida/ferreiro; `src/ui/{MenuDeComportamento,SobrevivenciaHud,FerrariaHud,bancada_ferraria,celula_tripulacao}.gd`. Integração em progressão, ciclo, vida, dano, pets, navegação, HUD e coleta. `DamageZone`/`SwordBlade` repassam autoria do ataque sem confundir com marca de corpo a corpo. Fixture `jornada_concluida.gd` adapta regressões posteriores ao tutorial.

Assets NPCs: `mapas/modelos/npc_comida.glb`, `npc_ferreiro.glb`, exportados pelo importador idempotente `tools/importar_npcs_na_loja.gd`, com fonte base já existente. Fonte vetorial da bancada: `src/ui/bancada_ferraria.gd`.

## Validação concluída

Godot 4.6.3. **87 checks novos aprovados**: jornada 50, integração 14, economia 23. Incluem quatro dias em passos fracionários, consumo, regeneração, orçamento, persistência, médico/NPC/boss/projétil, drag/drop real, sequência de missões, retry da ferraria, autosave e morte de sede. Testes usam saves próprios.

`SOP_PORTA=24668 XDG_DATA_HOME=/tmp/sobrevivencia_ab_atual DISPLAY= WAYLAND_DISPLAY= ./validar.sh sobrevivencia npcs_e_lojas bandidos_e_missao`: **5 suítes aprovadas, zero falhas** em `art_src/validation/sobrevivencia/logs/final_da_frente.log`. Regressões anteriores aprovadas: machado_madeira, missao_madeira_reset, pets_comportamento, tripulacao, tripulantes_de_bordo. Na bateria geral também passaram cadeia_do_guarda, ciclo_dia_noite, combate_historia e defesa_historia.

Capturas reais inspecionadas em `art_src/validation/sobrevivencia/`: tripulação, três etapas da ferraria, ferraria dentro da loja, vendedor e ferreiro. UI em OpenGL; NPCs/cenário em Forward+ (RTX 3050 6 GB). Scripts de captura não criam Player nem capturam o mouse. Avaliação visual em 1280×800; não houve playtest manual de uma campanha inteira de quatro dias.

## Portão geral e exceção desta entrega

`DISPLAY= WAYLAND_DISPLAY= ./validar.sh rapido` iniciado em 15/10/2026; resultado corrente em `art_src/validation/sobrevivencia/logs/rapido.log`. Não declarar portão verde. Regra de `docs/guia/COMO_TRABALHAR.md:66` preservada. Claude aceitou exceção apenas para esta entrega, com categorias explícitas.

**Comprovadas por A/B (6 suítes):** `test_arena`, `test_asas_de_anjo`, `test_ataque_aereo`, `test_ataques_contextuais`, `test_bomu_z_rush`, `test_chute_giratorio`. Mesmas asserções de dummy ausente no estado atual e no HEAD `9301956`. Comparação em 15/10/2026: `git archive HEAD` extraído em `/tmp/sobrevivencia_base_head`; Godot importado ali; execução de cada teste com `--headless --path /tmp/sobrevivencia_base_head --script tools/dev_tests/<teste>.gd`, `SOP_PORTA=24666`, `XDG_DATA_HOME=/tmp/sobrevivencia_ab_head`. Preferências de arena iguais, copiadas para dados isolados; campanha pessoal não copiada. Logs e códigos de saída em `logs/base_head/`. Nenhum stash, reset ou edição da arena.

**Observada, não atribuída por A/B (studio, 1 suíte/6 scripts):** `tools/anim_editor/studio/rig_scene.gd`, `main.gd`, `timeline.gd`, `test_selection.gd`, `test_studio.gd`, `view.gd`. `test_compila` reprova os seis. Dependências usam `res://document.gd`, `main.gd`, `view.gd`, `selection.gd`, `rig_scene.gd`, ausentes na raiz do projeto; não dependem dos scripts desta implementação. Arquivos não versionados, sem snapshot anterior; logs antigos em /tmp desapareceram na retomada. Claude relatou memória de sessão de 14/10 com falhas em anim_editor, sem comparação anterior; isso é evidência indireta, não prova. Studio preservado.

Outras falhas gerais ainda em apuração: água, bestas, balanceamento, corte e camada visual dos cozinheiros. Elas NÃO são automaticamente classificadas como anteriores só por estarem fora da frente. `test_agua` carrega ModoHistoria, alterado nesta implementação; exige diagnóstico próprio.

A antiga expectativa de 13 frutas em `test_npcs_e_lojas` foi corrigida por aprovação delegada: compara catálogo e botões vigentes, sem alterar as frutas. Teste final aprovado.

## Próximo passo / pendência de base

Concluir leitura da bateria geral, registrar resultados e qualquer correção necessária. Sessão de execução geral: 58907. Não repetir os testes já aprovados sem nova alteração relevante.

Antes da próxima grande frente, o usuário deve versionar ou commitar o estado atual para permitir A/B completo; não fazer commit automaticamente. Contagem “25 testes” desatualizada em COMO_TRABALHAR: corrigir em frente documental quando o portão voltar a zero falhas.
