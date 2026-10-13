class_name CharacterLook
extends Resource
## Aparência do personagem escolhida pelo jogador (menu de personagem, F4). Só visual: não muda gameplay.
## Fica salva em `user://personagem.tres`; o padrão é `config/character_look.tres`.
## Cores de cabelo, pele e olhos são TINTAS (branco = cor original do modelo). As do traje valem só para o
## herói padrão (os personagens do VRoid usam as roupas deles).

const USER_PATH: String = "user://personagem.tres"
const DEFAULT_PATH: String = "res://config/character_look.tres"
## Herói padrão (montado no Blender por tools/blender/build_hero.py).
const HERO_MODEL: String = "res://assets/character/hero.glb"
## Personagens do VRoid trazidos com tools/import_vroid.py.
const MODELS_DIR: String = "res://assets/character/models"

@export_group("Modelo")
## Modelo do personagem (vazio = herói padrão).
@export_file("*.glb") var model_path: String = ""

@export_group("Cores")
@export var hair_color: Color = Color.WHITE
@export var skin_color: Color = Color.WHITE
@export var eye_color: Color = Color.WHITE

@export_group("Traje do herói")
@export var suit_color: Color = Color(0.105, 0.11, 0.165)
@export var seam_color: Color = Color(0.06, 0.063, 0.098)
@export var emblem_color: Color = Color(0.86, 0.88, 0.92)


## Caminho do modelo a carregar (o herói se vazio ou se o arquivo sumiu).
func resolved_model_path() -> String:
	if model_path == "" or not ResourceLoader.exists(model_path):
		return HERO_MODEL
	return model_path


func is_hero() -> bool:
	return resolved_model_path() == HERO_MODEL


## Aparência salva do jogador (ou o padrão do projeto).
static func load_user() -> CharacterLook:
	for path in [USER_PATH, DEFAULT_PATH]:
		if ResourceLoader.exists(path):
			var look := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterLook
			if look != null:
				return look
	return CharacterLook.new()


func save_user() -> Error:
	return ConfigIO.save_full(self, USER_PATH)


## Modelos disponíveis: o herói e os .glb em assets/character/models (nome legível → caminho).
static func available_models() -> Dictionary:
	var models := {"Herói": HERO_MODEL}
	var files := Array(DirAccess.get_files_at(MODELS_DIR)) if DirAccess.dir_exists_absolute(MODELS_DIR) else []
	files.sort()
	for file: String in files:
		# No jogo exportado o .glb vira .glb.import/.remap: o nome do recurso continua sendo o .glb.
		var base := file.trim_suffix(".import").trim_suffix(".remap")
		if base.get_extension() != "glb":
			continue
		var path := MODELS_DIR.path_join(base)
		var label := base.get_basename().replace("_", " ").capitalize()
		if not models.values().has(path):
			models[label] = path
	return models
