# Loja de frutas e HUD — 17/10/2026

Pedido: barra verde e N+número; fome/sede no canto superior direito; frutas com
imagens e ordenadas por preço. Bomu/Suke/Noro = 100; Buki/Bara = 1.000; demais =
500.000 moedas.

Implementação: `barras_de_criaturas.gd`, `SobrevivenciaHud.gd`,
`perfil_de_frutas.gd`, `loja_de_frutas.gd`, `JanelaDeLoja.gd`.
Tabela única para exibição/cobrança. Ordenação crescente, desempate alfabético.
Frutas do Builder também seguem a tabela; campo e aviso de publicação mostram o
valor efetivo. Kit do Builder não é fruta e mantém seu preço editável.

Imagens: 18 PNG de 128 px em `assets/ui/frutas/`, renderizados dos modelos existentes
por `tools/gerar_imagens_frutas.gd` usando GeradorDeMiniaturas. Sem assets externos.
Frutas novas ainda sem PNG usam o ícone de fruta como fallback.

Validação em andamento: compra com saldo exato/insuficiente, ordem, imagens,
ancoragem em três resoluções, capturas reais, regressões das lojas e do Builder.
