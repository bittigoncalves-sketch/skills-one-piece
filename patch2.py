import re

with open('TreeAndFruitGenerator.gd', 'r') as f:
    content = f.read()

# Add "sem_fruta" to the _todas_as_definicoes list
patch_fruit = """	return [
		{
			"id": "sem_fruta",
			"nome": "Fruta da Normalidade (Sem Fruta)",
			"foliage_color": Color(0.3, 0.3, 0.3),
			"trunk_color": Color(0.5, 0.5, 0.5),
			"fruit_color": Color(0.8, 0.8, 0.8),
			"fruit_glow": Color(0.1, 0.1, 0.1),
			"leaf_shape": "canopy"
		},"""

content = content.replace("	return [", patch_fruit, 1)

# Modify get_tree_definitions to include "sem_fruta"
patch_get = """		if com_poder.has(str(d.get("id", ""))) or str(d.get("id", "")) == "sem_fruta":"""
content = content.replace('		if com_poder.has(str(d.get("id", ""))):', patch_get)

with open('TreeAndFruitGenerator.gd', 'w') as f:
    f.write(content)
