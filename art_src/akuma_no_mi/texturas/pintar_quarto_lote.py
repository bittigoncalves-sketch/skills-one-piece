#!/usr/bin/env python3
"""Atlas restantes; desenhos não confirmados são identificados em notas.json."""
import importlib.util
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('pintor_akuma',HERE/'pintar_primeiro_lote.py')
p=importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
p.FRUTAS={
 'aro_aro':('#9a516d','#eea1aa','#632b4e','#789b57','raio'),
 'buki_buki':('#85909e','#d9e0e7','#465663','#876b52','raio'),
 'hito_hito_daibutsu':('#b89129','#ecd16b','#725f1f','#927c46','espiral'),
 'imu':('#352b43','#8b667c','#171322','#685a68','espiral'),
 'mero_mero':('#d9789c','#f3bccb','#9d496e','#6b9f59','espiral'),
 'rocket':('#705594','#c7b4e7','#473c68','#7d9b5a','raio'),
 'ryu_ryu_brachiosaurus':('#a29b32','#d6ce68','#66611f','#a0aa5c','bagas'),
 'ryu_ryu_pachycephalosaurus':('#65a845','#b3df7c','#34692d','#5686b4','bagas'),
 'ryu_ryu_pteranodon':('#8e80b5','#c9b9e0','#584878','#d98937','bagas'),
 'soru_soru':('#cbd1cb','#f5f3e9','#646e6a','#588d57','espiral'),
 'suke_suke':('#8acdd2','#d6f4f1','#52949e','#81a99a','espiral'),
 'tori_tori_phoenix':('#67a64e','#b6d57d','#396b44','#5b9eb5','bagas'),
 'ushi_ushi_giraffe':('#a23855','#db7792','#692a46','#8d9b57','espiral'),
 'zushi_zushi':('#a87871','#e4b3a8','#65444e','#b3717d','espiral'),
}
forms=json.loads((p.ARTE/'formas.json').read_text())['frutas']
for fid in p.FRUTAS:p.make(fid,forms)
