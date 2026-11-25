#!/usr/bin/env python3
"""Segundo lote de atlas; reutiliza a projeção 3D do primeiro lote."""
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('pintor_akuma', HERE / 'pintar_primeiro_lote.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)

p.FRUTAS = {
    'bomu_bomu': ('#332653', '#bb5e73', '#201b3c', '#bc9b51', 'espiral'),
    'gura_gura': ('#365b96', '#b5dbeb', '#20365f', '#74a660', 'magma'),
    'horo_horo': ('#e7d6a0', '#fff5cf', '#302b34', '#899a5b', 'fantasma'),
    'kage_kage': ('#252328', '#5f565f', '#100e14', '#78a36a', 'espiral'),
    'kiro_kiro': ('#d78091', '#f4bdc3', '#a34e61', '#74a660', 'espiral'),
    'mochi_mochi': ('#e6ddc9', '#fff8e9', '#bdb29e', '#9fb55c', 'espiral'),
    'supa_supa': ('#aab5cf', '#f3f2e4', '#50627e', '#74a660', 'raio'),
    'uo_uo_seiryu': ('#268eb1', '#a8dbe7', '#185274', '#8a65a0', 'bagas'),
    'uta_uta': ('#e79eb8', '#ffd9e1', '#b36d89', '#6d9d62', 'espiral'),
    'neko_neko_leopard': ('#e3b346', '#f6d976', '#664123', '#85a95b', 'leopardo'),
}
forms = json.loads((p.ARTE / 'formas.json').read_text())['frutas']
for fruit in p.FRUTAS:
    p.make(fruit, forms)
