"""Desenha dois atlas de roupa originais no UV biped 64x64; não lê imagens externas.
Execute na raiz: python3 art_src/uniformes_faccoes/gerar_uniformes.py
SVGs são as fontes editáveis usadas diretamente pelo importador do Godot.
"""
from pathlib import Path

DESTINO = Path(__file__).resolve().parents[2] / 'assets/textures/uniformes_faccoes'


def gerar(marinha):
    partes = ['<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 64 64">']
    claro = '#eef2ed' if marinha else '#303745'
    sombra = '#c4d2dc' if marinha else '#202531'
    azul = '#234f83' if marinha else '#a62d3c'
    ouro = '#d6af62'

    def rect(x, y, w, h, cor):
        partes.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{cor}"/>')

    def path(d, cor, stroke='none', width=.12):
        partes.append(f'<path d="{d}" fill="{cor}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>')

    def circle(x, y, r, cor):
        partes.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{cor}"/>')

    # Tronco: frente 20,20..28,32; costas 32,20..40,32; laterais e tampas.
    rect(16, 20, 24, 12, claro)
    rect(20, 16, 16, 4, claro)
    for x in (16, 28):
        rect(x, 20, 4, 12, sombra)
        path(f'M{x+.4} 21 V29', 'none', claro, .16)
    for x in (20, 32):
        rect(x, 20, .28, 12, sombra)
        rect(x+7.72, 20, .28, 12, sombra)
        path(f'M{x+.7} 26 L{x+1} 28 M{x+7.2} 27 L{x+7} 28.7', 'none', sombra, .15)
    # Gola e lenço / lapelas.
    if marinha:
        path('M21 20 H27 L24 24 Z', azul)
        path('M21 20 L24 22.6 L27 20 M21.5 20 L24 21.9 L26.5 20', 'none', '#f8faf3', .18)
        path('M23.5 23 L24.5 23 L24.35 26 L23.8 26.8 L23.6 25.7 Z', azul)
        rect(32, 20, 8, 2, azul)
        path('M32.5 20 V21.5 H39.5 V20', 'none', '#f8faf3', .16)
        rect(25.1, 24.1, 2.15, 1.5, sombra)
        rect(25.2, 24.2, 1.95, 1.2, claro)
        path('M25.3 24.4 H27', 'none', azul, .13)
    else:
        rect(22.8, 20, 2.4, 8.5, '#e8d8b6')
        for y in (21, 22.5, 24, 25.5, 27):
            rect(22.8, y, 2.4, .45, '#a43c46')
        path('M20.5 20 H22.8 L23.2 25 L21.2 22.8 L22 22.2 Z', '#48515c')
        path('M27.5 20 H25.2 L24.8 25 L26.8 22.8 L26 22.2 Z', '#48515c')
        path('M22.8 20 L23.2 25 M25.2 20 L24.8 25', 'none', ouro, .14)
        for y in (25.5, 27, 28):
            for x in (22, 26): circle(x, y, .17, ouro)
    # Barra, cinto, fivela; piratas com faixa vermelha.
    rect(16, 29, 24, 3, azul if not marinha else claro)
    if not marinha:
        path('M16 29.7 H40 M16 30.6 H40', 'none', '#cf5256', .13)
    rect(16, 31, 24, .8, '#293341' if marinha else '#372b29')
    rect(23.2, 30.85, 1.6, 1, ouro)
    rect(23.5, 31.06, 1, .55, '#30313b')
    # Emblemas autorais nas costas: ave sobre âncora / caveira com sabres.
    if marinha:
        path('M33 23.1 Q34.5 22.7 36 24 Q37.5 22.7 39 23.1 L37 24.3 L36 25 L35 24.3 Z', azul)
        path('M36 24.8 V27.3 M34.2 26 Q36 28.9 37.8 26 M35.2 25.3 H36.8', 'none', azul, .25)
        circle(36, 24.7, .25, azul)
        # MARINE em glifos vetoriais: independente de fontes externas.
        letras = ['101/111/101/101/101', '010/101/111/101/101', '110/101/110/101/101', '111/010/010/010/111', '101/111/111/111/101', '111/100/110/100/111']
        for i, letra in enumerate(letras):
            for yy, linha in enumerate(letra.split('/')):
                for xx, p in enumerate(linha):
                    if p == '1': rect(33.15+i*.95+xx*.21, 28+yy*.17, .21, .17, azul)
    else:
        path('M33.7 24 L38.3 28 M38.3 24 L33.7 28', 'none', '#eee0bf', .28)
        path('M33.3 23.7 L34.2 24.5 M38.7 23.7 L37.8 24.5', 'none', ouro, .35)
        path('M34.3 25.2 C34.3 22.8 37.7 22.8 37.7 25.2 L37.1 26.2 V27.1 H34.9 V26.2 Z', '#eee0bf')
        for x in (35.2, 36.8): circle(x, 25.15, .42, '#242a35')
        path('M36 25.6 L35.7 26.1 H36.3 Z', '#242a35')
        path('M35.6 26.5 V27.1 M36.4 26.5 V27.1', 'none', '#242a35', .13)
    # Mangas: oito unidades de UV, deixando mãos/pele originais expostas.
    for x, y in ((40, 16), (32, 48)):
        rect(x+4, y, 8, 4, claro)
        rect(x, y+4, 16, 8, claro)
        for side in (0, 8): rect(x+side, y+4, 4, 8, sombra)
        rect(x, y+10.7, 16, 1.3, azul)
        rect(x, y+11, 16, .18, ouro if not marinha else '#f8faf3')
        rect(x+4.4, y+4, 3.2, .7, azul)
        for q in (.7, 1.3, 1.9): rect(x+4+q, y+4.1, .28, .5, ouro)
        path(f'M{x+4.35} {y+5.5} V{y+10} M{x+7.6} {y+6.5} V{y+10}', 'none', sombra, .12)
    # Calças e botas, ambos os lados. Nenhuma pintura fora das ilhas UV.
    for x, y in ((0, 16), (16, 48)):
        rect(x+4, y, 8, 4, '#263e60' if marinha else '#51454b')
        rect(x, y+4, 16, 12, '#304e76' if marinha else '#51454b')
        for side in (0, 8): rect(x+side, y+4, 4, 12, '#263e60' if marinha else '#40373e')
        for side in (4, 12):
            path(f'M{x+side+.4} {y+4} V{y+10} M{x+side+3.6} {y+4} V{y+10}', 'none', '#6883a0' if marinha else '#79626a', .12)
            path(f'M{x+side+.7} {y+9} L{x+side+2.8} {y+9.5}', 'none', '#203650' if marinha else '#342e35', .22)
        rect(x, y+11, 16, 5, '#202c3b' if marinha else '#302a2c')
        rect(x, y+11, 16, .45, '#536075' if marinha else '#766057')
        rect(x, y+15.4, 16, .6, '#151f2d')
        rect(x+8, y, 4, 4, '#151f2d')
        for side in (4, 12):
            path(f'M{x+side+.6} {y+12} V{y+14.9} H{x+side+3.2}', 'none', '#566175', .16)
    partes.append('</svg>')
    return '\n'.join(partes) + '\n'


if __name__ == '__main__':
    DESTINO.mkdir(parents=True, exist_ok=True)
    for nome, marinha in (('marinheiro', True), ('pirata', False)):
        (DESTINO / f'{nome}.svg').write_text(gerar(marinha))
        print(DESTINO / f'{nome}.svg')
