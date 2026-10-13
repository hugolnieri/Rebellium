extends Node
## Autoload "SceneCycler": lista os mapas e abre sua seleção com F3 durante a partida.

const LOADOUT_SCENE: String = "res://scenes/ui/Loadout.tscn"

const SCENES: Array[String] = [
	"res://scenes/arenas/SkyArena.tscn",
	"res://scenes/arenas/CombatArena.tscn",
	"res://scenes/arenas/TrainingCourse.tscn",
	"res://scenes/arenas/Arena.tscn",
]
var open_maps_on_ready: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_scene"):
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == LOADOUT_SCENE:
			return
		open_map_selection()
		get_viewport().set_input_as_handled()


func open_map_selection() -> void:
	open_maps_on_ready = true
	get_tree().change_scene_to_file(LOADOUT_SCENE)


func cycle() -> void:
	var current := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	var index := SCENES.find(current)
	get_tree().change_scene_to_file(SCENES[(index + 1) % SCENES.size()])
