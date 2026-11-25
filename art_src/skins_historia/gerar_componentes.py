"""Fonte editável dos SVGs modulares da personalização. Sem bibliotecas externas.
Exporta fragmentos vetoriais num recurso JSON, composto pelo Godot em um atlas.
As chaves {cor} são substituídas apenas por cores do catálogo validado.
"""
import json
from gerar_texturas import OUT, face, rect, path

TONE = {key: '{' + key + '}' for key in
        ('pele', 'sombra', 'luz', 'labio', 'brilho_labio', 'bochecha', 'boca')}


def cores(svg, female):
    for old, new in {
        '#35251f': '{cabelo}', '#654032': '{cabelo_luz}',
        '#c65e50' if female else '#246d79': '{roupa}',
        '#873f40' if female else '#194d5b': '{roupa_sombra}',
        '#db8570' if female else '#408593': '{roupa_luz}',
        '#43776a' if female else '#3a5149': '{olhos}',
    }.items():
        svg = svg.replace(old, new)
    return svg


def base_cabeca(side, female):
    s = rect(0, 0, 64, 64, '{pele}')
    if side == 0:
        if female:
            s += path('M25 50l7 -2l7 2l-7 4z', '{labio}')
            s += path('M28 50h8', 'none', '{brilho_labio}', 1)
            s += rect(10, 43, 9, 2, '{bochecha}') + rect(45, 43, 9, 2, '{bochecha}')
        else:
            s += path('M24 51h16', 'none', '{boca}', 2)
            s += path('M18 55l7 4h14l7 -4', 'none', '{sombra}', 2)
        s += path('M7 40v11l7 8h36l7 -8V40', 'none', '{sombra}', 1)
    elif side in (2, 3):
        s += rect(27, 30, 11, 16, '{luz}') + rect(31, 34, 4, 8, '{sombra}')
    return s


def cabelo(side, female):
    if side == 0:
        return path('M0 0H64V18L55 14L49 18L43 10L27 16L16 13L8 24H0Z' if female else
                    'M0 0H64V20H57V13H42V10H20V15H7V28H0Z', '{cabelo}') + path('M3 3H57V7H38V10H18V7H3Z', '{cabelo_luz}')
    if side in (1, 4):
        s = rect(0, 0, 64, 64, '{cabelo}')
        for x in (7, 17, 29, 42, 54):
            s += path(f'M{x} 2v45l-3 14', 'none', '{cabelo_luz}', 2)
        if not female and side == 1:
            s += path('M0 49l10 -3l4 7h36l4 -7l10 3v15H0Z', '{pele}')
        return s
    if side in (2, 3):
        return path('M0 0H64V48L52 53V24H39V20H0Z' if female else
                    'M0 0H64V28H45V22H16V37H8V20H0Z', '{cabelo}') + path('M5 6h49v9', 'none', '{cabelo_luz}', 2)
    return ''


def olhos(style, female):
    s = ''
    for x in ((12, 38) if female else (11, 39)):
        if style == 'original' and female:
            s += path(f'M{x} 30l3 -3h10l3 3v8l-3 3h-10l-3 -3z', '#fff1dc')
            s += rect(x+6, 29, 7, 12, '{olhos}') + rect(x+8, 29, 4, 10, '#182c32')
            s += rect(x+7, 30, 3, 3, '#ffffff')
            s += path(f'M{x-3} 26l4 3h13l3 2', 'none', '{cabelo}', 2)
        elif style == 'original':
            s += rect(x, 28, 15, 8, '#f9e6cb') + rect(x+5, 28, 6, 8, '{olhos}')
            s += rect(x+7, 28, 4, 7, '#172c30') + rect(x+6, 29, 2, 2, '#ffffff')
        else:
            height = {'amendoados': 9, 'grandes': 14, 'serenos': 6}[style]
            top = 30 if style == 'serenos' else 27
            s += path(f'M{x} {top+3}l4 -3h9l3 3v{height-4}l-4 2h-9l-3 -2z', '#fff0dc')
            s += rect(x+5, top+1, 7, height-1, '{olhos}') + rect(x+8, top+1, 3, height-2, '#20252a')
            s += rect(x+6, top+2, 2, 2, '#ffffff')
            s += path(f'M{x} {top+3}l4 -3h9l3 3', 'none', '{cabelo}', 1.5)
    return s


def sobrancelhas(style, female):
    s = ''
    for x in ((12, 38) if female else (11, 39)):
        if style == 'original':
            s += path(f'M{x} 23l6 -2l8 1', 'none', '{cabelo_luz}', 2) if female else path(f'M{x-1} 21l16 2v3l-16 -1z', '{cabelo}')
        elif style == 'retas':
            s += rect(x, 22, 15, 2, '{cabelo}')
        elif style == 'arqueadas':
            s += path(f'M{x-1} 24l6 -5l10 3', 'none', '{cabelo}', 2)
        else:
            s += path(f'M{x-1} 20l7 -1l10 3v4l-10 -3l-7 1z', '{cabelo}')
    return s


def roupa(style, row, side):
    s = rect(0, 0, 64, 64, '{roupa}')
    s += rect(0, 0, 4, 64, '{roupa_sombra}') + rect(60, 0, 4, 64, '{roupa_sombra}')
    s += path('M7 4v56M57 4v56', 'none', '{roupa_luz}', 1)
    if style == 'listrada':
        for y in (8, 24, 40, 56):
            s += rect(4, y, 56, 6, '#ead9b9')
    if row == 1 and side == 0:
        s += path('M20 0h24L32 16Z', '{pele}')
        if style in ('camisa', 'casaco'):
            s += path('M14 0h7l11 17L43 0h7L40 25l-8 -8l-8 8Z', '#e6d8b7')
            s += rect(30, 18, 4, 46, '{roupa_sombra}')
            for y in (32, 50): s += rect(31, y, 3, 3, '#dba95a')
            s += path('M8 36h13v12H8Z', 'none', '{roupa_luz}', 2)
        elif style == 'marinheiro':
            s += path('M8 0h12l12 24L44 0h12L39 36H25Z', '#eee0c1')
            s += path('M13 0l19 29L51 0', 'none', '{roupa_sombra}', 2)
            s += path('M31 23l-7 22l8 -5l8 5l-7 -22Z', '#a94c45')
        if style == 'casaco':
            for x in (8, 51):
                s += rect(x, 4, 5, 15, '#dba95a')
                s += rect(x, 34, 5, 5, '#dba95a')
    if row == 2 and side == 0 and style in ('camisa', 'casaco'):
        s += rect(30, 0, 4, 64, '{roupa_sombra}')
        for y in (10, 32, 53): s += rect(31, y, 3, 3, '#dba95a')
        s += path('M8 27h15v16H8M41 27h15v16H41', 'none', '{roupa_luz}', 2)
    if row == 1 and side == 1 and style == 'marinheiro':
        s += path('M7 0h50v28H7Z', '#eee0c1') + path('M12 0v23h40V0', 'none', '{roupa_sombra}', 2)
    if row == 6:
        s += rect(0, 49, 64, 10, '#ead9b9') + rect(0, 60, 64, 4, '{roupa_sombra}')
    return s


def calca(style, side):
    base, shadow, light = {'escura': ('#343640', '#22242c', '#555767'),
                           'areia': ('#c0a47e', '#8d7459', '#dcc5a3'),
                           'listrada': ('#485968', '#2e3d4d', '#b9b6a6')}[style]
    s = rect(0, 0, 64, 64, base)
    if style == 'listrada':
        for x in (12, 28, 44): s += rect(x, 0, 3, 64, light)
    s += rect(0, 0, 4, 64, shadow) + rect(59, 0, 3, 64, light)
    if side in (0, 1): s += path('M9 6h31l9 7M12 51l34 -4M15 57h34', 'none', light, 1)
    return s


def sapato(style, side):
    if style == 'sandalia':
        s = rect(0, 0, 64, 64, '{pele}')
        s += rect(0, 48, 64, 16, '#41332c')
        s += path('M0 8L64 38M0 38L64 8', 'none', '#885635', 9)
        return s
    color = '#e8e3d8' if style == 'tenis' else '#563e32'
    s = rect(0, 0, 64, 64, color) + rect(0, 50, 64, 14, '#b9b8b1' if style == 'tenis' else '#29262a')
    if style == 'tenis':
        s += rect(0, 38, 64, 6, '#a4483f')
        if side in (0, 4):
            s += rect(23, 4, 18, 30, '#58565b')
            for y in (8, 16, 24): s += path(f'M22 {y}l20 5', 'none', '#f5efdc', 3)
    else:
        s += path('M9 8h46v32H9Z', 'none', '#a27a54', 2)
        s += rect(0, 17, 64, 10, '#372d2a') + rect(25, 16, 14, 12, '#c9a15f')
    return s


def main():
    data = {key: {} for key in ('original', 'cabeca', 'cabelo', 'olhos', 'sobrancelhas', 'nariz', 'roupas', 'calcas', 'sapatos')}
    for female, sex in ((False, 'masculino'), (True, 'feminino')):
        data['original'][sex] = [[cores(face(row, side, female, TONE), female) for side in range(6)] for row in range(8)]
        data['cabeca'][sex] = [base_cabeca(side, female) for side in range(6)]
        data['cabelo'][sex] = [cabelo(side, female) for side in range(6)]
        data['olhos'][sex] = {style: olhos(style, female) for style in ('original', 'amendoados', 'grandes', 'serenos')}
        data['sobrancelhas'][sex] = {style: sobrancelhas(style, female) for style in ('original', 'retas', 'arqueadas', 'espessas')}
        data['nariz'][sex] = path('M29 36l-2 8h6' if female else 'M30 34l-3 10h8', 'none', '{sombra}', 2)
    for style in ('camisa', 'marinheiro', 'casaco', 'listrada'):
        data['roupas'][style] = {str(row): [roupa(style, row, side) for side in range(6)] for row in (1, 2, 6)}
    for style in ('escura', 'areia', 'listrada'):
        data['calcas'][style] = [calca(style, side) for side in range(6)]
    for style in ('tenis', 'mocassim', 'sandalia'):
        data['sapatos'][style] = [sapato(style, side) for side in range(6)]
    (OUT / 'componentes.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print('Componentes vetoriais exportados:', OUT / 'componentes.json')


if __name__ == '__main__':
    main()
