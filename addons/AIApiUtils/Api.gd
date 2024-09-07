extends Node
# 工具接口
var VLMutils = preload("res://addons/AIApiUtils/Lib/VLMUtils.gd").new()

enum IMAGE_Q {HIGH, LOW, AUTO}
const FORMATSAVE = "res://addons/AIApiUtils/Lib/format.gd"
var format_list : Array = []:
	get:
		var format_save = load(FORMATSAVE).new()
		format_list = format_save.format_list
		return format_list
var mod_list : Array = []:
	get:
		mod_list = VLMutils.API_TYPE
		return mod_list

func _ready():
	add_child(VLMutils)

func reset():
	VLMutils.reset()

func save(api_url : String, api_key : String):
	VLMutils.api_save([api_url, api_key])

func run_VLMapi(prompt : String, api_mod : int = 0, timeout : int = 10, image_path : String = "", \
			image_quality : int = IMAGE_Q.AUTO, format : Dictionary = {}) -> String:
	timeout = clampi(timeout, 0, 300)
	api_mod = clampi(api_mod, 0, VLMutils.API_TYPE.size() - 1)
	image_quality = clampi(image_quality, 0, 2)
	return await VLMutils.run_api(prompt, api_mod, image_path, image_quality, timeout, format)

func get_format(format_id : int = 0) -> Dictionary:
	var format_save = load(FORMATSAVE).new()
	if format_save.format_save.size() > 0:
		format_id = clampi(format_id, 0, format_save.format_save.size() - 1)
		return format_save.format_save[format_id]
	else:
		return {"Error" : "NO DATA"}

