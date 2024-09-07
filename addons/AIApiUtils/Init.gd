@tool
extends EditorPlugin

var api_config = preload("res://addons/AIApiUtils/Res/config.tscn").instantiate()

const FORMATSAVE = "res://addons/AIApiUtils/Lib/format.gd"

func _enter_tree():
	add_control_to_bottom_panel(api_config, "VLMAPIConfig")
	add_autoload_singleton("API", "res://addons/AIApiUtils/Api.gd")
	if !FileAccess.file_exists(FORMATSAVE):
		var data = FileAccess.open(FORMATSAVE, FileAccess.WRITE)
		data.store_string("extends Node\n" + "const format_list = []")
		data.close()
	#add_custom_type("AIApi", "Node", preload("res://addons/AIApiUtils/ApiUtils.gd"), \
					#preload("res://addons/AIApiUtils/key1.png"))

func _exit_tree():
	remove_control_from_bottom_panel(api_config)
	api_config.queue_free()
	remove_autoload_singleton("API")
	#remove_custom_type("AIApi")
