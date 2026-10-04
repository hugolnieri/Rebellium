extends CanvasLayer
## HUD do jogador: barra de SP e vida (placeholder). Só lê estado; não altera gameplay.

const BAR_SIZE := Vector2(320, 18)

var player: Player
var _sp_bar: ProgressBar
var _hp_bar: ProgressBar
var _sp_fill: StyleBoxFlat
var _sp_label: Label


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	root.position = Vector2(24, -96)
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	_hp_bar = _make_bar(root, "VIDA")
	_hp_bar.value = 100.0
	_sp_bar = _make_bar(root, "SP")
	_sp_label = Label.new()
	_sp_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_sp_label)


func _make_bar(parent: Control, title: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(48, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.show_percentage = false
	bar.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.11, 0.85)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	if title == "SP":
		_sp_fill = fill
	else:
		fill.bg_color = Color(0.62, 1.0, 0.12)
	return bar


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null:
			return
		_hp_bar.get_theme_stylebox("fill").bg_color = player.feedback_config.hp_bar_color
	var fb := player.feedback_config
	_sp_bar.max_value = player.config.sp_max
	_sp_bar.value = player.sp.current
	_sp_fill.bg_color = fb.sp_exhausted_color if player.sp.exhausted else fb.sp_bar_color
	_sp_label.text = "%d / %d%s" % [roundi(player.sp.current), roundi(player.config.sp_max),
		"   EXAUSTO" if player.sp.exhausted else ""]
