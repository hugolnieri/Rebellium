extends GutTest
## Sons: todos os arquivos esperados existem, carregam e o SoundManager toca sem erro.

const SOUNDS: Array[String] = [
	"blade_swing", "blade_swing_heavy", "fang_swing", "hit_blade", "hit_fang", "hit_heavy",
	"footstep_1", "footstep_2", "footstep_3", "jump", "land", "wall_jump", "dash", "weapon_swap",
	"technique", "perfect_dodge", "hurt", "sp_empty", "dummy_warning", "dummy_swing",
]


func test_all_sound_files_load() -> void:
	for sound in SOUNDS:
		var stream := load("res://assets/sfx/%s.wav" % sound) as AudioStream
		assert_not_null(stream, sound)
		if stream != null:
			assert_gt(stream.get_length(), 0.05, sound)


func test_sound_manager_plays_without_errors() -> void:
	var manager := get_tree().root.get_node_or_null("SoundManager")
	assert_not_null(manager)
	manager.play(&"hit_blade", Vector3.ZERO, 0)
	manager.play(&"nao_existe", Vector3.ZERO, 0)  # som ausente é ignorado
	assert_not_null(manager.config)
