extends Node
## Autoload "SceneCycler": F3 alterna entre as cenas jogáveis (arena de combate, percurso, arena livre).

const SCENES: Array[String] = [
	"res://scenes/arenas/CombatArena.tscn",
	"res://scenes/arenas/TrainingCourse.tscn",
	"res://scenes/arenas/Arena.tscn",
]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_scene"):
		cycle()


func cycle() -> void:
	var current := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	var index := SCENES.find(current)
	get_tree().change_scene_to_file(SCENES[(index + 1) % SCENES.size()])
