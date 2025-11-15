extends RefCounted
class_name GDScriptGameKit

# Unavoidable here, ignore in all cases.
@warning_ignore_start("unsafe_method_access", "unsafe_property_access", "inferred_declaration")

var _gamekit: RefCounted

signal game_center_initialized(initialization: InitializationData)


func _init() -> void:
	if not ClassDB.class_exists("GodotGameKit"):
		return

	_gamekit = ClassDB.instantiate("GodotGameKit")

	_gamekit.game_center_initialized.connect(func(data: Dictionary) -> void:
		var init := InitializationData.new()
		# data comes from C++ as: { "initialized": bool, "error": String }
		init.initialized = data.initialized
		init.error = data.error
		game_center_initialized.emit(init)
	)


func initialize_game_center() -> Signal:
	if not _gamekit:
		return game_center_initialized
	return _gamekit.initialize_game_center()


func is_authenticated() -> bool:
	if not _gamekit:
		return false
	return _gamekit.is_authenticated()


class InitializationData:
	var initialized: bool = false
	var error: String = ""

	func _to_string() -> String:
		var props := {}

		for prop in get_property_list():
			if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			props[prop.name] = self[prop.name]

		return str(props)

@warning_ignore_end
