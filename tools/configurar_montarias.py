"""Classificação inicial, preservando os demais campos do catálogo (inclusive extensões)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "mapas/modelos/catalogo.json"
data = json.loads(path.read_text())
if not any(c["id"] == "montarias" for c in data["categorias"]):
    data["categorias"].append({"id": "montarias", "nome": "Montarias"})
ids = {"caranguejo_grande", "horse", "cavalo_da_vila_leve", "animals__farm__horse_1__base"}
found = []
for model in data["modelos"]:
    if model["id"] in ids:
        for cat in ["pets", "montarias"]:
            if cat not in model.setdefault("categorias", []):
                model["categorias"].append(cat)
        found.append(model["id"])
assert set(found) == ids, f"Modelos ausentes: {ids - set(found)}"
path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n")
print("MONTARIAS_CLASSIFICADAS", ", ".join(found))
