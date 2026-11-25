# Fênix anime — reconstrução 14/10/2026

Objetivo: refazer forma completa Tori Tori no Mi do modo história, baseada no Marco, com detalhe de plumagem/rosto/chamas e anatomia estável em caminhada, repouso, decolagem, voo e pouso.

Evidência inicial: forma antiga procedural com pernas fixas e asas inteiras; captura anterior em art_src/validation/phoenix/frente.png. Frente -Z, pés do Player em -0.8. Forma antiga offset +0.35 fazia garras flutuarem.

Decisões: fonte procedural editável Godot; rig de nós com ombro/cotovelo/punho, pernas articuladas com apoio calculado e cauda segmentada. Geometria fechada de penas, materiais cel e detalhe em volume. Não deformar escala de tronco para animar. H para sentar/levantar, cancelado por movimento. Preservar kit/balanceamento existente. Pergunta sobre arco de referência enviada; padrão Marco completo.

Trabalho dividido conforme docs/AGENTES.md: principal forma/animação/captura; phoenix_geometria helper plumagem_phoenix.gd; phoenix_movimento controller + teste integração locomocao. Repositório com muitas alterações anteriores: não reverter nem commitar.

Contrato visual: atualizar_movimento(velocidade_local: Vector3, no_chao: bool, em_voo: bool, sentado: bool); voando/ataque preservados. Forma com origem no chão, controller a posiciona em y=-0.8.

Validação pendente: geometria/rig, teste_phoenix, locomocao real história, test_compila, capturas reais e avaliação visual de todas as poses/transições. Não declarar qualidade aprovada só por testes.
