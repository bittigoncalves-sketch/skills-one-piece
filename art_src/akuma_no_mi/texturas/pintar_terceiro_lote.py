#!/usr/bin/env python3
"""Terceiro lote de atlas, projetado sobre os voxels atuais."""
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('pintor_akuma', HERE / 'pintar_primeiro_lote.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
p.FRUTAS = {
    'batto_batto': ('#762d7b','#b96db5','#461e58','#698e48','espiral'),
    'bisu_bisu': ('#ba8c4e','#e4bd7c','#765432','#766043','bagas'),
    'inu_inu_okuchi_no_makami': ('#d5772a','#f6b55e','#925020','#8b5a33','espiral'),
    'inu_inu_wolf': ('#8b809f','#c3b9d1','#50455f','#837c92','espiral'),
    'kira_kira': ('#6eaccf','#d6f3ff','#39769e','#6a9a59','raio'),
    'moku_moku': ('#d5d9e1','#f7f8fb','#8b96aa','#8cab60','espiral'),
    'mori_mori': ('#9d485d','#df8f9a','#543c32','#839243','bagas'),
    'neko_neko_sabertiger': ('#deb74b','#fff4d3','#715333','#91a85f','sabertiger'),
    'nikyu_nikyu': ('#db72b8','#ffc3e5','#9b3e83','#75a856','espiral'),
    'riki_riki': ('#d13ca4','#fb92da','#832d7f','#66a2a7','espiral'),
}
forms=json.loads((p.ARTE/'formas.json').read_text())['frutas']
for fid in p.FRUTAS: p.make(fid,forms)
