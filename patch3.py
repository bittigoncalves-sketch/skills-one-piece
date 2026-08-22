import re

with open('Player.gd', 'r') as f:
    content = f.read()

patch = """		if not fruit_skills.has(current_fruit_id):
			if current_fruit_id == "":
				print("🚫 Sem Akuma no Mi — pegue uma fruta numa árvore para usar poderes.")
			elif current_fruit_id == "sem_fruta":
				print("🚫 Você comeu a Fruta da Normalidade. Suas skills não fazem nada.")
			else:"""

content = content.replace("""		if not fruit_skills.has(current_fruit_id):
			if current_fruit_id == "":
				print("🚫 Sem Akuma no Mi — pegue uma fruta numa árvore para usar poderes.")
			else:""", patch)

with open('Player.gd', 'w') as f:
    f.write(content)
