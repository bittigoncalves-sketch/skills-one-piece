# Diálogo cinematográfico + instrutor quadrado — checkpoint (21/11/2026)

**Divisão:** Claude = código; Codex = legendas, referências e plano (`art_src/references/dialogo_cinematografico/`, `data/dialogos/treino.json`).
**Decisões do dono:** faixa de legenda + tarjas letterbox; E/Enter/Espaço/clique avança (1º completa a linha), ESC pula.

## Feito (Claude)
- `src/ui/caixa_de_fala_cinematografica.gd` — tarjas + faixa acima do número do nível (âncora = hotbar), máquina de escrever 38 cps, `tocar(linhas, ao_fim)`.
- `src/historia/dialogos_de_npc.gd` — lê `data/dialogos/<id>.json`; cai no padrão do código se faltar arquivo/estado/linha.
- `HistoriaHud._conversar_com`: loja com `dialogo()` fala primeiro e abre a janela no fim; `fala_em_cena()` entra no `is_menu_open`.
- `loja_do_treinador.dialogo()` — estados `primeira`, `repeticao`, `recusa_nivel` (falas provisórias).
- Instrutor com corpo em caixas (`"corpo": "masculino"` na ficha → meta `corpo_historia`); `visual_do_instrutor.gd` adaptado (faixa no `Torso`, ataduras, sem `Manga`).
- Testes: `test_caixa_de_fala` (9/9), `test_instrutor_quadrado`, `test_treino_npc_no_mapa`, `test_treino_de_soco` — todos saída 0.

## Validação visual (21/11/2026, com autorização do dono para abrir janela)
- `tools/dev_tests/captura_instrutor_fala.gd` → `art_src/validation/dialogo_cinematografico/` (5 prints, 1280×720 no jogo real).
- Achados e correções: faixa saía com 114 px e invadia a margem do nível (agora altura fixa 116, folga 14 px medida em 720/1080/1440p); a faixa do instrutor saía VERMELHA (obi do quimono maior que a caixa) → agora ocre, na altura do obi; opacidade da legenda 0,84→0,93.
- Conferido nos prints: tarjas, faixa acima do XP, máquina de escrever, instrutor quadrado com colete índigo, faixa ocre com ponta, ataduras.
- Limite: só 1280×720 foi visto em pixels; as outras resoluções foram medidas numericamente. A faixa ainda cobre parte do painel "Estilo de Combate" (esperado em cena de filme).

## Tamanho e animações do instrutor (21/11/2026)
- Tamanho: ficha `"tamanho": 1.13` → corpo escalado em volta dos pés (1,92 m com o cabelo; o pescador tem 1,77 m); sola em y≈0 (antes −0,03).
- `src/historia/treino/animacoes_do_instrutor.gd`: ciclo de 14 s — guarda saltitante, combo (jab E, jab D, direto D), aponta para o boneco, ensaia o gancho; falando (balão de fala visível) vira "explicar" (mão gesticulando + aceno). Função pura `pose(t, falando)`; o NPC grava o resultado na meta `pose_de_skill` a cada quadro (respeita `economia_fora_da_tela`).
- Prints: `art_src/validation/dialogo_cinematografico/anim_*.png` (5 instantes + altura ao lado do jogador). Não visto: o movimento fluido (só poses congeladas em 1280×720).

## Gatilhos
- Retrato do falante: criar `TextureRect` na faixa quando houver arte por NPC.
- >6 NPCs com diálogo: arquivo-padrão por NPC + teste de dados (limite 90 caracteres/linha).
