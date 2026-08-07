"""Viewport 3D em tkinter Canvas — sem GPU, sem lib externa.

Os personagens do jogo são caixas voxel, então desenhar as 6 faces de cada
caixa como polígonos preenchidos, ordenados por profundidade (algoritmo do
pintor), dá uma leitura fiel o bastante para animar. Com 13 ossos = 78 faces,
Python puro roda folgado a 30+ fps.
"""

import math

# Faces de um cubo, indexando os 8 cantos gerados por rig.Rig.caixas().
# Ordem dos cantos: itera x em (-,+), depois y em (-,+), depois z em (-,+).
FACES = [
    (0, 1, 3, 2), (4, 6, 7, 5),   # -X, +X
    (0, 4, 5, 1), (2, 3, 7, 6),   # -Y, +Y
    (0, 2, 6, 4), (1, 5, 7, 3),   # -Z, +Z
]
NORMAIS = [(-1, 0, 0), (1, 0, 0), (0, -1, 0), (0, 1, 0), (0, 0, -1), (0, 0, 1)]

COR_BASE = (0.62, 0.66, 0.72)
COR_SELECAO = (1.00, 0.72, 0.20)
LUZ = (-0.42, 0.78, 0.46)


class Camera:
    def __init__(self):
        self.giro = 0.6      # em torno de Y
        self.altura = 0.25   # elevação
        self.dist = 3.2
        self.alvo = [0.0, 0.85, 0.0]
        self.zoom = 520.0

    def orbitar(self, dx, dy):
        self.giro -= dx * 0.01
        self.altura = max(-1.3, min(1.3, self.altura + dy * 0.01))

    def aproximar(self, passos):
        self.dist = max(0.8, min(12.0, self.dist * (0.9 ** passos)))

    def matriz(self):
        cy, sy = math.cos(self.giro), math.sin(self.giro)
        cp, sp = math.cos(self.altura), math.sin(self.altura)
        # base da câmera: direita, cima, frente
        f = (-sy * cp, -sp, -cy * cp)
        d = (cy, 0.0, -sy)
        u = (d[1] * f[2] - d[2] * f[1], d[2] * f[0] - d[0] * f[2], d[0] * f[1] - d[1] * f[0])
        return d, u, f

    def projetar(self, p, larg, alt):
        d, u, f = self.matriz()
        olho = (self.alvo[0] - f[0] * self.dist,
                self.alvo[1] - f[1] * self.dist,
                self.alvo[2] - f[2] * self.dist)
        v = (p[0] - olho[0], p[1] - olho[1], p[2] - olho[2])
        z = v[0] * f[0] + v[1] * f[1] + v[2] * f[2]
        if z < 0.05:
            z = 0.05
        x = v[0] * d[0] + v[1] * d[1] + v[2] * d[2]
        y = v[0] * u[0] + v[1] * u[1] + v[2] * u[2]
        k = self.zoom / z
        return larg * 0.5 + x * k, alt * 0.5 - y * k, z


class Viewport:
    def __init__(self, canvas):
        self.canvas = canvas
        self.cam = Camera()
        self.selecionado = None
        self._arrastando = None
        canvas.bind("<ButtonPress-1>", self._pressiona)
        canvas.bind("<B1-Motion>", self._arrasta)
        canvas.bind("<ButtonRelease-1>", lambda e: setattr(self, "_arrastando", None))
        canvas.bind("<Button-4>", lambda e: (self.cam.aproximar(1), self.pedir_redraw()))
        canvas.bind("<Button-5>", lambda e: (self.cam.aproximar(-1), self.pedir_redraw()))
        canvas.bind("<MouseWheel>", self._roda)
        self.ao_redesenhar = lambda: None
        self.ao_clicar_osso = lambda papel: None
        self._itens_papel = []

    # -- interação --------------------------------------------------------
    def _pressiona(self, ev):
        self._arrastando = (ev.x, ev.y)
        papel = self._papel_em(ev.x, ev.y)
        if papel:
            self.ao_clicar_osso(papel)

    def _arrasta(self, ev):
        if not self._arrastando:
            return
        dx = ev.x - self._arrastando[0]
        dy = ev.y - self._arrastando[1]
        self._arrastando = (ev.x, ev.y)
        self.cam.orbitar(dx, dy)
        self.pedir_redraw()

    def _roda(self, ev):
        self.cam.aproximar(1 if ev.delta > 0 else -1)
        self.pedir_redraw()

    def _papel_em(self, x, y):
        for item in reversed(self.canvas.find_overlapping(x - 1, y - 1, x + 1, y + 1)):
            for iid, papel in self._itens_papel:
                if iid == item:
                    return papel
        return None

    def pedir_redraw(self):
        self.ao_redesenhar()

    # -- desenho ----------------------------------------------------------
    def desenhar(self, rig, pose):
        c = self.canvas
        c.delete("all")
        self._itens_papel = []
        larg = max(c.winfo_width(), 10)
        alt = max(c.winfo_height(), 10)

        self._chao(larg, alt)

        # coleta as faces de todas as caixas e ordena da mais longe p/ a mais perto
        faces = []
        for papel, cantos in rig.caixas(pose):
            proj = [self.cam.projetar(v, larg, alt) for v in cantos]
            m = pose[papel][0]
            for fi, face in enumerate(FACES):
                pts = [proj[i] for i in face]
                z = sum(p[2] for p in pts) / 4.0
                n = (m[0] * NORMAIS[fi][0] + m[1] * NORMAIS[fi][1] + m[2] * NORMAIS[fi][2],
                     m[3] * NORMAIS[fi][0] + m[4] * NORMAIS[fi][1] + m[5] * NORMAIS[fi][2],
                     m[6] * NORMAIS[fi][0] + m[7] * NORMAIS[fi][1] + m[8] * NORMAIS[fi][2])
                luz = max(0.0, n[0] * LUZ[0] + n[1] * LUZ[1] + n[2] * LUZ[2])
                faces.append((z, papel, pts, 0.42 + 0.58 * luz))
        faces.sort(key=lambda f: -f[0])

        for _z, papel, pts, brilho in faces:
            base = COR_SELECAO if papel == self.selecionado else COR_BASE
            cor = _hex(tuple(min(1.0, ch * brilho) for ch in base))
            contorno = "#ffcc55" if papel == self.selecionado else "#2b2f36"
            iid = c.create_polygon([co for p in pts for co in p[:2]],
                                   fill=cor, outline=contorno, width=1)
            self._itens_papel.append((iid, papel))

        c.create_text(8, 8, anchor="nw", fill="#8b93a1", font=("TkDefaultFont", 8),
                      text="arraste = orbitar · roda = zoom · clique num osso = selecionar")

    def _chao(self, larg, alt):
        c = self.canvas
        c.create_rectangle(0, 0, larg, alt, fill="#1c1f26", outline="")
        passo = 0.5
        n = 8
        for i in range(-n, n + 1):
            a = self.cam.projetar((i * passo, 0, -n * passo), larg, alt)
            b = self.cam.projetar((i * passo, 0, n * passo), larg, alt)
            c.create_line(a[0], a[1], b[0], b[1], fill="#2b3038")
            a = self.cam.projetar((-n * passo, 0, i * passo), larg, alt)
            b = self.cam.projetar((n * passo, 0, i * passo), larg, alt)
            c.create_line(a[0], a[1], b[0], b[1], fill="#2b3038")


def _hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(ch * 255))) for ch in rgb)
