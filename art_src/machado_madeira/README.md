# Machado e madeira

Fontes editáveis dos dois modelos da loja do Modo História:

- `machado_lenhador.blend`: cabo de cedro, pega de couro, anéis de latão e cabeça de aço com fio separado.
- `tabuas_madeira.blend`: três tábuas chanfradas com veios em geometria.
- `gerar.py`: recria os arquivos Blender e exporta os GLBs para `mapas/modelos/`.

Na raiz do projeto, para recriar os assets:

```sh
blender -b --python art_src/machado_madeira/gerar.py
```

O script sobrescreve as fontes e os GLBs: preserve ajustes manuais antes de regenerar.
O encaixe do machado fica na origem, com o cabo em +Y e o fio em +X no Godot.
`tools/gerar_pose_machado.gd` gera o estilo e as poses de corte usadas pelo executor de combate.
`tools/importar_machado_madeira.gd` registra os modelos no catálogo da loja.

Capturas em execução e logs de validação: `art_src/validation/machado_madeira/`.
Requisitos, comportamento e limites: `docs/MACHADO_MADEIRA_CHECKPOINT.md`.
