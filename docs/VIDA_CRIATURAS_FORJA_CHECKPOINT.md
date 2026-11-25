# Vida das criaturas e forja — 17/10/2026

Pedido: vida acima da cabeça, nível acima da vida em aliados/inimigos do modo
história, exceto bosses; forja com medidor semelhante à pesca e teclas 1–4.

Implementação:
- `src/ui/barras_de_criaturas.gd`, instalado em `HistoriaHud`: lê health/max_health
  dos grupos de criaturas, exclui chefes, mortos, ocultos, fora da câmera ou a mais
  de 40 m; testa oclusão. Segue cabeça/osso quando disponível ou limites da malha.
  Nível vem da propriedade, metadado ou ficha; padrão 1, pois os corpos consultados
  não têm progressão própria. Não altera dano, atributos nem save.
- `FerrariaHud.gd`, `medidor_ferraria.gd`, `bancada_ferraria.gd`: medidor vertical
  com faixa verde/traço branco e movimento contínuo nos dois sentidos; resfriamento
  acelera e estreita a faixa. Dificuldade exportada controla velocidade/largura.
  Quatro pontos, teclado físico/lógico/numérico, mouse e Espaço/Enter.
  Entrada antes do GUI evita acionamento de botão focado; eco é ignorado.
  Penalidade que esgota tempo encerra imediatamente; conclusão não reinicia prêmio.

Validação concluída em Godot 4.6.3:
- `test_barras_de_criaturas.gd`: 19/19; modelos reais, dano, movimento, morte/retorno,
  oclusão, níveis, humano aliado, besta pacífica, exclusão de boss e escala. A
  inspeção visual encontrou margem fixa insuficiente na bovina; agora a margem
  mede a distância do osso ao topo da malha, deixando os chifres livres.
- `test_ferraria_controles.gd`: 20/20, inclusive com renderização X11/Vulkan.
- `test_sobrevivencia_jornada.gd`: 50/50.
- `test_sobrevivencia_integracao.gd`: 15/15, HUD real, missão, machado e autosave.
- `test_barras_de_chefes.gd`: 9/9, regressão das barras existentes.
- Total: 113 verificações específicas; logs desses testes sem SCRIPT ERROR,
  ERROR ou WARNING. Não houve playtest manual do usuário.
- `test_compila`: seis falhas em `tools/anim_editor/studio`, as mesmas documentadas
  em PROJECT_CONTEXT. Nenhum erro de parse nos scripts desta frente.
- Bateria rápida iniciada e interrompida após reproduzir falhas gerais: arena
  sem dummy (já documentada), balanceamento Pika Z e sequência da besta bovina.
  Não foi executada até o fim e não está aprovada. A bovina repetiu 39/40 com o
  novo HUD removido antes das verificações; detalhes na lista de correções.

Evidências: `art_src/validation/vida_forja/` contém comparações das criaturas,
humano aliado, besta pacífica, capturas antes/depois da forja e `logs/`.
As cenas de captura isoladas não criam Player nem capturam o mouse. A integração
headless usa saves de teste, sem ler/gravar a campanha pessoal.

Limites: NPCs de loja sem health/max_health não recebem vida fictícia; o padrão
de nível 1 é apresentação para corpos sem nível configurado, sem criar um sistema
de evolução. Exibição próxima (40 m) foi a suposição anunciada, sem resposta à
pergunta opcional de preferência. Nenhuma mudança em atributos de combate.

Entrega implementada; pendências gerais de IA/arena/studio registradas à parte.
