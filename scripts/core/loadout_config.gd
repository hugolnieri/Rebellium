class_name LoadoutConfig
extends Resource
## Escolha de arma inicial feita antes de entrar na partida.

const USER_PATH: String = "user://loadout.tres"

@export_group("Equipamento")
@export_range(0, 1, 1) var starting_weapon_slot: int = 0


static func load_user() -> LoadoutConfig:
	if ResourceLoader.exists(USER_PATH):
		var saved := ResourceLoader.load(USER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LoadoutConfig
		if saved != null:
			return saved
	return LoadoutConfig.new()


func save_user() -> Error:
	return ConfigIO.save_full(self, USER_PATH)
