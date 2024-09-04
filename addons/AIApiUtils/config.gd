@tool
extends VBoxContainer

func _ready():
	pass # Replace with function body.

const SAVEPATH = "user://data.api"
func _on_confirm_pressed():
	var data : Array[String] = [$Box2/APIurl.text, $Box2/APIkey.text]
	var save_data = FileAccess.open(SAVEPATH, FileAccess.WRITE)
	save_data.store_var(data)
	save_data.close()
