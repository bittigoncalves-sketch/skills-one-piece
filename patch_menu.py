import sys

with open("src/ui/MainMenu.gd", "r") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "func _ready() -> void:" in line:
        lines.insert(i+1, "\n\tvar t = Timer.new()\n\tt.wait_time = 0.5\n\tt.one_shot = true\n\tt.timeout.connect(func(): _on_singleplayer_pressed())\n\tadd_child(t)\n\tt.start()\n")
        break

with open("src/ui/MainMenu.gd", "w") as f:
    f.writelines(lines)
