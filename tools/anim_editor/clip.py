"""Clipe de animação: keyframes por papel, interpolação e exportação .tres.

O jogo toca `Animation` com faixas "<Papel>:rotation" via
ProceduralAnimator.play_baked(). O `.res` é binário e Python não escreve; mas o
Godot lê `.tres` (texto) exatamente igual — testado. Então o editor grava
`.tres` direto em assets/animations/, sem precisar do Godot no caminho.
"""

import json
import os

from rig import PAPEIS


class Clip:
    def __init__(self, nome="novo", duracao=1.0, loop=True):
        self.nome = nome
        self.duracao = float(duracao)
        self.loop = bool(loop)
        # papel -> lista de (tempo, (x, y, z)), sempre ordenada por tempo
        self.faixas = {}

    # -- carga / gravação em JSON (formato de trabalho do editor) ---------
    @staticmethod
    def de_json(caminho):
        with open(caminho, encoding="utf-8") as f:
            d = json.load(f)
        c = Clip(d.get("name", "novo"), d.get("length", 1.0), d.get("loop", True))
        for papel, chaves in d.get("tracks", {}).items():
            c.faixas[papel] = [(float(t), tuple(float(x) for x in v)) for t, v in chaves]
            c.faixas[papel].sort(key=lambda k: k[0])
        return c

    def para_json(self, caminho):
        d = {
            "name": self.nome,
            "length": self.duracao,
            "loop": self.loop,
            "tracks": {p: [[t, list(v)] for t, v in ks] for p, ks in self.faixas.items() if ks},
        }
        with open(caminho, "w", encoding="utf-8") as f:
            json.dump(d, f, indent=1)

    # -- edição -----------------------------------------------------------
    def por_chave(self, papel, tempo, valor):
        ks = self.faixas.setdefault(papel, [])
        for i, (t, _) in enumerate(ks):
            if abs(t - tempo) < 1e-4:
                ks[i] = (tempo, tuple(valor))
                return
        ks.append((tempo, tuple(valor)))
        ks.sort(key=lambda k: k[0])

    def tirar_chave(self, papel, tempo):
        ks = self.faixas.get(papel)
        if not ks:
            return False
        for i, (t, _) in enumerate(ks):
            if abs(t - tempo) < 1e-4:
                ks.pop(i)
                if not ks:
                    del self.faixas[papel]
                return True
        return False

    def tempos_de_chave(self, papel=None):
        if papel:
            return [t for t, _ in self.faixas.get(papel, [])]
        ts = set()
        for ks in self.faixas.values():
            ts.update(t for t, _ in ks)
        return sorted(ts)

    # -- leitura ----------------------------------------------------------
    def amostrar(self, tempo):
        """Rotação de cada papel no instante dado (interpolação linear)."""
        out = {}
        for papel, ks in self.faixas.items():
            if not ks:
                continue
            out[papel] = _interp(ks, tempo)
        return out

    def fechar_loop(self):
        """Copia a primeira chave para o fim de cada faixa.

        Sem isso a última chave não casa com a primeira e o loop dá um tranco —
        é o erro mais comum ao autorar ciclo de caminhada à mão.
        """
        n = 0
        for papel, ks in self.faixas.items():
            if not ks:
                continue
            t0, v0 = ks[0]
            if t0 > 1e-4:
                continue
            if abs(ks[-1][0] - self.duracao) < 1e-4:
                ks[-1] = (self.duracao, v0)
            else:
                ks.append((self.duracao, v0))
            n += 1
        return n

    # -- exportação para o jogo -------------------------------------------
    def para_tres(self, caminho):
        """Grava Animation em texto. O Godot carrega igual a um .res."""
        linhas = ['[gd_resource type="Animation" format=3]\n', "\n[resource]\n",
                  "resource_name = \"%s\"\n" % self.nome,
                  "length = %.4f\n" % self.duracao,
                  "loop_mode = %d\n" % (1 if self.loop else 0)]
        i = 0
        for papel in PAPEIS:
            ks = self.faixas.get(papel)
            if not ks:
                continue
            tempos = ", ".join("%.4f" % t for t, _ in ks)
            trans = ", ".join("1" for _ in ks)
            vals = ", ".join("Vector3(%.5f, %.5f, %.5f)" % v for _, v in ks)
            linhas += [
                'tracks/%d/type = "value"\n' % i,
                "tracks/%d/imported = false\n" % i,
                "tracks/%d/enabled = true\n" % i,
                'tracks/%d/path = NodePath("%s:rotation")\n' % (i, papel),
                "tracks/%d/interp = 1\n" % i,
                "tracks/%d/loop_wrap = true\n" % i,
                "tracks/%d/keys = {\n" % i,
                '"times": PackedFloat32Array(%s),\n' % tempos,
                '"transitions": PackedFloat32Array(%s),\n' % trans,
                '"update": 0,\n',
                '"values": [%s]\n}\n' % vals,
            ]
            i += 1
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "w", encoding="utf-8") as f:
            f.write("".join(linhas))
        return i


def _interp(ks, t):
    if t <= ks[0][0]:
        return ks[0][1]
    if t >= ks[-1][0]:
        return ks[-1][1]
    for i in range(len(ks) - 1):
        t0, v0 = ks[i]
        t1, v1 = ks[i + 1]
        if t0 <= t <= t1:
            f = 0.0 if t1 - t0 < 1e-9 else (t - t0) / (t1 - t0)
            return tuple(v0[j] + (v1[j] - v0[j]) * f for j in range(3))
    return ks[-1][1]


def listar_clipes(pasta):
    if not os.path.isdir(pasta):
        return []
    return sorted(n[:-5] for n in os.listdir(pasta)
                  if n.endswith(".json") and n != "index.json")
