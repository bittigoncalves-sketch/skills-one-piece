"""Malha voxelizada do personagem — o fundo sobre o qual se marcam as juntas.

Quem varre a malha é o Godot (`tools/export_mesh.gd`), porque Python não lê
.glb/.fbx/.scn. Aqui só carregamos a casca já pronta e desenhamos.

Desenho: cada voxel vira UM retângulo, não um cubo de 6 faces. Com ~2000 voxels,
6 faces cada daria 12000 itens de canvas e o tkinter engasgaria. Um retângulo
por voxel, ordenado por profundidade, dá a mesma leitura por uma fração do custo.
"""

import json
import os


class Malha:
    def __init__(self, dados):
        self.nome = dados.get("name", "?")
        self.origem = dados.get("source", "")
        self.celula = float(dados.get("cell", 0.05))
        self.base = tuple(dados.get("origin", (0, 0, 0)))
        self.tamanho = tuple(dados.get("size", (1, 1, 1)))
        # centro de cada voxel, já em coordenadas do modelo
        meia = self.celula * 0.5
        self.pontos = [
            (self.base[0] + c[0] * self.celula + meia,
             self.base[1] + c[1] * self.celula + meia,
             self.base[2] + c[2] * self.celula + meia)
            for c in dados.get("voxels", [])
        ]

    @staticmethod
    def de_arquivo(caminho):
        with open(caminho, encoding="utf-8") as f:
            return Malha(json.load(f))

    @property
    def altura(self):
        return self.tamanho[1]

    @property
    def centro_x(self):
        """Plano de simetria: é em torno dele que o marcador A espelha em B."""
        return self.base[0] + self.tamanho[0] * 0.5

    def raio_em(self, y, eixo="x", tolerancia=None):
        """Meia-largura do corpo na altura `y` — usado para engrossar os ossos.

        Sem isso todo osso sairia com a mesma espessura arbitrária; medindo no
        modelo, braço fino e tronco largo saem certos.
        """
        tol = tolerancia if tolerancia is not None else self.celula * 1.5
        i = 0 if eixo == "x" else 2
        centro = self.centro_x if eixo == "x" else self.base[2] + self.tamanho[2] * 0.5
        maior = 0.0
        for p in self.pontos:
            if abs(p[1] - y) <= tol:
                maior = max(maior, abs(p[i] - centro))
        return maior if maior > 0 else self.celula


def listar_malhas(pasta):
    idx = os.path.join(pasta, "index.json")
    if os.path.exists(idx):
        with open(idx, encoding="utf-8") as f:
            return [m["name"] for m in json.load(f).get("models", [])]
    if not os.path.isdir(pasta):
        return []
    return sorted(n[:-5] for n in os.listdir(pasta)
                  if n.endswith(".json") and n != "index.json")
