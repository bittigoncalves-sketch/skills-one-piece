# Texturas de marinheiros e piratas — 2026-11-12

Pedido: criar e implementar uma textura personalizada para cada grupo.
Direção assumida enquanto aguarda preferência: marinheiros branco/azul, piratas carvão/vermelho, emblemas próprios.
Destino: NPCs genéricos do Modo História, incluindo variantes humanas e homens-peixe. Personagens nomeados conservam a identidade.
Fonte: dois atlas SVG autorais de roupas, com gerador reproduzível. Preservar rostos, mãos, armas, rig e animações.
Integração concluída: `src/historia/east_blue/personagem_mine_piece.gd` chama `uniformes_faccoes.gd` ao montar o NPC. O helper aplica materiais ao corpo e à roupa equipada do marinheiro, com cache por material de origem; GLBs não foram modificados.
Validação: importação Godot 4.6.3 sem erros no log da execução final; 52 verificações headless e 54 na execução com renderização (incluem as duas capturas), zero falhas.
Cobertura: marine, pirate, pirate1..8, fishman1..4, Morgan como controle negativo; comparação de pixels do rosto, preservação das armas, disponibilidade de animações, procedure de nascimento e chamada de renascimento, cache entre instâncias.
Evidência visual: `validacao/antes.png` e `validacao/depois.png`, renderizados no Godot com os NPCs reais em cena controlada. Revisados frente e costas; corrigida a camada de roupa equipada que inicialmente ocultava a camisa personalizada.
Limites: não foi feito playtest prolongado da campanha nem validação visual individual das 14 variantes. A geometria existente foi preservada; o trabalho cria roupas, não novos modelos.
Próximo passo: avaliação artística do usuário, se desejar ajustes de paleta/emblemas.
