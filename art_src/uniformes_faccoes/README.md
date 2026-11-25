# Uniformes personalizados

Criação vetorial procedural original para as roupas dos NPCs genéricos. Os rostos, chapéus, armas, modelos e animações existentes mantêm suas fontes anteriores.

- Marinheiros: camisa branca, azul naval, botões dourados, calça azul e emblema de ave/âncora nas costas.
- Piratas: casaco carvão, camisa listrada, faixa vermelha, botões dourados, botas e caveira com sabres nas costas.
- Destino: NPCs `mp_marine`, `mp_pirate`, oito variantes humanas e quatro homens-peixe; personagens nomeados não são uniformizados.

## Fontes e reprodução

`gerar_uniformes.py` desenha os dois SVGs em `assets/textures/uniformes_faccoes/`. Não depende de serviços ou bibliotecas externas. Execute da raiz:

```bash
python3 art_src/uniformes_faccoes/gerar_uniformes.py
```

O atlas usa coordenadas 64×64, rasterizadas em 512×512 pelo Godot. Alpha transparente fora das roupas permite preservar rostos/mãos. `uniformes_faccoes.gd` combina cópias das imagens, remapeia o UV da roupa equipada do marinheiro e gera mipmaps, compartilhando o material entre NPCs iguais. Não altera os recursos de origem. Para editar à mão, abra os SVGs num editor vetorial; executar o gerador novamente sobrescreve os SVGs.

## Validação

```bash
Godot --headless --path . --fixed-fps 60 --script tools/dev_tests/test_uniformes_faccoes.gd
Godot --path . --display-driver x11 --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script tools/dev_tests/test_uniformes_faccoes.gd -- --capturar
```

Substitua `Godot` pelo executável instalado. Utilize um diretório XDG temporário para testes. Resultado final: 52 checks headless; 54 com renderização e gravação de antes/depois. Logs e capturas estão em `validacao/`.

As capturas usam o construtor real de `PersonagemMinePiece`, também usado pelo Modo História e pelas raids, em cena controlada. Não constituem um playtest completo da campanha. A aprovação artística fica com o usuário.
