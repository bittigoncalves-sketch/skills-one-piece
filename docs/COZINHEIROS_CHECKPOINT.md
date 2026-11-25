# Cinco cozinheiros — 15/10/2026

Pedido: criar cinco modelos, incluindo Sanji, baseados no acabamento do elenco Nami/Barba Negra/Crocodile; ossos, animações e exposição na cidade inicial.

Referências capturadas na engine: `art_src/validation/cozinheiros/referencias.png`.
Pergunta enviada sobre os outros quatro; sem resposta até iniciar a produção, adotados quatro originais (decisão reversível): Beto, Iara, Ravi e Otto.

Direção corrigida pelo usuário: aliados mais quadriculados, com relevos feitos de quadrados como o Barba Negra. Substitui o primeiro acabamento arredondado. Aplicar ao corpo, rosto, cabelo e roupas, preservando identidade, ossos, clipes e exposição. Sanji de terno preto, camisa azul e franja loira. Geometria autoral no Blender. Sem alterar o elenco jogável.

Plano: fonte editável e gerador → GLBs com descanso/caminhada/saudação/cozinhar → catálogo e cinco peças próximas do spawn → controlador de apresentação → testes de rig, clipes, mapa e captura na cidade.

Estado: investigação concluída; produção iniciada. Projeto já contém numerosas alterações de outras frentes; preservar. Sandbox falha com `bwrap: loopback`; comandos dependem da execução aprovada fora dele.

## Correção com referência enviada

Usuário enviou imagem em `/tmp/codex-clipboard-70doU2.png`, preservada em `art_src/references/cozinheiros/sanji_referencia_usuario.png`: usar como base de altura/proporção e estilo. Mechas retangulares longas, cabeça de mandíbula quadrada, placas maiores no terno e sapatos quadrados. Pergunta pendente sobre escala relativa ao jogador/Barba Negra; sem resposta, preservada por enquanto a escala de apresentação e ajustadas as proporções. Usuário determinou não usar skills não nativas do Codex nesta continuação; não carregar as skills personalizadas.

Antes desta última revisão: 142/142 verificações de rig, clipes, posição e integração passaram em `teste_final.log`. Revalidar a revisão atual. Bateria `./validar.sh rapido` iniciada sem DISPLAY/WAYLAND_DISPLAY; processo em andamento, relatório `regressao_geral.log`.
