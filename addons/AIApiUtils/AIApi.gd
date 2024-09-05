@tool
extends EditorPlugin

var api_config = preload("res://addons/AIApiUtils/config.tscn").instantiate()

func _enter_tree():
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BR,api_config)
	#add_custom_type("AIApi", "Node", preload("res://addons/AIApiUtils/ApiUtils.gd"), \
					#preload("res://addons/AIApiUtils/key1.png"))
	add_autoload_singleton("API", "res://addons/AIApiUtils/Api.gd")

func _exit_tree():
	remove_control_from_docks(api_config)
	#remove_custom_type("AIApi")
	remove_autoload_singleton("API")
